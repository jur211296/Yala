//
//  TasasDeCambioSaldoInicialTests.swift
//  YalaTests / TasasDeCambioLote
//
//  Ticket `initial-balance-date-move-leaves-converted-amount-stale`: un import con movimientos anteriores al saldo inicial
//  retrocede su fecha (`updateInitialBalanceDateIfNeeded`), y la fecha es input de la conversión. Sin recalcular, el monto
//  en la divisa preferida se quedaba con la tasa del día viejo.
//
//  Testigo aritmético (molde de `RecordsViewModelBulkAccountCurrencyTests`): todas las divisas a 1.0 salvo la de la
//  cuenta, así que la conversión da `importe / tasa` con cualquier divisa preferida. Día viejo: 100; día nuevo: 50.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Tasas de cambio · mover la fecha del saldo inicial recalcula el monto convertido", .serialized)
struct TasasDeCambioSaldoInicialTests {

    private static let utc: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    /// Una divisa que no es la preferida del entorno ni el USD.
    private var foreignCode: String {
        normalizeCurrencyCode(CurrencyDefaults.currentPreferred) == "JPY" ? "CHF" : "JPY"
    }

    private func rates(foreign rate: Double) -> [String: Double] {
        var out: [String: Double] = [:]
        for code in CurrencyCode.allRawValues { out[code] = 1.0 }
        out[normalizeCurrencyCode(CurrencyDefaults.currentPreferred)] = 1.0
        out[foreignCode] = rate
        return out
    }

    private func localDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) ?? .distantPast
    }

    @Test func movingTheDateBack_convertsWithTheRateOfTheNewDate() throws {
        let context = try makeTestContext()
        let account = Account(name: "Viaje", currencyCode: foreignCode, colorHex: "#000000", iconName: "creditcard",
                              type: "bank")
        context.insert(account)

        let initial = TransactionItem(date: localDate(2025, 6, 1), amount: 1000, currencyCode: foreignCode, note: nil)
        initial.account = account
        initial.balanceAdjustmentType = InitialBalanceService.typeInitialBalance
        context.insert(initial)
        let older = TransactionItem(date: localDate(2025, 3, 15), amount: -10, currencyCode: foreignCode, note: nil)
        older.account = account
        context.insert(older)

        let newDate = InitialBalanceService.calculateInitialBalanceDate(for: account, allTransactions: [initial, older])
        // Mismo día de la fila que lee el converter.
        context.insert(try ExchangeRate(dateKey: Self.utc.string(from: initial.date), base: "USD",
                                        ratesDictionary: rates(foreign: 100)))
        context.insert(try ExchangeRate(dateKey: Self.utc.string(from: newDate), base: "USD",
                                        ratesDictionary: rates(foreign: 50)))
        try context.save()

        initial.recalculatePreferredCurrency(context: context)
        #expect(abs(initial.amountInPreferredCurrency - 10) < 0.0001, "control: el saldo nace con la tasa del día viejo")
        #expect(!initial.isExchangeRateProvisional)

        InitialBalanceService.updateInitialBalanceDateIfNeeded(
            for: account, allTransactions: [initial, older], context: context)

        #expect(initial.date == newDate)
        #expect(abs(initial.amountInPreferredCurrency - 20) < 0.0001)
        #expect(abs(initial.exchangeRate - 0.02) < 0.000001)
        #expect(!initial.isExchangeRateProvisional)
    }

    @Test func aDateThatDoesNotMove_leavesTheAmountAlone() throws {
        let context = try makeTestContext()
        let account = Account(name: "Viaje", currencyCode: foreignCode, colorHex: "#000000", iconName: "creditcard",
                              type: "bank")
        context.insert(account)
        let initial = TransactionItem(date: localDate(2025, 3, 1), amount: 1000, currencyCode: foreignCode, note: nil)
        initial.account = account
        initial.balanceAdjustmentType = InitialBalanceService.typeInitialBalance
        initial.amountInPreferredCurrency = 7  // un valor que el recálculo cambiaría
        context.insert(initial)
        let later = TransactionItem(date: localDate(2025, 4, 15), amount: -10, currencyCode: foreignCode, note: nil)
        later.account = account
        context.insert(later)
        try context.save()

        InitialBalanceService.updateInitialBalanceDateIfNeeded(
            for: account, allTransactions: [initial, later], context: context)

        #expect(initial.amountInPreferredCurrency == 7)
    }
}
