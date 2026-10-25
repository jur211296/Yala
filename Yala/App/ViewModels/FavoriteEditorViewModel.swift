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
            #if DEBUG
            print("FavoriteEditorViewModel: Error fetching favorites count: \(error)")
            #endif
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
        needOverride: SubcategoryNeed?,
        destinationAccount: Account? = nil
    ) -> Bool {
        guard let context = modelContext else { return false }

        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return false }
        // Card 93ta: una transferencia de una cuenta a sí misma no se guarda (el editor tampoco deja elegirla).
        guard FavoriteEditorTransferLogic.accountsAreValid(
            isTransfer: transactionType == .transfer, origin: account?.persistentModelID,
            destination: destinationAccount?.persistentModelID) else { return false }
        // Una transferencia no lleva categoría, etiquetas ni naturaleza; y el destino solo vive en una transferencia
        // (antes, tocar «Gasto» dejaba el destino puesto e invisible).
        let isTransfer = transactionType == .transfer
        let subcategory = isTransfer ? nil : subcategory
        let tags = isTransfer ? [] : tags
        let needOverride = isTransfer ? nil : needOverride
        let destinationAccount = isTransfer ? destinationAccount : nil

        let amount: Double? = amountString.isEmpty ? nil : AmountInputHelper.parseDecimal(amountString)
        let needRaw: String? =
            needOverride != subcategory?.need
            ? needOverride?.rawValue
            : nil

        if let existing = existing {
            // Update existing
            existing.name = trimmedName
            existing.transactionType = transactionType.rawValue
            existing.amount = amount
            existing.note = note.isEmpty ? nil : note
            existing.account = account
            existing.subcategory = subcategory
            existing.setTags(from: tags)
            existing.needOverride = needRaw
            existing.destinationAccount = destinationAccount
            existing.currencyCode = account?.currencyCode
        } else {
            // Create new
            let newFavorite = FavoritePayment(
                name: trimmedName,
                transactionType: transactionType.rawValue,
                amount: amount,
                note: note.isEmpty ? nil : note,
                account: account,
                destinationAccount: destinationAccount,
                subcategory: subcategory,
                tags: tags,
                needOverride: needRaw,
                currencyCode: account?.currencyCode,
                displayOrder: existingFavoritesCount
            )
            // Modo Nube I2: born-cloud identity capture (gateado DARK; no-op en producción hoy).
            SyncIdentityService.captureIfEnabled(newFavorite)
            context.insert(newFavorite)
        }

        do {
            try context.save()
            SessionState.shared.incrementDataVersion()
            return true
        } catch {
            #if DEBUG
            print("FavoriteEditorViewModel: Error saving favorite: \(error)")
            #endif
            showSaveError = true
            return false
        }
    }

    /// «Eliminar favorito» desde el editor (auditoría UX 2.2, lote 7, L7-14). Lo mismo que deslizar la fila.
    func deleteFavorite(_ favorite: FavoritePayment) -> Bool {
        guard let context = modelContext else { return false }
        context.delete(favorite)
        do {
            try context.save()
            SessionState.shared.incrementDataVersion()
            return true
        } catch {
            #if DEBUG
            print("FavoriteEditorViewModel: Error deleting favorite: \(error)")
            #endif
            showSaveError = true
            return false
        }
    }

    func dismissSaveError() {
        showSaveError = false
    }
}

// MARK: - Favorito de transferencia (card 93ta)

/// Lo que el editor de Ajustes › Favoritos decide de un favorito de transferencia. Puro, para probarlo sin vista.
nonisolated enum FavoriteEditorTransferLogic {
    /// Origen y destino no pueden ser la misma cuenta. Falta uno de los dos: se guarda igual (el formulario señala lo que
    /// falta al usarlo, como con un favorito de transferencia de antes de 2.2, que no tenía destino).
    static func accountsAreValid<ID: Equatable>(isTransfer: Bool, origin: ID?, destination: ID?) -> Bool {
        guard isTransfer, let origin, let destination else { return true }
        return origin != destination
    }
}
