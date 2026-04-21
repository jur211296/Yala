//
//  AmountInputHelper.swift
//  Yala
//
//  Shared amount input filtering logic.
//

import Foundation

enum AmountInputHelper {

    /// Filters amount input: digits + one decimal (max 2 places) + thousand grouping separators.
    /// Formats the integer part with locale grouping separators in real time (e.g. "12345" → "12,345").
    static func filterAmountInput(_ input: String) -> String {
        let decimalSeparator = Locale.current.decimalSeparator ?? "."
        let groupingSeparator = Locale.current.groupingSeparator ?? ","

        // Step 1: Extract only digits and one decimal separator
        var digits = ""
        var hasDecimal = false
        var decimalCount = 0

        for char in input {
            if char.isNumber {
                if hasDecimal {
                    if decimalCount < 2 {
                        digits.append(char)
                        decimalCount += 1
                    }
                } else {
                    digits.append(char)
                }
            } else if String(char) == groupingSeparator && !hasDecimal {
                continue // Strip existing grouping separators
            } else if String(char) == decimalSeparator || char == "." || char == "," {
                if !hasDecimal {
                    digits.append(decimalSeparator.first ?? ".")
                    hasDecimal = true
                }
            }
        }

        // Step 2: Remove leading zeros except "0.x" pattern
        while digits.hasPrefix("0") && digits.count > 1 {
            let secondChar = digits[digits.index(after: digits.startIndex)]
            if String(secondChar) == decimalSeparator { break }
            digits = String(digits.dropFirst())
        }

        // Step 3: Add grouping separators to integer part
        guard !digits.isEmpty else { return "" }

        let parts = digits.split(separator: Character(decimalSeparator), maxSplits: 1, omittingEmptySubsequences: false)
        let integerPart = String(parts[0])
        let decimalPart = parts.count > 1 ? String(parts[1]) : nil

        // Insert grouping separators every 3 digits from the right
        var grouped = ""
        for (index, char) in integerPart.reversed().enumerated() {
            if index > 0 && index % 3 == 0 {
                grouped.append(groupingSeparator.first ?? ",")
            }
            grouped.append(char)
        }
        grouped = String(grouped.reversed())

        if let dec = decimalPart {
            return grouped + decimalSeparator + dec
        } else if hasDecimal {
            return grouped + decimalSeparator
        }
        return grouped
    }

    /// Parses a text field value to Double, handling locale grouping and decimal separators.
    static func parseDecimal(_ text: String) -> Double {
        let grouping = Locale.current.groupingSeparator ?? ","
        let decimal = Locale.current.decimalSeparator ?? "."
        let cleaned = text.replacing(grouping, with: "").replacing(decimal, with: ".")
        return Double(cleaned) ?? 0
    }

    /// Formats a Double with thousand grouping separators and 2 decimal places, respecting locale.
    static func formatWithGrouping(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    /// Filters input to only allow whole numbers (no decimal).
    /// Used for fields like "people count" or "shares".
    static func filterIntegerInput(_ input: String) -> String {
        var result = ""
        for char in input {
            if char.isNumber {
                result.append(char)
            }
        }

        // Remove leading zeros
        while result.hasPrefix("0") && result.count > 1 {
            result = String(result.dropFirst())
        }

        return result
    }
}
