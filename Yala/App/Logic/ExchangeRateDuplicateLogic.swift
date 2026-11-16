//
//  ExchangeRateDuplicateLogic.swift
//  Yala
//
//  Qué filas de `ExchangeRate` son la MISMA tasa (mismo día, misma base) y cómo se funden en una. Lo usa la subida de
//  «Activar la nube» antes de enumerar (`MigrationSnapshotUploader.fuseDuplicateExchangeRates`).
//
//  Por qué existe (card i9wh, medido el 2026-11-05 en el iPhone de pruebas): «Subir tus datos» contó 3333 elementos para
//  2 registros y 2 cuentas, y tardó 459 s de los 505 de la activación. El store tenía 3234 filas de tipos de cambio para
//  383 días: hasta 9 copias del mismo día. `persistRate` no duplica en local (busca por `dateKey`), pero cada instalación
//  siembra su año de tasas ANTES de que llegue el import de iCloud, y el espejo junta las copias de todas. La subida
//  las mandaba todas.
//

import Foundation

enum ExchangeRateDuplicateLogic {

    /// Lo que la lógica necesita de una fila. `id` es opaco (el índice del llamador).
    struct Row: Equatable {
        let id: Int
        let dateKey: String
        let base: String
        /// `syncID` en minúsculas. Las filas sin identidad no entran: no suben (`identityGap`) y no tienen con qué elegir
        /// superviviente de forma estable entre dispositivos.
        let syncID: String
        let timestamp: Date?
        let rates: [String: Double]
    }

    /// Una fusión: la fila que se queda, con lo que tiene que quedar escrito, y las que se borran.
    struct Fusion: Equatable {
        let survivorID: Int
        let mergedRates: [String: Double]
        let mergedTimestamp: Date?
        let loserIDs: [Int]
    }

    /// Agrupa por `(dateKey, base)` y devuelve una fusión por grupo con más de una fila.
    ///
    /// - **Superviviente: el menor `syncID`.** Dos dispositivos del mismo iCloud que fundan a la vez eligen la MISMA fila,
    ///   así que entre los dos nunca borran las dos (regla «Fundir duplicados que llegan de dos dispositivos» de
    ///   `swiftdata-cloudkit.md`). «Gana la más nueva» dependería de qué vio cada uno.
    /// - **Las tasas se funden, no se elige una copia**: una copia puede traer solo las 2-4 divisas del histórico y otra
    ///   las 54 de hoy. Se aplican de la más vieja a la más nueva por `timestamp` (sin hora primero; empate, por
    ///   `syncID`), y en cada divisa gana la más nueva, como en `ExchangeRateMergeLogic.merged`.
    /// - **El timestamp es el más reciente** de las copias que lo traen.
    static func fusions(_ rows: [Row]) -> [Fusion] {
        let groups = Dictionary(grouping: rows) { GroupKey(dateKey: $0.dateKey, base: $0.base) }
        return groups.values
            .filter { $0.count > 1 }
            .map { fuse($0) }
            .sorted { $0.survivorID < $1.survivorID }
    }

    private struct GroupKey: Hashable {
        let dateKey: String
        let base: String
    }

    private static func fuse(_ group: [Row]) -> Fusion {
        let bySyncID = group.sorted { $0.syncID < $1.syncID }
        // `group` nunca está vacío: viene de `Dictionary(grouping:)`.
        let survivor = bySyncID[0]
        let oldestFirst = group.sorted { lhs, rhs in
            switch (lhs.timestamp, rhs.timestamp) {
            case let (l?, r?) where l != r: return l < r
            case (nil, _?): return true
            case (_?, nil): return false
            default: return lhs.syncID < rhs.syncID
            }
        }
        var rates: [String: Double] = [:]
        for row in oldestFirst {
            rates = ExchangeRateMergeLogic.merged(existing: rates, incoming: row.rates)
        }
        let timestamp = group.compactMap(\.timestamp).max()
        return Fusion(
            survivorID: survivor.id,
            mergedRates: rates,
            mergedTimestamp: timestamp,
            loserIDs: bySyncID.dropFirst().map(\.id).sorted()
        )
    }
}
