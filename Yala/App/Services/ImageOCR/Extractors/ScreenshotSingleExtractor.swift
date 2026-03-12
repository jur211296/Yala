//
//  ScreenshotSingleExtractor.swift
//  Yala
//
//  Extractor for single transaction screenshots (bank alerts, notifications)
//

import Foundation
import SwiftData

/// Extracts transaction data from single-transaction screenshots (bank alerts)
@MainActor
struct ScreenshotSingleExtractor {

    /// Extract a draft from a single-transaction screenshot
    /// - Parameters:
    ///   - ocrResult: OCR result containing extracted text
    ///   - context: SwiftData context for inserting draft
    /// - Returns: Created InboxDraft or nil if extraction failed
    func extract(from ocrResult: OCRResult, context: ModelContext) -> InboxDraft? {
        let text = ocrResult.fullText

        // 1. Extract amount
        guard let (amount, amountConfidence) = AmountParser.parse(text) else {
            return nil // No amount = not a valid transaction
        }

        // 2. Extract date (optional, uses createdAt as fallback)
        let dateResult = DateParser.parse(text)

        // 3. Extract merchant name
        let merchantResult = Self.extractMerchant(from: text)
        let merchant = merchantResult?.merchant
        let merchantConfidence = merchantResult?.confidence

        // 4. Create note: use merchant or truncated text
        let note: String
        if let merchant = merchant {
            note = merchant
        } else {
            // Fallback: use first 50 chars of text
            note = String(text.prefix(50))
        }

        // 5. Create evidence: first line or first 100 chars
        let evidence = text.components(separatedBy: "\n").first ?? String(text.prefix(100))

        // 6. Create and insert draft
        let draft = InboxDraft(
            note: note,
            amount: Double(truncating: amount as NSNumber),
            date: dateResult?.date,
            sourceType: .screenshotSingle,
            rawText: text,
            evidence: evidence,
            confidenceAmount: amountConfidence,
            confidenceDate: dateResult?.confidence,
            confidenceMerchant: merchantConfidence,
            needsUserInput: ["account", "subcategory"],
            status: .pending
        )

        context.insert(draft)

        return draft
    }

    /// Extract merchant name from text using common patterns
    /// - Parameter text: Text to search for merchant name
    /// - Returns: Tuple with merchant name and confidence, or nil if not found
    static func extractMerchant(from text: String) -> (merchant: String, confidence: Double)? {
        // Patterns to detect merchant names in Spanish and English
        let patterns: [(pattern: String, confidence: Double)] = [
            // Spanish patterns
            (#"(?:en|comercio:|establecimiento:|tienda:)\s+([A-ZÀ-ÿ][A-ZÀ-ÿ\s&.,'-]{2,30})"#, 0.85),
            (#"(?:compra en|consumo en)\s+([A-ZÀ-ÿ][A-ZÀ-ÿ\s&.,'-]{2,30})"#, 0.80),
            // English patterns
            (#"(?:at|merchant:|store:)\s+([A-Z][A-Za-z\s&.,'-]{2,30})"#, 0.85),
            (#"(?:purchase at|transaction at)\s+([A-Z][A-Za-z\s&.,'-]{2,30})"#, 0.80)
        ]

        for (patternString, baseConfidence) in patterns {
            guard let regex = try? NSRegularExpression(pattern: patternString, options: []) else {
                continue
            }

            if let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
               match.numberOfRanges > 1 {
                let merchantRange = match.range(at: 1)
                if let range = Range(merchantRange, in: text) {
                    let merchant = String(text[range])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .capitalized

                    // Filter out too short or invalid names
                    guard merchant.count >= 3 else { continue }

                    return (merchant, baseConfidence)
                }
            }
        }

        return nil
    }
}
