//
//  FavoritesAlRegistrar23Tests.swift
//  YalaTests
//
//  Revisión 2.3 · Nuevo registro, decisiones 22, 69, 70, 71 y 72 del 9-nov. La lógica de cada punto; lo que se ve lo
//  fija `YalaUITests/Flows/FavoritesAlRegistrar23UITests`.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Favoritos al registrar (2.3) · lógica")
@MainActor
struct FavoritesAlRegistrar23LogicTests {

    private func favorites() -> [FavoritePayment] {
        [
            FavoritePayment(name: "Café", transactionType: TransactionType.expense.rawValue, amount: 12),
            FavoritePayment(name: "Sueldo", transactionType: TransactionType.income.rawValue, amount: 3000),
            FavoritePayment(name: "Ahorro", transactionType: TransactionType.transfer.rawValue, amount: 200),
        ]
    }

    // MARK: - 69 · La fila filtra por el tipo elegido

    @Test("En «Ingreso» la fila solo enseña ingresos; en «Gasto», gastos; en «Transferencia», transferencias")
    func row_filtersByTheChosenType() {
        let all = favorites()
        #expect(FavoritesVisibility.shown(all, isExpensesOnlyMode: false, type: .income).map(\.name) == ["Sueldo"])
        #expect(FavoritesVisibility.shown(all, isExpensesOnlyMode: false, type: .expense).map(\.name) == ["Café"])
        #expect(FavoritesVisibility.shown(all, isExpensesOnlyMode: false, type: .transfer).map(\.name) == ["Ahorro"])
    }

    @Test("Sin tipo (Ajustes, «Ver todos») salen todos; con «Solo gastos», solo los gastos, como siempre")
    func withoutType_allOrExpensesOnly() {
        let all = favorites()
        #expect(FavoritesVisibility.shown(all, isExpensesOnlyMode: false).count == 3)
        #expect(FavoritesVisibility.shown(all, isExpensesOnlyMode: true).map(\.name) == ["Café"])
        #expect(FavoritesVisibility.shown(all, isExpensesOnlyMode: true, type: .income).isEmpty)
    }

    // MARK: - 70 · El editor nombra los tres tipos

    @Test("El editor ofrece Gasto, Ingreso y Transferencia; con «Solo gastos», solo Gasto")
    func editor_offersTheThreeTypes() {
        #expect(FavoriteEditorTypeLogic.availableTypes(isExpensesOnlyMode: false) == [.expense, .income, .transfer])
        #expect(FavoriteEditorTypeLogic.availableTypes(isExpensesOnlyMode: true) == [.expense])
    }

    @Test("Los nombres del selector del editor son los del formulario, en singular")
    func editor_usesTheFormNames() {
        for type in FavoriteEditorTypeLogic.availableTypes(isExpensesOnlyMode: false) {
            #expect(FavoriteEditorTypeLogic.title(for: type) == type.displayName)
        }
    }

    // MARK: - 72 · Una transferencia vieja no se lista como «Cuenta Principal → …»

    @Test("Con las dos cuentas, «origen → destino»; con una, su nombre; sin ninguna, «Transferencia»")
    func transferLine_namesWhatItHas() {
        #expect(FavoriteRowLine.transfer(origin: "Cuenta Principal", destination: "Ahorros USD")
            == "Cuenta Principal → Ahorros USD")
        #expect(FavoriteRowLine.transfer(origin: "Cuenta Principal", destination: nil) == "Cuenta Principal")
        #expect(FavoriteRowLine.transfer(origin: nil, destination: "Ahorros USD") == "Ahorros USD")
        #expect(FavoriteRowLine.transfer(origin: nil, destination: nil) == TransactionType.transfer.displayName)
        #expect(!FavoriteRowLine.transfer(origin: "Cuenta Principal", destination: nil).contains("…"))
    }

    // MARK: - 22 · F4 · Los textos dejan de prometer «un toque»

    @Test("Ningún texto de favoritos en español promete registrar «con un toque»",
          arguments: ["es", "es-419", "es-ES", "es-AR"])
    func copy_doesNotPromiseOneTap(language: String) throws {
        let keys = [
            "favorites.createTemplate", "favorites.saveDescription", "l2d.favorites.transferHelp",
            "tips.favorites.detail", "tutorials.createFavorites.intro.desc",
            "tutorials.createFavorites.completion.desc",
        ]
        let path = try #require(Bundle.main.path(forResource: "Localizable", ofType: "strings", inDirectory: nil,
                                                 forLocalization: language))
        let table = try #require(NSDictionary(contentsOfFile: path) as? [String: String])
        for key in keys {
            let value = try #require(table[key], "Falta \(key) en \(language)")
            #expect(!value.contains("un toque") && !value.contains("un solo toque"),
                    "\(language) · \(key) sigue prometiendo un toque: \(value)")
        }
    }
}

