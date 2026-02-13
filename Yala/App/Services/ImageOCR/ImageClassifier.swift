//
//  ImageClassifier.swift
//  Yala
//
//  Heuristic classifier for identifying image types from OCR results
//

import Foundation

/// Classifies images based on OCR text content using heuristics
struct ImageClassifier {

    /// Types of images that can be classified
    enum ImageType {
        case screenshotList      // List of transactions (multiple rows with amounts)
        case screenshotSingle    // Single transaction alert (bank notification)
        case receiptPhoto        // Physical receipt photo
        case unknown             // Unrecognized type
    }

    /// Classify an image based on its OCR result
    /// - Parameter ocrResult: The OCR result containing extracted text
    /// - Returns: The classified image type
    func classify(ocrResult: OCRResult) -> ImageType {
        let text = ocrResult.fullText.lowercased()
        let textBlocks = ocrResult.textBlocks

        // 1. Detect screenshotList: multiple lines with amounts
        let linesWithAmount = textBlocks.filter { hasAmountPattern($0.text) }
        if linesWithAmount.count >= 3 {
            return .screenshotList
        }

        // 2. Detect screenshotSingle/emailAlert: bank keywords + amount
        let bankKeywords = ["consumo", "compra", "cargo", "aprobad", "tarjeta", "banco",
                           "purchase", "transaction", "approved", "card", "bank",
                           "débito", "crédito", "debit", "credit"]
        let hasBankKeyword = bankKeywords.contains { text.contains($0) }
        if hasBankKeyword && hasAmountPattern(text) {
            return .screenshotSingle
        }

        // 3. Detect receiptPhoto: receipt keywords + amount
        let receiptKeywords = ["total", "subtotal", "iva", "ticket", "recibo", "factura",
                              "receipt", "invoice", "tax", "vat"]
        let hasReceiptKeyword = receiptKeywords.contains { text.contains($0) }
        if hasReceiptKeyword && hasAmountPattern(text) {
            return .receiptPhoto
        }

        // 4. If has multiple amounts but no other indicators, assume list
        if linesWithAmount.count >= 2 {
            return .screenshotList
        }

        // 5. Unknown type
        return .unknown
    }

    /// Check if text contains an amount pattern
    /// - Parameter text: Text to check
    /// - Returns: True if text contains amount-like pattern
    private func hasAmountPattern(_ text: String) -> Bool {
        // Regex for amount detection: currency symbols + numbers with separators
        // Matches: $1,234.56 | €100 | 1.234,56 | -$50 | ($100)
        let pattern = #"[\$€£]?\s*\d{1,3}([.,]\d{3})*([.,]\d{2})?"#
        return text.range(of: pattern, options: .regularExpression) != nil
    }
}
