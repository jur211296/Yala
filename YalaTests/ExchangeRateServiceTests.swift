//
//  ExchangeRateServiceTests.swift
//  YalaTests
//
//  Unit tests for ExchangeRateService utility logic (date grouping, protocol conformance) and
//  ExchangeRate.decodedRates() (tolerancia a las dos caras del blob — doubles nativos y strings
//  escala-8 del canal nube; bug device 2026-07-18).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

struct ExchangeRateServiceTests {

    // MARK: - Protocol Conformance

    @MainActor @Test func conformsToProtocol() {
        let service = ExchangeRateService.shared
        #expect(service is ExchangeRateServiceProtocol)
    }

    // MARK: - Date Key Format

    @Test func dateKeyFormat_isYYYYMMDD() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")

        let calendar = Calendar.current
        let date = calendar.date(from: DateComponents(year: 2025, month: 3, day: 15))!
        let key = formatter.string(from: date)
        #expect(key == "2025-03-15")
    }

    @Test func dateKeyFormat_singleDigitMonthDay_pads() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")

        let calendar = Calendar.current
        let date = calendar.date(from: DateComponents(year: 2025, month: 1, day: 5))!
        let key = formatter.string(from: date)
        #expect(key == "2025-01-05")
    }

    // MARK: - Date Grouping Logic (mirrors private groupIntoRanges)

    @Test func groupIntoRanges_contiguousDates_singleRange() {
        let calendar = Calendar.current
        let dates = [
            calendar.date(from: DateComponents(year: 2025, month: 1, day: 1))!,
            calendar.date(from: DateComponents(year: 2025, month: 1, day: 2))!,
            calendar.date(from: DateComponents(year: 2025, month: 1, day: 3))!,
        ]

        let ranges = groupDatesIntoRanges(dates)
        #expect(ranges.count == 1)
    }

    @Test func groupIntoRanges_withGap_twoRanges() {
        let calendar = Calendar.current
        let dates = [
            calendar.date(from: DateComponents(year: 2025, month: 1, day: 1))!,
            calendar.date(from: DateComponents(year: 2025, month: 1, day: 2))!,
            // gap
            calendar.date(from: DateComponents(year: 2025, month: 1, day: 5))!,
            calendar.date(from: DateComponents(year: 2025, month: 1, day: 6))!,
        ]

        let ranges = groupDatesIntoRanges(dates)
        #expect(ranges.count == 2)
    }

    @Test func groupIntoRanges_singleDate_singleRange() {
        let calendar = Calendar.current
        let dates = [
            calendar.date(from: DateComponents(year: 2025, month: 6, day: 15))!
        ]

        let ranges = groupDatesIntoRanges(dates)
        #expect(ranges.count == 1)
    }

    @Test func groupIntoRanges_empty_noRanges() {
        let ranges = groupDatesIntoRanges([])
        #expect(ranges.isEmpty)
    }

    @Test func groupIntoRanges_allSeparate_manyRanges() {
        let calendar = Calendar.current
        let dates = [
            calendar.date(from: DateComponents(year: 2025, month: 1, day: 1))!,
            calendar.date(from: DateComponents(year: 2025, month: 1, day: 5))!,
            calendar.date(from: DateComponents(year: 2025, month: 1, day: 10))!,
        ]

        let ranges = groupDatesIntoRanges(dates)
        #expect(ranges.count == 3)
    }

    // MARK: - Helper (mirrors ExchangeRateService.groupIntoRanges)

    /// Reimplementation of the private groupIntoRanges for testing the algorithm
    private func groupDatesIntoRanges(_ dates: [Date]) -> [DateInterval] {
        guard !dates.isEmpty else { return [] }

        let sortedDates = dates.sorted()
        var ranges: [DateInterval] = []
        var rangeStart = sortedDates[0]
        var rangeEnd = sortedDates[0]

        for date in sortedDates.dropFirst() {
            let daysDiff = Calendar.current.dateComponents([.day], from: rangeEnd, to: date).day ?? 0

            if daysDiff <= 1 {
                rangeEnd = date
            } else {
                ranges.append(DateInterval(start: rangeStart, end: rangeEnd))
                rangeStart = date
                rangeEnd = date
            }
        }

        ranges.append(DateInterval(start: rangeStart, end: rangeEnd))
        return ranges
    }

    // MARK: - ExchangeRate.decodedRates (tolerancia a las dos caras del blob)

    private func makeRate(_ json: String) -> ExchangeRate {
        ExchangeRate(dateKey: "2026-07-12", base: "USD", rates: Data(json.utf8))
    }

    @Test func decodedRates_nativeDoubles_decodes() {
        let rate = makeRate(#"{"EUR":0.9,"PEN":3.75}"#)
        #expect(rate.decodedRates() == ["EUR": 0.9, "PEN": 3.75])
    }

    @Test func decodedRates_stringScale8PostPull_decodes() {
        // La cara post-pull del canal nube: el canon c1 proyecta números anidados como STRING escala-8
        // y el apply re-serializa verbatim. El decode estricto pre-fix devolvía [:] (bug 2026-07-18:
        // "Expected Double... Path: ILS" → se perdían TODAS las tasas de la fecha).
        let rate = makeRate(#"{"ILS":"3.61230000","PEN":"3.75000000"}"#)
        #expect(rate.decodedRates() == ["ILS": 3.6123, "PEN": 3.75])
    }

    @Test func decodedRates_mixedFaces_decodesBoth() {
        // Blob mixto alcanzable: persistRate escribe doubles sobre una fila que llegó con strings.
        let rate = makeRate(#"{"ILS":"3.61230000","EUR":0.9}"#)
        #expect(rate.decodedRates() == ["ILS": 3.6123, "EUR": 0.9])
    }

    @Test func decodedRates_nonNumericValues_skipOnlyThatKey() {
        // Un valor no numérico ya no tumba la fecha entera — se omite solo esa key.
        let rate = makeRate(#"{"EUR":0.9,"BAD":"n/a","FLAG":true,"NIL":null,"NEST":{"x":1}}"#)
        #expect(rate.decodedRates() == ["EUR": 0.9])
    }

    @Test func decodedRates_nonFiniteString_skipped() {
        // `Double("Infinity")` parsea a .infinity — el guard isFinite la descarta (el canon jamás
        // emite no-finitos; esto solo puede ser blob basura).
        let rate = makeRate(#"{"EUR":0.9,"INF":"Infinity"}"#)
        #expect(rate.decodedRates() == ["EUR": 0.9])
    }

    @Test func decodedRates_emptyOrMalformed_returnsEmpty() {
        #expect(ExchangeRate(dateKey: "2026-07-12", base: "USD", rates: Data()).decodedRates() == [:])
        #expect(makeRate("{not json").decodedRates() == [:])
        #expect(makeRate(#"[1,2]"#).decodedRates() == [:])
    }
}
