//
//  GroupSplitPlaceholderLogic.swift
//  Yala
//
//  Pure-logic placeholder calculator for the per-member input fields in
//  GroupSplitSelectorView. When the user fills some members partially,
//  the next empty member shows the "remaining" as a suggested placeholder.
//
//  Rules per split type:
//  - .equal → "" (no input field; ignored).
//  - .exact → first empty member shows `total - filledSum`, others "0".
//  - .percentage → first empty member shows `100 - filledSum`, others "0".
//  - .shares → always "1" (no natural "total expected", shares are free).
//
//  Overflow clamp: `max(0, remaining)` avoids showing negatives.
//

import Foundation

enum GroupSplitPlaceholderLogic {

    /// Returns the placeholder text to display for `forMemberID` when its input is empty.
    ///
    /// - Parameters:
    ///   - forMemberID: target member with empty input
    ///   - orderedMemberIDs: all selected member IDs in display order (used to detect "first empty")
    ///   - currentInputs: map [memberID: stringValue] of current form state
    ///   - splitType: active split type
    ///   - total: expense total (relevant for .exact)
    static func placeholder(
        forMemberID: String,
        orderedMemberIDs: [String],
        currentInputs: [String: String],
        splitType: SplitType,
        total: Double
    ) -> String {
        switch splitType {
        case .equal:
            return ""

        case .shares:
            // No dynamic computation — shares are free proportions.
            return "1"

        case .exact:
            return placeholderForExact(
                forMemberID: forMemberID,
                orderedMemberIDs: orderedMemberIDs,
                currentInputs: currentInputs,
                total: total
            )

        case .percentage:
            return placeholderForPercentage(
                forMemberID: forMemberID,
                orderedMemberIDs: orderedMemberIDs,
                currentInputs: currentInputs
            )
        }
    }

    // MARK: - Per-type implementations

    private static func placeholderForExact(
        forMemberID: String,
        orderedMemberIDs: [String],
        currentInputs: [String: String],
        total: Double
    ) -> String {
        let filledSum = sumFilled(orderedMemberIDs: orderedMemberIDs, currentInputs: currentInputs)
        let remaining = max(0, total - filledSum)

        guard isFirstEmpty(forMemberID, orderedMemberIDs: orderedMemberIDs, currentInputs: currentInputs),
              filledSum > 0,
              remaining > 0 else {
            return "0"
        }
        return String(format: "%.2f", remaining)
    }

    private static func placeholderForPercentage(
        forMemberID: String,
        orderedMemberIDs: [String],
        currentInputs: [String: String]
    ) -> String {
        let filledSum = sumFilled(orderedMemberIDs: orderedMemberIDs, currentInputs: currentInputs)
        let remaining = max(0, 100 - filledSum)

        guard isFirstEmpty(forMemberID, orderedMemberIDs: orderedMemberIDs, currentInputs: currentInputs),
              filledSum > 0,
              remaining > 0 else {
            return "0"
        }
        return formatPercent(remaining)
    }

    // MARK: - Helpers

    /// True if `memberID` is the first member in `orderedMemberIDs` whose input is empty.
    private static func isFirstEmpty(
        _ memberID: String,
        orderedMemberIDs: [String],
        currentInputs: [String: String]
    ) -> Bool {
        let firstEmpty = orderedMemberIDs.first(where: { (currentInputs[$0] ?? "").isEmpty })
        return firstEmpty == memberID
    }

    /// Sum of all numeric values from `currentInputs` for members in `orderedMemberIDs`.
    /// Empty / unparseable values count as 0.
    private static func sumFilled(
        orderedMemberIDs: [String],
        currentInputs: [String: String]
    ) -> Double {
        orderedMemberIDs.reduce(0.0) { acc, id in
            let raw = currentInputs[id] ?? ""
            return acc + parseLenient(raw)
        }
    }

    /// Tolerant parser: accepts "30", "30.5", "30,5", or "" (→ 0). Locale-agnostic
    /// for tests; treats both "." and "," as decimal separators.
    private static func parseLenient(_ text: String) -> Double {
        guard !text.isEmpty else { return 0 }
        // Strip thousand separators (commas before decimal) — heuristic: if text contains
        // both "," and ".", treat "," as grouping; else either could be decimal.
        let normalized: String
        if text.contains(",") && text.contains(".") {
            normalized = text.replacingOccurrences(of: ",", with: "")
        } else {
            normalized = text.replacingOccurrences(of: ",", with: ".")
        }
        return Double(normalized) ?? 0
    }

    /// Format percentage: trims trailing zeros (50.0 → "50", 33.3 → "33.3").
    private static func formatPercent(_ value: Double) -> String {
        if value == value.rounded() {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }
}
