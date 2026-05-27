//
//  BridgedTransactionFilter.swift
//  Yala
//
//  SSOT pure-logic para excluir TX bridgeadas (`splitExpenseID/splitSettlementID
//  != nil`) de stats cuando `AppPreferences.includeGroupTransactionsInStats == false`.
//
//  Centraliza la lógica antes dispersa entre `RecordsViewModel`, `BudgetsViewModel`
//  e `InsightsCalculator` — previene drift en V2 cuando se añadan readers de stats.
//
//  Default: defaults ON (toggle aún sin cablear), comportamiento de paridad con el
//  estado previo (sin filtrado).
//

import Foundation

enum BridgedTransactionFilter {

    /// TODO V1.1: opt-in TXs (creadas via draft `optInPersonalOnly`) deberían incluirse
    /// SIEMPRE en stats — el user explícitamente las creó en su cuenta personal. Hoy
    /// se excluyen junto con las auto-bridgeadas porque ambas tienen `splitExpenseID != nil`.
    /// Para distinguirlas se necesita un flag adicional en `TransactionItem` (e.g.
    /// `personalOptIn: Bool`) que el draft approve setea a true. Diferido — requiere
    /// migración SwiftData del modelo TransactionItem.

    /// Devuelve `true` si la TX debe incluirse en cómputos de stats según el toggle.
    /// - Parameters:
    ///   - splitExpenseID: campo del TX (nil = no bridgeada).
    ///   - splitSettlementID: campo del TX (nil = no bridgeada).
    ///   - includeGroupsToggle: `AppPreferences.includeGroupTransactionsInStats`.
    static func shouldInclude(
        splitExpenseID: String?,
        splitSettlementID: String?,
        includeGroupsToggle: Bool
    ) -> Bool {
        if includeGroupsToggle { return true }
        return splitExpenseID == nil && splitSettlementID == nil
    }
}
