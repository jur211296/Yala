//
//  CurrencyChangeServiceTests.swift
//  YalaTests
//
//  La tasa y el progreso que deja `CurrencyChangeService.updateAllTransactions` al cambiar de moneda preferida.
//
//  Ticket `currency-change-service-tests-mirror-the-logic`. Estos casos copiaban antes la derivación de la tasa y el
//  `index % 20` dentro del propio test, así que seguían en verde con cualquier cambio del servicio. Ahora llaman al
//  servicio con un store sembrado y leen lo que quedó PERSISTIDO en cada registro.
//
//  Sin red: la fila de tasas del día ya existe, así que `ensureRates` no encuentra fechas que pedir (molde de
//  `ManualWriteRateQualityBehaviorTests`). No se tocan los seams del singleton: `CurrencyChangeFailureTests` los pone a
//  lanzar, y no hace falta acoplar las dos suites.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Cambio de moneda preferida: tasa y progreso", .serialized)
struct CurrencyChangeServiceTests {

    private let service = CurrencyChangeService.shared

    /// Fecha fija, lejos de las que siembran otras suites, para que ninguna fila ajena caiga en el mismo día.
    private static let day: Date = {
        var components = DateComponents()
        components.year = 2024
        components.month = 3
        components.day = 15
        components.hour = 12
        components.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: components) ?? Date(timeIntervalSince1970: 1_710_504_000)
    }()

    /// Fila completa del día, con base USD y el sol a 3,75 exacto.
    private func seedRates(in context: ModelContext) throws {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        var rates = Dictionary(
            uniqueKeysWithValues: CurrencyCode.allRawValues.map { ($0, CurrencyCode.fallbackRates[$0] ?? 1.0) }
        )
        rates["USD"] = 1.0
        rates["PEN"] = 3.75
        context.insert(
            try ExchangeRate(dateKey: formatter.string(from: Self.day), base: "USD", ratesDictionary: rates)
        )
        try context.save()
    }

    /// Una transacción en dólares con valores viejos puestos a propósito, para ver que el servicio los pisa.
    private func seedTransaction(amount: Double, in context: ModelContext) throws {
        let account = makeTestAccount(context: context, name: "Dólares", currencyCode: "USD")
        let transaction = TransactionItem(date: Self.day, amount: amount, currencyCode: "USD", account: account)
        transaction.exchangeRate = 9.99
        transaction.amountInPreferredCurrency = 999
        transaction.preferredCurrencyCode = "EUR"
        context.insert(transaction)
        try context.save()
    }

    /// Lo persistido, leído con un fetch nuevo y no del objeto que el test tiene en la mano.
    private func storedTransaction(_ context: ModelContext) throws -> TransactionItem {
        let all = try context.fetch(FetchDescriptor<TransactionItem>())
        try #require(all.count == 1, "se esperaba un solo registro y hay \(all.count)")
        return try #require(all.first)
    }

    private func isClose(_ lhs: Double, _ rhs: Double, tolerance: Double = 1e-9) -> Bool {
        abs(lhs - rhs) < tolerance
    }

    // MARK: - Tasa derivada

    @Test("Un monto normal queda con la tasa del día y el monto convertido")
    func effectiveRate_normalAmount() async throws {
        let context = try makeTestContext()
        try seedRates(in: context)
        try seedTransaction(amount: 100, in: context)

        try await service.updateAllTransactions(to: "PEN", context: context)

        let stored = try storedTransaction(context)
        #expect(isClose(stored.exchangeRate, 3.75), "tasa guardada: \(stored.exchangeRate)")
        #expect(isClose(stored.amountInPreferredCurrency, 375), "monto convertido: \(stored.amountInPreferredCurrency)")
        #expect(stored.preferredCurrencyCode == "PEN")
    }

    /// El `abs()` del servicio no se puede poner rojo desde aquí: el monto convertido lleva siempre el signo del original,
    /// así que la división ya sale positiva (mutante equivalente, medido). Lo que este caso fija es el monto con su signo.
    @Test("Un gasto guarda la tasa del día y el monto convertido con su signo")
    func effectiveRate_negativeAmount() async throws {
        let context = try makeTestContext()
        try seedRates(in: context)
        try seedTransaction(amount: -50, in: context)

        try await service.updateAllTransactions(to: "PEN", context: context)

        let stored = try storedTransaction(context)
        #expect(isClose(stored.exchangeRate, 3.75), "tasa guardada: \(stored.exchangeRate)")
        #expect(
            isClose(stored.amountInPreferredCurrency, -187.5),
            "monto convertido: \(stored.amountInPreferredCurrency)"
        )
    }

    @Test("Un monto cero guarda tasa 1 en vez de dividir por cero")
    func effectiveRate_zeroAmount_defaultsToOne() async throws {
        let context = try makeTestContext()
        try seedRates(in: context)
        try seedTransaction(amount: 0, in: context)

        try await service.updateAllTransactions(to: "PEN", context: context)

        let stored = try storedTransaction(context)
        #expect(stored.exchangeRate == 1.0, "tasa guardada: \(stored.exchangeRate)")
        #expect(stored.amountInPreferredCurrency == 0)
        #expect(stored.preferredCurrencyCode == "PEN")
    }

    /// Bajo el umbral la división daría 3,75 igual: solo el `else { 1.0 }` deja un 1. Si el umbral baja, rojo.
    @Test("Un monto por debajo del umbral guarda tasa 1")
    func effectiveRate_tinyAmount_defaultsToOne() async throws {
        let context = try makeTestContext()
        try seedRates(in: context)
        try seedTransaction(amount: 0.00001, in: context)

        try await service.updateAllTransactions(to: "PEN", context: context)

        let stored = try storedTransaction(context)
        #expect(stored.exchangeRate == 1.0, "tasa guardada: \(stored.exchangeRate)")
    }

    /// La pareja del anterior: por encima del umbral se divide. Si el umbral sube, rojo.
    @Test("Un monto pequeño por encima del umbral guarda la tasa del día")
    func effectiveRate_smallAmountAboveThreshold_usesTheRate() async throws {
        let context = try makeTestContext()
        try seedRates(in: context)
        try seedTransaction(amount: 0.001, in: context)

        try await service.updateAllTransactions(to: "PEN", context: context)

        let stored = try storedTransaction(context)
        #expect(isClose(stored.exchangeRate, 3.75, tolerance: 1e-6), "tasa guardada: \(stored.exchangeRate)")
    }

    // MARK: - Progreso

    @Test("El progreso avisa cada 20 registros y termina en 1")
    func progress_every20ItemsAndCompletion() async throws {
        let context = try makeTestContext()
        try seedRates(in: context)
        let account = makeTestAccount(context: context, name: "Dólares", currencyCode: "USD")
        for index in 1...45 {
            context.insert(
                TransactionItem(date: Self.day, amount: Double(index), currencyCode: "USD", account: account)
            )
        }
        try context.save()

        var reported: [Double] = []
        try await service.updateAllTransactions(to: "PEN", context: context) { reported.append($0) }

        let expected = [0.0, 20.0 / 45.0, 40.0 / 45.0, 1.0]
        #expect(reported.count == expected.count, "avisos: \(reported)")
        #expect(zip(reported, expected).allSatisfy { isClose($0, $1) }, "avisos: \(reported)")
    }

    @Test("Sin registros, el progreso salta directo a 1")
    func progress_emptyStoreReportsCompletion() async throws {
        let context = try makeTestContext()

        var reported: [Double] = []
        try await service.updateAllTransactions(to: "PEN", context: context) { reported.append($0) }

        #expect(reported == [1.0])
    }
}
