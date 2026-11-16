//
//  PendingGroupImportStore.swift
//  Yala
//
//  El import de Splitwise o Tricount que espera a que su gente se una al grupo. Uno por grupo (zona), en un fichero JSON
//  de Application Support de ESTE teléfono.
//
//  Por qué un fichero y no un `@Model`: lo que espera es una lista de aristas por nombre del export y a qué miembro
//  corresponde cada nombre. Ponerlo en el store de Grupos sería un campo o una tabla nueva del canal (manifest, backend y
//  despliegue), y el encargo prohíbe cambios de esquema en Production sin el GO de Jürgen. Lo creado ya está en el
//  grupo (son saldos iniciales normales) y viaja como siempre; lo que vive aquí es solo lo que falta por crear.
//  Precio aceptado, anotado en el ticket: si el dueño cambia de teléfono antes de que todos se unan, lo pendiente no
//  viaja; los saldos que faltan se pueden poner a mano en «Añadir saldo inicial».
//

import Foundation
import Observation

/// Lo que espera de un import.
struct PendingGroupImport: Codable, Equatable, Sendable {
    let zoneID: String
    let source: ImportedGroupSnapshot.Source
    let people: [String]
    let balances: [String: [String: Int]]
    let debts: [ImportedDebt]
    /// Persona del export → `SplitMember.id.uuidString`.
    var mapping: [String: String]
    /// Ids de las aristas ya creadas como saldo inicial.
    var applied: Set<String>
    let createdAt: Date

    /// Quién falta por emparejar (sin miembro elegido todavía).
    var pendingPeople: [String] {
        ImportedDebtPlanLogic.pendingPeople(debts: debts, applied: applied, people: people, mapping: mapping)
    }

    var isComplete: Bool {
        debts.allSatisfy { applied.contains($0.id) }
    }
}

@MainActor
@Observable
final class PendingGroupImportStore {

    static let shared = PendingGroupImportStore(directory: PendingGroupImportStore.defaultDirectory)

    static var defaultDirectory: URL {
        URL.applicationSupportDirectory.appending(path: "GroupImports", directoryHint: .isDirectory)
    }

    private let directory: URL
    private(set) var imports: [String: PendingGroupImport] = [:]

    /// Lee lo guardado al nacer, no en el primer `pending(for:)`: ese lo pide un `body`, y escribir `imports` mientras
    /// SwiftUI evalúa la vista es mutar estado observado en mitad de un render.
    init(directory: URL) {
        self.directory = directory
        imports = Self.load(from: directory)
    }

    func pending(for zoneID: String) -> PendingGroupImport? {
        imports[zoneID]
    }

    func save(_ pending: PendingGroupImport) {
        imports[pending.zoneID] = pending
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(pending)
            try data.write(to: fileURL(for: pending.zoneID), options: .atomic)
        } catch {
            #if DEBUG
            print("PendingGroupImportStore: Error: \(error)")
            #endif
        }
    }

    func remove(zoneID: String) {
        imports[zoneID] = nil
        let url = fileURL(for: zoneID)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            #if DEBUG
            print("PendingGroupImportStore: Error: \(error)")
            #endif
        }
    }

    private static func load(from directory: URL) -> [String: PendingGroupImport] {
        guard FileManager.default.fileExists(atPath: directory.path) else { return [:] }
        var result: [String: PendingGroupImport] = [:]
        do {
            let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            for file in files where file.pathExtension == "json" {
                do {
                    let pending = try JSONDecoder().decode(PendingGroupImport.self, from: Data(contentsOf: file))
                    result[pending.zoneID] = pending
                } catch {
                    #if DEBUG
                    print("PendingGroupImportStore: Error: \(error)")
                    #endif
                }
            }
        } catch {
            #if DEBUG
            print("PendingGroupImportStore: Error: \(error)")
            #endif
        }
        return result
    }

    private func fileURL(for zoneID: String) -> URL {
        let safe = zoneID.map { $0.isLetter || $0.isNumber || $0 == "-" ? $0 : "_" }
        return directory.appending(path: String(safe) + ".json")
    }
}
