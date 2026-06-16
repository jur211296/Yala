//
//  RecordsDuplicateLogicTests.swift
//  YalaTests
//
//  Pure-logic tests for RecordsDuplicateLogic. R8-safe (no ModelContext).
//

import Foundation
import Testing

@testable import Yala

struct RecordsDuplicateLogicTests {

    // MARK: - Helpers

    private var utcCalendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int = 12, _ min: Int = 0) -> Date {
        var comps = DateComponents()
        comps.year = y; comps.month = mo; comps.day = d; comps.hour = h; comps.minute = min
        comps.timeZone = TimeZone(identifier: "UTC")!
        return Calendar(identifier: .gregorian).date(from: comps)!
    }

    private func cand(
        _ id: Int,
        amount: Double = -50,
        currency: String = "USD",
        note: String? = nil,
        sub: String? = "sub1",
        date: Date
    ) -> RecordsDuplicateLogic.Candidate<Int> {
        .init(id: id, amount: amount, currencyCode: currency, note: note, subcategoryID: sub, date: date)
    }

    private let all = RecordsDuplicateLogic.Criteria(amount: true, note: true, subcategory: true, date: true)

    // MARK: - Tests

    @Test func allCriteria_exactMatch_groupsDuplicates() {
        let d = date(2024, 1, 15)
        let candidates = [
            cand(1, amount: -50, note: "Café", sub: "sub1", date: d),
            cand(2, amount: -50, note: "Café", sub: "sub1", date: d),       // idéntico a 1
            cand(3, amount: -50, note: "Taxi", sub: "sub1", date: d),       // nota distinta
        ]
        let result = RecordsDuplicateLogic.duplicateIDs(in: candidates, criteria: all, calendar: utcCalendar)
        #expect(result == [1, 2])
    }

    @Test func onlyAmount_groupsBySameAmount() {
        let crit = RecordsDuplicateLogic.Criteria(amount: true, note: false, subcategory: false, date: false)
        let candidates = [
            cand(1, amount: -50, note: "uno", sub: "a", date: date(2024, 1, 1)),
            cand(2, amount: -50, note: "dos", sub: "b", date: date(2024, 6, 9)),  // mismo monto, todo lo demás distinto
            cand(3, amount: -30, note: "tres", sub: "c", date: date(2024, 1, 1)),
        ]
        let result = RecordsDuplicateLogic.duplicateIDs(in: candidates, criteria: crit, calendar: utcCalendar)
        #expect(result == [1, 2])
    }

    @Test func note_trimAndCaseInsensitive_matches() {
        let crit = RecordsDuplicateLogic.Criteria(amount: false, note: true, subcategory: false, date: false)
        let candidates = [
            cand(1, amount: -10, note: "Café ", date: date(2024, 1, 1)),
            cand(2, amount: -99, note: "café", date: date(2024, 1, 1)),   // trim + lowercase → coincide
            cand(3, amount: -10, note: "Taxi", date: date(2024, 1, 1)),
        ]
        let result = RecordsDuplicateLogic.duplicateIDs(in: candidates, criteria: crit, calendar: utcCalendar)
        #expect(result == [1, 2])
    }

    @Test func date_sameDayDifferentTime_matches() {
        let crit = RecordsDuplicateLogic.Criteria(amount: false, note: false, subcategory: false, date: true)
        let candidates = [
            cand(1, date: date(2024, 1, 15, 9, 0)),
            cand(2, date: date(2024, 1, 15, 23, 30)),  // mismo día, distinta hora
            cand(3, date: date(2024, 1, 16, 9, 0)),    // otro día
        ]
        let result = RecordsDuplicateLogic.duplicateIDs(in: candidates, criteria: crit, calendar: utcCalendar)
        #expect(result == [1, 2])
    }

    @Test func crossCurrency_sameAmount_noMatch() {
        let candidates = [
            cand(1, amount: -50, currency: "USD", note: "x", sub: "a", date: date(2024, 1, 1)),
            cand(2, amount: -50, currency: "PEN", note: "x", sub: "a", date: date(2024, 1, 1)),
        ]
        let result = RecordsDuplicateLogic.duplicateIDs(in: candidates, criteria: all, calendar: utcCalendar)
        #expect(result.isEmpty)
    }

    @Test func signedAmount_expenseVsIncome_sameAbs_noMatch() {
        let crit = RecordsDuplicateLogic.Criteria(amount: true, note: false, subcategory: false, date: false)
        let candidates = [
            cand(1, amount: -50, date: date(2024, 1, 1)),  // gasto
            cand(2, amount: 50, date: date(2024, 1, 1)),   // ingreso, mismo valor absoluto
        ]
        let result = RecordsDuplicateLogic.duplicateIDs(in: candidates, criteria: crit, calendar: utcCalendar)
        #expect(result.isEmpty)
    }

    @Test func emptyCriteria_returnsEmpty() {
        let crit = RecordsDuplicateLogic.Criteria(amount: false, note: false, subcategory: false, date: false)
        let d = date(2024, 1, 1)
        let candidates = [
            cand(1, amount: -50, note: "x", sub: "a", date: d),
            cand(2, amount: -50, note: "x", sub: "a", date: d),  // idénticos pero sin criterios
        ]
        let result = RecordsDuplicateLogic.duplicateIDs(in: candidates, criteria: crit, calendar: utcCalendar)
        #expect(result.isEmpty)
    }

    @Test func singleOccurrences_returnsEmpty() {
        let candidates = [
            cand(1, amount: -10, note: "a", sub: "s1", date: date(2024, 1, 1)),
            cand(2, amount: -20, note: "b", sub: "s2", date: date(2024, 2, 2)),
            cand(3, amount: -30, note: "c", sub: "s3", date: date(2024, 3, 3)),
        ]
        let result = RecordsDuplicateLogic.duplicateIDs(in: candidates, criteria: all, calendar: utcCalendar)
        #expect(result.isEmpty)
    }

    @Test func subcategoryCriterion_distinguishesBySubcategory() {
        let crit = RecordsDuplicateLogic.Criteria(amount: true, note: false, subcategory: true, date: false)
        let candidates = [
            cand(1, amount: -50, sub: "food", date: date(2024, 1, 1)),
            cand(2, amount: -50, sub: "food", date: date(2024, 1, 1)),   // mismo monto + subcat
            cand(3, amount: -50, sub: "transport", date: date(2024, 1, 1)), // misma cantidad, otra subcat
        ]
        let result = RecordsDuplicateLogic.duplicateIDs(in: candidates, criteria: crit, calendar: utcCalendar)
        #expect(result == [1, 2])
    }
}
