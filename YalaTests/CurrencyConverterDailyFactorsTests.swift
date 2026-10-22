//
//  CurrencyConverterDailyFactorsTests.swift
//  YalaTests
//
//  `CurrencyConverter.rateFactors` lee en bloque las tasas de muchas fechas para que una curva de saldo valore cada
//  día a su tipo de cambio sin una consulta por día (ticket `panel-balance-chart-contradicts-its-own-figure`). Tiene
//  que dar EXACTAMENTE lo que `convertChecked(1, …, on:)` da fecha a fecha: misma tasa y misma calidad. Si las dos
//  rutas divergen, una está eligiendo peor (la forma del bug de este módulo, `.claude/rules/currency-fx.md`).
//
//  El fixture tiene lo que hace fallar a este módulo: filas parciales, huecos, una tasa a cero, fechas anteriores a
//  cualquier fila, una divisa que ninguna fila trae y un relleno que queda a más de 30 filas.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Tasas de varias fechas en bloque = conversión fecha a fecha", .serialized)
struct CurrencyConverterDailyFactorsTests {

    private static let utc: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    private let calendar = Calendar.current
    private let start = Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 1, hour: 12)) ?? Date()

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: start) ?? start
    }

    private func insertRow(_ context: ModelContext, dayOffset: Int, _ rates: [String: Double]) throws {
        context.insert(try ExchangeRate(dateKey: Self.utc.string(from: day(dayOffset)), base: "USD", ratesDictionary: rates))
    }

    /// 60 días con filas casi diarias: un hueco cada 7 días (los de resto 3), EUR ausente los múltiplos de 5, PEN a cero el
    /// día 12 y una fila con solo USD el día 20. Nada antes del día 0.
    private func seedRows(_ context: ModelContext) throws {
        for offset in 0..<60 where offset % 7 != 3 {
            var rates: [String: Double] = [
                "USD": 1, "PEN": 3.6 + Double(offset) * 0.01, "MXN": 18 + Double(offset) * 0.05,
            ]
            if offset % 5 != 0 { rates["EUR"] = 0.9 + Double(offset) * 0.001 }
            if offset == 12 { rates["PEN"] = 0 }
            if offset == 20 { rates = ["USD": 1] }
            try insertRow(context, dayOffset: offset, rates)
        }
        try context.save()
    }

    private func perDate(
        _ converter: CurrencyConverter, codes: Set<String>, to: String, dates: [Date]
    ) -> [Date: [String: RateFactor]] {
        var out: [Date: [String: RateFactor]] = [:]
        for date in dates {
            var byCode: [String: RateFactor] = [:]
            for code in codes {
                let c = converter.convertChecked(1, from: code, to: to, on: date)
                byCode[code] = RateFactor(factor: c.amount, quality: c.quality)
            }
            out[date] = byCode
        }
        return out
    }

    @Test(arguments: ["PEN", "USD", "MXN"])
    func batchMatchesPerDate_onPartialRowsGapsAndZeros(_ target: String) throws {
        let context = try makeTestContext()
        try seedRows(context)
        let converter = CurrencyConverter()
        converter.setContext(context)
        // Desde 10 días antes de la primera fila hasta 5 después de la última, a mediodía y a medianoche.
        let dates = (-10..<65).flatMap { offset -> [Date] in
            let noon = day(offset)
            return [noon, calendar.startOfDay(for: noon)]
        }
        let codes: Set<String> = ["PEN", "USD", "EUR", "MXN", "JPY"]

        let batch = converter.rateFactors(for: codes, to: target, on: dates)
        let oneByOne = perDate(converter, codes: codes, to: target, dates: dates)

        var mismatches: [String] = []
        for date in dates {
            for code in codes.sorted() where batch[date]?[code] != oneByOne[date]?[code] {
                mismatches.append("\(Self.utc.string(from: date)) \(code)→\(target): bloque \(String(describing: batch[date]?[code])) ≠ fecha a fecha \(String(describing: oneByOne[date]?[code]))")
            }
        }
        #expect(mismatches.isEmpty, "\(mismatches.prefix(8))")
        // Y el fixture recorre los cuatro casos de la escalera, o el test no distinguiría nada.
        let qualities = batch.values.flatMap(\.values).map(\.quality)
        #expect(qualities.contains(.exact))
        #expect(qualities.contains { if case .carriedForward = $0 { true } else { false } })
        #expect(qualities.contains(.staticFallback))
    }

    /// El escalón 2 mira como mucho 30 filas atrás. Una divisa que solo trae una fila más vieja que eso cae a la
    /// tabla estática por las dos rutas.
    @Test func carryForwardStopsAtThirtyRowsInBothRoutes() throws {
        let context = try makeTestContext()
        try insertRow(context, dayOffset: 0, ["USD": 1, "PEN": 3.7, "EUR": 0.91])
        for offset in 1...35 { try insertRow(context, dayOffset: offset, ["USD": 1, "PEN": 3.7]) }
        try context.save()
        let converter = CurrencyConverter()
        converter.setContext(context)
        let dates = [day(10), day(31), day(32), day(36), day(40)]

        let batch = converter.rateFactors(for: ["EUR"], to: "PEN", on: dates)
        let oneByOne = perDate(converter, codes: ["EUR"], to: "PEN", dates: dates)

        for date in dates {
            #expect(batch[date]?["EUR"] == oneByOne[date]?["EUR"], "\(Self.utc.string(from: date))")
        }
        #expect(batch[day(10)]?["EUR"]?.quality == .carriedForward(fromDateKey: Self.utc.string(from: day(0))))
        #expect(batch[day(40)]?["EUR"]?.quality == .staticFallback)
    }

    /// Dos filas de la misma fecha (dos dispositivos escriben la del día): el relleno de la fecha siguiente las mira
    /// las dos, por las dos rutas.
    @Test func duplicateRowsOfOneDate_matchPerDate() throws {
        let context = try makeTestContext()
        try insertRow(context, dayOffset: 0, ["USD": 1, "PEN": 3.6, "EUR": 0.90])
        try insertRow(context, dayOffset: 1, ["USD": 1, "PEN": 3.7])
        try insertRow(context, dayOffset: 1, ["USD": 1, "PEN": 3.7, "EUR": 0.95])
        try context.save()
        let converter = CurrencyConverter()
        converter.setContext(context)
        let dates = [day(1), day(2), day(3)]
        let batch = converter.rateFactors(for: ["EUR", "PEN"], to: "PEN", on: dates)
        let oneByOne = perDate(converter, codes: ["EUR", "PEN"], to: "PEN", dates: dates)
        for date in [day(2), day(3)] {
            #expect(batch[date]?["EUR"] == oneByOne[date]?["EUR"], "\(Self.utc.string(from: date))")
        }
    }

    /// El día de la tasa es el día LOCAL, en cualquier zona: las filas van por fecha UTC, y ni la medianoche local
    /// (al este de Greenwich) ni el mediodía local (en UTC+13 y +14) caen siempre en ese día UTC.
    @Test(arguments: ["America/Lima", "Europe/Madrid", "Asia/Tokyo", "Pacific/Tongatapu", "Pacific/Pago_Pago"])
    func rateDay_isTheLocalCalendarDayInUTC(_ zone: String) throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: zone))
        for hour in [0, 6, 12, 18, 23] {
            let local = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 15, hour: hour, minute: 30)))
            let key = Self.utc.string(from: BalanceValuation.rateDay(of: local, calendar: calendar))
            #expect(key == "2026-03-15", "\(zone) a las \(hour):30 lee la fila \(key)")
        }
    }

    @Test func sameCurrencyIsExactAndOne() throws {
        let context = try makeTestContext()
        try seedRows(context)
        let converter = CurrencyConverter()
        converter.setContext(context)
        let factors = converter.rateFactors(for: ["PEN"], to: "PEN", on: [day(3)])
        #expect(factors[day(3)]?["PEN"] == RateFactor(factor: 1, quality: .exact))
    }
}
