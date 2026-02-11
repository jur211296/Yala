//
//  DraftDeduplicationServiceTests.swift
//  YalaTests
//
//  Unit tests for DraftDeduplicationService.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

struct DraftDeduplicationServiceTests {

    // MARK: - normalizeNote (pure)

    @Test func normalizeNote_trims() {
        #expect(DraftDeduplicationService.normalizeNote("  hello  ") == "hello")
    }

    @Test func normalizeNote_lowercases() {
        #expect(DraftDeduplicationService.normalizeNote("HELLO WORLD") == "hello world")
    }

    @Test func normalizeNote_removesSpecialChars() {
        #expect(DraftDeduplicationService.normalizeNote("hello! @world#") == "hello world")
    }

    @Test func normalizeNote_collapsesSpaces() {
        #expect(DraftDeduplicationService.normalizeNote("hello   world") == "hello world")
    }

    @Test func normalizeNote_empty() {
        #expect(DraftDeduplicationService.normalizeNote("") == "")
    }

    // MARK: - notesAreSimilar (pure)

    @Test func notesAreSimilar_exactMatch() {
        #expect(DraftDeduplicationService.notesAreSimilar("Café", "café") == true)
    }

    @Test func notesAreSimilar_containment() {
        #expect(DraftDeduplicationService.notesAreSimilar("Starbucks Coffee", "Starbucks") == true)
    }

    @Test func notesAreSimilar_bothEmpty() {
        #expect(DraftDeduplicationService.notesAreSimilar("", "") == true)
    }

    @Test func notesAreSimilar_oneEmpty() {
        #expect(DraftDeduplicationService.notesAreSimilar("hello", "") == false)
    }

    @Test func notesAreSimilar_shortSimilar() {
        // "cafe" vs "cate" = distance 1, max 4, threshold 3 → similar
        #expect(DraftDeduplicationService.notesAreSimilar("cafe", "cate") == true)
    }

    @Test func notesAreSimilar_longSimilar() {
        // Very similar long strings
        #expect(DraftDeduplicationService.notesAreSimilar(
            "Starbucks Coffee Reserve",
            "Starbucks Coffe Reserve"
        ) == true)
    }

    @Test func notesAreSimilar_longDifferent() {
        #expect(DraftDeduplicationService.notesAreSimilar(
            "Starbucks Coffee Reserve",
            "McDonalds Happy Meal"
        ) == false)
    }

    // MARK: - isDuplicate + deduplicate (no ModelContext needed — pure property access)

    @Test func isDuplicate_sameAmountDateNote() {
        let now = Date()
        let a = InboxDraft(note: "Café", amount: 50.0, date: now)
        let b = InboxDraft(note: "café", amount: 50.0, date: now)
        #expect(DraftDeduplicationService.isDuplicate(a, b) == true)
    }

    @Test func isDuplicate_differentAmount() {
        let now = Date()
        let a = InboxDraft(note: "Café", amount: 50.0, date: now)
        let b = InboxDraft(note: "Café", amount: 100.0, date: now)
        #expect(DraftDeduplicationService.isDuplicate(a, b) == false)
    }

    @Test func deduplicate_filtersExistingDuplicates() {
        let now = Date()
        let existing = [InboxDraft(note: "Café", amount: 50.0, date: now)]
        let newDrafts = [
            InboxDraft(note: "café", amount: 50.0, date: now),
            InboxDraft(note: "Almuerzo", amount: 100.0, date: now),
        ]
        let result = DraftDeduplicationService.deduplicate(newDrafts: newDrafts, existingDrafts: existing)
        #expect(result.count == 1)
        #expect(result.first?.note == "Almuerzo")
    }
}
