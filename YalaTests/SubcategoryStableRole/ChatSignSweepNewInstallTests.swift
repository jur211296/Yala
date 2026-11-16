//
//  ChatSignSweepNewInstallTests.swift
//  YalaTests
//
//  Ticket `chat-sign-sweep-stays-armed-until-the-first-transaction-of-a-new-install`.
//
//  En una instalación nueva el barrido del signo del chat no se sella hasta el primer registro. Lo que
//  la persona cree en ESTA instalación no puede ser del código viejo y no se voltea; un corpus viejo
//  que baja después por restore sí se sigue reparando.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("El barrido del signo no voltea lo creado en esta instalación", .serialized)
struct ChatSignSweepNewInstallTests {

    private func makeIsolatedDefaults() throws -> UserDefaults {
        try #require(testDefaults(suiteName: "ChatSignSweepNewInstallTests.\(UUID().uuidString)"))
    }

    /// Primer arranque de la instalación nueva, con el store vacío. Fijo, dentro de la ventana.
    private var firstLaunch: Date {
        ChatUnsignedExpenseRepairLogic.windowStart.addingTimeInterval(60 * 60 * 24 * 200)
    }

    /// El arranque siguiente, cuando ya hay registros.
    private var secondLaunch: Date { firstLaunch.addingTimeInterval(60 * 60 * 24) }

    /// Una fila que guardó el código viejo, meses antes de esta instalación. Llega por restore.
    private var oldCorpusCreatedAt: Date {
        ChatUnsignedExpenseRepairLogic.windowStart.addingTimeInterval(60 * 60 * 24 * 30)
    }

    /// Un gasto positivo en una categoría de gasto: la forma que el barrido busca. Una sola fila por
    /// llamada y separadas en el tiempo, así que ninguna parece un lote de import.
    @discardableResult
    private func insertPositiveExpense(
        amount: Double, createdAt: Date, context: ModelContext, preferred: String
    ) throws -> TransactionItem {
        let account = makeTestAccount(context: context, name: "Diaria", currencyCode: preferred)
        let category = makeTestCategory(context: context, name: "Comida", isIncome: false)
        let subcategory = makeTestSubcategory(context: context, name: "Restaurantes", category: category)
        let transaction = TransactionItem(
            date: createdAt,
            amount: amount,
            currencyCode: preferred,
            note: "caso",
            category: category,
            subcategory: subcategory,
            account: account,
            exchangeRate: 1.0,
            amountInPreferredCurrency: amount,
            preferredCurrencyCode: preferred
        )
        transaction.createdAt = createdAt
        context.insert(transaction)
        try context.save()
        return transaction
    }

