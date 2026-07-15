//
//  GroupsOutboxMirror.swift
//  Yala
//
//  Espejo durable del `GroupSyncOutbox` en el App Group (endurecimiento pre-flag B2 — riesgo A1 del
//  canal de GRUPOS, molde EXACTO de `SyncOutboxMirror`).
//
//  PROBLEMA (idéntico al personal): Yala migra con SwiftData LIGHTWEIGHT PURO. Una migración que recree
//  la tabla `GroupSyncOutbox` VACÍA borra deltas de gastos/liquidaciones de grupo aplicados-local-pero-
//  no-subidos, SIN tombstone → divergencia silenciosa del canal de Grupos (el Merkle B1 la vería, pero
//  la remediación es re-PULL: el delta local perdido no se recupera).
//
//  MECANISMO: directorio de archivos en el App Group (`.../GroupsSyncOutboxMirror/`, un `.atomic` JSON
//  por delta, DISJUNTO del `CloudSyncOutboxMirror/` personal). Se escribe DENTRO del drain de Grupos, en
//  la MISMA vuelta síncrona ANTES del `insert+save` (regla Q3: sin `await` entremedias). Se borra al
//  purgar la fila (applied/noop del push) Y al dead-letterizarla — **las dead-letter se EXCLUYEN del
//  espejo** (decisión B2 documentada: el espejo es red de DURABILIDAD de PENDIENTES; una fila rechazada
//  permanente re-hidratada como viva re-atacaría el server en loop. El re-drive de `yala_not_authorized`
//  RE-ESCRIBE la entry al revivir la fila — vuelve a ser pendiente). Al boot,
//  `GroupsSyncClient.rehydrateOutboxFromMirror` re-inserta por DIFF owner-scoped.
//
//  GUARDARRAÍL M1 (device compartido): `fieldsJSON` contiene MONTOS → (a) el sign-out purga TODO el
//  directorio (`GroupsSyncClient.teardownForSignOut`); (b) el rehydrate filtra DURO por `userID` (las
//  entries de otra identidad se IGNORAN — ni se re-insertan ni se borran).
//

import CryptoKit
import Foundation

// MARK: - DTO

/// Una fila del outbox de Grupos espejada a un archivo del App Group. `nonisolated` (DTO puro Codable
/// cross-proceso, regla Swift 6 bajo default-MainActor). Espeja `OutboxMirrorEntry` + `groupID` (el eje
/// del wire de Grupos). `op`/`tombstoneReason` PRESERVADOS (un tombstone re-hidratado como upsert
/// resucitaría la entidad en otros devices). Las filas dead-letter NUNCA llegan aquí.
nonisolated struct GroupsOutboxMirrorEntry: Codable, Equatable {
    /// El `sub` de la sesión que produjo el delta (owner-scoping M1). Obligatorio.
    let userID: String
    /// Identidad de sync de la entidad mutada (el `id` de la fila `Split*`; dedup local para SplitGroup).
    let syncID: UUID
    /// `group_id` del wire (`groupZoneID` / `cloudKitZoneID`).
    let groupID: String
    /// Tipo de entidad (`GroupSyncEntityType.*` = nombre de clase).
    let entityType: String
    /// Operación (`SyncOutboxOp.rawValue`): "upsert" | "tombstone".
    let op: String
    /// HLC canónico c1. FIJADO — nunca se regenera (invariante §d.5).
    let hlc: String
    /// Identidad de idempotencia end-to-end de esta mutación. Preservada.
    let clientMutationID: UUID
    /// `fields` del delta serializado por el codec c1. "{}" en tombstone.
    let fieldsJSON: String
    /// `field_hlcs` como JSON plano. `nil` en tombstone.
    let fieldHlcsJSON: String?
    /// Razón del tombstone (auditoría). `nil` en upsert.
    let tombstoneReason: String?
    /// Autor con el que la fila se re-inserta = `GroupsSyncClient.outboxSaveAuthor` (echo-suppression).
    let author: String
    /// Cuándo se encoló la fila original (diagnóstico/orden; la verdad temporal es `hlc`).
    let createdAt: Date
}

// MARK: - GroupsOutboxMirror

