//
//  ChatDraftExpensesOnlyModeTests.swift
//  YalaTests
//
//  Ticket `chat-ignores-expenses-only-mode` (revisión de Yala IA del 2026-10-20): con el modo «solo gastos», el
//  borrador que propone el chat nace como gasto aunque el modelo lea un ingreso, como en Siri, el Atajo y Apple Pay.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

#if DEBUG

@Suite("Yala IA · el borrador del chat respeta «solo gastos»", .serialized)
@MainActor
struct ChatDraftExpensesOnlyModeTests {

    private func income() -> ParsedTransaction {
        ParsedTransaction(
            amount: 1500, date: nil, note: "Proyecto", isExpense: false, subcategoryHint: nil, tagHints: [],
            currencyHint: "PEN",
            confidence: .init(amount: 1, date: 1, merchant: 1, subcategory: 1, tags: 1))
    }

    @Test func expensesOnlyMode_forcesAnExpenseDraft() throws {
        let ctx = try makeTestContext()
        _ = makeTestAccount(context: ctx, name: "Principal")
        try ctx.save()
        let draft = DraftBuilder.build(parsed: income(), defaultCurrency: "PEN", context: ctx, expensesOnlyMode: true)
        #expect(draft.isExpense)
    }

    @Test func withoutTheMode_anIncomeStaysAnIncome() throws {
        let ctx = try makeTestContext()
        _ = makeTestAccount(context: ctx, name: "Principal")
        try ctx.save()
        let draft = DraftBuilder.build(parsed: income(), defaultCurrency: "PEN", context: ctx)
        #expect(!draft.isExpense)
    }

    /// El servicio del chat lee el modo donde lo leen Siri y el Atajo (App Group) y se lo pasa al constructor.
    @Test func chatService_passesTheModeToTheDraftBuilder() throws {
        let src = try String(
            contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("Yala/Services/ChatAssistantService.swift"),
            encoding: .utf8)
        #expect(src.contains("UserDefaults(suiteName: WidgetURLHelper.appGroupIdentifier)?\n            .bool(forKey: AppPreferences.Keys.expensesOnlyMode)"))
        #expect(src.contains("context: modelContext, expensesOnlyMode: expensesOnlyMode)"))
    }
}

#endif
