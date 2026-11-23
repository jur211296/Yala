//
//  TasasDeCambioConverterTests.swift
//  YalaTests / TasasDeCambioLote
//
//  Ticket `duplicate-exchange-rate-rows-pick-an-arbitrary-rate`: con dos filas del mismo día y valores distintos, el
//  converter usaba `results.first` sin orden. Ahora funde las copias con una regla fija, por las tres rutas que leen
//  filas (la del día, el escalón de los días anteriores y las tasas en bloque) y por la caché del TC actual.
//
//  Cada caso se siembra en LOS DOS órdenes de inserción: con `results.first`, uno de los dos sale con la otra copia.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Tasas de cambio · el converter lee un día repetido siempre igual", .serialized)
struct TasasDeCambioConverterTests {

    private static let utc: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    /// Un día fijo del pasado, a mediodía UTC.
    private func day(_ offset: Int) -> Date {
        let base = Date(timeIntervalSince1970: 1_748_779_200)  // 2025-06-01 12:00 UTC
        return base.addingTimeInterval(Double(offset) * 86_400)
    }

    private func insert(_ context: ModelContext, on date: Date, ts: TimeInterval?, sid: UUID? = nil,
                        _ rates: [String: Double]) throws {
        let row = try ExchangeRate(dateKey: Self.utc.string(from: date), base: "USD", ratesDictionary: rates,
                                   timestamp: ts.map { Date(timeIntervalSince1970: $0) })
        row.syncID = sid
        context.insert(row)
    }

    private func converter(_ context: ModelContext) -> CurrencyConverter {
        let converter = CurrencyConverter(notificationCenter: NotificationCenter())
        converter.setContext(context)
        return converter
    }

    private let older: [String: Double] = ["USD": 1, "EUR": 0.80, "PEN": 3.70]
    private let newer: [String: Double] = ["USD": 1, "EUR": 0.95]

    @Test(arguments: [false, true])
    func twoCopiesOfTheDay_convertWithTheNewestEachTime(_ newerFirst: Bool) throws {
        let context = try makeTestContext()
        if newerFirst {
            try insert(context, on: day(0), ts: 200, newer)
            try insert(context, on: day(0), ts: 100, older)
        } else {
            try insert(context, on: day(0), ts: 100, older)
            try insert(context, on: day(0), ts: 200, newer)
        }
        try context.save()
        let sut = converter(context)

        let eur = sut.convertChecked(100, from: "USD", to: "EUR", on: day(0))
        #expect(eur.amount == Decimal(100) * Decimal(0.95))
        #expect(eur.quality == .exact)
        // La copia nueva no trae PEN: la vieja lo completa, y sigue siendo la tasa EXACTA del día.
        let pen = sut.convertChecked(100, from: "USD", to: "PEN", on: day(0))
        #expect(pen.amount == Decimal(100) * Decimal(3.70))
        #expect(pen.quality == .exact)
    }

    @Test(arguments: [false, true])
    func copiesOfAPreviousDay_carryForwardTheSameRate(_ newerFirst: Bool) throws {
        let context = try makeTestContext()
        if newerFirst {
            try insert(context, on: day(0), ts: 200, newer)
            try insert(context, on: day(0), ts: 100, older)
        } else {
            try insert(context, on: day(0), ts: 100, older)
            try insert(context, on: day(0), ts: 200, newer)
        }
        // El día siguiente no trae EUR: se arrastra del anterior.
        try insert(context, on: day(1), ts: 300, ["USD": 1, "PEN": 3.75])
        try context.save()
        let sut = converter(context)

        let eur = sut.convertChecked(100, from: "USD", to: "EUR", on: day(1))
        #expect(eur.amount == Decimal(100) * Decimal(0.95))
        #expect(eur.quality == .carriedForward(fromDateKey: Self.utc.string(from: day(0))))
    }

    @Test(arguments: [false, true])
    func latestRateCache_readsTodaysCopiesWithTheSameRule(_ newerFirst: Bool) throws {
        let context = try makeTestContext()
        let now = Date.now
        if newerFirst {
            try insert(context, on: now, ts: 200, newer)
            try insert(context, on: now, ts: 100, older)
        } else {
            try insert(context, on: now, ts: 100, older)
            try insert(context, on: now, ts: 200, newer)
        }
        try context.save()
        let sut = converter(context)
        let latest = sut.convertCheckedWithLatestRate(100, from: "USD", to: "EUR")
        #expect(latest.amount == Decimal(100) * Decimal(0.95))
        #expect(latest.amount == sut.convertChecked(100, from: "USD", to: "EUR", on: now).amount)
    }

