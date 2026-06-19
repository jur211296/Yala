//
//  FilterCriteriaPopulateTagUUIDsTests.swift
//  YalaTests
//
//  Pure-logic tests for `FilterCriteria.populateTagUUIDs(from:)`. Verifies
//  the contract that maps `[Tag]` → `Set<UUID>` (Tag.id) for CSV-first
//  matching without depending on SwiftData context.
//

import Foundation
import Testing

@testable import Yala

@Suite("FilterCriteria populateTagUUIDs")
struct FilterCriteriaPopulateTagUUIDsTests {

    @Test func populateFromEmptyTags_clearsUUIDs() {
        var criteria = FilterCriteria()
        criteria.selectedTagUUIDs = [UUID(), UUID()]  // Stale
        criteria.populateTagUUIDs(from: [])
        #expect(criteria.selectedTagUUIDs.isEmpty)
    }

    @Test func populateFromSingleTag_setsOneUUID() {
        let tag = Tag(name: "a")
        var criteria = FilterCriteria()
        criteria.populateTagUUIDs(from: [tag])
        #expect(criteria.selectedTagUUIDs == [tag.id])
    }

    @Test func populateFromMultipleTags_setsAllUUIDs() {
        let t1 = Tag(name: "a")
        let t2 = Tag(name: "b")
        let t3 = Tag(name: "c")
        var criteria = FilterCriteria()
        criteria.populateTagUUIDs(from: [t1, t2, t3])
        #expect(criteria.selectedTagUUIDs == Set([t1.id, t2.id, t3.id]))
    }

    @Test func populateOverwritesPreviousState() {
        let oldTag = Tag(name: "old")
        var criteria = FilterCriteria()
        criteria.populateTagUUIDs(from: [oldTag])

        let newTag = Tag(name: "new")
        criteria.populateTagUUIDs(from: [newTag])
        #expect(criteria.selectedTagUUIDs == [newTag.id])
        #expect(!criteria.selectedTagUUIDs.contains(oldTag.id))
    }

    @Test func clearAllResetsTagUUIDs() {
        var criteria = FilterCriteria()
        criteria.populateTagUUIDs(from: [Tag(name: "a"), Tag(name: "b")])
        criteria.clearAll()
        #expect(criteria.selectedTagUUIDs.isEmpty)
    }
}
