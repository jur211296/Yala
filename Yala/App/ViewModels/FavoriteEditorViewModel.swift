//
//  FavoriteEditorViewModel.swift
//  Yala
//
//  ViewModel for FavoriteEditorView - handles favorite payment creation and editing.
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class FavoriteEditorViewModel {
    private var modelContext: ModelContext?

    // Data
    private(set) var existingFavoritesCount: Int = 0

    // Save state
    private(set) var showSaveError = false

    func setContext(_ context: ModelContext) {
        self.modelContext = context
        loadFavoritesCount()
    }

    func loadFavoritesCount() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<FavoritePayment>()
        do {
            existingFavoritesCount = try context.fetchCount(descriptor)
        } catch {
            print("FavoriteEditorViewModel: Error fetching favorites count: \(error)")
            existingFavoritesCount = 0
        }
    }

    func saveFavorite(
        existing: FavoritePayment?,
        name: String,
        transactionType: TransactionType,
        amountString: String,
        note: String,
        account: Account?,
        subcategory: Subcategory?,
        tags: [Tag],
        natureOverride: SubcategoryNature?
    ) -> Bool {
        guard let context = modelContext else { return false }

        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return false }

        let amount: Double? = amountString.isEmpty ? nil : Double(amountString)
        let natureRaw: String? =
            natureOverride != subcategory?.nature
            ? natureOverride?.rawValue
            : nil

        if let existing = existing {
            // Update existing
            existing.name = trimmedName
            existing.transactionType = transactionType.rawValue
            existing.amount = amount
            existing.note = note.isEmpty ? nil : note
            existing.account = account
            existing.subcategory = subcategory
            existing.tags = tags
            existing.natureOverride = natureRaw
            existing.currencyCode = account?.currencyCode
        } else {
            // Create new
            let newFavorite = FavoritePayment(
                name: trimmedName,
                transactionType: transactionType.rawValue,
                amount: amount,
                note: note.isEmpty ? nil : note,
                account: account,
                subcategory: subcategory,
                tags: tags,
                natureOverride: natureRaw,
                currencyCode: account?.currencyCode,
                displayOrder: existingFavoritesCount
            )
            context.insert(newFavorite)
        }

        do {
            try context.save()
            return true
        } catch {
            print("FavoriteEditorViewModel: Error saving favorite: \(error)")
            showSaveError = true
            return false
        }
    }

    func dismissSaveError() {
        showSaveError = false
    }
}
