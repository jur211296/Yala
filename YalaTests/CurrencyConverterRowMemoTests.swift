//
//  CurrencyConverterRowMemoTests.swift
//  YalaTests
//
//  Card «Convertir importes de otra fecha hace un fetch de tasas por llamada» (Time Profiler del 2026-10-30: ~170 ms
//  de un arranque en `convertChecked` → `fetchExchangeRate`). `resolveRates` lee ahora cada fila una vez por pasada
//  (`CurrencyConverter.rowMemo`), y lo que importa tanto como el ahorro es que la memoria NO tape una fila mejor que
//  llega después: el bug de siempre de este módulo (`currency-fx.md`).
//
//  Cada caso de invalidación lleva su control: sin la retirada, la conversión seguiría con la tasa vieja.
//

import CoreData
import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Converter · cada fila de tasas se lee una vez por pasada", .serialized)
struct CurrencyConverterRowMemoTests {

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    /// Un día fijo del pasado: la fila de «hoy» no interviene.
    private let day: Date = {
        var components = DateComponents()
        components.year = 2025
        components.month = 6
        components.day = 15
        components.hour = 12
        components.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: components) ?? .distantPast
    }()

    private func makeContext() throws -> ModelContext {
        let schema = Schema([ExchangeRate.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
    }

    @discardableResult
    private func insertRow(_ rates: [String: Double], on date: Date, into context: ModelContext) throws -> ExchangeRate {
        let row = try ExchangeRate(dateKey: Self.dateFormatter.string(from: date), base: "USD", ratesDictionary: rates)
        context.insert(row)
        return row
    }

    // MARK: - El ahorro

    @Test func manyConversionsOfTheSameDay_readTheRowsOnce() throws {
        let context = try makeContext()
        // Falta PEN en la fila del día: cada conversión baja también al escalón de las filas anteriores.
        try insertRow(["USD": 1, "EUR": 0.9], on: day, into: context)
        try insertRow(["USD": 1, "EUR": 0.9, "PEN": 3.7], on: day.addingTimeInterval(-86_400), into: context)
        try context.save()

        let converter = CurrencyConverter()
        let first = converter.convertChecked(100, from: "EUR", to: "PEN", on: day, context: context)
        let afterFirst = converter._testRateRowFetches
        for _ in 0..<50 {
            let again = converter.convertChecked(100, from: "EUR", to: "PEN", on: day, context: context)
            #expect(again.amount == first.amount)
            #expect(again.quality == first.quality)
        }
        #expect(afterFirst == 2, "La primera conversión lee la fila del día y las anteriores.")
        #expect(converter._testRateRowFetches == afterFirst, "Las 50 siguientes no vuelven a leer.")
        #expect(first.quality == .carriedForward(fromDateKey: Self.dateFormatter.string(from: day.addingTimeInterval(-86_400))))
    }

    @Test func memoAgreesWithAFreshConverter_onEveryRung() throws {
        let context = try makeContext()
        try insertRow(["USD": 1, "EUR": 0.9, "JPY": 0], on: day, into: context)        // JPY inservible
        try insertRow(["USD": 1, "PEN": 3.7], on: day.addingTimeInterval(-86_400), into: context)
        try context.save()

        let warm = CurrencyConverter()
        let pairs: [(String, String)] = [("EUR", "USD"), ("EUR", "PEN"), ("JPY", "EUR"), ("CHF", "EUR"), ("USD", "USD")]
        for _ in 0..<2 {
            for (from, to) in pairs {
                let memo = warm.convertChecked(1_000, from: from, to: to, on: day, context: context)
                let fresh = CurrencyConverter().convertChecked(1_000, from: from, to: to, on: day, context: context)
                #expect(memo.amount == fresh.amount, "\(from)→\(to)")
                #expect(memo.quality == fresh.quality, "\(from)→\(to)")
            }
        }
    }

    // MARK: - Lo que la retira

    @Test func aSaveThatWritesABetterRow_isSeenInTheSamePass() throws {
        let context = try makeContext()
        try insertRow(["USD": 1, "EUR": 0.9], on: day, into: context)
        try context.save()

        let converter = CurrencyConverter()
        let before = converter.convertChecked(100, from: "USD", to: "PEN", on: day, context: context)
        #expect(before.quality == .staticFallback)

        // Llega la fila completa del día (lo que haría el pull del Modo Nube o el espejo, sin notificación).
        let rows = try context.fetch(FetchDescriptor<ExchangeRate>())
        for row in rows { context.delete(row) }
        try insertRow(["USD": 1, "EUR": 0.9, "PEN": 4], on: day, into: context)
        try context.save()

        let after = converter.convertChecked(100, from: "USD", to: "PEN", on: day, context: context)
        #expect(after.quality == .exact)
        #expect(after.amount == 400)
    }

    @Test func theRatesNotification_dropsWhatWasRead() throws {
        let context = try makeContext()
        let row = try insertRow(["USD": 1, "PEN": 3], on: day, into: context)
        try context.save()

        let converter = CurrencyConverter()
        #expect(converter.convertChecked(100, from: "USD", to: "PEN", on: day, context: context).amount == 300)

        // Cambio SIN guardar: solo la notificación puede retirar lo leído.
        row.rates = try JSONEncoder().encode(["USD": 1.0, "PEN": 4.0])
        #expect(converter.convertChecked(100, from: "USD", to: "PEN", on: day, context: context).amount == 300,
                "Control: dentro de la pasada, sin guardado ni aviso, sigue lo leído.")

        NotificationCenter.default.post(name: .yalaExchangeRatesUpdated, object: nil)
        #expect(converter.convertChecked(100, from: "USD", to: "PEN", on: day, context: context).amount == 400)
    }

    @Test func anotherContext_doesNotReadTheFirstOnesRows() throws {
        let first = try makeContext()
        try insertRow(["USD": 1, "PEN": 3], on: day, into: first)
        try first.save()
        let second = try makeContext()
        try insertRow(["USD": 1, "PEN": 4], on: day, into: second)
        try second.save()

        let converter = CurrencyConverter()
        #expect(converter.convertChecked(100, from: "USD", to: "PEN", on: day, context: first).amount == 300)
        #expect(converter.convertChecked(100, from: "USD", to: "PEN", on: day, context: second).amount == 400)
        #expect(converter.convertChecked(100, from: "USD", to: "PEN", on: day, context: first).amount == 300)
    }

    @Test func theNextTurnOfTheMainActor_readsAgain() async throws {
        let context = try makeContext()
        let row = try insertRow(["USD": 1, "PEN": 3], on: day, into: context)
        try context.save()

        let converter = CurrencyConverter()
        #expect(converter.convertChecked(100, from: "USD", to: "PEN", on: day, context: context).amount == 300)

        // Cambio que no avisa por ningún lado (como un import del espejo que aún no notificó): vale en la vuelta siguiente.
        row.rates = try JSONEncoder().encode(["USD": 1.0, "PEN": 4.0])
        var seen: Decimal = 0
        for _ in 0..<20 {
            await Task.yield()
            seen = converter.convertChecked(100, from: "USD", to: "PEN", on: day, context: context).amount
            if seen == 400 { break }
        }
        #expect(seen == 400)
    }

    @Test func aRemoteStoreChange_dropsWhatWasRead() throws {
        let context = try makeContext()
        let row = try insertRow(["USD": 1, "PEN": 3], on: day, into: context)
        try context.save()

        let converter = CurrencyConverter()
        #expect(converter.convertChecked(100, from: "USD", to: "PEN", on: day, context: context).amount == 300)
        row.rates = try JSONEncoder().encode(["USD": 1.0, "PEN": 4.0])
        #expect(converter.convertChecked(100, from: "USD", to: "PEN", on: day, context: context).amount == 300)

        // Lo que postea Core Data cuando el espejo de iCloud importa (sin pasar por `ModelContext.didSave` aquí).
        NotificationCenter.default.post(name: .NSPersistentStoreRemoteChange, object: nil)
        #expect(converter.convertChecked(100, from: "USD", to: "PEN", on: day, context: context).amount == 400)
    }
}
