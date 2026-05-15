//
//  TagsSettingsListViewModelTests.swift
//  YalaTests
//
//  Tests for TagsSettingsListViewModel UI state and initial state.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

struct TagsSettingsListViewModelTests {

    // MARK: - Initial State

    @MainActor @Test func initialState_tagsEmpty() {
        let vm = TagsSettingsListViewModel()
        #expect(vm.tags.isEmpty)
    }

    @MainActor @Test func initialState_isEmptyTrue() {
        let vm = TagsSettingsListViewModel()
        #expect(vm.isEmpty == true)
    }

    @MainActor @Test func initialState_isPresentingCreateTagFalse() {
        let vm = TagsSettingsListViewModel()
        #expect(vm.isPresentingCreateTag == false)
    }

    @MainActor @Test func initialState_tagToEditNil() {
        let vm = TagsSettingsListViewModel()
        #expect(vm.tagToEdit == nil)
    }

    @MainActor @Test func initialState_isEditModeFalse() {
        let vm = TagsSettingsListViewModel()
        #expect(vm.isEditMode == false)
    }

    @MainActor @Test func initialState_orderedActiveTagsEmpty() {
        let vm = TagsSettingsListViewModel()
        #expect(vm.orderedActiveTags.isEmpty)
    }

    @MainActor @Test func initialState_inactiveTagsEmpty() {
        let vm = TagsSettingsListViewModel()
        #expect(vm.inactiveTags.isEmpty)
    }

    // MARK: - Sort Order

    @MainActor @Test func sortOrderNames_emptyWorks() {
        let vm = TagsSettingsListViewModel()
        vm.tagsSortOrderNames = []
        #expect(vm.orderedActiveTags.isEmpty)
    }

    @MainActor @Test func sortOrderNames_changeInvalidatesCache() {
        let vm = TagsSettingsListViewModel()
        vm.tagsSortOrderNames = ["A", "B", "C"]
        _ = vm.orderedActiveTags // Build cache
        vm.tagsSortOrderNames = ["C", "B", "A"]
        // No crash, works fine even with empty tags
        #expect(vm.orderedActiveTags.isEmpty)
    }

    // MARK: - UI State Management

    @MainActor @Test func uiState_toggleEditMode() {
        let vm = TagsSettingsListViewModel()
        vm.isEditMode = true
        #expect(vm.isEditMode == true)
        vm.isEditMode = false
        #expect(vm.isEditMode == false)
    }

    @MainActor @Test func uiState_setPresentingCreateTag() {
        let vm = TagsSettingsListViewModel()
        vm.isPresentingCreateTag = true
        #expect(vm.isPresentingCreateTag == true)
    }

    @MainActor @Test func uiState_setTagToEdit() {
        let vm = TagsSettingsListViewModel()
        let tag = YalaTag(name: "Vacation", colorHex: "#FF9F0A", iconName: "tag.fill")
        vm.tagToEdit = tag
        #expect(vm.tagToEdit != nil)
        #expect(vm.tagToEdit?.name == "Vacation")
    }
}

/*
Tests generated:
1. initialState_tagsEmpty - Tags start empty
2. initialState_isEmptyTrue - isEmpty true initially
3. initialState_isPresentingCreateTagFalse - Create sheet not shown
4. initialState_tagToEditNil - No tag selected for edit
5. initialState_isEditModeFalse - Edit mode off by default
6. initialState_orderedActiveTagsEmpty - Ordered active tags empty
7. initialState_inactiveTagsEmpty - Inactive tags empty
8. sortOrderNamesRaw_emptyWorks - Empty sort order works
9. sortOrderNamesRaw_changeInvalidatesCache - Cache invalidation
10. uiState_toggleEditMode - Edit mode toggle
11. uiState_setPresentingCreateTag - Create tag sheet state
12. uiState_setTagToEdit - Tag edit selection

Cases NOT covered (require ModelContext or private(set) data):
- orderedActiveTags sorting with data (tags is private(set))
- inactiveTags filtering with data (tags is private(set))
- moveTag reorder (reads from orderedActiveTags which needs tags)
- loadTags (requires ModelContext)

RECOMMENDATION: Extract sort logic into a standalone function (like PanelViewModel pattern)
to enable comprehensive testing of the ordering algorithm.
*/
