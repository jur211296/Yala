//
//  DetailContainerDataGenerationTests.swift
//  YalaTests
//
//  `DetailContainerViewModel.dataGeneration` es lo que hace que Estadísticas › Distribución recalcule su hero (saldo y
//  flujo) cuando cambian los datos. Hasta el 2026-10-09 la pestaña solo miraba `allTransactions.count` y solo
//  recalculaba el Sankey: tras registrar un movimiento el hero seguía con el saldo viejo, y tras editar el importe de uno
//  existente no saltaba nada (ticket `el-saldo-de-distribucion-no-se-entera-de-un-registro-nuevo`).
//
//  Tres casos: avanza con un alta, avanza con una edición del importe (con las mismas filas, que es por lo que `.count`
//  no bastaba) y NO avanza en una recarga que no trae nada (la segunda recarga de un alta, al cerrar la pantalla de
//  éxito, o cerrar el formulario sin guardar): así Distribución no recalcula más veces por gesto que antes.
//
//  Se inyecta `dataVersion` en vez de tocar `SessionState.shared`.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite(.serialized)
struct DetailContainerDataGenerationTests {

    /// Contexto con una cuenta, una subcategoría y un gasto ya cargados en el ViewModel.
    private func makeLoadedViewModel() throws -> (DetailContainerViewModel, ModelContext, TransactionItem, Account, YalaCategory, Subcategory) {
        let context = try makeTestContext()
        let account = makeTestAccount(context: context)
        let category = makeTestCategory(context: context)
        let subcategory = makeTestSubcategory(context: context, category: category)
        let expense = makeTestTransaction(
            context: context, amount: -100, account: account, category: category, subcategory: subcategory)
        try context.save()

        let viewModel = DetailContainerViewModel()
        viewModel.setContext(context)
        viewModel.loadData(dataVersion: 1)
        return (viewModel, context, expense, account, category, subcategory)
    }

    @Test("Registrar un movimiento avanza la generación")
    func newRecord_advancesGeneration() throws {
        let (viewModel, context, _, account, category, subcategory) = try makeLoadedViewModel()
        let before = viewModel.dataGeneration

        _ = makeTestTransaction(
            context: context, amount: 500, account: account, category: category, subcategory: subcategory)
        try context.save()
        viewModel.loadData(dataVersion: 2)

        #expect(viewModel.allTransactions.count == 2)
        #expect(viewModel.dataGeneration != before, "Un alta no llegó al recálculo de Distribución")
    }

    @Test("Editar el importe de un movimiento avanza la generación aunque las filas sean las mismas")
    func amountEdit_advancesGeneration_withTheSameRows() throws {
        let (viewModel, context, expense, _, _, _) = try makeLoadedViewModel()
        let before = viewModel.dataGeneration
        let countBefore = viewModel.allTransactions.count

        expense.amount = -300
        expense.amountInPreferredCurrency = -300
        try context.save()
        viewModel.loadData(dataVersion: 2)

        // Por esto el observador de `allTransactions.count` no se enteraba de una edición.
        #expect(viewModel.allTransactions.count == countBefore)
        #expect(viewModel.dataGeneration != before, "Una edición del importe no llegó al recálculo de Distribución")
    }

    @Test("Una recarga que no trae nada no avanza la generación")
    func reloadWithNothingNew_keepsGeneration() throws {
        let (viewModel, _, _, _, _, _) = try makeLoadedViewModel()
        let before = viewModel.dataGeneration

        // La segunda recarga de un alta (al cerrar la pantalla de éxito) o cerrar el formulario sin guardar: mismo
        // `dataVersion`, mismas filas.
        viewModel.loadData(dataVersion: 1)

        #expect(viewModel.dataGeneration == before, "Distribución recalcularía más veces por gesto que antes")
    }
}
