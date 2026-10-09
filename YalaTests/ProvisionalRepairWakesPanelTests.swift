//
//  ProvisionalRepairWakesPanelTests.swift
//  YalaTests
//
//  Que reparar importes provisionales avise a quien los pinta precalculados.
//  Ticket `reparacion-de-tasas-no-avisa-al-panel`.
//
//  La reparación muta los `@Model` en sitio y guarda. El Panel no los observa uno a uno: se entera por
//  `dataVersion` (`PanelDataFilterObservers` → `reloadAndRecalculate()`). Antes del arreglo nadie lo
//  movía y el Panel seguía con los importes envenenados hasta el siguiente toque.
//
//  Sin red: la fila de tasas de la fecha ya cubre las dos divisas, así que `uncoveredDates` sale vacío
//  y `fetchRates` vuelve sin pedir nada.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Reparación de importes provisionales · avisa al Panel", .serialized)
struct ProvisionalRepairWakesPanelTests {

    private static let dayKey = "2026-01-15"
    private static let day: Date = {
        var c = DateComponents()
        c.year = 2026; c.month = 1; c.day = 15; c.hour = 12
        c.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: c) ?? .distantPast
    }()

    /// Una transacción en divisa ajena sellada con el 1:1 provisional de un día sin tasas, y la fila de
    /// ese día ya en disco con las dos divisas.
    private func seedProvisional(_ context: ModelContext) throws -> TransactionItem {
        let preferred = CurrencyDefaults.currentPreferred
        let foreign = preferred == "USD" ? "EUR" : "USD"
        var rates: [String: Double] = ["USD": 1.0, "EUR": 0.92, "PEN": 3.75]
        rates[preferred] = rates[preferred] ?? 2.0
        _ = try makeTestExchangeRate(context: context, dateKey: Self.dayKey, rates: rates)

        let tx = TransactionItem(
            date: Self.day, amount: -100, currencyCode: foreign, exchangeRate: 1.0,
            amountInPreferredCurrency: -100, preferredCurrencyCode: preferred,
            isExchangeRateProvisional: true)
        context.insert(tx)
        try context.save()
        return tx
    }

    @Test("Una reparación que cambia importes mueve `dataVersion` exactamente una vez")
    func repairThatChangesAmounts_bumpsDataVersionOnce() async throws {
        let context = try makeTestContext()
        let tx = try seedProvisional(context)
        let defaults = makeIsolatedDefaults()
        let before = SessionState.shared.dataVersion

        await TransactionUpdateService.updateProvisionalTransactions(context: context, defaults: defaults)

        // Premisa: la reparación de verdad curó la fila (si no, el test no mediría nada).
        #expect(!tx.isExchangeRateProvisional)
        #expect(tx.amountInPreferredCurrency != -100)
        #expect(SessionState.shared.dataVersion == before + 1)
    }

    @Test("Control: con la cola vacía no se mueve `dataVersion`")
    func emptyQueue_doesNotBump() async throws {
        let context = try makeTestContext()
        let defaults = makeIsolatedDefaults()
        let before = SessionState.shared.dataVersion

        await TransactionUpdateService.updateProvisionalTransactions(context: context, defaults: defaults)

        #expect(SessionState.shared.dataVersion == before)
    }

    @Test("Control: una segunda pasada sobre lo ya curado no vuelve a avisar")
    func secondPassOverHealedRows_doesNotBumpAgain() async throws {
        let context = try makeTestContext()
        _ = try seedProvisional(context)
        let defaults = makeIsolatedDefaults()
        await TransactionUpdateService.updateProvisionalTransactions(context: context, defaults: defaults)
        let afterFirst = SessionState.shared.dataVersion

        await TransactionUpdateService.updateProvisionalTransactions(context: context, defaults: defaults)

        #expect(SessionState.shared.dataVersion == afterFirst)
    }
}
