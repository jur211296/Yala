//
//  BulkEditLogic.swift
//  Yala
//
//  «Editar varios» (auditoría UX 2.2 · L8-13): se elige primero y se aplica después. Aquí lo que queda pendiente
//  y las decisiones de qué se enseña (qué tienen hoy los elegidos, qué va a cambiar, en qué moneda va el monto),
//  sin vistas. Las operaciones siguen en `RecordsViewModel.bulkUpdate*`.
//

import Foundation
import SwiftData

/// Lo que el usuario ha elegido cambiar y todavía no se ha aplicado. `nil` (o vacío) = ese campo no cambia.
struct BulkEditChanges {
    var account: Account?
    var subcategory: Subcategory?
    var tagsToAdd: [Tag] = []
    var tagsToRemove: [Tag] = []
    /// `""` borra la nota de todos; `nil` no la toca.
    var note: String?
    /// En valor absoluto: cada registro conserva su signo (gasto o ingreso).
    var amount: Double?

    var isEmpty: Bool {
        account == nil && subcategory == nil && tagsToAdd.isEmpty && tagsToRemove.isEmpty
            && note == nil && amount == nil
    }

    /// Lo que identifica lo pendiente, para que la hoja vuelva a medir los bloqueos cada vez que cambia.
    struct Signature: Equatable {
        let account: PersistentIdentifier?
        let subcategory: PersistentIdentifier?
        let tagsToAdd: [PersistentIdentifier]
        let tagsToRemove: [PersistentIdentifier]
        let note: String?
        let amount: Double?
    }

    var signature: Signature {
        Signature(
            account: account?.persistentModelID,
            subcategory: subcategory?.persistentModelID,
            tagsToAdd: tagsToAdd.map(\.persistentModelID),
            tagsToRemove: tagsToRemove.map(\.persistentModelID),
            note: note,
            amount: amount
        )
    }

    var changedOptions: Set<BulkEditOption> {
        var options: Set<BulkEditOption> = []
        if account != nil { options.insert(.account) }
        if subcategory != nil { options.insert(.subcategory) }
        if !tagsToAdd.isEmpty || !tagsToRemove.isEmpty { options.insert(.tag) }
        if note != nil { options.insert(.note) }
        if amount != nil { options.insert(.amount) }
        return options
    }
}

enum BulkEditLogic {

    /// Qué tienen hoy los elegidos en un campo.
    enum Current: Equatable {
        /// Todos lo comparten (`nil` = todos lo tienen vacío, p. ej. sin nota).
        case same(String?)
        /// Hay `n` valores distintos.
        case distinct(Int)
    }

    /// `values` son los del campo, uno por registro elegido (`nil` = vacío). Una nota vacía y una sin nota cuentan
    /// como lo mismo.
    static func current(_ values: [String?]) -> Current {
        let normalized = values.map { value -> String? in
            guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return value
        }
        var seen: [String?] = []
        for value in normalized where !seen.contains(value) {
            seen.append(value)
        }
        if seen.count == 1, let only = seen.first { return .same(only) }
        return .distinct(seen.count)
    }

    /// La moneda del campo «Monto»: la de la cuenta nueva si se va a cambiar (todos quedarán en ella), o la que
    /// comparten hoy los elegidos. Con monedas distintas y sin cuenta nueva, `nil`: el mismo número no significaría
    /// lo mismo en cada registro, así que el monto no se ofrece.
    static func amountCurrency(selectedCurrencies: [String], pendingAccountCurrency: String?) -> String? {
        if let pendingAccountCurrency { return normalizeCurrencyCode(pendingAccountCurrency) }
        let unique = Set(selectedCurrencies.map(normalizeCurrencyCode))
        guard unique.count == 1 else { return nil }
        return unique.first
    }

    /// El aviso de moneda sale antes de aplicar, y solo si la cuenta nueva cambia la moneda de alguno.
    static func changesCurrency(selectedCurrencies: [String], destination: String) -> Bool {
        let target = normalizeCurrencyCode(destination)
        return selectedCurrencies.contains { normalizeCurrencyCode($0) != target }
    }

    /// Una línea del resumen «Vas a cambiar en 3 registros:».
    struct SummaryLine: Equatable {
        let option: BulkEditOption
        let value: String
    }

    /// Las líneas del resumen en el orden de la lista de opciones. Cada valor llega ya escrito por la vista
    /// (nombre de cuenta, monto con su moneda…); `noNote` es el texto de «nota vacía».
    static func summaryLines(
        account: String?,
        subcategory: String?,
        tagsAdded: [String],
        tagsRemoved: [String],
        note: String?,
        amount: String?,
        noNote: String
    ) -> [SummaryLine] {
        var lines: [SummaryLine] = []
        if let account { lines.append(.init(option: .account, value: account)) }
        if let subcategory { lines.append(.init(option: .subcategory, value: subcategory)) }
        if !tagsAdded.isEmpty || !tagsRemoved.isEmpty {
            let parts = tagsAdded.map { "+\($0)" } + tagsRemoved.map { "−\($0)" }
            lines.append(.init(option: .tag, value: parts.joined(separator: ", ")))
        }
        if let note {
            let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
            lines.append(.init(option: .note, value: trimmed.isEmpty ? noNote : trimmed))
        }
        if let amount { lines.append(.init(option: .amount, value: amount)) }
        return lines
    }
}
