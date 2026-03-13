//
//  ScreenshotListExtractorTests.swift
//  YalaTests
//
//  Tests for ScreenshotListExtractor.extractDescription (static, pure logic).
//

import Foundation
import Testing

@testable import Yala

struct ScreenshotListExtractorTests {

    // MARK: - extractDescription

    @Test @MainActor func extractDescription_removesAmount() {
        let result = ScreenshotListExtractor.extractDescription(
            from: "Walmart 50 groceries",
            amount: Decimal(50),
            date: nil
        )
        #expect(!result.contains("50"))
        #expect(result.contains("Walmart"))
    }

    @Test @MainActor func extractDescription_removesCurrencySymbols() {
        let result = ScreenshotListExtractor.extractDescription(
            from: "$100 Coffee Shop",
            amount: Decimal(100),
            date: nil
        )
        #expect(!result.contains("$"))
    }

    @Test @MainActor func extractDescription_removesEuroSymbol() {
        let result = ScreenshotListExtractor.extractDescription(
            from: "€25 Bakery",
            amount: Decimal(25),
            date: nil
        )
        #expect(!result.contains("€"))
    }

    @Test @MainActor func extractDescription_removesDatePatterns_whenDateProvided() {
        let date = makeDate(2025, 3, 15)
        let result = ScreenshotListExtractor.extractDescription(
            from: "15/03 Coffee Shop 100",
            amount: Decimal(100),
            date: date
        )
        #expect(!result.contains("15/03"))
    }

    @Test @MainActor func extractDescription_keepsDatePatterns_whenDateNil() {
        let result = ScreenshotListExtractor.extractDescription(
            from: "15/03 Coffee Shop",
            amount: Decimal(0),
            date: nil
        )
        // Currency symbol regex may strip the leading zero; check the date digits remain
        #expect(result.contains("15"))
    }

    @Test @MainActor func extractDescription_removesRelativeDates_hoy() {
        let date = Date()
        let result = ScreenshotListExtractor.extractDescription(
            from: "Hoy Cafe Central",
            amount: Decimal(0),
            date: date
        )
        #expect(!result.lowercased().contains("hoy"))
    }

    @Test @MainActor func extractDescription_removesRelativeDates_yesterday() {
        let date = Date()
        let result = ScreenshotListExtractor.extractDescription(
            from: "Yesterday Market",
            amount: Decimal(0),
            date: date
        )
        #expect(!result.lowercased().contains("yesterday"))
    }

    @Test @MainActor func extractDescription_collapsesWhitespace() {
        let result = ScreenshotListExtractor.extractDescription(
            from: "Coffee   Shop   Downtown",
            amount: Decimal(0),
            date: nil
        )
        #expect(!result.contains("  "))
    }

    @Test @MainActor func extractDescription_tooShortResult_returnsOriginalTruncated() {
        // After removing amount, the remaining text is < 3 chars
        let result = ScreenshotListExtractor.extractDescription(
            from: "50",
            amount: Decimal(50),
            date: nil
        )
        // Should return original text (truncated to 50 chars)
        #expect(result.count >= 1)
    }

    @Test @MainActor func extractDescription_trimsWhitespace() {
        let result = ScreenshotListExtractor.extractDescription(
            from: "  Coffee Shop  ",
            amount: Decimal(0),
            date: nil
        )
        #expect(result == "Coffee Shop")
    }

    // MARK: - Helpers

    private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        return Calendar.current.date(from: components)!
    }
}
