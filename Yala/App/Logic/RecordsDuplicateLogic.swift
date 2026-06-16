//
//  RecordsDuplicateLogic.swift
//  Yala
//
//  Pure-logic de detección de registros potencialmente duplicados en la vista
//  de Registros. Match EXACTO sobre criterios seleccionables (monto, nota,
//  subcategoría, fecha): dos o más registros que comparten la "firma" construida
//  con los criterios activos se consideran duplicados.
//
//  Testeable sin `ModelContext` (R8): opera sobre `Candidate` genérico en el `ID`.
//  El callsite (RecordsViewModel) mapea `TransactionItem` → `Candidate` y excluye
//  transferencias/ajustes antes de invocar.
//

import Foundation

enum RecordsDuplicateLogic {

    /// Qué campos deben coincidir para considerar duplicado. Al menos uno debe estar
    /// activo; si todos están en `false`, la detección no devuelve nada.
    struct Criteria: Equatable {
        var amount: Bool
        var note: Bool
        var subcategory: Bool
        var date: Bool

        var isEmpty: Bool { !amount && !note && !subcategory && !date }
    }

    /// Datos mínimos de un registro para construir su firma de duplicado.
    struct Candidate<ID: Hashable> {
        let id: ID
        let amount: Double          // con signo (gasto negativo / ingreso positivo)
        let currencyCode: String
        let note: String?
        let subcategoryID: String?  // Subcategory.shortcutID.uuidString
        let date: Date
    }

    /// Devuelve los `id` de todo registro que comparte su firma con al menos otro
    /// (grupos de ≥2). `criteria.isEmpty` → conjunto vacío.
    static func duplicateIDs<ID: Hashable>(
        in candidates: [Candidate<ID>],
        criteria: Criteria,
        calendar: Calendar = .current
    ) -> Set<ID> {
        guard !criteria.isEmpty else { return [] }

        var groups: [String: [ID]] = [:]
        for candidate in candidates {
            let key = signature(candidate, criteria: criteria, calendar: calendar)
            groups[key, default: []].append(candidate.id)
        }

        var duplicates: Set<ID> = []
        for (_, ids) in groups where ids.count >= 2 {
            duplicates.formUnion(ids)
        }
        return duplicates
    }

    /// Firma de coincidencia construida SOLO con los criterios activos.
    /// - Monto: valor con signo (2 decimales) + `currencyCode` → un gasto −50 no
    ///   coincide con un ingreso +50, ni 50 USD con 50 PEN.
    /// - Nota: normalizada (trim + lowercase); nil/vacía → "".
    /// - Subcategoría: `subcategoryID` o "".
    /// - Fecha: inicio del día calendario (`Calendar` inyectable — nunca `.current`
    ///   en lógica testeada).
    static func signature<ID: Hashable>(
        _ candidate: Candidate<ID>,
        criteria: Criteria,
        calendar: Calendar = .current
    ) -> String {
        var parts: [String] = []
        if criteria.amount {
            parts.append("a:" + String(format: "%.2f", candidate.amount) + ":" + candidate.currencyCode)
        }
        if criteria.note {
            let normalized = (candidate.note ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            parts.append("n:" + normalized)
        }
        if criteria.subcategory {
            parts.append("s:" + (candidate.subcategoryID ?? ""))
        }
        if criteria.date {
            let day = calendar.startOfDay(for: candidate.date)
            parts.append("d:" + String(Int(day.timeIntervalSince1970)))
        }
        return parts.joined(separator: "|")
    }
}
