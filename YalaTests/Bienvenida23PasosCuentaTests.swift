//
//  Bienvenida23PasosCuentaTests.swift
//  YalaTests
//
//  Lote 03 de la bienvenida 2.3 (docs/onboarding-2-3/SPEC.md): la cuenta que guarda el paso 1 (Y23-07). En su propio fichero porque pide
//  `makeTestContext()` (una suite por fichero, `.claude/rules/testing.md`).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

// MARK: - Y23-07 · lo que se guarda

@MainActor
@Suite("Bienvenida 2.3 · paso 1, la cuenta que se guarda (Y23-07)", .serialized)
struct FirstAccountCreatorTests {

    /// Ficha: «Una tarjeta en soles y dólares queda como principal + línea en USD con su saldo» y «el recordatorio
    /// guarda 0/1/3/5 días».
    @Test func card_inSolesAndDollars_isPrincipalPlusUSDLine_withTheReminder() throws {
        let context = try makeTestContext()
        defer { UserDefaults.standard.removeObject(forKey: SetupStepID.firstAccount.storageKey) }
        var draft = FirstAccountDraft(mainCurrency: "PEN")
        draft.kind = .creditCard
        draft.currencies = ["PEN", "USD"]
        draft.name = "Visa del trabajo"
        draft.balances = ["PEN": -620, "USD": -85]
        draft.statementDay = .day(18)
        draft.paymentDay = .day(3)
        draft.reminderLead = 3

        let principal = try FirstAccountCreator.create(draft, suggestedName: "Tarjeta", in: context)

        let accounts = try context.fetch(FetchDescriptor<Account>())
        #expect(accounts.count == 2)
        let line = try #require(accounts.first { $0.parentAccountID == principal.shortcutID })
        #expect(principal.currencyCode == "PEN")
        #expect(principal.type == AccountType.creditCard.rawValue)
        #expect(principal.name == "Visa del trabajo")
        #expect(line.currencyCode == "USD")
        #expect(principal.creditCardStatementDay == 18)
        #expect(principal.creditCardPaymentDay == 3)
        #expect(principal.creditCardPaymentReminder)
        #expect(principal.creditCardReminderDaysBefore == 3)

        let rows = try context.fetch(FetchDescriptor<TransactionItem>())
        let opening = rows.filter { $0.balanceAdjustmentType == InitialBalanceService.typeInitialBalance }
        #expect(opening.first { $0.account?.persistentModelID == principal.persistentModelID }?.amount == -620)
        #expect(opening.first { $0.account?.persistentModelID == line.persistentModelID }?.amount == -85)
    }

    /// «No me lo recuerdes» y un saldo en 0: la cuenta sale sin recordatorio y sin fila de saldo inicial.
    @Test func noReminder_andZeroBalance() throws {
        let context = try makeTestContext()
        defer { UserDefaults.standard.removeObject(forKey: SetupStepID.firstAccount.storageKey) }
        var draft = FirstAccountDraft(mainCurrency: "PEN")
        draft.kind = .creditCard
        draft.balances = ["PEN": 0]
        draft.statementDay = .unknown
        draft.paymentDay = .day(5)
        draft.reminderLead = nil

        let principal = try FirstAccountCreator.create(draft, suggestedName: "Tarjeta", in: context)

        #expect(principal.name == "Tarjeta")
        #expect(!principal.creditCardPaymentReminder)
        #expect(principal.creditCardStatementDay == nil)
        #expect(try context.fetch(FetchDescriptor<TransactionItem>()).isEmpty)
    }

    /// Efectivo con saldo negativo: el signo del botón se respeta.
    @Test func cash_negativeBalance() throws {
        let context = try makeTestContext()
        defer { UserDefaults.standard.removeObject(forKey: SetupStepID.firstAccount.storageKey) }
        var draft = FirstAccountDraft(mainCurrency: "USD")
        draft.kind = .cash
        draft.balances = ["USD": FirstAccountFlowLogic.storedBalance(kind: .cash, magnitude: 40, isNegative: true)]

        let principal = try FirstAccountCreator.create(draft, suggestedName: "Efectivo", in: context)

        #expect(principal.name == "Efectivo")
        #expect(principal.type == AccountType.cash.rawValue)
        let opening = try context.fetch(FetchDescriptor<TransactionItem>())
        #expect(opening.map(\.amount) == [-40])
    }
}
