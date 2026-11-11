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

    /// Cómo estaba el formulario al abrirse: la X pregunta antes de tirar lo que cambió (lote 09 de mejoras 2.3).
    private let initialName: String
    private let initialColorHex: String
    private let initialIconName: String
    private let initialIsActive: Bool

    /// Si hay algo que perder al cerrar. Un nombre de solo espacios no cuenta: no se guardaría.
    var hasUnsavedChanges: Bool {
        trimmedName != initialName.trimmingCharacters(in: .whitespacesAndNewlines)
            || selectedColorHex.uppercased() != initialColorHex.uppercased()
            || selectedIconName != initialIconName
            || isActive != initialIsActive
    }

    // MARK: - Init

    init(tagToEdit: Tag? = nil, initialExistingTags: [Tag] = []) {
        self.tagToEdit = tagToEdit

        let name: String
        let colorHex: String
        let iconName: String
        let isActive: Bool
        if let tag = tagToEdit {
            name = tag.name
            colorHex = tag.colorHex
            iconName = tag.iconName
            isActive = tag.isActive
        } else {
            // Calculate unique color based on existing tags
            let usedColors = initialExistingTags.map { $0.colorHex }
            name = ""
            colorHex = Tag.nextAvailableColor(excluding: usedColors)
            iconName = "tag.fill"
            isActive = true
        }
        self.name = name
        self.selectedColorHex = colorHex
        self.selectedIconName = iconName
        self.isActive = isActive
        self.initialName = name
        self.initialColorHex = colorHex
        self.initialIconName = iconName
        self.initialIsActive = isActive

        self.existingTags = initialExistingTags
    }

    /// Suelta las etiquetas cargadas tras eliminar la que se edita: el formulario sigue presentado mientras se cierra, su
    /// barra lee `canSave` y la unicidad del nombre recorría la lista leyendo la borrada. En iOS 27.x leer un modelo
    /// borrado aborta (card 1w89).
    func releaseDeletedTag() {
        existingTags = []
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
        !trimmedName.isEmpty && trimmedName.count <= TagNameLimit.maxLength
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
