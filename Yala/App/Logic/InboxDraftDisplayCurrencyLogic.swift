//
//  InboxDraftDisplayCurrencyLogic.swift
//  Yala
//
//  En qué divisa pinta la Bandeja el importe de un borrador (bug del 2026-11-09, «Google One S/ -10.84» siendo un gasto
//  de grupo en USD). El borrador de un gasto de grupo que todavía no tiene cuenta nace con `account == nil`, así que
//  `InboxDraft.displayCurrencyCode` (que sale de la cuenta) daba `nil` y la fila caía a la divisa por defecto de la
//  persona. Su divisa de verdad es la del gasto del grupo, la misma que ya enseña la hoja de «Elige la cuenta».
//
//  Se resuelve leyendo el gasto por `splitExpenseID` y no guardando la divisa en el borrador: así se corrigen también los
//  borradores que ya existen, sin campo nuevo en el modelo (que sería un campo nuevo de CloudKit).
//

import Foundation

nonisolated enum InboxDraftDisplayCurrencyLogic {

    /// La divisa que enseña la fila: la de la cuenta del borrador si la tiene (también la de un borrador resuelto, que
    /// guarda la suya); si no, la del gasto de grupo del que viene; si tampoco, la de por defecto.
    static func currency(draftCurrency: String?, groupExpenseCurrency: String?, fallback: String) -> String {
        if let draftCurrency, !draftCurrency.isEmpty { return draftCurrency }
        if let groupExpenseCurrency, !groupExpenseCurrency.isEmpty { return groupExpenseCurrency }
        return fallback
    }

    /// Los `splitExpenseID` cuya divisa hace falta leer: borradores de gasto de grupo sin divisa propia.
    static func groupExpenseIDsNeedingCurrency(
        _ drafts: [(splitExpenseID: String?, draftCurrency: String?)]
    ) -> Set<UUID> {
        Set(drafts.compactMap { draft in
            guard draft.draftCurrency?.isEmpty ?? true, let id = draft.splitExpenseID else { return nil }
            return UUID(uuidString: id)
        })
    }
}
