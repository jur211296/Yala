//
//  AmountParser.swift
//  Yala
//
//  Parser for extracting monetary amounts from text
//

import Foundation

/// Parses monetary amounts from text in various formats
struct AmountParser {

    /// Parse an amount from text
    /// - Parameter text: Text containing an amount
    /// - Returns: Tuple with parsed amount and confidence (0.0-1.0), or nil if no amount found
    static func parse(_ text: String) -> (amount: Decimal, confidence: Double)? {
        // Patterns to detect amounts:
        // 1. With currency symbol: $1,234.56 | €100 | £50.00
        // 2. With sign: -$50.00 | +100
        // 3. In parentheses (negative): ($100.00)
        // 4. Plain numbers: 1,234.56 | 1.234,56

        let patterns: [(pattern: String, isNegative: Bool)] = [
            // Parentheses = negative
            (#"\([\$€£]?\s*([\d.,]+)\)"#, true),
            // Explicit negative sign
            (#"-\s*[\$€£]?\s*([\d.,]+)"#, true),
            // Currency symbol with amount
            (#"[\$€£]\s*([\d.,]+)"#, false),
            // Plain number with separators
            (#"\b([\d]{1,3}[.,][\d]{3}[.,]?[\d]*)\b"#, false),
            // Simple decimal
            (#"\b([\d]+[.,][\d]{2})\b"#, false),
            // Whole number
            (#"\b([\d]{2,})\b"#, false)
        ]

        for (pattern, isNegativePattern) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
                continue
            }

            if let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)) {
                // Extract amount string
                var amountString = ""
                let matchRange: NSRange
                if match.numberOfRanges > 1 {
                    matchRange = match.range(at: 1)
                } else {
                    matchRange = match.range
                }

                if let range = Range(matchRange, in: text) {
                    amountString = String(text[range])
                } else {
                    continue
                }

                // Clean and parse
                let cleanedAmount = cleanAmount(amountString)
                guard let value = Decimal(string: cleanedAmount) else { continue }

                // Apply sign
                let finalValue = isNegativePattern ? -value : value

                // Calculate confidence based on pattern type
                let confidence = calculateConfidence(for: pattern, text: text)

                return (finalValue, confidence)
            }
        }

        return nil
    }

    /// Clean amount string for decimal parsing
    /// - Parameter amount: Raw amount string
    /// - Returns: Cleaned amount string
    private static func cleanAmount(_ amount: String) -> String {
        var cleaned = amount

        // Detect format: European (1.234,56) vs American (1,234.56)
        let hasCommaAsDecimal = cleaned.contains(",") &&
                               (cleaned.lastIndex(of: ",")! > cleaned.lastIndex(of: ".") ?? cleaned.startIndex)

        if hasCommaAsDecimal {
            // European format: 1.234,56 -> remove dots, replace comma with dot
            cleaned = cleaned.replacingOccurrences(of: ".", with: "")
            cleaned = cleaned.replacingOccurrences(of: ",", with: ".")
        } else {
            // American format: 1,234.56 -> remove commas
            cleaned = cleaned.replacingOccurrences(of: ",", with: "")
        }

        return cleaned
    }

    /// Calculate confidence score based on pattern and context
    /// - Parameters:
    ///   - pattern: Regex pattern that matched
    ///   - text: Full text context
    /// - Returns: Confidence score (0.0-1.0)
    private static func calculateConfidence(for pattern: String, text: String) -> Double {
        // Parentheses or explicit negative sign = high confidence
        if pattern.contains("\\(") || pattern.contains("-") {
            return 0.95
        }

        // Currency symbol present = high confidence
        if pattern.contains("$") || pattern.contains("€") || pattern.contains("£") {
            return 0.90
        }

        // Number with decimal separator = medium-high confidence
        if pattern.contains("[.,]") {
            return 0.85
        }

        // Plain number = lower confidence
        return 0.75
    }
}