    /// El caso del ticket: un CSV de una sola fila con un reembolso, importado en una instalación
    /// nueva. Sin el arreglo, el arranque siguiente lo volteaba a negativo.
    @Test func singleRowRefundImportedInThisInstall_survivesTheNextLaunch() throws {
        let context = try makeTestContext()
        let defaults = try makeIsolatedDefaults()
        let preferred = CurrencyDefaults.currentPreferred

        // Arranque 1: store vacío. No se sella, pero la ventana cierra aquí.
        let first = ChatUnsignedExpenseRepairService.repairUnsignedChatExpensesIfNeeded(
            context: context, defaults: defaults, now: firstLaunch)
        #expect(first == 0)
        #expect(!defaults.bool(forKey: ChatUnsignedExpenseRepairService.repairSweepKey))

        // La persona importa un CSV de una fila: «Comida › Restaurantes» con +20.
        let refund = try insertPositiveExpense(
            amount: 20, createdAt: firstLaunch.addingTimeInterval(60 * 10),
            context: context, preferred: preferred)

        // Arranque 2.
        let repaired = ChatUnsignedExpenseRepairService.repairUnsignedChatExpensesIfNeeded(
            context: context, defaults: defaults, now: secondLaunch)

        #expect(repaired == 0, "lo creado en esta instalación lo escribió un build que ya firma")
        #expect(refund.amount == 20)
        #expect(refund.amountInPreferredCurrency == 20)
        #expect(
            defaults.bool(forKey: ChatUnsignedExpenseRepairService.repairSweepKey),
            "con corpus en el store el barrido hizo su trabajo y se sella")
    }

    /// La otra mitad: un corpus viejo que baja por restore DESPUÉS del primer arranque se sigue
    /// reparando, porque sus filas conservan el `createdAt` de cuando las escribió el código viejo.
    @Test func oldCorpusArrivingByRestore_isStillRepaired() throws {
        let context = try makeTestContext()
        let defaults = try makeIsolatedDefaults()
        let preferred = CurrencyDefaults.currentPreferred

        _ = ChatUnsignedExpenseRepairService.repairUnsignedChatExpensesIfNeeded(
            context: context, defaults: defaults, now: firstLaunch)

        let restored = try insertPositiveExpense(
            amount: 30, createdAt: oldCorpusCreatedAt, context: context, preferred: preferred)

        let repaired = ChatUnsignedExpenseRepairService.repairUnsignedChatExpensesIfNeeded(
            context: context, defaults: defaults, now: secondLaunch)

        #expect(repaired == 1)
        #expect(restored.amount == -30)
        #expect(restored.amountInPreferredCurrency == -30)
    }

    /// Las dos poblaciones en el mismo store: solo se voltea la del restore.
    @Test func restoreAndNewRowsTogether_onlyTheRestoredOneFlips() throws {
        let context = try makeTestContext()
        let defaults = try makeIsolatedDefaults()
        let preferred = CurrencyDefaults.currentPreferred

        _ = ChatUnsignedExpenseRepairService.repairUnsignedChatExpensesIfNeeded(
            context: context, defaults: defaults, now: firstLaunch)

        let restored = try insertPositiveExpense(
            amount: 30, createdAt: oldCorpusCreatedAt, context: context, preferred: preferred)
        let createdHere = try insertPositiveExpense(
            amount: 20, createdAt: firstLaunch.addingTimeInterval(60 * 60 * 3),
            context: context, preferred: preferred)

        let repaired = ChatUnsignedExpenseRepairService.repairUnsignedChatExpensesIfNeeded(
            context: context, defaults: defaults, now: secondLaunch)

        #expect(repaired == 1)
        #expect(restored.amount == -30)
        #expect(createdHere.amount == 20)
    }

    /// El cierre se fija una vez y no se mueve en los arranques siguientes.
    @Test func windowCloseIsArmedOnceAndKept() throws {
        let defaults = try makeIsolatedDefaults()
        let armed = ChatUnsignedExpenseRepairService.armWindowCloseIfNeeded(
            defaults: defaults, now: firstLaunch)
        let later = ChatUnsignedExpenseRepairService.armWindowCloseIfNeeded(
            defaults: defaults, now: secondLaunch)
        #expect(armed == firstLaunch)
        #expect(later == firstLaunch)
    }

    /// El arranque fija el cierre ANTES de esperar al store: el barrido corre hasta dos minutos
    /// después, y lo que la persona registre en ese rato ya es de un build que firma.
    @Test func bootstrapArmsTheWindowBeforeWaitingForTheStore() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: root.appendingPathComponent("Yala/App/AppBootstrapper.swift"), encoding: .utf8)
        let function = try #require(
            source.range(of: "private func repairUnsignedChatExpensesIfNeeded(context: ModelContext) async"))
        let body = source[function.upperBound...]
        let arm = try #require(body.range(of: "ChatUnsignedExpenseRepairService.armWindowCloseIfNeeded()"))
        let wait = try #require(body.range(of: "await awaitPersonalStoreReady()"))
        #expect(arm.lowerBound < wait.lowerBound)
    }
}
