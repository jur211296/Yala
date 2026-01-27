//
//  DraftDeduplicationService.swift
//  Yala
//
//  Prevents duplicate InboxDrafts from being created when processing
//  the same image or voice input multiple times.
//

import Foundation

struct DraftDeduplicationService {

    /// Removes duplicates from newDrafts by comparing against each other and against existingDrafts.
    /// Returns only the unique drafts that should be inserted.
    static func deduplicate(newDrafts: [InboxDraft], existingDrafts: [InboxDraft]) -> [InboxDraft] {
        var unique: [InboxDraft] = []

        for draft in newDrafts {
            let isDupOfExisting = existingDrafts.contains { isDuplicate(draft, $0) }
            let isDupOfAlreadyAdded = unique.contains { isDuplicate(draft, $0) }

            if !isDupOfExisting && !isDupOfAlreadyAdded {
                unique.append(draft)
            }
        }

        return unique
    }

    /// Two drafts are considered duplicates if ALL three criteria match:
    /// 1. Amount: exact match ±0.01 (both non-nil)
    /// 2. Date: same calendar day (both non-nil)
    /// 3. Note: fuzzy text match
    static func isDuplicate(_ a: InboxDraft, _ b: InboxDraft) -> Bool {
        guard amountsMatch(a.amount, b.amount) else { return false }
        guard datesMatch(a.date, b.date) else { return false }
        guard notesAreSimilar(a.note, b.note) else { return false }
        return true
    }

    // MARK: - Amount Matching

    private static func amountsMatch(_ a: Double?, _ b: Double?) -> Bool {
        guard let a = a, let b = b else { return false }
        return abs(a - b) <= 0.01
    }

    // MARK: - Date Matching

    private static func datesMatch(_ a: Date?, _ b: Date?) -> Bool {
        guard let a = a, let b = b else { return false }
        return Calendar.current.isDate(a, inSameDayAs: b)
    }

    // MARK: - Note Matching

    static func normalizeNote(_ note: String) -> String {
        let lowered = note.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // Remove common special characters but keep letters, numbers, spaces
        let allowed = CharacterSet.alphanumerics.union(.whitespaces)
        return String(lowered.unicodeScalars.filter { allowed.contains($0) })
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    static func notesAreSimilar(_ a: String, _ b: String) -> Bool {
        let na = normalizeNote(a)
        let nb = normalizeNote(b)

        // Both empty → similar
        if na.isEmpty && nb.isEmpty { return true }
        // One empty, other not → not similar
        if na.isEmpty || nb.isEmpty { return false }

        // Exact match after normalization
        if na == nb { return true }

        // Containment: one contains the other
        if na.contains(nb) || nb.contains(na) { return true }

        // Levenshtein distance
        let distance = levenshteinDistance(na, nb)
        let maxLen = max(na.count, nb.count)

        if maxLen <= 15 {
            // Short notes: allow up to 3 characters difference
            return distance <= 3
        } else {
            // Longer notes: allow up to 20% difference
            return Double(distance) <= Double(maxLen) * 0.2
        }
    }

    // MARK: - Levenshtein Distance

    private static func levenshteinDistance(_ a: String, _ b: String) -> Int {
        let aChars = Array(a)
        let bChars = Array(b)
        let aLen = aChars.count
        let bLen = bChars.count

        if aLen == 0 { return bLen }
        if bLen == 0 { return aLen }

        // Use two rows for space efficiency
        var prevRow = Array(0...bLen)
        var currRow = Array(repeating: 0, count: bLen + 1)

        for i in 1...aLen {
            currRow[0] = i
            for j in 1...bLen {
                let cost = aChars[i - 1] == bChars[j - 1] ? 0 : 1
                currRow[j] = min(
                    prevRow[j] + 1,       // deletion
                    currRow[j - 1] + 1,   // insertion
                    prevRow[j - 1] + cost  // substitution
                )
            }
            swap(&prevRow, &currRow)
        }

        return prevRow[bLen]
    }
}
