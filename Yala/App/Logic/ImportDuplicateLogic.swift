//
//  ImportDuplicateLogic.swift
//  Yala
//
//  Qué filas de un archivo parecen ya importadas (H11 de la auditoría del import 2.2, ticket
//  `import-has-no-duplicate-detection`). Hasta el 2026-11-22 importar dos veces el mismo extracto lo duplicaba todo, sin
//  aviso.
//
//  Cada fila tiene una huella —día, importe, moneda, cuenta y nota— y se compara CONTANDO contra lo que ya hay: si el
//  archivo trae dos cafés iguales y en la cuenta ya hay uno, uno es duplicado y el otro entra. Así dos filas iguales
//  legítimas en un archivo nuevo entran las dos, y reimportar el mismo archivo las marca todas.
//

import Foundation

nonisolated enum ImportDuplicateLogic {

    /// Lo que identifica un movimiento al reimportar. La categoría no entra: si la persona lo recategorizó después, sigue
    /// siendo el mismo movimiento.
    struct Fingerprint: Hashable, Sendable {
        /// «2026-10-27» en la zona del teléfono.
        let day: String
        /// El importe en diezmilésimas, con su signo.
        let amount: Int64
        let currencyCode: String
        /// La cuenta a la que va (o en la que está).
        let accountKey: String
        /// La nota sin mayúsculas ni espacios de más; vacía si no hay.
        let note: String
    }

    static func fingerprint(
        date: Date, amount: Double, currencyCode: String, accountKey: String, note: String?, calendar: Calendar
    ) -> Fingerprint {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let day = String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
        let scaled = (amount * 10_000).rounded()
        let minor = scaled.isFinite ? Int64(clamping: Int(exactly: scaled) ?? 0) : 0
        return Fingerprint(
            day: day, amount: minor, currencyCode: currencyCode.uppercased(), accountKey: accountKey,
            note: normalizedNote(note))
    }

    static func normalizedNote(_ note: String?) -> String {
        (note ?? "")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .lowercased()
    }

    /// Los índices de las filas que parecen ya importadas: por cada huella, tantas como movimientos iguales hay ya en la
    /// base, en el orden del archivo.
    static func duplicateIndices(rows: [Fingerprint], existing: [Fingerprint]) -> Set<Int> {
        var available: [Fingerprint: Int] = [:]
        for fingerprint in existing { available[fingerprint, default: 0] += 1 }
        var result: Set<Int> = []
        for (index, fingerprint) in rows.enumerated() {
            guard let left = available[fingerprint], left > 0 else { continue }
            available[fingerprint] = left - 1
            result.insert(index)
        }
        return result
    }
}
