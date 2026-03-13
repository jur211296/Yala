// Tests generated for: ImageClassifier
// Cobertura estimada: 85%

import Foundation
import Testing
import Vision

@testable import Yala

struct ImageClassifierTests {

    private let sut = ImageClassifier()

    // MARK: - Helper

    /// Creates an OCRResult with the given fullText and no observations.
    /// Since textBlocks is computed from observations (which are empty),
    /// only fullText-based classification paths can be tested.
    private func makeOCRResult(fullText: String) -> OCRResult {
        OCRResult(fullText: fullText, observations: [])
    }

    // MARK: - Screenshot Single (bank keywords + amount)

    @Test func classify_withBankKeywordAndAmount_returnsScreenshotSingle() {
        let result = sut.classify(ocrResult: makeOCRResult(
            fullText: "Compra aprobada por $50.00 en STARBUCKS con tarjeta *1234"
        ))
        #expect(result == .screenshotSingle)
    }

    @Test func classify_withEnglishBankKeywordAndAmount_returnsScreenshotSingle() {
        let result = sut.classify(ocrResult: makeOCRResult(
            fullText: "Purchase transaction approved $120.00 card ending 5678"
        ))
        #expect(result == .screenshotSingle)
    }

    @Test func classify_withConsumoKeyword_returnsScreenshotSingle() {
        let result = sut.classify(ocrResult: makeOCRResult(
            fullText: "Consumo por S/ 45.50 en comercio WONG"
        ))
        #expect(result == .screenshotSingle)
    }

    @Test func classify_withCargoKeyword_returnsScreenshotSingle() {
        let result = sut.classify(ocrResult: makeOCRResult(
            fullText: "Cargo en cuenta $300.00 banco nacional"
        ))
        #expect(result == .screenshotSingle)
    }

    @Test func classify_withDebitKeyword_returnsScreenshotSingle() {
        let result = sut.classify(ocrResult: makeOCRResult(
            fullText: "Débito automático $99.99"
        ))
        #expect(result == .screenshotSingle)
    }

    // MARK: - Receipt Photo (receipt keywords + amount)

    @Test func classify_withTotalKeyword_returnsReceiptPhoto() {
        let result = sut.classify(ocrResult: makeOCRResult(
            fullText: "Supermercado XYZ\nManzanas 3.50\nLeche 2.00\nTotal $5.50"
        ))
        #expect(result == .receiptPhoto)
    }

    @Test func classify_withSubtotalKeyword_returnsReceiptPhoto() {
        let result = sut.classify(ocrResult: makeOCRResult(
            fullText: "Subtotal: 100.00\nIVA: 16.00\nTotal: 116.00"
        ))
        #expect(result == .receiptPhoto)
    }

    @Test func classify_withTicketKeyword_returnsReceiptPhoto() {
        let result = sut.classify(ocrResult: makeOCRResult(
            fullText: "Ticket #12345\nImporte: $25.00"
        ))
        #expect(result == .receiptPhoto)
    }

    @Test func classify_withInvoiceKeyword_returnsReceiptPhoto() {
        let result = sut.classify(ocrResult: makeOCRResult(
            fullText: "Invoice #987\nAmount Due: $250.00"
        ))
        #expect(result == .receiptPhoto)
    }

    // MARK: - Unknown

    @Test func classify_withNoKeywordsAndNoAmounts_returnsUnknown() {
        let result = sut.classify(ocrResult: makeOCRResult(
            fullText: "Hello world this is some random text without numbers"
        ))
        #expect(result == .unknown)
    }

    @Test func classify_withBankKeywordButNoAmount_returnsUnknown() {
        let result = sut.classify(ocrResult: makeOCRResult(
            fullText: "Bienvenido a tu banco digital"
        ))
        #expect(result == .unknown)
    }

    @Test func classify_withEmptyText_returnsUnknown() {
        let result = sut.classify(ocrResult: makeOCRResult(fullText: ""))
        #expect(result == .unknown)
    }

    // MARK: - Priority: bank keywords take precedence over receipt keywords

    @Test func classify_withBothBankAndReceiptKeywords_returnsScreenshotSingle() {
        // Bank keywords are checked before receipt keywords
        let result = sut.classify(ocrResult: makeOCRResult(
            fullText: "Compra aprobada por $50.00 Total factura"
        ))
        #expect(result == .screenshotSingle)
    }

    // MARK: - Case insensitivity

    @Test func classify_withUppercaseBankKeyword_returnsScreenshotSingle() {
        let result = sut.classify(ocrResult: makeOCRResult(
            fullText: "TARJETA DE CREDITO - CARGO POR $150.00"
        ))
        // fullText.lowercased() contains "tarjeta" and "cargo"
        #expect(result == .screenshotSingle)
    }
}

/*
Tests generated:
1. classify_withBankKeywordAndAmount_returnsScreenshotSingle - Spanish bank alert detection
2. classify_withEnglishBankKeywordAndAmount_returnsScreenshotSingle - English bank alert
3. classify_withConsumoKeyword_returnsScreenshotSingle - "consumo" keyword detection
4. classify_withCargoKeyword_returnsScreenshotSingle - "cargo" keyword
5. classify_withDebitKeyword_returnsScreenshotSingle - "debito" keyword
6. classify_withTotalKeyword_returnsReceiptPhoto - Receipt with "total"
7. classify_withSubtotalKeyword_returnsReceiptPhoto - Receipt with "subtotal"
8. classify_withTicketKeyword_returnsReceiptPhoto - Receipt with "ticket"
9. classify_withInvoiceKeyword_returnsReceiptPhoto - Receipt with "invoice"
10. classify_withNoKeywordsAndNoAmounts_returnsUnknown - Random text returns unknown
11. classify_withBankKeywordButNoAmount_returnsUnknown - Keyword without amount
12. classify_withEmptyText_returnsUnknown - Empty text returns unknown
13. classify_withBothBankAndReceiptKeywords_returnsScreenshotSingle - Priority ordering
14. classify_withUppercaseBankKeyword_returnsScreenshotSingle - Case insensitivity

Cases NOT covered (require VNRecognizedTextObservation):
- screenshotList detection (requires textBlocks from real Vision observations)
- Fallback to screenshotList when linesWithAmount >= 2 (same reason)
- hasAmountPattern is private, tested indirectly through classify
*/
