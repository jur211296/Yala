//
//  BulkEditViewModelTests.swift
//  YalaTests
//
//  Unit tests for BulkEditViewModel state and behavior.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

struct BulkEditViewModelTests {

    // MARK: - Initial State

    @MainActor @Test func initialState_tagsEmpty() {
        let vm = BulkEditViewModel()
        #expect(vm.allTags.isEmpty)
        #expect(vm.activeTags.isEmpty)
    }

    // MARK: - loadData without context

    @MainActor @Test func loadData_withoutContext_keepsEmptyTags() {
        let vm = BulkEditViewModel()
        vm.loadData()
        #expect(vm.allTags.isEmpty)
    }

    // MARK: - activeTags contract

    @MainActor @Test func activeTags_isSubsetOfAllTags() {
        // Contract: activeTags should always be <= allTags count
        let vm = BulkEditViewModel()
        #expect(vm.activeTags.count <= vm.allTags.count)
    }

    // MARK: - Tag isActive filtering logic

    @Test func tagIsActive_defaultTrue() {
        let tag = Tag(name: "Test", colorHex: "#000000", iconName: "tag")
        #expect(tag.isActive == true)
    }

    @Test func tagIsActive_canBeSetFalse() {
        let tag = Tag(name: "Test", colorHex: "#000000", iconName: "tag")
        tag.isActive = false
        #expect(tag.isActive == false)
    }

    @Test func filterActiveTags_logic() {
        let active = Tag(name: "Work", colorHex: "#000", iconName: "tag")
        let inactive = Tag(name: "Old", colorHex: "#000", iconName: "tag")
        inactive.isActive = false

        let allTags = [active, inactive]
        let activeTags = allTags.filter { $0.isActive }

        #expect(activeTags.count == 1)
        #expect(activeTags[0].name == "Work")
    }
}
