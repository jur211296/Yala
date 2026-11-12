//
//  CategoryDetailViewModel.swift
//  Yala
//
//  ViewModel for CategoryDetailView - handles category editing and subcategory management.
//  Fase D: Arquitectura - @Query → ViewModels
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class CategoryDetailViewModel {

    // MARK: - Dependencies

    private var modelContext: ModelContext?
    private var deletionService: EntityDeletionService?

    // MARK: - Data

    let category: Category
    let isNewCategory: Bool
    private(set) var allSubcategories: [Subcategory] = []

    // MARK: - Form State (editable)

    var name: String
    var isVisible: Bool
    var iconName: String
    var colorHex: String

    // Initial values for change detection
    private let initialName: String
    private let initialIsVisible: Bool
    private let initialIconName: String
    private let initialColorHex: String

    // MARK: - Computed Properties

    /// La categoría mientras se puede leer. Eliminarla (o descartarla, o mover sus registros) la borra con la pantalla
    /// aún montada mientras se cierra, y en iOS 27.x leer un modelo borrado aborta (card 1w89). Lo que el `body` lea de
    /// ella pasa por aquí.
    var readableCategory: Category? {
        categoryWasReleased || category.isDeleted ? nil : category
    }

    /// La pantalla borró la categoría y soltó lo cargado (`releaseDeletedCategory`).
    private(set) var categoryWasReleased = false

    /// Sin las ya borradas: al eliminar la categoría se van con ella, y al eliminar una desde su detalle esta pantalla
    /// —debajo— la conserva cargada hasta recargar.
    var subcategories: [Subcategory] {
        allSubcategories
            .filter { !$0.isDeleted && $0.modelContext != nil }
            .filter { $0.category == category }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var visibleSubcategories: [Subcategory] {
        subcategories.filter { $0.isVisible }
    }

    var hiddenSubcategories: [Subcategory] {
        subcategories.filter { !$0.isVisible }
    }

    var hasUnsavedChanges: Bool {
        let trimmedCurrentName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedInitialName = initialName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedCurrentName != trimmedInitialName
            || isVisible != initialIsVisible
            || iconName != initialIconName
            || colorHex != initialColorHex
    }

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && hasUnsavedChanges
    }

    var displayName: String {
        name.isEmpty ? L10n.Category.newCategory : name
    }

    var isSystemCategory: Bool {
        guard let category = readableCategory else { return false }
        // `isSystem` cubre las categorías sistema del bridge de grupos ("Grupos",
        // "Cobros de grupos"). Se preserva la protección legacy de "Otros" y de las
        // categorías de ingreso, que ya eran read-only por esta vía.
        // Y, en cualquier idioma, la que guarda subcategorías de sistema (review de UX 2.2 · L7-10): «Otros» solo se
        // reconocía por su nombre en español.
        return category.isSystem || category.isIncome || category.name == "Otros"
            || CategoryRecordsMoveService.holdsSystemSubcategories(category)
    }

    // MARK: - Init

    /// - Parameter readsCategory: `false` si quien la crea ya sabe que la categoría no se puede leer (borrada): la lista
    ///   vuelve a crear esta pantalla en su `NavigationLink` mientras se cierra, y entonces no se copia nada de ella.
    init(category: Category, isNewCategory: Bool = false, readsCategory: Bool = true) {
        self.category = category
        self.isNewCategory = isNewCategory
        self.categoryWasReleased = !readsCategory
        let readable = readsCategory
        let name = readable ? category.name : ""
        let isVisible = readable ? category.isVisible : true
        let iconName = readable ? (category.iconName ?? "tag") : "tag"
        let colorHex = readable ? category.colorHex : AppConstants.defaultColorHex
        self.initialName = name
        self.initialIsVisible = isVisible
        self.initialIconName = iconName
        self.initialColorHex = colorHex
        self.name = name
        self.isVisible = isVisible
        self.iconName = iconName
        self.colorHex = colorHex
    }

    // MARK: - Context Injection

    func setContext(_ context: ModelContext, deletionService: EntityDeletionService) {
        self.modelContext = context
        self.deletionService = deletionService
        deletionService.setContext(context)
        loadSubcategories()
    }

    // MARK: - Data Loading

    func loadSubcategories() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<Subcategory>(sortBy: [SortDescriptor(\Subcategory.sortOrder)])
        do {
            allSubcategories = try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("CategoryDetailViewModel: Error loading subcategories: \(error)")
            #endif
            allSubcategories = []
        }
    }

    // MARK: - Category Operations

    func countTransactionsInCategory() -> Int {
        guard let service = deletionService else { return 0 }
        return service.transactionCount(forCategory: category)
    }

    /// Los registros que impiden borrarla: los de la categoría y los de sus subcategorías (L7-10).
    /// `nil` si no se pudo leer: «no pude contar» no puede tomarse por «está vacía».
    func recordCountForDeletion() -> Int? {
        guard let context = modelContext else { return nil }
        do {
            return try CategoryRecordsMoveService.recordCount(of: category, context: context)
        } catch {
            #if DEBUG
            print("CategoryDetailViewModel: Error counting records: \(error)")
            #endif
            return nil
        }
    }

    func saveCategory() -> Bool {
        guard let context = modelContext else { return false }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return false }

        if isNewCategory && subcategories.isEmpty {
            return false
        }

        category.name = trimmedName
        category.isVisible = isVisible
        category.iconName = iconName
        category.colorHex = colorHex

        // Enforce color inheritance for all subcategories
        for subcategory in category.subcategories ?? [] {
            subcategory.colorHex = colorHex
        }

        do {
            try context.save()
            SessionState.shared.incrementDataVersion()
            return true
        } catch {
            #if DEBUG
            print("CategoryDetailViewModel: Error saving category: \(error)")
            #endif
            return false
        }
    }

    func deleteCategory() -> Bool {
        guard let service = deletionService else { return false }
        do {
            try service.deleteCategory(category, withSubcategories: subcategories)
            releaseDeletedCategory()
            SessionState.shared.incrementDataVersion()
            return true
        } catch {
            #if DEBUG
            print("CategoryDetailViewModel: Error deleting category: \(error)")
            #endif
            return false
        }
    }

    func discardNewCategory() {
        guard let context = modelContext, isNewCategory else { return }
        context.delete(category)
        releaseDeletedCategory()
        do {
            try context.save()
        } catch {
            #if DEBUG
            print("CategoryDetailViewModel: Error discarding new category: \(error)")
            #endif
        }
    }

    /// Suelta las subcategorías cargadas tras borrar la categoría: se fueron con ella y la pantalla sigue presentada
    /// mientras se cierra (card 1w89).
    func releaseDeletedCategory() {
        allSubcategories = []
        categoryWasReleased = true
    }

    // MARK: - Subcategory Operations

    func countTransactionsForSubcategory(_ subcategory: Subcategory) -> Int {
        guard let service = deletionService else { return 0 }
        return service.transactionCount(forSubcategory: subcategory)
    }

    func deleteSubcategory(_ subcategory: Subcategory) -> Bool {
        guard let service = deletionService else { return false }
        do {
            try service.deleteSubcategory(subcategory)
            loadSubcategories()
            return true
        } catch {
            #if DEBUG
            print("CategoryDetailViewModel: Error deleting subcategory: \(error)")
            #endif
            return false
        }
    }
}
