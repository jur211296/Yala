//
//  PagoLogoPropioSync.swift
//  Yala
//
//  Modo Nube: las fotos de los logos propios de los pagos planificados (encargo del 2026-11-20). El pago guarda solo la
//  referencia (`ScheduledPayment.customLogoRef`, columna `custom_logo_ref`, manifest v7); la foto vive en Supabase Storage,
//  bucket PRIVADO `scheduled-payment-logos`, carpeta `<user_id>/` (políticas de `qa/cloud/g32_01`).
//
//  SIN COLA. Cada pasada pide la lista de la carpeta (una petición) y la compara con los pagos de este teléfono
//  (`PagoLogoPropioPlan`, lógica pura):
//   - foto sin referencia → se le da una (un pago que llegó con foto desde iCloud al pasar a la nube);
//   - foto con referencia que no está en la carpeta → se sube (lo elegido sin conexión sube aquí);
//   - referencia sin foto que sí está en la carpeta → se baja (lo que eligió el otro teléfono);
//   - archivo de la carpeta que ningún pago nombra → se borra (foto cambiada, pago borrado, en este teléfono o en otro).
//  Lo último, solo tras un pull COMPLETO, hablando ya la v7 y con el archivo de más de 24 h: el otro teléfono puede haber
//  subido la foto nueva y no haber subido aún el pago que la nombra, un pull a medias no sabe qué nombra el servidor, y
//  con un Worker v6 este teléfono no recibe ninguna referencia y borraría las fotos de los demás.
//
//  Cuándo corre: al final de cada ciclo del motor (`CloudSyncRuntime`, paso 5.55), como mucho cada 5 min salvo que este
//  teléfono acabe de guardar una foto (`noteLocalChange`). Al ELIMINAR la cuenta, `deleteAll` vacía la carpeta antes del
//  borrado de la cuenta.
//
//  Por qué Storage directo y no el Worker: la frontera es la RLS de Storage (cada usuario, su carpeta), con el mismo JWT de
//  Supabase que ya usa el motor. El Worker solo cambia de manifest.
//

import Foundation
import SwiftData

// MARK: - La decisión (pura)

nonisolated enum PagoLogoPropioPlan {

    /// Un pago planificado de este teléfono, visto por lo que importa aquí.
    struct Local: Equatable {
        let id: UUID
        let ref: String?
        let hasPhoto: Bool
    }

    /// Un archivo de la carpeta del usuario.
    struct Remote: Equatable {
        let name: String
        let createdAt: Date?
    }

    struct Actions: Equatable {
        var assignRef: [UUID] = []
        var upload: [String] = []
        var download: [String] = []
        var delete: [String] = []
    }

    /// Lo que un archivo huérfano tiene que esperar antes de borrarse.
    static let orphanGrace: TimeInterval = 24 * 60 * 60

    /// `remote == nil`: la lista no se pudo leer; solo se dan referencias.
    static func actions(local: [Local], remote: [Remote]?, pullComplete: Bool, now: Date) -> Actions {
        var result = Actions()
        for payment in local where payment.hasPhoto && payment.ref == nil {
            result.assignRef.append(payment.id)
        }
        guard let remote else { return result }
        let remoteNames = Set(remote.map(\.name))
        let validRefs = local.compactMap { payment -> (String, Bool)? in
            guard let ref = payment.ref, PagoLogoPropioFoto.esReferenciaValida(ref) else { return nil }
            return (ref, payment.hasPhoto)
        }
        var upload = Set<String>(), download = Set<String>()
        for (ref, hasPhoto) in validRefs {
            if hasPhoto, !remoteNames.contains(ref) { upload.insert(ref) }
            if !hasPhoto, remoteNames.contains(ref) { download.insert(ref) }
        }
        result.upload = upload.sorted()
        result.download = download.sorted()
        if pullComplete {
            let named = Set(validRefs.map(\.0))
            result.delete = remote.filter { file in
                guard !named.contains(file.name), let created = file.createdAt else { return false }
                return now.timeIntervalSince(created) > orphanGrace
            }.map(\.name).sorted()
        }
        return result
    }
}

