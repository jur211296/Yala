//
//  SaveAsFavoriteViewModelTests.swift
//  YalaTests
//
//  Tests for SaveAsFavoriteViewModel - tag filtering and selection logic.
//  Data loading requires ModelContext, so we test computed properties
//  and selection logic with manually created Tag objects.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

struct SaveAsFavoriteViewModelTests {

    // MARK: - Initial State

    @MainActor @Test("Initial state has empty allTags")
    func initialState_allTagsEmpty() {
        let vm = SaveAsFavoriteViewModel()
        #expect(vm.allTags.isEmpty)
    }

    @MainActor @Test("Initial state has empty activeTags")
    func initialState_activeTagsEmpty() {
        let vm = SaveAsFavoriteViewModel()
        #expect(vm.activeTags.isEmpty)
    }

    // MARK: - loadTags without context

    @MainActor @Test("loadTags without context keeps empty array")
    func loadTags_withoutContext_keepsEmpty() {
        let vm = SaveAsFavoriteViewModel()
        vm.loadTags()
        #expect(vm.allTags.isEmpty)
    }

    // MARK: - activeTags filtering logic (tested via Tag model)

    @Test("Tag isActive defaults to true")
    func tag_isActive_defaultsTrue() {
        let tag = YalaTag(name: "Work", colorHex: "#FF0000", iconName: "tag")
        #expect(tag.isActive == true)
    }

    @Test("Inactive tag is excluded from active filter")
    func tag_inactiveExcludedFromFilter() {
        let active1 = YalaTag(name: "Work", colorHex: "#FF0000", iconName: "tag")
        let active2 = YalaTag(name: "Personal", colorHex: "#00FF00", iconName: "tag")
        let inactive = YalaTag(name: "Old", colorHex: "#999999", iconName: "tag")
        inactive.isActive = false

        let allTags = [active1, active2, inactive]
        let activeTags = allTags.filter { $0.isActive }

        #expect(activeTags.count == 2)
        #expect(activeTags.contains(where: { $0.name == "Work" }))
        #expect(activeTags.contains(where: { $0.name == "Personal" }))
        #expect(!activeTags.contains(where: { $0.name == "Old" }))
    }

    @Test("All tags inactive results in empty activeTags")
    func tag_allInactive_emptyActive() {
        let tag1 = YalaTag(name: "A", colorHex: "#000", iconName: "tag")
        let tag2 = YalaTag(name: "B", colorHex: "#000", iconName: "tag")
        tag1.isActive = false
        tag2.isActive = false

        let activeTags = [tag1, tag2].filter { $0.isActive }
        #expect(activeTags.isEmpty)
    }

    // MARK: - selectedTagObjects logic

    @MainActor @Test("selectedTagObjects returns empty when no IDs match")
    func selectedTagObjects_noMatch_returnsEmpty() {
        let vm = SaveAsFavoriteViewModel()
        // With empty allTags, no IDs can match
        let result = vm.selectedTagObjects(from: Set())
        #expect(result.isEmpty)
    }

    @MainActor @Test("selectedTagObjects with empty IDs set returns empty")
    func selectedTagObjects_emptyIDs_returnsEmpty() {
        let vm = SaveAsFavoriteViewModel()
        let result = vm.selectedTagObjects(from: [])
        #expect(result.isEmpty)
    }

    // MARK: - activeTags contract

    @MainActor @Test("activeTags count is always <= allTags count")
    func activeTags_alwaysSubsetOfAllTags() {
        let vm = SaveAsFavoriteViewModel()
        #expect(vm.activeTags.count <= vm.allTags.count)
    }

    // MARK: - FavoritePayment creation properties (pure logic)

    @Test("FavoritePayment currencyCode stored correctly")
    func favoritePayment_currencyCode_stored() {
        let fav = FavoritePayment(name: "Test", currencyCode: "PEN")
        #expect(fav.currencyCode == "PEN")
    }

    @Test("FavoritePayment tags default to empty array")
    func favoritePayment_tags_defaultEmpty() {
        let fav = FavoritePayment(name: "Test")
        #expect(fav.tags?.isEmpty ?? true)
    }

    @Test("FavoritePayment displayOrder set correctly")
    func favoritePayment_displayOrder_setCorrectly() {
        let fav = FavoritePayment(name: "Test", displayOrder: 5)
        #expect(fav.displayOrder == 5)
    }
}

/*
Tests generated:
1. initialState_allTagsEmpty - VM starts with no tags
2. initialState_activeTagsEmpty - Active tags also empty initially
3. loadTags_withoutContext_keepsEmpty - No crash without context
4. tag_isActive_defaultsTrue - Tag default active state
5. tag_inactiveExcludedFromFilter - Active filter excludes inactive tags
6. tag_allInactive_emptyActive - Edge case: all inactive
7. selectedTagObjects_noMatch_returnsEmpty - No matching IDs
8. selectedTagObjects_emptyIDs_returnsEmpty - Empty selection set
9. activeTags_alwaysSubsetOfAllTags - Contract verification
10. favoritePayment_currencyCode_stored - Currency code storage
11. favoritePayment_tags_defaultEmpty - Tags default
12. favoritePayment_displayOrder_setCorrectly - Display order

Cases NOT covered (require ModelContext):
- selectedTagObjects with actual PersistentIdentifier matching
  (tags loaded via fetch, IDs are context-dependent)
- saveFavorite operation (inserts into context + saves)
*/
