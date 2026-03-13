//
//  ScreenshotListExtractor.swift
//  Yala
//
//  Extractor for transaction list screenshots (multiple rows)
//

import Foundation
import SwiftData

/// Extracts multiple transactions from screenshot lists (bank app transaction history)
@MainActor
struct ScreenshotListExtractor {

    private let rowClusterer = RowClusterer()

    /// Extract drafts from a transaction list screenshot
    /// - Parameters:
    ///   - ocrResult: OCR result containing extracted text
    ///   - context: SwiftData context for inserting drafts
    /// - Returns: Array of created InboxDrafts
    func extract(from ocrResult: OCRResult, context: ModelContext) -> [InboxDraft] {
        // 1. Cluster text blocks into rows
        let rows = rowClusterer.clusterIntoRows(ocrResult.textBlocks)

        guard !rows.isEmpty else { return [] }

        // 2. Process each row and extract transaction data
        var drafts: [InboxDraft] = []

        for row in rows {
            let rowText = row.combinedText

            // Skip rows that are too short (likely headers or UI elements)
            guard rowText.count >= 5 else { continue }

            // 3. Try to extract amount (required)
            guard let (amount, amountConfidence) = AmountParser.parse(rowText) else {
                continue // Skip rows without amount
            }

            // 4. Try to extract date (optional)
            let dateResult = DateParser.parse(rowText)

            // 5. Extract description: remove amount and date patterns, use what's left
            let description = Self.extractDescription(from: rowText, amount: amount, date: dateResult?.date)

            // 6. Create evidence: first 100 chars of row
            let evidence = String(rowText.prefix(100))

            // 7. Create and insert draft
            let draft = InboxDraft(
                note: description,
                amount: Double(truncating: amount as NSNumber),
                date: dateResult?.date,
                sourceType: .screenshotList,
                rawText: rowText,
                evidence: evidence,
                confidenceAmount: amountConfidence,
                confidenceDate: dateResult?.confidence,
                confidenceMerchant: nil, // Lists don't usually have merchant names
                needsUserInput: ["account", "subcategory"],
                status: .pending
            )

            context.insert(draft)
            drafts.append(draft)
        }

        return drafts
    }

    /// Extract description from row text by removing amount and date patterns
    /// - Parameters:
    ///   - text: Row text
    ///   - amount: Parsed amount
    ///   - date: Parsed date (optional)
    /// - Returns: Cleaned description text
    static func extractDescription(from text: String, amount: Decimal, date: Date?) -> String {
        var cleaned = text

        // Remove currency symbols and amount
        let amountString = String(describing: amount)
        cleaned = cleaned.replacingOccurrences(of: amountString, with: "")
        cleaned = cleaned.replacingOccurrences(of: "\\$|€|£|S/", with: "", options: .regularExpression)

        // Remove common date patterns
        if date != nil {
            // Remove dd/MM, dd-MM patterns
            cleaned = cleaned.replacingOccurrences(of: "\\d{1,2}[/-]\\d{1,2}([/-]\\d{2,4})?", with: "", options: .regularExpression)
            // Remove relative dates
            cleaned = cleaned.replacingOccurrences(of: "\\b(hoy|ayer|today|yesterday)\\b", with: "", options: [.regularExpression, .caseInsensitive])
        }

        // Remove extra whitespace and trim
        cleaned = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        // If result is too short, use original text truncated
        if cleaned.count < 3 {
            return String(text.prefix(50))
        }

        return cleaned
    }
}
