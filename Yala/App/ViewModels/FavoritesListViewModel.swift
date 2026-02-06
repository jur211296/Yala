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

    var isEmpty: Bool {
        favorites.isEmpty
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

    func deleteFavorites(at offsets: IndexSet) {
        guard let context = modelContext else { return }

        for index in offsets {
            let favorite = favorites[index]
            context.delete(favorite)
        }

        do {
            try context.save()
            loadFavorites()
        } catch {
            #if DEBUG
            print("FavoritesListViewModel: Error deleting favorites: \(error)")
            #endif
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