// MARK: - Storage

protocol PagoLogoPropioStorage: Sendable {
    func list(userID: String, token: String) async throws -> [PagoLogoPropioPlan.Remote]
    func upload(_ data: Data, name: String, userID: String, token: String) async throws
    func download(name: String, userID: String, token: String) async throws -> Data
    func delete(names: [String], userID: String, token: String) async throws
}

enum PagoLogoPropioStorageError: Error {
    case notConfigured
    case http(Int)
    case unexpectedListing
}

/// Supabase Storage por REST, con el JWT de la sesión y la anon key (`CloudBackendConfig`).
struct PagoLogoPropioSupabaseStorage: PagoLogoPropioStorage {
    static let bucket = "scheduled-payment-logos"

    let session: URLSession

    init(session: URLSession = .shared) { self.session = session }

    private func request(_ path: String, method: String, token: String) throws -> URLRequest {
        guard let base = CloudBackendConfig.supabaseURL else { throw PagoLogoPropioStorageError.notConfigured }
        var request = URLRequest(url: base.appendingPathComponent("storage/v1/" + path))
        request.httpMethod = method
        request.timeoutInterval = 30
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(CloudBackendConfig.anonKey, forHTTPHeaderField: "apikey")
        return request
    }

    private func check(_ response: URLResponse) throws {
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else { throw PagoLogoPropioStorageError.http(status) }
    }

    func list(userID: String, token: String) async throws -> [PagoLogoPropioPlan.Remote] {
        var request = try request("object/list/\(Self.bucket)", method: "POST", token: token)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "prefix": userID, "limit": 1000, "offset": 0,
            "sortBy": ["column": "name", "order": "asc"],
        ])
        let (data, response) = try await session.data(for: request)
        try check(response)
        // Una respuesta que no es la lista no se lee como «carpeta vacía»: volvería a subirlo todo.
        guard let items = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw PagoLogoPropioStorageError.unexpectedListing
        }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return items.compactMap { item in
            // Las «carpetas» vienen con `id` nulo: solo cuentan los archivos.
            guard let name = item["name"] as? String, item["id"] is String else { return nil }
            let created = (item["created_at"] as? String).flatMap { iso.date(from: $0) }
            return PagoLogoPropioPlan.Remote(name: name, createdAt: created)
        }
    }

    func upload(_ data: Data, name: String, userID: String, token: String) async throws {
        var request = try request("object/\(Self.bucket)/\(userID)/\(name)", method: "POST", token: token)
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.setValue("true", forHTTPHeaderField: "x-upsert")
        let (_, response) = try await session.upload(for: request, from: data)
        try check(response)
    }

    func download(name: String, userID: String, token: String) async throws -> Data {
        let request = try request("object/authenticated/\(Self.bucket)/\(userID)/\(name)", method: "GET", token: token)
        let (data, response) = try await session.data(for: request)
        try check(response)
        return data
    }

    func delete(names: [String], userID: String, token: String) async throws {
        guard !names.isEmpty else { return }
        var request = try request("object/\(Self.bucket)", method: "DELETE", token: token)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["prefixes": names.map { "\(userID)/\($0)" }])
        let (_, response) = try await session.data(for: request)
        try check(response)
    }
}

// MARK: - La pasada

@MainActor
final class PagoLogoPropioSync {

    static let shared = PagoLogoPropioSync()

    /// Entre dos pasadas sin cambios de este teléfono.
    static let minimumInterval: TimeInterval = 5 * 60

    var storage: PagoLogoPropioStorage = PagoLogoPropioSupabaseStorage()
    var session: () async -> (userID: String, token: String)? = {
        guard let userID = CloudAuthService.shared.currentUserID,
              let token = await CloudAuthService.shared.accessToken(), !token.isEmpty else { return nil }
        return (userID.lowercased(), token)
    }

    private var lastRun: Date?
    private var localChangePending = false
    private var running = false

    /// Este teléfono acaba de guardar una foto: la próxima pasada no espera los 5 min.
    func noteLocalChange() { localChangePending = true }

