//
//  GroupFormDiscardLogic.swift
//  Yala
//
//  Decisión 39 de la revisión 2.3 (F1 + F3, 2026-11-09): en Grupos, la X y deslizar la hoja preguntan antes de tirar lo
//  escrito, en «Nuevo gasto», «Saldar» y «Saldo inicial»; cambiar de grupo en «Nuevo gasto» conserva lo escrito, y
//  «Nuevo gasto» abre en el último grupo donde apuntaste un gasto.
//

import Foundation

/// Cuándo un formulario de Grupos pregunta antes de cerrarse. Lo de ahora se compara con lo que había al abrir (lo
/// precargado incluido): solo pregunta si la persona cambió algo. Sin foto de partida todavía, no pregunta.
enum GroupFormDiscardLogic {
    static func asksBeforeDiscarding<Snapshot: Equatable>(current: Snapshot, baseline: Snapshot?) -> Bool {
        guard let baseline else { return false }
        return current != baseline
    }
}

/// Lo que «Nuevo gasto» se lleva al cambiar de grupo (F3). Quién pagó y el reparto no viajan: son personas del grupo de
/// antes. La moneda sí, porque el importe se escribió en ella.
struct GroupExpenseCarryOver {
    var expenseDescription: String
    var amountString: String
    var note: String
    var date: Date
    var currencyCode: String
    /// Categoría y cuenta son tuyas, no del grupo: siguen valiendo en el otro.
    var subcategory: Subcategory?
    var account: Account?

    /// Hay algo escrito que conservar. Sin nada, cambiar de grupo abre el formulario limpio, como antes, y no avisa.
    var hasContent: Bool {
        !expenseDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || AmountInputHelper.parseDecimal(amountString) > 0
            || !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// El último grupo donde apuntaste un gasto en este dispositivo: ahí abre «Nuevo gasto» (F3). Si ya no admite gastos
/// (archivado, sales, congelado), abre en el primero de la lista, como antes.
enum LastExpenseGroupMark {
    static let key = "groups.lastExpenseGroupID"

    static func record(_ groupID: UUID, defaults: UserDefaults = .standard) {
        defaults.set(groupID.uuidString, forKey: key)
    }

    static func lastGroupID(defaults: UserDefaults = .standard) -> UUID? {
        defaults.string(forKey: key).flatMap(UUID.init(uuidString:))
    }

    static func clear(_ defaults: UserDefaults) {
        defaults.removeObject(forKey: key)
    }

    /// El grupo en el que abre «Nuevo gasto» entre los que admiten gastos, en el orden de la lista.
    static func initialGroupID(eligibleIDs: [UUID], lastID: UUID?) -> UUID? {
        if let lastID, eligibleIDs.contains(lastID) { return lastID }
        return eligibleIDs.first
    }
}
