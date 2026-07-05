//
//  DraftToGroupExpenseTemplateLogicTests.swift
//  YalaTests
//
//  Pure-logic tests para `DraftToGroupExpenseTemplateLogic` — construye el
//  `GroupExpensePrefillTemplate` desde un draft personal de gasto. Sin SwiftData
//  (se invoca con `accountPrefill: nil`; el resto son valores planos).
//

import Foundation
import Testing

@testable import Yala

@Suite("Draft → Group Expense Template")
struct DraftToGroupExpenseTemplateLogicTests {

    @Test func negativeAmount_normalizedToPositive() {
        let t = DraftToGroupExpenseTemplateLogic.buildTemplate(
            amount: -42.5, cachedCurrencyCode: "PEN", note: "Cena",
            activeMemberIDs: [], groupCurrencyCode: "USD"
        )
        #expect(t.totalAmount == 42.5)
    }

    @Test func positiveAmount_unchanged() {
        let t = DraftToGroupExpenseTemplateLogic.buildTemplate(
            amount: 30, cachedCurrencyCode: "PEN", note: "x",
            activeMemberIDs: [], groupCurrencyCode: "USD"
        )
        #expect(t.totalAmount == 30)
    }

    @Test func cachedCurrency_takesPrecedence() {
        let t = DraftToGroupExpenseTemplateLogic.buildTemplate(
            amount: -10, cachedCurrencyCode: "PEN", note: "x",
            activeMemberIDs: [], groupCurrencyCode: "USD"
        )
        #expect(t.currencyCode == "PEN")
    }

    @Test func nilCachedCurrency_fallsBackToGroup() {
        let t = DraftToGroupExpenseTemplateLogic.buildTemplate(
            amount: -10, cachedCurrencyCode: nil, note: "x",
            activeMemberIDs: [], groupCurrencyCode: "USD"
        )
        #expect(t.currencyCode == "USD")
    }

    @Test func splitTypeIsEqual_andValuesEmpty() {
        let t = DraftToGroupExpenseTemplateLogic.buildTemplate(
            amount: -10, cachedCurrencyCode: "USD", note: "x",
            activeMemberIDs: [UUID(), UUID()], groupCurrencyCode: "USD"
        )
        #expect(t.splitType == .equal)
        #expect(t.values.isEmpty)
    }

    @Test func participantsDescriptionAndAccount_carriedThrough() {
        let ids = [UUID(), UUID(), UUID()]
        let t = DraftToGroupExpenseTemplateLogic.buildTemplate(
            amount: -10, cachedCurrencyCode: "USD", note: "Almuerzo equipo",
            activeMemberIDs: ids, groupCurrencyCode: "USD"
        )
        #expect(t.participantIDs == ids)
        #expect(t.description == "Almuerzo equipo")
        #expect(t.accountPrefill == nil)
    }
}
