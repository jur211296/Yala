//
//  TagFormViewModelTests.swift
//  YalaTests
//
//  Unit tests for TagFormViewModel validation logic.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

struct TagFormViewModelTests {

    // MARK: - isNameValid

    @MainActor @Test func isNameValid_empty_false() {
        let vm = TagFormViewModel()
        vm.name = ""
        #expect(vm.isNameValid == false)
    }

    @MainActor @Test func isNameValid_oneChar_true() {
        let vm = TagFormViewModel()
        vm.name = "A"
        #expect(vm.isNameValid == true)
    }

    @MainActor @Test func isNameValid_20chars_true() {
        let vm = TagFormViewModel()
        vm.name = String(repeating: "A", count: 20)
        #expect(vm.isNameValid == true)
    }

    @MainActor @Test func isNameValid_21chars_false() {
        let vm = TagFormViewModel()
        vm.name = String(repeating: "A", count: 21)
        #expect(vm.isNameValid == false)
    }

    @MainActor @Test func isNameValid_whitespaceOnly_false() {
        let vm = TagFormViewModel()
        vm.name = "   "
        #expect(vm.isNameValid == false)
    }

    // MARK: - isNameUnique

    @MainActor @Test func isNameUnique_noExisting_true() {
        let vm = TagFormViewModel(initialExistingTags: [])
        vm.name = "Nuevo"
        #expect(vm.isNameUnique == true)
    }

    @MainActor @Test func isNameUnique_duplicateCaseInsensitive_false() {
        let existingTag = Tag(name: "Comida", colorHex: "#8B5CF6", iconName: "tag.fill")
        let vm = TagFormViewModel(initialExistingTags: [existingTag])
        vm.name = "comida"
        #expect(vm.isNameUnique == false)
    }

    // MARK: - canSave

    @MainActor @Test func canSave_validAndUnique_true() {
        let vm = TagFormViewModel(initialExistingTags: [])
        vm.name = "NuevoTag"
        #expect(vm.canSave == true)
    }
}
