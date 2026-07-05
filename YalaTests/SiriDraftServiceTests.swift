//
//  SiriDraftServiceTests.swift
//  YalaTests
//
//  Tests de la materialización de dictados de Siri en InboxDraft (SiriDraftService.buildDraft:
//  match de cuenta por divisa, subcategoría por hint, expensesOnlyMode, signo, needsUserInput,
//  fallback de fecha). El flujo completo `processPending` (gate de quiescencia del singleton
//  iCloudSyncService + cola del App Group real) NO es aislable → se valida en device, igual que
//  ScheduledPaymentDraftService.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite(.serialized)
struct SiriDraftServiceTests {

    /// Fecha de fallback fija (representa el momento del dictado) para las llamadas a `buildDraft`.
    private let fallbackDate = Date(timeIntervalSince1970: 1_700_000_000)

    private func parsed(
        amount: Decimal?,
        date: Date? = nil,
        note: String = "café",
        isExpense: Bool = true,
        currencyHint: String? = nil,
        subcategoryHint: String? = nil
    ) -> ParsedTransaction {
        ParsedTransaction(
            amount: amount,
            date: date,
            note: note,
            isExpense: isExpense,
            subcategoryHint: subcategoryHint,
            tagHints: [],
            currencyHint: currencyHint,
            confidence: ParsedTransaction.TransactionConfidence(amount: 1, date: 0, merchant: 0, subcategory: 0, tags: 0)
        )
    }

    @Test func buildDraft_matchesAccountByCurrency_andSubcategoryByHint() throws {
        let context = try makeTestContext()
        let cat = makeTestCategory(context: context, name: "Comida", isIncome: false)
        let sub = makeTestSubcategory(context: context, name: "Café", category: cat)
        let account = makeTestAccount(context: context, name: "BBVA", currencyCode: "PEN")

        let draft = SiriDraftService.buildDraft(
            from: parsed(amount: 50, note: "Starbucks", currencyHint: "PEN", subcategoryHint: "Café"),
            rawText: "50 en café",
            fallbackDate: fallbackDate,
            realAccounts: [account],
            visibleSubcategories: [sub],
            expensesOnlyMode: false,
            context: context
        )

        #expect(draft != nil)
        #expect(draft?.amount == -50.0)               // gasto → negativo
        #expect(draft?.account === account)
        #expect(draft?.subcategory === sub)
        #expect(draft?.needsUserInput.isEmpty == true)
        #expect(draft?.sourceType == .siri)
        #expect(draft?.rawText == "50 en café")
    }

    @Test func buildDraft_noCurrencyHint_needsAccountInput() throws {
        let context = try makeTestContext()
        let account = makeTestAccount(context: context, currencyCode: "PEN")

        let draft = SiriDraftService.buildDraft(
            from: parsed(amount: 30, currencyHint: nil),
            rawText: "30 en algo",
            fallbackDate: fallbackDate,
            realAccounts: [account],
            visibleSubcategories: [],
            expensesOnlyMode: false,
            context: context
        )

        #expect(draft?.account == nil)
        #expect(draft?.needsUserInput.contains("account") == true)
    }

    @Test func buildDraft_currencyWithNoMatchingAccount_needsAccountInput() throws {
        let context = try makeTestContext()
        let account = makeTestAccount(context: context, currencyCode: "PEN")

        let draft = SiriDraftService.buildDraft(
            from: parsed(amount: 30, currencyHint: "USD"),   // no hay cuenta USD
            rawText: "30 dólares",
            fallbackDate: fallbackDate,
            realAccounts: [account],
            visibleSubcategories: [],
            expensesOnlyMode: false,
            context: context
        )

        #expect(draft?.account == nil)
        #expect(draft?.needsUserInput.contains("account") == true)
    }

    @Test func buildDraft_expensesOnlyMode_forcesExpenseSign() throws {
        let context = try makeTestContext()
        let account = makeTestAccount(context: context, currencyCode: "PEN")

        let draft = SiriDraftService.buildDraft(
            from: parsed(amount: 200, isExpense: false, currencyHint: "PEN"),  // LLM dijo ingreso
            rawText: "me pagaron 200",
            fallbackDate: fallbackDate,
            realAccounts: [account],
            visibleSubcategories: [],
            expensesOnlyMode: true,   // fuerza gasto
            context: context
        )

        #expect(draft?.amount == -200.0)   // forzado a gasto (negativo)
    }

    @Test func buildDraft_income_positiveAmount_whenNotExpensesOnly() throws {
        let context = try makeTestContext()
        let account = makeTestAccount(context: context, currencyCode: "PEN")

        let draft = SiriDraftService.buildDraft(
            from: parsed(amount: 200, isExpense: false, currencyHint: "PEN"),
            rawText: "me pagaron 200",
            fallbackDate: fallbackDate,
            realAccounts: [account],
            visibleSubcategories: [],
            expensesOnlyMode: false,
            context: context
        )

        #expect(draft?.amount == 200.0)   // ingreso → positivo
    }

    @Test func buildDraft_noSubcategoryHint_noMerchantMemory_needsSubcategoryInput() throws {
        let context = try makeTestContext()
        let account = makeTestAccount(context: context, currencyCode: "PEN")

        let draft = SiriDraftService.buildDraft(
            from: parsed(amount: 15, note: "xyzqwerty", currencyHint: "PEN", subcategoryHint: nil),
            rawText: "15 en xyzqwerty",
            fallbackDate: fallbackDate,
            realAccounts: [account],
            visibleSubcategories: [],
            expensesOnlyMode: false,
            context: context
        )

        #expect(draft?.subcategory == nil)
        #expect(draft?.needsUserInput.contains("subcategory") == true)
    }

    @Test func buildDraft_noParsedDate_usesFallbackDate() throws {
        let context = try makeTestContext()
        let account = makeTestAccount(context: context, currencyCode: "PEN")

        let draft = SiriDraftService.buildDraft(
            from: parsed(amount: 40, date: nil, currencyHint: "PEN"),   // LLM no infirió fecha
            rawText: "40 en café",
            fallbackDate: fallbackDate,
            realAccounts: [account],
            visibleSubcategories: [],
            expensesOnlyMode: false,
            context: context
        )

        #expect(draft?.date == fallbackDate)   // usa la fecha del dictado, no nil
    }

    @Test func buildDraft_withParsedDate_keepsParsedDate() throws {
        let context = try makeTestContext()
        let account = makeTestAccount(context: context, currencyCode: "PEN")
        let parsedDate = Date(timeIntervalSince1970: 1_600_000_000)

        let draft = SiriDraftService.buildDraft(
            from: parsed(amount: 40, date: parsedDate, currencyHint: "PEN"),
            rawText: "40 en café ayer",
            fallbackDate: fallbackDate,
            realAccounts: [account],
            visibleSubcategories: [],
            expensesOnlyMode: false,
            context: context
        )

        #expect(draft?.date == parsedDate)   // respeta la fecha inferida por el LLM
    }

    @Test func buildDraft_nilAmount_returnsNil() throws {
        let context = try makeTestContext()
        let draft = SiriDraftService.buildDraft(
            from: parsed(amount: nil),
            rawText: "sin monto",
            fallbackDate: fallbackDate,
            realAccounts: [],
            visibleSubcategories: [],
            expensesOnlyMode: false,
            context: context
        )
        #expect(draft == nil)
    }
}
