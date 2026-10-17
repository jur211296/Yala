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

        /// Un criterio, para decir en el vacío qué se miró («monto, nota, subcategoría y fecha»).
        enum Field: Equatable, CaseIterable {
            case amount, note, subcategory, date
        }

        /// Los criterios activos, en el orden del menú «Coincidir por».
        var activeFields: [Field] {
            Field.allCases.filter { field in
                switch field {
                case .amount: return amount
                case .note: return note
                case .subcategory: return subcategory
                case .date: return date
                }
            }
        }
    }

    /// Datos mínimos de un registro para construir su firma de duplicado.
    ///
    /// `createdAt`, `isDeletable` y `tiebreak` solo cuentan para elegir cuál se queda al «Quitar repetidos»
    /// (`duplicateGroups`); la firma no los mira.
    struct Candidate<ID: Hashable> {
        let id: ID
        let amount: Double          // con signo (gasto negativo / ingreso positivo)
        let currencyCode: String
        let note: String?
        let subcategoryID: String?  // Subcategory.shortcutID.uuidString
        let date: Date
        /// Cuándo se creó el registro (`TransactionItem.createdAt`).
        var createdAt: Date = .distantPast
        /// `false` si viene de un grupo: eso se borra desde el grupo (`RecordBulkActionLogic`).
        var isDeletable: Bool = true
        /// Desempate estable cuando todo lo demás coincide (p. ej. el `syncID`).
        var tiebreak: String = ""
        /// La cuenta del registro. Entra SIEMPRE en la firma, sea cual sea el criterio: «Quitar repetidos» borra, y el
        /// mismo almuerzo de S/ 20 pagado una vez en efectivo y otra con tarjeta no es una copia (borrar uno cambiaría el
        /// saldo de otra cuenta). Un Excel importado dos veces repite también la cuenta.
        var accountID: String? = nil
    }

    /// Cuántos posibles duplicados hay y en cuántos grupos, para el encabezado del modo
    /// («2 posibles duplicados en 1 grupo»).
    struct Tally: Equatable {
        let duplicates: Int
        let groups: Int
    }

    /// Lo que hace «Quitar repetidos»: deja uno por grupo y borra el resto, salvo lo que viene de un grupo
    /// (Grupos), que se queda y se cuenta para decirlo en la confirmación.
    struct RemovalPlan<ID: Hashable>: Equatable {
        let toDelete: [ID]
        let keptGroupRecords: Int
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

    /// Los registros agrupados por firma, solo los grupos de ≥2 (auditoría UX 2.2 · L8-11: la lista del modo salía
    /// mezclada por fecha y cada par no se veía junto).
    ///
    /// **Cuál se queda** (el primero de cada grupo), con un criterio determinista:
    /// 1. Si alguno viene de un grupo (`isDeletable == false`), ese: no se puede borrar desde Registros, así que
    ///    quedarse con otro dejaría dos.
    /// 2. Si no, el creado primero (`createdAt`): en un Excel importado dos veces, el original es el de la primera
    ///    importación.
    /// 3. Empate: la fecha del registro más antigua, y después `tiebreak`.
    /// El resto del grupo sigue el mismo orden. Los grupos van del más reciente al más antiguo (por la fecha más
    /// reciente de sus registros), como la lista normal.
    static func duplicateGroups<ID: Hashable>(
        in candidates: [Candidate<ID>],
        criteria: Criteria,
        calendar: Calendar = .current
    ) -> [[Candidate<ID>]] {
        guard !criteria.isEmpty else { return [] }

        var bySignature: [String: [Candidate<ID>]] = [:]
        var signatureOrder: [String] = []
        for candidate in candidates {
            let key = signature(candidate, criteria: criteria, calendar: calendar)
            if bySignature[key] == nil { signatureOrder.append(key) }
            bySignature[key, default: []].append(candidate)
        }

        let groups: [(key: String, members: [Candidate<ID>])] = signatureOrder.compactMap { key in
            guard let members = bySignature[key], members.count >= 2 else { return nil }
            return (key, members.sorted { keepsBefore($0, $1) })
        }

        return groups.sorted { lhs, rhs in
            let lhsLatest = lhs.members.map(\.date).max() ?? .distantPast
            let rhsLatest = rhs.members.map(\.date).max() ?? .distantPast
            if lhsLatest != rhsLatest { return lhsLatest > rhsLatest }
            return lhs.key < rhs.key
        }.map(\.members)
    }

    /// `true` si `lhs` tiene más derecho a quedarse que `rhs` (ver `duplicateGroups`).
    static func keepsBefore<ID: Hashable>(_ lhs: Candidate<ID>, _ rhs: Candidate<ID>) -> Bool {
        if lhs.isDeletable != rhs.isDeletable { return !lhs.isDeletable }
        if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
        if lhs.date != rhs.date { return lhs.date < rhs.date }
        return lhs.tiebreak < rhs.tiebreak
    }

    static func tally<ID: Hashable>(_ groups: [[Candidate<ID>]]) -> Tally {
        Tally(duplicates: groups.reduce(0) { $0 + $1.count }, groups: groups.count)
    }

    /// Deja el primero de cada grupo (el que `duplicateGroups` puso delante) y borra los demás que se puedan borrar.
    static func removalPlan<ID: Hashable>(_ groups: [[Candidate<ID>]]) -> RemovalPlan<ID> {
        var toDelete: [ID] = []
        var kept = 0
        for group in groups {
            for extra in group.dropFirst() {
                if extra.isDeletable {
                    toDelete.append(extra.id)
                } else {
                    kept += 1
                }
            }
        }
        return RemovalPlan(toDelete: toDelete, keptGroupRecords: kept)
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
        var parts: [String] = ["c:" + (candidate.accountID ?? "")]
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
