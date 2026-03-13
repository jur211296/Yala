//
//  TagSelectorViewModelTests.swift
//  YalaTests
//
//  Tests for TagSelectorViewModel UI state management.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

struct TagSelectorViewModelTests {

    // MARK: - Initial State

    @MainActor @Test func initialState_tagsEmpty() {
        let vm = TagSelectorViewModel()
        #expect(vm.tags.isEmpty)
    }

    @MainActor @Test func initialState_activeTagsEmpty() {
        let vm = TagSelectorViewModel()
        #expect(vm.activeTags.isEmpty)
    }

    @MainActor @Test func initialState_isEmptyTrue() {
        let vm = TagSelectorViewModel()
        #expect(vm.isEmpty == true)
    }

    @MainActor @Test func initialState_showNewTagSheetFalse() {
        let vm = TagSelectorViewModel()
        #expect(vm.showNewTagSheet == false)
    }

    @MainActor @Test func initialState_tagCountBeforeSheetZero() {
        let vm = TagSelectorViewModel()
        #expect(vm.tagCountBeforeSheet == 0)
    }

    // MARK: - prepareForNewTag

    @MainActor @Test func prepareForNewTag_setsShowNewTagSheet() {
        let vm = TagSelectorViewModel()

        vm.prepareForNewTag()

        #expect(vm.showNewTagSheet == true)
    }

    @MainActor @Test func prepareForNewTag_capturesActiveTagCount() {
        let vm = TagSelectorViewModel()
        // activeTags is empty since tags is private(set) and empty
        vm.prepareForNewTag()

        #expect(vm.tagCountBeforeSheet == 0)
    }

    // MARK: - closeNewTagSheet

    @MainActor @Test func closeNewTagSheet_hidesSheet() {
        let vm = TagSelectorViewModel()
        vm.prepareForNewTag()
        #expect(vm.showNewTagSheet == true)

        vm.closeNewTagSheet()

        #expect(vm.showNewTagSheet == false)
    }

    // MARK: - Full Lifecycle

    @MainActor @Test func lifecycle_prepareAndClose() {
        let vm = TagSelectorViewModel()

        // Initial
        #expect(vm.showNewTagSheet == false)
        #expect(vm.tagCountBeforeSheet == 0)

        // Prepare
        vm.prepareForNewTag()
        #expect(vm.showNewTagSheet == true)
        #expect(vm.tagCountBeforeSheet == 0)

        // Close
        vm.closeNewTagSheet()
        #expect(vm.showNewTagSheet == false)
    }

    @MainActor @Test func prepareForNewTag_calledTwice_stillWorks() {
        let vm = TagSelectorViewModel()

        vm.prepareForNewTag()
        vm.prepareForNewTag()

        #expect(vm.showNewTagSheet == true)
        #expect(vm.tagCountBeforeSheet == 0)
    }
}

/*
Tests generated:
1. initialState_tagsEmpty - Tags start empty
2. initialState_activeTagsEmpty - Active tags start empty
3. initialState_isEmptyTrue - isEmpty true initially
4. initialState_showNewTagSheetFalse - Sheet not shown initially
5. initialState_tagCountBeforeSheetZero - Count starts at zero
6. prepareForNewTag_setsShowNewTagSheet - Opens new tag sheet
7. prepareForNewTag_capturesActiveTagCount - Captures current count
8. closeNewTagSheet_hidesSheet - Closes sheet
9. lifecycle_prepareAndClose - Full prepare/close cycle
10. prepareForNewTag_calledTwice_stillWorks - Idempotent open

Cases NOT covered (require ModelContext):
- activeTags filtering with actual Tag data (tags is private(set))
- isEmpty with actual tags (tags is private(set))
- loadTags (requires ModelContext)
*/