    /// La pasada del ciclo del motor. Nunca lanza: lo que falla se reintenta en la siguiente.
    func runIfDue(context: ModelContext, pullComplete: Bool, now: Date = .now) async {
        guard !running else { return }
        if !localChangePending, let lastRun, now.timeIntervalSince(lastRun) < Self.minimumInterval { return }
        running = true
        defer { running = false }
        lastRun = now
        localChangePending = false
        await run(context: context, pullComplete: pullComplete, now: now)
    }

    func run(context: ModelContext, pullComplete: Bool, now: Date = .now) async {
        let payments: [ScheduledPayment]
        do {
            payments = try context.fetch(FetchDescriptor<ScheduledPayment>())
        } catch {
            #if DEBUG
            print("PagoLogoPropioSync: Error: \(error)")
            #endif
            return
        }
        let local = payments.map { PagoLogoPropioPlan.Local(id: $0.id, ref: $0.customLogoRef,
                                                            hasPhoto: $0.customLogoData != nil) }
        // Las referencias que faltan se dan siempre, también sin red: el drain las sube con el pago.
        var actions = PagoLogoPropioPlan.actions(local: local, remote: nil, pullComplete: false, now: now)
        if !actions.assignRef.isEmpty {
            let ids = Set(actions.assignRef)
            for payment in payments where ids.contains(payment.id) {
                payment.customLogoRef = PagoLogoPropioFoto.nuevaReferencia()
            }
            save(context)
        }
        guard let auth = await session() else { return }
        let remote: [PagoLogoPropioPlan.Remote]
        do {
            remote = try await storage.list(userID: auth.userID, token: auth.token)
        } catch {
            log(error)
            return
        }
        let current = payments.filter { !$0.isDeleted && $0.modelContext != nil }
        let knowsEveryReference = pullComplete && SyncCapability.declaredLevel >= SyncCapability.customLogoSince
        actions = PagoLogoPropioPlan.actions(
            local: current.map { .init(id: $0.id, ref: $0.customLogoRef, hasPhoto: $0.customLogoData != nil) },
            remote: remote, pullComplete: knowsEveryReference, now: now)

        for ref in actions.upload {
            guard let data = current.first(where: { $0.customLogoRef == ref })?.customLogoData else { continue }
            do { try await storage.upload(data, name: ref, userID: auth.userID, token: auth.token) } catch { log(error) }
        }
        var downloaded = false
        for ref in actions.download {
            do {
                let data = try await storage.download(name: ref, userID: auth.userID, token: auth.token)
                // Solo una imagen, y solo si el pago sigue nombrando esa foto (pudo cambiar mientras bajaba).
                guard PhotoIntake.image(from: data, maxEdge: PagoLogoPropioFoto.lado) != nil else { continue }
                for payment in current where payment.customLogoRef == ref && payment.customLogoData == nil
                    && !payment.isDeleted {
                    payment.customLogoData = data
                    downloaded = true
                }
            } catch { log(error) }
        }
        if downloaded { save(context) }
        if !actions.delete.isEmpty {
            do { try await storage.delete(names: actions.delete, userID: auth.userID, token: auth.token) } catch { log(error) }
        }
    }

    /// Al eliminar la cuenta en la nube: vacía la carpeta del usuario. Lo que falle queda en un bucket que nadie puede
    /// leer (la RLS pide la sesión de ese usuario, que deja de existir).
    func deleteAll(userID: String, token: String) async {
        let id = userID.lowercased()
        do {
            let files = try await storage.list(userID: id, token: token)
            try await storage.delete(names: files.map(\.name), userID: id, token: token)
        } catch {
            log(error)
        }
    }

    private func save(_ context: ModelContext) {
        do { try context.save() } catch {
            #if DEBUG
            print("PagoLogoPropioSync: Error: \(error)")
            #endif
        }
    }

    private func log(_ error: Error) {
        #if DEBUG
        print("PagoLogoPropioSync: Error: \(error)")
        #endif
    }

    #if DEBUG
    func _testReset() {
        lastRun = nil
        localChangePending = false
        running = false
    }
    #endif
}