// MARK: - 71 · Borrar desde la lista pregunta antes

@Suite("Favoritos al registrar (2.3) · borrar desde la lista", .serialized)
@MainActor
struct FavoritesAlRegistrar23DeletionTests {

    private func seeded() throws -> (FavoritesListViewModel, ModelContext) {
        let context = try makeTestContext()
        for (index, name) in ["Café", "Sueldo", "Taxi"].enumerated() {
            context.insert(FavoritePayment(name: name, displayOrder: index))
        }
        try context.save()
        let viewModel = FavoritesListViewModel()
        viewModel.setContext(context)
        return (viewModel, context)
    }

    private func names(_ context: ModelContext) throws -> [String] {
        try context.fetch(FetchDescriptor<FavoritePayment>(sortBy: [SortDescriptor(\.displayOrder)])).map(\.name)
    }

    @Test("Deslizar no borra: pregunta, y «Cancelar» lo deja todo como estaba")
    func swipe_asksFirst_andCancelKeepsIt() throws {
        let wasExpensesOnly = SessionState.shared.isExpensesOnlyMode
        SessionState.shared.isExpensesOnlyMode = false
        defer { SessionState.shared.isExpensesOnlyMode = wasExpensesOnly }
        let (viewModel, context) = try seeded()

        viewModel.requestDeletion(at: IndexSet(integer: 1))
        #expect(viewModel.showDeleteConfirmation)
        #expect(try names(context) == ["Café", "Sueldo", "Taxi"], "Pedir el borrado no borra nada.")

        viewModel.cancelPendingDeletion()
        #expect(!viewModel.showDeleteConfirmation)
        #expect(viewModel.pendingDeletion.isEmpty)
        #expect(try names(context) == ["Café", "Sueldo", "Taxi"])
    }

    @Test("«Eliminar» en la pregunta borra el que se deslizó, y solo ese")
    func confirm_deletesTheSwipedOne() throws {
        let wasExpensesOnly = SessionState.shared.isExpensesOnlyMode
        SessionState.shared.isExpensesOnlyMode = false
        defer { SessionState.shared.isExpensesOnlyMode = wasExpensesOnly }
        let (viewModel, context) = try seeded()

        viewModel.requestDeletion(at: IndexSet(integer: 1))
        viewModel.confirmPendingDeletion()
        #expect(try names(context) == ["Café", "Taxi"])
        #expect(viewModel.pendingDeletion.isEmpty)
    }

    @Test("Con «Solo gastos», el índice es el de la lista que se ve: no borra otro favorito")
    func expensesOnly_resolvesTheIndexOnTheShownList() throws {
        let wasExpensesOnly = SessionState.shared.isExpensesOnlyMode
        defer { SessionState.shared.isExpensesOnlyMode = wasExpensesOnly }
        let context = try makeTestContext()
        context.insert(FavoritePayment(name: "Sueldo", transactionType: TransactionType.income.rawValue, displayOrder: 0))
        context.insert(FavoritePayment(name: "Café", displayOrder: 1))
        try context.save()
        SessionState.shared.isExpensesOnlyMode = true
        let viewModel = FavoritesListViewModel()
        viewModel.setContext(context)
        #expect(viewModel.displayedFavorites.map(\.name) == ["Café"])

        viewModel.requestDeletion(at: IndexSet(integer: 0))
        viewModel.confirmPendingDeletion()
        #expect(try names(context) == ["Sueldo"], "Borra «Café», la fila deslizada, no «Sueldo».")
    }
}
