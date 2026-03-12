//
//  ScreenshotSingleExtractorTests.swift
//  YalaTests
//
//  Tests for ScreenshotSingleExtractor.extractMerchant (static, pure logic).
//

import Foundation
import Testing

@testable import Yala

struct ScreenshotSingleExtractorTests {

    // MARK: - extractMerchant — Spanish patterns

    @Test @MainActor func extractMerchant_spanishPattern_en() {
        let result = ScreenshotSingleExtractor.extractMerchant(from: "Compra en WALMART por $50")
        #expect(result != nil)
        #expect(result?.merchant.lowercased().contains("walmart") == true)
    }

    @Test @MainActor func extractMerchant_spanishPattern_comercio() {
        let result = ScreenshotSingleExtractor.extractMerchant(from: "comercio: STARBUCKS PERU")
        #expect(result != nil)
        #expect(result?.merchant.lowercased().contains("starbucks") == true)
    }

    @Test @MainActor func extractMerchant_spanishPattern_establecimiento() {
        let result = ScreenshotSingleExtractor.extractMerchant(from: "establecimiento: METRO SANTA ANITA")
        #expect(result != nil)
        #expect(result?.merchant.lowercased().contains("metro") == true)
    }

    @Test @MainActor func extractMerchant_spanishPattern_consumoEn() {
        let result = ScreenshotSingleExtractor.extractMerchant(from: "consumo en RAPPI PERU")
        #expect(result != nil)
        #expect(result?.merchant.lowercased().contains("rappi") == true)
    }

    // MARK: - extractMerchant — English patterns

    @Test @MainActor func extractMerchant_englishPattern_at() {
        let result = ScreenshotSingleExtractor.extractMerchant(from: "Purchase at Amazon Store for $25")
        #expect(result != nil)
        #expect(result?.merchant.lowercased().contains("amazon") == true)
    }

    @Test @MainActor func extractMerchant_englishPattern_merchant() {
        let result = ScreenshotSingleExtractor.extractMerchant(from: "merchant: Target Supercenter")
        #expect(result != nil)
        #expect(result?.merchant.lowercased().contains("target") == true)
    }

    @Test @MainActor func extractMerchant_englishPattern_transactionAt() {
        let result = ScreenshotSingleExtractor.extractMerchant(from: "transaction at Whole Foods Market")
        #expect(result != nil)
        #expect(result?.merchant.lowercased().contains("whole") == true)
    }

    // MARK: - extractMerchant — Confidence

    @Test @MainActor func extractMerchant_confidence_isReasonable() {
        let result = ScreenshotSingleExtractor.extractMerchant(from: "comercio: STARBUCKS PERU")
        #expect(result != nil)
        #expect(result!.confidence >= 0.7)
        #expect(result!.confidence <= 1.0)
    }

    // MARK: - extractMerchant — No match

    @Test @MainActor func extractMerchant_noPattern_returnsNil() {
        let result = ScreenshotSingleExtractor.extractMerchant(from: "Random text without merchant info")
        #expect(result == nil)
    }

    @Test @MainActor func extractMerchant_emptyText_returnsNil() {
        let result = ScreenshotSingleExtractor.extractMerchant(from: "")
        #expect(result == nil)
    }

    @Test @MainActor func extractMerchant_tooShortName_returnsNil() {
        // Merchant name must be at least 3 chars
        let result = ScreenshotSingleExtractor.extractMerchant(from: "en AB")
        #expect(result == nil)
    }

    // MARK: - extractMerchant — Formatting

    @Test @MainActor func extractMerchant_result_isCapitalized() {
        let result = ScreenshotSingleExtractor.extractMerchant(from: "comercio: WALMART PERU")
        #expect(result != nil)
        // .capitalized: first letter of each word uppercase
        if let merchant = result?.merchant {
            #expect(merchant == merchant.capitalized)
        }
    }

    @Test @MainActor func extractMerchant_result_isTrimmed() {
        let result = ScreenshotSingleExtractor.extractMerchant(from: "comercio: WALMART  ")
        if let merchant = result?.merchant {
            #expect(merchant == merchant.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
}
