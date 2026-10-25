//
//  FavoriteEditorTransferTests.swift
//  YalaTests
//
//  Card 93ta: Ajustes › Favoritos edita un favorito de transferencia como transferencia. Lo que fija:
//   - origen y destino no pueden ser la misma cuenta (la lógica pura y el guardado);
//   - guardar una transferencia conserva el tipo y el destino, y le quita categoría, etiquetas y naturaleza;
//   - guardar un gasto quita un destino colgando (antes, tocar «Gasto» lo dejaba puesto e invisible).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Favoritos · el editor de una transferencia (card 93ta)")
struct FavoriteEditorTransferLogicTests {

    @Test func transfer_sameOriginAndDestination_isInvalid() {
        #expect(!FavoriteEditorTransferLogic.accountsAreValid(isTransfer: true, origin: 1, destination: 1))
    }

    @Test func transfer_differentAccounts_orOneMissing_isValid() {
        #expect(FavoriteEditorTransferLogic.accountsAreValid(isTransfer: true, origin: 1, destination: 2))
        #expect(FavoriteEditorTransferLogic.accountsAreValid(isTransfer: true, origin: 1, destination: nil as Int?))
        #expect(FavoriteEditorTransferLogic.accountsAreValid(isTransfer: true, origin: nil as Int?, destination: 2))
    }

    /// Control: un gasto no tiene destino que comparar.
    @Test func expense_isAlwaysValid() {
        #expect(FavoriteEditorTransferLogic.accountsAreValid(isTransfer: false, origin: 1, destination: 1))
    }
}

@Suite("Favoritos · guardar desde el editor (card 93ta)", .serialized)
@MainActor
struct FavoriteEditorTransferSaveTests {

    private func account(_ context: ModelContext, _ name: String) -> Account {
        let a = Account(name: name, currencyCode: "PEN", colorHex: "#6366F1", iconName: "creditcard.fill",
                        type: AccountType.checking.rawValue)
        context.insert(a)
        return a
    }

    @Test func savingATransfer_keepsTypeAndDestination_andDropsCategoryAndTags() throws {
        let context = try makeTestContext()
        let origin = account(context, "Principal")
        let savings = account(context, "Ahorros")
        let category = Yala.Category(name: "Comida", colorHex: "#FF0000", isIncome: false, iconName: "fork.knife")
        context.insert(category)
        let subcategory = Subcategory(name: "Restaurantes", category: category)
        context.insert(subcategory)
        let tag = Yala.Tag(name: "Viaje")
        context.insert(tag)
        let favorite = FavoritePayment(name: "Ahorro", transactionType: TransactionType.transfer.rawValue, amount: 200,
                                       account: origin, subcategory: subcategory, tags: [tag])
        context.insert(favorite)
        try context.save()

        let vm = FavoriteEditorViewModel()
        vm.setContext(context)
        #expect(vm.saveFavorite(existing: favorite, name: "Ahorro", transactionType: .transfer, amountString: "200",
                                note: "", account: origin, subcategory: subcategory, tags: [tag],
                                needOverride: .optional, destinationAccount: savings))

        #expect(favorite.type == .transfer)
        #expect(favorite.destinationAccount?.persistentModelID == savings.persistentModelID)
        #expect(favorite.subcategory == nil, "una transferencia no lleva categoría")
        #expect((favorite.resolvedTagIDs() ?? []).isEmpty, "una transferencia no lleva etiquetas")
        #expect(favorite.needOverride == nil)
    }

    @Test func savingATransferToItsOwnOrigin_isRefused() throws {
        let context = try makeTestContext()
        let origin = account(context, "Principal")
        let favorite = FavoritePayment(name: "Ahorro", transactionType: TransactionType.transfer.rawValue,
                                       account: origin)
        context.insert(favorite)
        try context.save()

        let vm = FavoriteEditorViewModel()
        vm.setContext(context)
        #expect(!vm.saveFavorite(existing: favorite, name: "Ahorro", transactionType: .transfer, amountString: "",
                                 note: "", account: origin, subcategory: nil, tags: [], needOverride: nil,
                                 destinationAccount: origin))
        #expect(favorite.destinationAccount == nil, "no se guardó nada")
    }

    @Test func savingAnExpense_dropsAHangingDestination() throws {
        let context = try makeTestContext()
        let origin = account(context, "Principal")
        let savings = account(context, "Ahorros")
        let favorite = FavoritePayment(name: "Café", transactionType: TransactionType.expense.rawValue,
                                       account: origin, destinationAccount: savings)
        context.insert(favorite)
        try context.save()

        let vm = FavoriteEditorViewModel()
        vm.setContext(context)
        #expect(vm.saveFavorite(existing: favorite, name: "Café", transactionType: .expense, amountString: "12",
                                note: "", account: origin, subcategory: nil, tags: [], needOverride: nil))
        #expect(favorite.destinationAccount == nil, "un gasto no conserva el destino de una transferencia")
    }
}
