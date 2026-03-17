//
//  AmountInputHelper.swift
//  Yala
//
//  Shared amount input filtering logic.
//

import Foundation

enum AmountInputHelper {

    /// Filters amount input to only allow numbers and one decimal with max 2 decimal places
    static func filterAmountInput(_ input: String) -> String {
        let decimalSeparator = Locale.current.decimalSeparator ?? "."
        var result = ""
        var hasDecimal = false
        var decimalCount = 0

        for char in input {
            if char.isNumber {
                if hasDecimal {
                    if decimalCount < 2 {
                        result.append(char)
                        decimalCount += 1
                    }
                } else {
                    result.append(char)
                }
            } else if String(char) == decimalSeparator || char == "." || char == "," {
                if !hasDecimal {
                    result.append(decimalSeparator.first ?? ".")
                    hasDecimal = true
                }
            }
        }

        // Remove ALL leading zeros except for "0.x" pattern
        while result.hasPrefix("0") && result.count > 1 {
            let secondChar = result[result.index(after: result.startIndex)]
            // Keep if it's "0." pattern
            if String(secondChar) == decimalSeparator {
                break
            }
            result = String(result.dropFirst())
        }

        // Allow empty string (will be restored to "0" when field loses focus)
        return result
    }

    /// Parses a text field value to Double, normalizing comma to dot.
    static func parseDecimal(_ text: String) -> Double {
        Double(text.replacing(",", with: ".")) ?? 0
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