/// Espejo del `GroupSyncOutbox` como directorio de archivos del App Group. `nonisolated` (I/O + JSON).
/// `directoryURL` inyectable para tests. Reusa `SyncOutboxMirrorError` (mismos modos de fallo).
nonisolated struct GroupsOutboxMirror {

    /// Nombre del subdirectorio dentro del contenedor App Group (DISJUNTO del personal).
    static let directoryName = "GroupsSyncOutboxMirror"

    /// Autor constante de la re-inserción. DEBE coincidir con `GroupsSyncClient.outboxSaveAuthor`
    /// (echo-suppression del drain de Grupos). Literal por la misma razón que el espejo personal;
    /// la paridad la fija `GroupsSyncHardeningTests.mirrorAuthor_matchesGroupsOutboxAuthor`.
    static let author = "GroupsSyncOutbox"

    /// El directorio `GroupsSyncOutboxMirror/` (App Group en prod, temp en tests).
    let directoryURL: URL

    // MARK: Init

    /// Producción: resuelve `<AppGroup>/GroupsSyncOutboxMirror/`. `nil` si el App Group no está
    /// disponible (mismo fail-soft que `SyncOutboxMirror`).
    init?(appGroupIdentifier: String = WidgetURLHelper.appGroupIdentifier) {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            #if DEBUG
            print("GroupsOutboxMirror: App Group container unavailable for \(appGroupIdentifier)")
            #endif
            return nil
        }
        self.directoryURL = container.appendingPathComponent(Self.directoryName, isDirectory: true)
    }

    /// Inyectable (tests): apunta directo al directorio espejo.
    init(directoryURL: URL) {
        self.directoryURL = directoryURL
    }

    // MARK: Filenames

    /// Nombre DETERMINISTA por `(syncID, hlc)` (mismo esquema SHA-256 que el personal). `(syncID, hlc)`
    /// identifica unívocamente una fila (el HLC avanza por cada `appendRow`).
    static func fileName(syncID: UUID, hlc: String) -> String {
        let key = "\(syncID.uuidString)\u{1}\(hlc)"
        let digest = SHA256.hash(data: Data(key.utf8))
        return digest.map { String(format: "%02x", $0) }.joined() + ".json"
    }

    // MARK: Directorio

    private func ensureDirectory() throws {
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    // MARK: Escritura

    /// Escribe un archivo `.atomic` para la entry. Lanza tipado (el drain hace do/catch y NO aborta:
    /// la History es backup redundante).
    func write(_ entry: GroupsOutboxMirrorEntry) throws {
        try ensureDirectory()
        let data: Data
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            data = try encoder.encode(entry)
        } catch {
            throw SyncOutboxMirrorError.encodeFailed(underlying: error)
        }
        let url = directoryURL.appendingPathComponent(Self.fileName(syncID: entry.syncID, hlc: entry.hlc))
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw SyncOutboxMirrorError.writeFailed(underlying: error)
        }
    }

    // MARK: Borrado (consume al purgar/dead-letterizar)

    /// Borra el archivo espejo de `(syncID, hlc)`. Idempotente. Lo llama `applyResults` al purgar
    /// (applied/noop) Y al dead-letterizar (las dead-letter se excluyen del espejo).
    func remove(syncID: UUID, hlc: String) {
        let url = directoryURL.appendingPathComponent(Self.fileName(syncID: syncID, hlc: hlc))
        removeItem(at: url)
    }

    /// Red M1(a): borra TODO el directorio espejo (sign-out — `GroupsSyncClient.teardownForSignOut`).
    func purgeAll() {
        for url in allFileURLs() { removeItem(at: url) }
    }

    private func removeItem(at url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            #if DEBUG
            print("GroupsOutboxMirror: error removing \(url.lastPathComponent): \(error)")
            #endif
        }
    }

    // MARK: Lectura

    /// Entries del `userID` dado (owner-scoping M1: las de OTRA identidad se IGNORAN), ordenadas por
    /// `creationDate` ASCENDENTE (orden natural de re-inserción).
    func entriesForUser(_ userID: String) -> [GroupsOutboxMirrorEntry] {
        allDecoded()
            .filter { $0.entry.userID == userID }
            .sorted { $0.creationDate < $1.creationDate }
            .map(\.entry)
    }

    private func allFileURLs() -> [URL] {
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: [.creationDateKey],
                options: .skipsHiddenFiles
            )
            return contents.filter { $0.pathExtension.lowercased() == "json" }
        } catch {
            return []  // directorio inexistente (aún sin escrituras) → sin entries
        }
    }

    /// Decodifica todos los archivos, descartando (con log) los corruptos — NO se borran (podrían ser
    /// de otro userID o de una versión futura).
    private func allDecoded() -> [(entry: GroupsOutboxMirrorEntry, creationDate: Date)] {
        let decoder = JSONDecoder()
        var result: [(entry: GroupsOutboxMirrorEntry, creationDate: Date)] = []
        for url in allFileURLs() {
            let creationDate = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            do {
                let data = try Data(contentsOf: url)
                let entry = try decoder.decode(GroupsOutboxMirrorEntry.self, from: data)
                result.append((entry, creationDate))
            } catch {
                #if DEBUG
                print("GroupsOutboxMirror: error decoding \(url.lastPathComponent): \(error)")
                #endif
            }
        }
        return result
    }
}
