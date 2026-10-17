//
//  CategoriesSettingsListViewModel.swift
//  Yala
//
//  ViewModel for CategoriesSettingsListView - handles category list state and operations.
//  Fase D: Arquitectura - @Query → ViewModels
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class CategoriesSettingsListViewModel {

    // MARK: - Dependencies

    private var modelContext: ModelContext?
    private var deletionService: EntityDeletionService?

    // MARK: - Data

    private(set) var categories: [Category] = []

    // MARK: - UI State

    var isEditing = false
    var isNavigatingToNewCategory = false
    var newCategory: Category?
    var showCannotDeleteAlert = false
    var categoryToDeleteName = ""
    var transactionCountForAlert = 0
    /// La categoría sin registros que espera el «sí» del usuario. Hasta el lote 7 de la auditoría UX 2.2 (B2)
    /// el «−» de Editar la borraba al primer toque, sin preguntar, junto con todas sus subcategorías.
    var categoryPendingDeletion: Category?
    var showDeleteConfirmation = false
    /// La categoría con registros del aviso «No se puede eliminar», para «Ocultarla» o «Mover sus registros…»
    /// (auditoría UX 2.2, lote 7, L7-10).
    var categoryWithRecords: Category?
    /// La categoría cuyos registros se van a mover (abre la hoja de destino).
    var categoryToMove: Category?

    // MARK: - Computed Properties

    var orderedCategories: [Category] {
        categories.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var activeCategories: [Category] {
        orderedCategories.filter { $0.isVisible && !$0.isSystem }
    }

    var hiddenCategories: [Category] {
        orderedCategories.filter { !$0.isVisible && !$0.isSystem }
    }

    /// Categorías sistema del bridge de grupos ("Grupos", "Cobros de grupos").
    /// Se muestran en una sección read-only aparte (espejo de las cuentas sistema):
    /// no editables ni eliminables, sin navegación al detalle.
    var systemCategories: [Category] {
        orderedCategories.filter { $0.isSystem }
    }

    var isEmpty: Bool {
        categories.isEmpty
    }

    // MARK: - Context Injection

    func setContext(_ context: ModelContext, deletionService: EntityDeletionService) {
        self.modelContext = context
        self.deletionService = deletionService
        deletionService.setContext(context)
        loadCategories()
    }

    // MARK: - Data Loading

    func loadCategories() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<Category>(sortBy: [SortDescriptor(\Category.name)])
        do {
            categories = try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("CategoriesSettingsListViewModel: Error loading categories: \(error)")
            #endif
            categories = []
        }
    }

    // MARK: - Category Creation

    func createAndOpenNewCategory() {
        guard let context = modelContext else { return }

        let nextSortOrder = (categories.map { $0.sortOrder }.max() ?? 0) + 1

        let category = Category(
            name: "",
            colorHex: AppConstants.defaultColorHex,
            isIncome: false,
            isDefaultSeed: false,
            isVisible: true,
            sortOrder: nextSortOrder,
            subcategories: []
        )
        // Modo Nube I2: born-cloud identity capture (gateado DARK; no-op en producción hoy).
        SyncIdentityService.captureIfEnabled(category)
        context.insert(category)

        newCategory = category
        isNavigatingToNewCategory = true
    }

    // MARK: - Category Deletion

    /// Se puede borrar (o vaciar moviendo sus registros) salvo las de sistema y las que guardan subcategorías de
    /// sistema, como «Otros» con «Ajustes de saldo» (review de UX 2.2 · L7-10).
    func canDelete(_ category: Category) -> Bool {
        !category.isSystem && !CategoryRecordsMoveService.holdsSystemSubcategories(category)
    }

    func handleCategoryDelete(_ category: Category) {
        guard modelContext != nil else { return }
        guard canDelete(category) else { return }

        // Las categorías sistema no se borran (esta ruta usa context.delete directo,
        // sin pasar por EntityDeletionService). Defensa: el botón "−" tampoco se
        // renderiza para ellas porque viven en la sección read-only.
        guard !category.isSystem else { return }

        // Si no se puede contar, se trata como «con registros»: el aviso ofrece ocultarla o moverlos, nunca
        // borrarla a ciegas.
        let count = recordCount(of: category)
        if count != 0 {
            categoryToDeleteName = category.name
            categoryWithRecords = category
            transactionCountForAlert = max(count ?? 0, 0)
            showCannotDeleteAlert = true
            return
        }

        categoryPendingDeletion = category
        showDeleteConfirmation = true
    }

    /// «Ocultarla» desde el aviso: deja de aparecer al registrar y su historial se queda (L7-10).
    func hideCategoryWithRecords() {
        defer { categoryWithRecords = nil }
        guard let context = modelContext, let category = categoryWithRecords else { return }
        category.isVisible = false
        do {
            try context.save()
            SessionState.shared.incrementDataVersion()
            loadCategories()
        } catch {
            #if DEBUG
            print("CategoriesSettingsListViewModel: Error hiding category: \(error)")
            #endif
        }
    }

    /// «Mover sus registros…» desde el aviso: abre la hoja de destino.
    func startMovingRecords() {
        categoryToMove = categoryWithRecords
        categoryWithRecords = nil
    }

    /// El usuario dijo que sí en la confirmación: borra la categoría pendiente y sus subcategorías.
    func confirmCategoryDeletion() {
        defer { categoryPendingDeletion = nil }
        guard let context = modelContext, let category = categoryPendingDeletion else { return }
        guard canDelete(category) else { return }
        // Se vuelve a contar: entre la pregunta y el «sí» pudo llegar un registro por sync.
        let count = recordCount(of: category)
        guard count == 0 else {
            categoryToDeleteName = category.name
            categoryWithRecords = category
            transactionCountForAlert = max(count ?? 0, 0)
            showCannotDeleteAlert = true
            return
        }

        // Delete subcategories first to avoid SwiftUI @Query conflicts
        for subcategory in category.subcategories ?? [] {
            context.delete(subcategory)
        }
        context.delete(category)

        do {
            try context.save()
            context.processPendingChanges()
            WidgetDataCache.updateCache(context: context)
            SessionState.shared.incrementDataVersion()
            loadCategories()
        } catch {
            #if DEBUG
            print("CategoriesSettingsListViewModel: Error deleting category: \(error)")
            #endif
        }
    }

    /// Los registros de la categoría y de sus subcategorías; `nil` si no se pudo leer (L7-10).
    private func recordCount(of category: Category) -> Int? {
        guard let context = modelContext else { return nil }
        do {
            return try CategoryRecordsMoveService.recordCount(of: category, context: context)
        } catch {
            #if DEBUG
            print("CategoriesSettingsListViewModel: Error counting records: \(error)")
            #endif
            return nil
        }
    }
}
