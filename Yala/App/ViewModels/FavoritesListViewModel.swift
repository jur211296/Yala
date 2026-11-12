//
//  FavoritesListViewModel.swift
//  Yala
//
//  ViewModel for FavoritesListView - handles favorite payment list operations.
//  Fase D: Arquitectura - @Query → ViewModels
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class FavoritesListViewModel {

    // MARK: - Dependencies

    private var modelContext: ModelContext?

    // MARK: - Data

    private(set) var favorites: [FavoritePayment] = []

    // MARK: - UI State

    var showEditor = false
    var favoriteToEdit: FavoritePayment?
    var showSaveError = false

    // MARK: - Computed Properties

    /// Favorites filtered for expenses-only mode (hides income favorites)
    var displayedFavorites: [FavoritePayment] {
        FavoritesVisibility.shown(favorites, isExpensesOnlyMode: SessionState.shared.isExpensesOnlyMode)
    }

    var isEmpty: Bool {
        displayedFavorites.isEmpty
    }

    // MARK: - Context Injection

    func setContext(_ context: ModelContext) {
        self.modelContext = context
        loadFavorites()
    }

    // MARK: - Data Loading

    func loadFavorites() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<FavoritePayment>(sortBy: [SortDescriptor(\FavoritePayment.displayOrder)])
        do {
            favorites = try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("FavoritesListViewModel: Error loading favorites: \(error)")
            #endif
            favorites = []
        }
    }

    // MARK: - Favorite Operations

    /// Lo que se deslizó para borrar, esperando la respuesta a «¿Eliminar este favorito?».
    private(set) var pendingDeletion: [FavoritePayment] = []
    var showDeleteConfirmation = false

    /// Deslizar (o el «−» de Editar) pregunta antes de borrar, como el editor (decisión 71 de la revisión 2.3, regla de
    /// la 39). Los índices son los de la lista que se pinta (`displayedFavorites`): con «Solo gastos», resolverlos sobre
    /// `favorites` borraba otro favorito.
    func requestDeletion(at offsets: IndexSet) {
        let shown = displayedFavorites
        pendingDeletion = offsets.filter { shown.indices.contains($0) }.map { shown[$0] }
        showDeleteConfirmation = !pendingDeletion.isEmpty
    }

    func cancelPendingDeletion() {
        pendingDeletion = []
        showDeleteConfirmation = false
    }

    func confirmPendingDeletion() {
        let toDelete = pendingDeletion
        pendingDeletion = []
        showDeleteConfirmation = false
        guard let context = modelContext, !toDelete.isEmpty else { return }

        for favorite in toDelete {
            context.delete(favorite)
        }

        do {
            try context.save()
            DS.Haptic.warning()
            loadFavorites()
        } catch {
            #if DEBUG
            print("FavoritesListViewModel: Error deleting favorites: \(error)")
            #endif
            DS.Haptic.error()
            showSaveError = true
        }
    }

    func moveFavorites(from source: IndexSet, to destination: Int) {
        guard let context = modelContext else { return }

        var orderedFavorites = favorites
        orderedFavorites.move(fromOffsets: source, toOffset: destination)

        // Update display order
        for (index, favorite) in orderedFavorites.enumerated() {
            favorite.displayOrder = index
        }

        do {
            try context.save()
            loadFavorites()
        } catch {
            #if DEBUG
            print("FavoritesListViewModel: Error moving favorites: \(error)")
            #endif
            DS.Haptic.error()
            showSaveError = true
        }
    }

    func openEditor(for favorite: FavoritePayment?) {
        favoriteToEdit = favorite
        showEditor = true
    }

    func closeEditor() {
        favoriteToEdit = nil
        showEditor = false
        loadFavorites()
    }
}
