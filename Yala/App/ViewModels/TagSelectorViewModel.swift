//
//  TagSelectorViewModel.swift
//  Yala
//
//  ViewModel for TagSelectorSheet - handles tag list loading.
//  Fase D: Arquitectura - @Query → ViewModels
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class TagSelectorViewModel {

    // MARK: - Dependencies

    private var modelContext: ModelContext?

    // MARK: - Data

    private(set) var tags: [Tag] = []

    // MARK: - Computed Properties

    var activeTags: [Tag] {
        tags.filter { $0.isActive }
    }

    var isEmpty: Bool {
        activeTags.isEmpty
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
            tags = try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("TagSelectorViewModel: Error loading tags: \(error)")
            #endif
            tags = []
        }
    }

    // MARK: - Etiqueta nueva solo con el nombre (UX 2.2 · L2-10)

    /// Lo escrito en «Nueva etiqueta».
    var newTagName = ""

    var trimmedNewTagName: String { newTagName.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// «Crear» se enciende con un nombre de 1 a 20 caracteres, el mismo límite del editor completo.
    var canCreateTag: Bool { TagQuickCreateLogic.isValidName(trimmedNewTagName) }

    /// Crea la etiqueta con el icono `tag.fill` y el siguiente color libre (`Tag.nextAvailableColor`); se cambian luego en
    /// Ajustes › Etiquetas. Un nombre que ya existe elige esa etiqueta (y la reactiva si estaba archivada). Devuelve la
    /// etiqueta que hay que poner, o `nil` si no se pudo guardar.
    func createOrPickTag() -> Tag? {
        guard let context = modelContext, canCreateTag else { return nil }
        let name = trimmedNewTagName
        if let existing = TagQuickCreateLogic.match(name, in: tags, name: \.name) {
            if !existing.isActive {
                existing.isActive = true
                guard save(context) else { return nil }
            }
            newTagName = ""
            loadTags()
            return existing
        }
        let tag = Tag(
            name: name,
            colorHex: Tag.nextAvailableColor(excluding: tags.map(\.colorHex)),
            iconName: "tag.fill",
            isActive: true
        )
        context.insert(tag)
        guard save(context) else {
            context.delete(tag)
            return nil
        }
        newTagName = ""
        loadTags()
        return tag
    }

    private func save(_ context: ModelContext) -> Bool {
        do {
            try context.save()
            SessionState.shared.incrementDataVersion()
            return true
        } catch {
            #if DEBUG
            print("TagSelectorViewModel: Error: guardar la etiqueta nueva: \(error)")
            #endif
            return false
        }
    }
}

/// Crear una etiqueta desde la hoja (UX 2.2 · L2-10). Lógica pura para fijarla con tests.
enum TagQuickCreateLogic {
    static let maxNameLength = 20

    static func isValidName(_ trimmed: String) -> Bool {
        !trimmed.isEmpty && trimmed.count <= maxNameLength
    }

    /// La etiqueta que ya se llama así, sin distinguir mayúsculas ni espacios en los extremos (el criterio de
    /// `TagFormViewModel.isNameUnique`).
    static func match<T>(_ name: String, in tags: [T], name keyPath: KeyPath<T, String>) -> T? {
        let wanted = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return tags.first { $0[keyPath: keyPath].trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == wanted }
    }
}
