//
//  TagFormViewModel.swift
//  Yala
//
//  ViewModel for TagFormView - handles tag validation and state.
//  Fase D: Arquitectura - @Query → ViewModels
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class TagFormViewModel {

    // MARK: - Dependencies

    private var modelContext: ModelContext?

    // MARK: - Form State

    var name: String = ""
    var selectedColorHex: String = ""
    var selectedIconName: String = "tag.fill"
    var isActive: Bool = true

    // MARK: - Data

    private(set) var existingTags: [Tag] = []

    // MARK: - Editing State

    let tagToEdit: Tag?
    var isEditing: Bool { tagToEdit != nil }

    // MARK: - Init

    init(tagToEdit: Tag? = nil, initialExistingTags: [Tag] = []) {
        self.tagToEdit = tagToEdit

        if let tag = tagToEdit {
            self.name = tag.name
            self.selectedColorHex = tag.colorHex
            self.selectedIconName = tag.iconName
            self.isActive = tag.isActive
        } else {
            // Calculate unique color based on existing tags
            let usedColors = initialExistingTags.map { $0.colorHex }
            let defaultColor = Tag.nextAvailableColor(excluding: usedColors)
            self.name = ""
            self.selectedColorHex = defaultColor
            self.selectedIconName = "tag.fill"
            self.isActive = true
        }

        self.existingTags = initialExistingTags
    }

    // MARK: - Context Injection

    func setContext(_ context: ModelContext) {
        self.modelContext = context
        loadTags()
    }

    // MARK: - Data Loading

    func loadTags() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<Tag>(sortBy: [SortDescriptor(\Tag.name)])
        do {
            existingTags = try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("TagFormViewModel: Error loading tags: \(error)")
            #endif
            existingTags = []
        }
    }

    // MARK: - Validation

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isNameValid: Bool {
        !trimmedName.isEmpty && trimmedName.count <= 20
    }

    var isNameUnique: Bool {
        let lowerName = trimmedName.lowercased()
        return !existingTags.contains { tag in
            // Check if it's the same tag we are editing
            if let tagToEdit = tagToEdit, tag.id == tagToEdit.id {
                return false
            }
            return tag.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == lowerName
        }
    }

    var canSave: Bool {
        isNameValid && isNameUnique
    }

    // MARK: - Actions

    func saveTag() -> Bool {
        guard canSave, let context = modelContext else { return false }

        if let tag = tagToEdit {
            tag.name = trimmedName
            tag.colorHex = selectedColorHex
            tag.iconName = selectedIconName
            tag.isActive = isActive
        } else {
            let newTag = Tag(
                name: trimmedName,
                colorHex: selectedColorHex,
                iconName: selectedIconName,
                isActive: isActive
            )
            context.insert(newTag)
        }

        do {
            try context.save()
            SessionState.shared.incrementDataVersion()
            return true
        } catch {
            #if DEBUG
            print("TagFormViewModel: Error saving tag: \(error)")
            #endif
            return false
        }
    }
}
