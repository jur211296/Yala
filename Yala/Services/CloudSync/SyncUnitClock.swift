//
//  SyncUnitClock.swift
//  Yala
//
//  Fuente LOCAL de HLC por-unidad por fila (Modo Nube, incremento I8f-2, D-A). El apply de I8f-1
//  descartaba los unit-HLCs remotos tras usarlos y el outbox solo conserva los HLCs de lo PENDIENTE →
//  no existía la señal que el desempate del transfer-pair (SERIO 4) necesita: "¿qué lado editó `money`
//  más recientemente?". Esta tabla la materializa:
//   - **DRAIN** (`appendUpsert`, MISMO save que la fila de outbox): unidades emitidas → HLC acuñado.
//   - **APPLY** (`applyToEntity`, MISMO save de página): unidades APLICADAS (no las saltadas por el
//     guard D-1 — la saltada conserva el HLC local pendiente que el drain ya escribió) → HLC remoto.
//   - **Tombstone** (drain Y apply): la fila de clock de ese syncID se BORRA (higiene; si el modelo
//     resucita, drain/apply la re-pueblan).
//  Merge = MAX por unidad (comparación `HLC.parse` estructurada, nunca string).
//
//  IMPORTANTE — NUNCA se espeja a CloudKit: vive en el store sync-meta (`cloudKitDatabase: .none`).
//  Es CACHE DERIVABLE: no necesita espejo A1 — si se recrea vacía (lightweight migration), los
//  reconcilers entran en su rama conservadora "sin señal → no tocar" (visible por `reconcilerNoSignal`)
//  hasta que drain/apply la re-pueblen. Degrada a reconciliación DIFERIDA, nunca a reconciliar MAL.
//

import Foundation
import SwiftData

extension CloudSyncSchemaVersions {
    /// Versión de schema de `SyncUnitClock` (testigo A1 en cada fila). v1 (I8f-2).
    static let syncUnitClock = 1
}

/// Una fila por entidad sincronizada: el último HLC conocido POR UNIDAD de coherencia.
@Model
final class SyncUnitClock {

    /// Identidad de sync de la fila de negocio.
    var syncID: UUID = UUID()

    /// Tabla Postgres de la entidad (`tx_items`, …) — coordina con el wire, no con la clase Swift.
    var entityTable: String = ""

    /// Mapa `{unit: hlc46}` serializado (JSON keys ordenadas — determinista).
    var unitHlcsJSON: String = "{}"

    /// Última vez que el mapa se tocó (diagnóstico; la verdad temporal son los HLCs del mapa).
    var updatedAt: Date = Date.now

    /// Versión del schema bajo la que se materializó esta fila (testigo A1).
    var schemaVersion: Int = CloudSyncSchemaVersions.syncUnitClock

    init(
        syncID: UUID,
        entityTable: String,
        unitHlcsJSON: String,
        updatedAt: Date = .now,
        schemaVersion: Int = CloudSyncSchemaVersions.syncUnitClock
    ) {
        self.syncID = syncID
        self.entityTable = entityTable
        self.unitHlcsJSON = unitHlcsJSON
        self.updatedAt = updatedAt
        self.schemaVersion = schemaVersion
    }
}

// MARK: - SyncUnitClockStore (helpers de acceso; fetch CONCRETO, merge MAX)

/// Operaciones sobre `SyncUnitClock`. Los llamadores (drain/apply/reconcilers) las ejecutan DENTRO de
/// sus propios saves — aquí no se hace `save()` nunca (la atomicidad la decide el caller).
@MainActor
enum SyncUnitClockStore {

    /// Fila de clock de un `syncID` (fetch concreto — regla inviolable `#Predicate`).
    static func row(syncID: UUID, context: ModelContext) -> SyncUnitClock? {
        var d = FetchDescriptor<SyncUnitClock>(predicate: #Predicate { $0.syncID == syncID })
        d.fetchLimit = 1
        do {
            return try context.fetch(d).first
        } catch {
            #if DEBUG
            print("SyncUnitClockStore.row fetch falló: \(error)")
            #endif
            return nil
        }
    }

    /// Upsert con merge MAX por unidad: cada unidad conserva el HLC MÁS RECIENTE entre el existente y
    /// el nuevo (comparación estructurada). Un HLC nuevo no parseable se ignora (con rastro); uno
    /// existente no parseable se reemplaza por el nuevo (auto-cura de una fila corrupta).
    static func upsert(
        syncID: UUID, entityTable: String, unitHlcs: [String: String], context: ModelContext,
        now: Date = .now
    ) {
        guard !unitHlcs.isEmpty else { return }
        let existing = row(syncID: syncID, context: context)
        var merged = decodeMap(existing?.unitHlcsJSON)
        for (unit, newRaw) in unitHlcs {
            guard let newHLC = try? HLC.parse(newRaw) else {
                #if DEBUG
                print("SyncUnitClockStore.upsert: HLC no parseable para unidad \(unit): \(newRaw)")
                #endif
                continue
            }
            if let currentRaw = merged[unit] {
                do {
                    let current = try HLC.parse(currentRaw)
                    if newHLC > current { merged[unit] = newRaw }
                } catch {
                    // Auto-cura: el existente corrupto se reemplaza por el nuevo (con rastro).
                    #if DEBUG
                    print("SyncUnitClockStore.upsert: HLC existente corrupto en \(unit), auto-cura: \(error)")
                    #endif
                    merged[unit] = newRaw
                }
            } else {
                merged[unit] = newRaw  // ausente → el nuevo manda
            }
        }
        let json = encodeMap(merged)
        if let existing {
            existing.entityTable = entityTable
            existing.unitHlcsJSON = json
            existing.updatedAt = now
        } else {
            context.insert(SyncUnitClock(syncID: syncID, entityTable: entityTable,
                                         unitHlcsJSON: json, updatedAt: now))
        }
    }

    /// Borra la fila de clock de un `syncID` (higiene del tombstone — drain y apply). No-op si no existe.
    static func delete(syncID: UUID, context: ModelContext) {
        if let existing = row(syncID: syncID, context: context) {
            context.delete(existing)
        }
    }

    /// HLC de UNA unidad, parseado. `nil` = sin fila / unidad ausente / no parseable → el reconciler
    /// toma su rama conservadora "sin señal".
    static func unitHLC(syncID: UUID, unit: String, context: ModelContext) -> HLC? {
        guard let row = row(syncID: syncID, context: context) else { return nil }
        guard let raw = decodeMap(row.unitHlcsJSON)[unit] else { return nil }
        do {
            return try HLC.parse(raw)
        } catch {
            #if DEBUG
            print("SyncUnitClockStore.unitHLC: HLC corrupto para \(unit): \(error)")
            #endif
            return nil
        }
    }

    // MARK: JSON del mapa

    static func decodeMap(_ json: String?) -> [String: String] {
        guard let json, !json.isEmpty else { return [:] }
        do {
            return try JSONDecoder().decode([String: String].self, from: Data(json.utf8))
        } catch {
            #if DEBUG
            print("SyncUnitClockStore.decodeMap: JSON corrupto (mapa vacío → señal degradada): \(error)")
            #endif
            return [:]
        }
    }

    static func encodeMap(_ map: [String: String]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        do {
            return String(decoding: try encoder.encode(map), as: UTF8.self)
        } catch {
            #if DEBUG
            print("SyncUnitClockStore.encodeMap error: \(error)")
            #endif
            return "{}"
        }
    }
}
