//
//  ExchangeRateDuplicateLogic.swift
//  Yala
//
//  Qué filas de `ExchangeRate` son la MISMA tasa (mismo día, misma base) y cómo se funden en una. Lo usan la subida de
//  «Activar la nube» antes de enumerar (`MigrationSnapshotUploader.fuseDuplicateExchangeRates`), la limpieza diaria de
//  `ExchangeRateService.cleanUpStoredRatesIfDue` y, para LEER un día con varias filas, el converter (`mergedDayRates`).
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

    // MARK: - Leer un día con varias filas

    /// Una fila tal como la lee quien convierte. A diferencia de `Row`, admite filas SIN identidad: en `.icloud` casi
    /// ninguna tasa tiene `syncID`, y leerlas no borra nada, así que no hace falta un superviviente estable.
    struct DayRow: Equatable {
        let syncID: String?
        let timestamp: Date?
        let rates: [String: Double]
    }

    /// Las tasas de UN día cuando hay varias filas con su clave (ticket
    /// `duplicate-exchange-rate-rows-pick-an-arbitrary-rate`). Hasta este arreglo el converter se quedaba con
    /// `results.first` sin orden, y dos iPhone del mismo usuario —o dos arranques del mismo— convertían el mismo
    /// movimiento con copias distintas (medido en staging: hasta un 12,6 % de diferencia).
    ///
    /// La regla es la de `fusions`, para que leer un día repetido y leerlo después de fundirlo den lo mismo: de la más
    /// vieja a la más nueva (`appliesBefore`), y en cada divisa gana la más nueva. Una tasa inservible (0, negativa, no
    /// finita) no pisa a una buena de otra copia: se descarta antes de fundir, como hace el converter con la suya.
    static func mergedDayRates(_ rows: [DayRow]) -> [String: Double] {
        var merged: [String: Double] = [:]
        for row in rows.sorted(by: { appliesBefore($0, $1) }) {
            merged = ExchangeRateMergeLogic.merged(
                existing: merged, incoming: row.rates.filter { CurrencyConverter.isUsableRate($0.value) })
        }
        return merged
    }

    /// La posición de la fila que se aplica la ÚLTIMA (la que gana en cada divisa que trae), o `nil` sin filas. Para
    /// quien necesita una fila concreta y no unas tasas: escribir sobre ella o enseñarla.
    static func newestIndex(_ rows: [DayRow]) -> Int? {
        guard var best = rows.indices.first else { return nil }
        for index in rows.indices.dropFirst() where appliesBefore(rows[best], rows[index]) { best = index }
        return best
    }

    /// El orden en que se aplican las copias de un día. Total y sin depender del orden de llegada, para que dos
    /// dispositivos con las mismas filas lean lo mismo: hora (sin hora primero), `syncID` (sin identidad primero),
    /// cuántas divisas trae (la más completa gana) y, como último desempate, el contenido.
    static func appliesBefore(_ lhs: DayRow, _ rhs: DayRow) -> Bool {
        switch (lhs.timestamp, rhs.timestamp) {
        case let (l?, r?) where l != r: return l < r
        case (nil, _?): return true
        case (_?, nil): return false
        default: break
        }
        switch (lhs.syncID, rhs.syncID) {
        case let (l?, r?) where l != r: return l < r
        case (nil, _?): return true
        case (_?, nil): return false
        default: break
        }
        if lhs.rates.count != rhs.rates.count { return lhs.rates.count < rhs.rates.count }
        return canonical(lhs.rates) < canonical(rhs.rates)
    }

    private static func canonical(_ rates: [String: Double]) -> String {
        rates.keys.sorted().map { "\($0)=\(rates[$0] ?? 0)" }.joined(separator: ";")
    }

    // MARK: - Claves de fecha imposibles

    /// `true` si la clave no es un día gregoriano `yyyy-MM-dd` creíble (ticket
    /// `exchange-rate-date-keys-follow-the-phone-calendar`). Hasta ese arreglo los formatters de las claves no fijaban
    /// calendario, y un iPhone en calendario budista guardaba hoy como `2569-…` y uno en japonés como `0008-…`: claves
    /// que ningún otro dispositivo busca y que suben a la nube. No se re-claven, se descartan: el año japonés no dice de
    /// qué era es, y la tasa de ese día se vuelve a pedir si alguien la necesita.
    ///
    /// Creíble = año entre 1900 y el siguiente al actual, mes 1-12 y día 1-31. Un tope más fino no hace falta: lo que
    /// escribe otro calendario cae lejísimos (5 siglos o 2 milenios).
    static func isImplausibleDateKey(_ key: String, currentYear: Int) -> Bool {
        let parts = key.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2])
        else { return true }
        return year < 1900 || year > currentYear + 1 || !(1...12).contains(month) || !(1...31).contains(day)
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
