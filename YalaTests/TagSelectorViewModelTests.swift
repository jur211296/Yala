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

@Suite(.serialized)
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

    // MARK: - Etiqueta nueva solo con el nombre (UX 2.2 · L2-10)

    @MainActor @Test func createTag_withOnlyAName_getsTheIconAndTheNextFreeColor() throws {
        let context = try makeTestContext()
        context.insert(Tag(name: "Viaje", colorHex: Tag.defaultColors[0]))
        try context.save()
        let vm = TagSelectorViewModel()
        vm.setContext(context)

        vm.newTagName = "  Cumpleaños  "
        let created = try #require(vm.createOrPickTag())

        #expect(created.name == "Cumpleaños")
        #expect(created.iconName == "tag.fill")
        #expect(created.colorHex == Tag.defaultColors[1], "El siguiente color libre: el primero ya lo usa «Viaje».")
        #expect(vm.newTagName.isEmpty, "Creada, el campo se vacía.")
        #expect(vm.tags.count == 2)
    }

    @MainActor @Test func createTag_withAnExistingName_picksTheExistingOne_andCreatesNothing() throws {
        let context = try makeTestContext()
        let existing = Tag(name: "Viaje")
        context.insert(existing)
        try context.save()
        let vm = TagSelectorViewModel()
        vm.setContext(context)

        vm.newTagName = "viaje "
        let picked = try #require(vm.createOrPickTag())

        #expect(picked.id == existing.id)
        #expect(vm.tags.count == 1, "Un nombre repetido elige la que ya existe.")
    }

    @MainActor @Test func createTag_withTheNameOfAnArchivedTag_reactivatesIt() throws {
        let context = try makeTestContext()
        let archived = Tag(name: "Viaje", isActive: false)
        context.insert(archived)
        try context.save()
        let vm = TagSelectorViewModel()
        vm.setContext(context)

        vm.newTagName = "Viaje"
        let picked = try #require(vm.createOrPickTag())

        #expect(picked.id == archived.id)
        #expect(picked.isActive, "La que se elige por nombre vuelve a estar activa: si no, quedaría oculta en el registro.")
    }

    @MainActor @Test func createButton_needsBetweenOneAndTwentyCharacters() {
        let vm = TagSelectorViewModel()
        vm.newTagName = "   "
        #expect(!vm.canCreateTag)
        vm.newTagName = String(repeating: "a", count: 20)
        #expect(vm.canCreateTag)
        vm.newTagName = String(repeating: "a", count: 21)
        #expect(!vm.canCreateTag)
    }
}
