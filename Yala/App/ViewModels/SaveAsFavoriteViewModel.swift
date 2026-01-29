//
//  SaveAsFavoriteViewModel.swift
//  Yala
//
//  ViewModel for SaveAsFavoriteSheet - handles tag loading.
//  Fase D: Arquitectura - @Query → ViewModels
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class SaveAsFavoriteViewModel {

    // MARK: - Dependencies

    private var modelContext: ModelContext?

    // MARK: - Data

    private(set) var allTags: [Tag] = []

    // MARK: - Computed Properties

    var activeTags: [Tag] {
        allTags.filter { $0.isActive }
    }

    func selectedTagObjects(from selectedIDs: Set<PersistentIdentifier>) -> [Tag] {
        activeTags.filter { selectedIDs.contains($0.persistentModelID) }
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
            allTags = try context.fetch(descriptor)
        } catch {
            print("SaveAsFavoriteViewModel: Error loading tags: \(error)")
            allTags = []
        }
    }

    // MARK: - Save Operation

    func saveFavorite(
        name: String,
        transactionType: TransactionType,
        amount: Double?,
        note: String?,
        account: Account?,
        subcategory: Subcategory?,
        selectedTagIDs: Set<PersistentIdentifier>,
        natureOverride: SubcategoryNature?,
        currencyCode: String
    ) throws {
        guard let context = modelContext else { return }

        // Get next display order
        let descriptor = FetchDescriptor<FavoritePayment>(
            sortBy: [SortDescriptor(\.displayOrder, order: .reverse)]
        )
        let existingFavorites = (try? context.fetch(descriptor)) ?? []
        let nextOrder = (existingFavorites.first?.displayOrder ?? -1) + 1

        let selectedTags = selectedTagObjects(from: selectedTagIDs)

        let favorite = FavoritePayment(
            name: name,
            transactionType: transactionType.rawValue,
            amount: amount,
            note: note,
            account: account,
            subcategory: subcategory,
            tags: selectedTags,
            natureOverride: natureOverride?.rawValue,
            currencyCode: currencyCode,
            displayOrder: nextOrder
        )

        context.insert(favorite)
        try context.save()
    }
}
