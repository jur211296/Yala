//
//  TasasDeCambioLogicTests.swift
//  YalaTests / TasasDeCambioLote
//
//  Encargo «Tasas de cambio» (2026-11-22): la regla fija con la que se lee un día con varias filas
//  (`duplicate-exchange-rate-rows-pick-an-arbitrary-rate`), las claves de otro calendario
//  (`exchange-rate-date-keys-follow-the-phone-calendar`) y los formatters que las escriben.
//

import Foundation
import Testing

@testable import Yala

@Suite("Tasas de cambio · regla fija para un día con varias filas y claves gregorianas")
struct TasasDeCambioLogicTests {

    private func row(_ sid: String?, ts: TimeInterval?, _ rates: [String: Double]) -> ExchangeRateDuplicateLogic.DayRow {
        .init(syncID: sid, timestamp: ts.map { Date(timeIntervalSince1970: $0) }, rates: rates)
    }

    @Test("el resultado no depende del orden de llegada: gana la copia más nueva en cada divisa")
    func mergedDayRates_isOrderIndependent() {
        let older = row("b", ts: 100, ["USD": 1, "EUR": 0.90, "PEN": 3.7])
        let newer = row("a", ts: 200, ["USD": 1, "EUR": 0.95])
        let expected: [String: Double] = ["USD": 1, "EUR": 0.95, "PEN": 3.7]
        #expect(ExchangeRateDuplicateLogic.mergedDayRates([older, newer]) == expected)
        #expect(ExchangeRateDuplicateLogic.mergedDayRates([newer, older]) == expected)
    }

    @Test("sin hora ni identidad decide el contenido, igual en los dos órdenes")
    func mergedDayRates_withoutTimestampOrIdentity_isStillDeterministic() {
        let partial = row(nil, ts: nil, ["USD": 1, "EUR": 0.80])
        let full = row(nil, ts: nil, ["USD": 1, "EUR": 0.90, "PEN": 3.7])
        let one = ExchangeRateDuplicateLogic.mergedDayRates([partial, full])
        let other = ExchangeRateDuplicateLogic.mergedDayRates([full, partial])
        #expect(one == other)
        // La más completa se aplica la última.
        #expect(one["EUR"] == 0.90)
    }

    @Test("una tasa inservible de la copia nueva no pisa la buena de otra copia")
    func mergedDayRates_unusableRateDoesNotOverride() {
        let older = row("a", ts: 100, ["USD": 1, "EUR": 0.90])
        let newer = row("b", ts: 200, ["USD": 1, "EUR": 0, "JPY": .nan])
        #expect(ExchangeRateDuplicateLogic.mergedDayRates([older, newer]) == ["USD": 1, "EUR": 0.90])
    }

    @Test("newestIndex señala la copia que se aplica la última")
    func newestIndex_pointsAtTheLastApplied() {
        let rows = [row("a", ts: 300, ["USD": 1]), row("b", ts: 100, ["USD": 1]), row(nil, ts: nil, ["USD": 1])]
        #expect(ExchangeRateDuplicateLogic.newestIndex(rows) == 0)
        #expect(ExchangeRateDuplicateLogic.newestIndex([]) == nil)
    }

    @Test("claves de otro calendario o mal formadas son imposibles; las gregorianas creíbles no",
          arguments: [
              ("2569-11-22", true), ("0008-11-22", true), ("2026-13-01", true), ("2026-11-32", true),
              ("2026-1-01", true), ("garbage", true), ("", true),
              ("2026-11-22", false), ("2027-01-01", false), ("1999-01-04", false),
          ])
    func implausibleDateKeys(_ key: String, _ expected: Bool) {
        #expect(ExchangeRateDuplicateLogic.isImplausibleDateKey(key, currentYear: 2026) == expected)
    }

    // MARK: - Formatters

    /// Lo que pasaba, reproducido sin tocar el sistema: un formatter con el formato fijo y SIN calendario propio escribe
    /// el año del calendario de su locale. Con el calendario budista, 2026 sale 2569.
    @Test func aFormatterWithoutCalendar_writesTheYearOfItsLocale() throws {
        let instant = try #require(ISO8601DateFormatter().date(from: "2026-11-22T12:00:00Z"))
        let buddhist = DateFormatter()
        buddhist.locale = Locale(identifier: "th_TH@calendar=buddhist")
        buddhist.dateFormat = "yyyy-MM-dd"
        buddhist.timeZone = TimeZone(identifier: "UTC")
        #expect(buddhist.string(from: instant) == "2569-11-22")

        // Con el arreglo (locale POSIX y calendario gregoriano fijos), la clave es la de todos.
        buddhist.locale = Locale(identifier: "en_US_POSIX")
        buddhist.calendar = Calendar(identifier: .gregorian)
        #expect(buddhist.string(from: instant) == "2026-11-22")
    }

    private static func readSource(of relativePath: String, file: StaticString = #filePath) throws -> String {
        let testFile = URL(fileURLWithPath: "\(file)")
        let repoRoot = testFile.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: repoRoot.appending(path: relativePath), encoding: .utf8)
    }

    /// Los tres formatters que escriben o piden claves de tasas fijan locale y calendario JUSTO antes del formato. Son
    /// `private`, así que la red es el código: si alguien quita una de las dos líneas, la clave vuelve a seguir al iPhone.
    @Test(arguments: [
        "Yala/Services/CurrencyConverter.swift",
        "Yala/Services/ExchangeRateService.swift",
        "Yala/Services/ExchangeRateAPIService.swift",
    ])
    func rateKeyFormatters_pinLocaleAndCalendar(_ path: String) throws {
        let lines = try Self.readSource(of: path).components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("//") }
        let formatLines = lines.indices.filter { lines[$0].contains("dateFormat = \"yyyy-MM-dd\"") }
        #expect(formatLines.count == 1, "\(path): un solo formatter de claves")
        let index = try #require(formatLines.first)
        let before = lines[max(0, index - 2)..<index].joined(separator: " ")
        #expect(before.contains("locale = Locale(identifier: \"en_US_POSIX\")"), "\(path)")
        #expect(before.contains("calendar = Calendar(identifier: .gregorian)"), "\(path)")
    }
}
