//
//  DateParserTests.swift
//  YalaTests
//
//  Unit tests for DateParser (semi-pure functions, no SwiftData).
//

import Foundation
import Testing

@testable import Yala

struct DateParserTests {

    // MARK: - Relative dates

    @Test func parse_hoy() {
        let result = DateParser.parse("hoy")
        #expect(result != nil)
        #expect(Calendar.current.isDateInToday(result!.date))
        #expect(result!.confidence == 0.99)
    }

    @Test func parse_today() {
        let result = DateParser.parse("today")
        #expect(result != nil)
        #expect(Calendar.current.isDateInToday(result!.date))
        #expect(result!.confidence == 0.99)
    }

    @Test func parse_ayer() {
        let result = DateParser.parse("ayer")
        #expect(result != nil)
        #expect(Calendar.current.isDateInYesterday(result!.date))
        #expect(result!.confidence == 0.99)
    }

    @Test func parse_yesterday() {
        let result = DateParser.parse("yesterday")
        #expect(result != nil)
        #expect(Calendar.current.isDateInYesterday(result!.date))
        #expect(result!.confidence == 0.99)
    }

    @Test func parse_caseInsensitive() {
        let result = DateParser.parse("HOY")
        #expect(result != nil)
        #expect(Calendar.current.isDateInToday(result!.date))
        #expect(result!.confidence == 0.99)
    }

    // MARK: - Absolute dates

    @Test func parse_ddMMYYYY() {
        let result = DateParser.parse("15/01/2026")
        #expect(result != nil)
        let cal = Calendar.current
        #expect(cal.component(.day, from: result!.date) == 15)
        #expect(cal.component(.month, from: result!.date) == 1)
        #expect(result!.confidence == 0.90)
    }

    @Test func parse_isoFormat() {
        let result = DateParser.parse("2026-01-15")
        #expect(result != nil)
        let cal = Calendar.current
        #expect(cal.component(.day, from: result!.date) == 15)
        #expect(cal.component(.month, from: result!.date) == 1)
        #expect(result!.confidence == 0.95)
    }

    @Test func parse_ddMMYY() {
        let result = DateParser.parse("15/01/26")
        #expect(result != nil)
        let cal = Calendar.current
        #expect(cal.component(.day, from: result!.date) == 15)
        #expect(cal.component(.month, from: result!.date) == 1)
        #expect(result!.confidence == 0.85)
    }

    @Test func parse_spanishMonth() {
        let result = DateParser.parse("24 enero")
        #expect(result != nil)
        let cal = Calendar.current
        #expect(cal.component(.day, from: result!.date) == 24)
        #expect(cal.component(.month, from: result!.date) == 1)
        #expect(result!.confidence == 0.85)
    }

    // MARK: - No match

    @Test func parse_noDate() {
        let result = DateParser.parse("hello")
        #expect(result == nil)
    }
}
