//
//  DateParser.swift
//  Yala
//
//  Parser for extracting dates from text
//

import Foundation

/// Parses dates from text in various formats
struct DateParser {

    /// Parse a date from text
    /// - Parameter text: Text containing a date
    /// - Returns: Tuple with parsed date and confidence (0.0-1.0), or nil if no date found
    static func parse(_ text: String) -> (date: Date, confidence: Double)? {
        let lowercased = text.lowercased()

        // 1. Relative dates (highest confidence)
        if lowercased.contains("hoy") || lowercased.contains("today") {
            return (Date(), 0.99)
        }
        if lowercased.contains("ayer") || lowercased.contains("yesterday") {
            if let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) {
                return (yesterday, 0.99)
            }
        }

        // 2. Absolute dates
        let patterns: [(String, String, Double)] = [
            // dd/MM/yyyy or dd-MM-yyyy
            (#"\b(\d{1,2})[/-](\d{1,2})[/-](\d{4})\b"#, "dd/MM/yyyy", 0.90),
            // yyyy-MM-dd (ISO format)
            (#"\b(\d{4})-(\d{1,2})-(\d{1,2})\b"#, "yyyy-MM-dd", 0.95),
            // dd/MM/yy
            (#"\b(\d{1,2})[/-](\d{1,2})[/-](\d{2})\b"#, "dd/MM/yy", 0.85),
            // Month name patterns (e.g., "24 Enero" or "Jan 24")
            (#"\b(\d{1,2})\s+(enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|octubre|noviembre|diciembre|jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\b"#, "dd MMMM", 0.85)
        ]

        for (pattern, format, baseConfidence) in patterns {
            if let result = tryParseWithPattern(text, pattern: pattern, format: format) {
                return (result, baseConfidence)
            }
        }

        return nil
    }

    /// Try to parse date with a specific pattern and format
    /// - Parameters:
    ///   - text: Text to parse
    ///   - pattern: Regex pattern
    ///   - format: Date format string
    /// - Returns: Parsed date or nil
    private static func tryParseWithPattern(_ text: String, pattern: String, format: String) -> Date? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }

        if let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range, in: text) {
            let dateString = String(text[range])

            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "es_ES") // Support Spanish months

            if let date = formatter.date(from: dateString) {
                return date
            }

            // Try with English locale if Spanish fails
            formatter.locale = Locale(identifier: "en_US")
            if let date = formatter.date(from: dateString) {
                return date
            }
        }

        return nil
    }
}
