//
//  CurrencyChangeFailureTests.swift
//  YalaTests
//
//  Ticket `currency-change-failure-is-silent-and-half-applied` (auditoría UX 2.2, lote 16). Si el guardado de la
//  migración al cambiar de moneda principal fallaba, los cambios se quedaban pendientes en el contexto y los escribía el
//  siguiente guardado de cualquier pantalla, con la moneda principal todavía en la vieja. Ahora cada registro vuelve a
//  como estaba, y los cambios ajenos pendientes no se tiran.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

private struct ForcedSaveFailure: Error {}

@MainActor
@Suite(.serialized)
struct CurrencyChangeFailureTests {

    private let service = CurrencyChangeService.shared

    private func seed(_ context: ModelContext) throws -> (TransactionItem, Account) {
        let account = makeTestAccount(context: context, name: "Principal", currencyCode: "USD")
        let category = makeTestCategory(context: context)
        let subcategory = makeTestSubcategory(context: context, category: category)
        let transaction = makeTestTransaction(
            context: context,
            amount: -100,
            account: account,
            category: category,
            subcategory: subcategory,
            currencyCode: "USD"
        )
        transaction.amountInPreferredCurrency = -375
        transaction.exchangeRate = 3.75
        transaction.preferredCurrencyCode = "PEN"
        transaction.isExchangeRateProvisional = false
        try context.save()
        return (transaction, account)
    }

    @Test func aFailedSave_leavesEveryRecordAsItWas() async throws {
        let context = try makeTestContext()
        let (transaction, _) = try seed(context)
        service.ensureRatesOverride = { _, _ in }
        service.saveOverride = { _ in throw ForcedSaveFailure() }
        defer {
            service.ensureRatesOverride = nil
            service.saveOverride = nil
        }

        await #expect(throws: ForcedSaveFailure.self) {
            try await service.updateAllTransactions(to: "EUR", context: context)
        }

        #expect(transaction.preferredCurrencyCode == "PEN")
        #expect(transaction.amountInPreferredCurrency == -375)
        #expect(transaction.exchangeRate == 3.75)
        #expect(transaction.isExchangeRateProvisional == false)
    }

    /// Restaurar registro a registro, y no `context.rollback()`: un cambio pendiente de otra pantalla sigue ahí.
    @Test func aFailedSave_keepsOtherPendingChanges() async throws {
        let context = try makeTestContext()
        let (_, account) = try seed(context)
        account.name = "Renombrada sin guardar"
        service.ensureRatesOverride = { _, _ in }
        service.saveOverride = { _ in throw ForcedSaveFailure() }
        defer {
            service.ensureRatesOverride = nil
            service.saveOverride = nil
        }

        await #expect(throws: ForcedSaveFailure.self) {
            try await service.updateAllTransactions(to: "EUR", context: context)
        }

        #expect(account.name == "Renombrada sin guardar")
    }

    @Test func aGoodSave_writesTheNewCurrency() async throws {
        let context = try makeTestContext()
        let (transaction, _) = try seed(context)
        service.ensureRatesOverride = { _, _ in }
        defer { service.ensureRatesOverride = nil }

        try await service.updateAllTransactions(to: "EUR", context: context)

        #expect(transaction.preferredCurrencyCode == "EUR")
        let stored = try context.fetch(FetchDescriptor<TransactionItem>())
        #expect(stored.allSatisfy { $0.preferredCurrencyCode == "EUR" })
    }
}

/// La pantalla: la nueva principal sale de las secundarias solo si la migración salió bien, y si falla lo dice. Código
/// de vista, sin forma de llamarlo desde un test: se fija el orden con el cuerpo de la función.
@MainActor
struct CurrencySettingsFailureWiringTests {

    private func source() throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Yala/App/Views/Settings/CurrencySettingsView.swift")
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func body(of function: String, in source: String) throws -> Substring {
        let start = try #require(source.range(of: "private func \(function)("))
        let rest = source[start.upperBound...]
        let end = rest.range(of: "\n    private func ")?.lowerBound ?? rest.endIndex
        return rest[..<end]
    }

    @Test func secondaryIsRemovedOnlyAfterTheMigration() throws {
        let update = try body(of: "updatePreferredCurrency", in: try source())
        let migration = try #require(update.range(of: "CurrencyChangeService.shared.updateAllTransactions"))
        let removal = try #require(update.range(of: "updated.remove(newCurrency)"))
        let failure = try #require(update.range(of: "showCurrencyChangeFailed = true"))
        #expect(migration.lowerBound < removal.lowerBound)
        // Y antes del `catch`: dentro de él, la moneda saldría de las secundarias justo cuando la migración falla.
        #expect(removal.lowerBound < failure.lowerBound)
        // El aviso vive en el `catch`, detrás de la migración.
        #expect(migration.lowerBound < failure.lowerBound)
        #expect(update.range(of: "progress * 0.5") == nil)
    }

    @Test func choosingACurrency_asksBeforeApplying() throws {
        let source = try source()
        #expect(source.range(of: ".onChange(of: tempPreferredCurrency)") == nil)
        #expect(source.range(of: "CurrencyChangeConfirmSheet(") != nil)
        #expect(source.range(of: "onDismiss: preferredPickerDismissed") != nil)
    }
}