    /// El escalón 2 mira las 30 filas más recientes. Si el corte cae entre las dos copias de un día, sin completarlo cada
    /// lectura se quedaría con la copia que SQLite devolviera primero: aquí el día 0 tiene dos copias con EUR distinto y
    /// es justo el que corta la ventana del día 30 (29 filas de los días 1-29, sin EUR, más una del día 0).
    @Test(arguments: [(false, false), (false, true), (true, false), (true, true)])
    func lookbackCutInsideADay_readsTheWholeDay(_ secondIsNewer: Bool, _ eightyFirst: Bool) throws {
        let context = try makeTestContext()
        // Las dos copias del día 0, en los cuatro órdenes posibles de inserción y de hora: SQLite no garantiza qué
        // copia devuelve en un empate de clave, así que solo así alguna de las cuatro deja fuera la buena.
        let first: (ts: TimeInterval, eur: Double) = (secondIsNewer ? 100 : 200, eightyFirst ? 0.80 : 0.95)
        let second: (ts: TimeInterval, eur: Double) = (secondIsNewer ? 200 : 100, eightyFirst ? 0.95 : 0.80)
        try insert(context, on: day(0), ts: first.ts, ["USD": 1, "EUR": first.eur])
        try insert(context, on: day(0), ts: second.ts, ["USD": 1, "EUR": second.eur])
        let expected = secondIsNewer ? second.eur : first.eur
        for offset in 1...29 { try insert(context, on: day(offset), ts: 300, ["USD": 1, "PEN": 3.7]) }
        try context.save()
        let sut = converter(context)

        let eur = sut.convertChecked(100, from: "USD", to: "EUR", on: day(30))
        #expect(eur.amount == Decimal(100) * Decimal(expected))
        // USD llega ya del día 29, que es el primero que se arrastra.
        #expect(eur.quality == .carriedForward(fromDateKey: Self.utc.string(from: day(29))))
        let batch = sut.rateFactors(for: ["EUR"], to: "USD", on: [day(30)])
        let single = sut.convertChecked(1, from: "EUR", to: "USD", on: day(30))
        #expect(batch[day(30)]?["EUR"] == RateFactor(factor: single.amount, quality: single.quality))
    }

    /// Las tasas en bloque y la conversión fecha a fecha siguen de acuerdo con copias repetidas, también cuando el tope
    /// de 30 filas del escalón 2 corta en medio de un día con copias.
    @Test func batchMatchesPerDate_withCopiesAndTheLookbackBoundary() throws {
        let context = try makeTestContext()
        // EUR solo en el día 0 (dos copias distintas) y en el día 5 (dos copias); los demás días, una o dos copias sin
        // EUR, para que la ventana de 30 filas corte dentro de un día repetido según la fecha.
        try insert(context, on: day(0), ts: 100, ["USD": 1, "PEN": 3.6, "EUR": 0.80])
        try insert(context, on: day(0), ts: 200, ["USD": 1, "EUR": 0.85])
        try insert(context, on: day(5), ts: 100, ["USD": 1, "PEN": 3.6, "EUR": 0.90])
        try insert(context, on: day(5), ts: 50, ["USD": 1, "EUR": 0.70])
        for offset in 6..<40 {
            try insert(context, on: day(offset), ts: 1000 + Double(offset), ["USD": 1, "PEN": 3.6 + Double(offset) / 100])
            if offset % 3 == 0 {
                try insert(context, on: day(offset), ts: 500, ["USD": 1, "PEN": 3.0])
            }
        }
        try context.save()
        let sut = converter(context)
        let dates = (0..<45).map(day)
        let codes: Set<String> = ["EUR", "PEN", "USD"]

        let batch = sut.rateFactors(for: codes, to: "USD", on: dates)
        var mismatches: [String] = []
        for date in dates {
            for code in codes.sorted() {
                let single = sut.convertChecked(1, from: code, to: "USD", on: date)
                if batch[date]?[code] != RateFactor(factor: single.amount, quality: single.quality) {
                    mismatches.append("\(Self.utc.string(from: date)) \(code)")
                }
            }
        }
        #expect(mismatches.isEmpty, "\(mismatches.prefix(8))")
        // El fixture recorre el arrastre y la tabla estática, o no distinguiría nada.
        let qualities = batch.values.flatMap(\.values).map(\.quality)
        #expect(qualities.contains { if case .carriedForward = $0 { true } else { false } })
        #expect(qualities.contains(.staticFallback))
    }
}
