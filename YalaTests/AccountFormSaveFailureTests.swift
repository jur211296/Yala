//
//  AccountFormSaveFailureTests.swift
//  YalaTests
//
//  Ticket `save-error-alert-lies-when-the-context-autosaves`. «No se pudo guardar» salía con los cambios ya en el contexto
//  compartido. Decisión A de Jürgen (2026-11-05): el aviso dice la verdad —puede verse parte— y el guardado NO se deshace
//  con `rollback()`, porque medido, con un campo de la cuenta cambiado antes de reescribir su saldo inicial, `rollback()`
//  aborta la app dentro de SwiftData (`docs/aprendizajes-tecnicos.md`). Lo tecleado sigue en el formulario y un segundo
//  «Guardar» lo escribe entero, sin duplicar el saldo inicial.
//
//  Fichero propio: `makeTestContext()` reusa el container por `#fileID`.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Un guardado de cuenta que falla dice la verdad y se puede repetir", .serialized)
@MainActor
struct AccountFormSaveFailureTests {

    private struct ForcedSaveFailure: Error {}

    /// Una cuenta «Banco» con su saldo inicial de 500, guardada.
    private func makeEditFixture() throws -> (ModelContext, AccountFormViewModel) {
        let context = try makeTestContext()
        let account = makeTestAccount(context: context, name: "Banco", currencyCode: "PEN")
        let category = makeTestCategory(context: context)
        let sub = makeTestSubcategory(context: context, category: category)
        let opening = makeTestTransaction(
            context: context, amount: 500, date: Date(), account: account, category: category, subcategory: sub)
        opening.balanceAdjustmentType = InitialBalanceService.typeInitialBalance
        try context.save()
        let vm = AccountFormViewModel(accountToEdit: account, existingNames: [])
        vm.setContext(context)
        return (context, vm)
    }

    private func storedOpeningAmounts(_ context: ModelContext) throws -> [Double] {
        try ModelContext(context.container).fetch(FetchDescriptor<TransactionItem>())
            .filter { $0.balanceAdjustmentType == InitialBalanceService.typeInitialBalance }
            .map(\.amount)
    }

    /// Lo escrito se queda en el contexto (no hay `rollback()`): es lo que hace verdad el aviso nuevo.
    @Test func aFailedSave_showsTheErrorAndLeavesTheChangesInTheContext() throws {
        let (context, vm) = try makeEditFixture()
        vm.name = "Banco nuevo"
        vm.persistChanges = { _ in throw ForcedSaveFailure() }

        #expect(vm.saveAccount(context: context) == false)
        #expect(vm.isShowingSaveError)
        #expect(context.hasChanges, "Sin cambios pendientes, algo deshizo el guardado: `rollback()` aborta en este camino.")
    }

    /// El camino que hacía abortar a `rollback()` (cuenta editada + saldo inicial reescrito): falla sin cerrar nada, y el
    /// segundo «Guardar» deja UN saldo inicial con lo tecleado.
    @Test func afterAFailedInitialBalanceChange_theRetryWritesItOnce() throws {
        let (context, vm) = try makeEditFixture()
        vm.name = "Banco nuevo"
        vm.selectedAdjustmentMode = .changeInitialBalance
        vm.adjustmentModeChanged()
        vm.balanceText = "900"
        vm.persistChanges = { _ in throw ForcedSaveFailure() }
        #expect(vm.saveAccount(context: context) == false)
        #expect(vm.isShowingSaveError)

        vm.isShowingSaveError = false
        vm.persistChanges = { try $0.save() }
        #expect(vm.saveAccount(context: context))
        #expect(try storedOpeningAmounts(context).count == 1)
    }

    // MARK: - Cableado

    private static func source(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    @Test func theFormSaysWhatHappened_andSaveAccountNeverRollsBack() throws {
        let view = try Self.source("Yala/App/Views/Accounts/AccountFormView.swift")
        let alert = try #require(view.range(of: "isPresented: $viewModel.isShowingSaveError"))
        let alertBody = view[alert.upperBound...].prefix(400)
        #expect(alertBody.contains("L10n.Account.saveErrorPartial"))
        #expect(!alertBody.contains("L10n.Common.saveError"), "«No se guardó» es falso: parte de lo escrito ya se ve.")

        let vm = try Self.source("Yala/App/ViewModels/Accounts/AccountFormViewModel.swift")
        let start = try #require(vm.range(of: "func saveAccount(context: ModelContext) -> Bool {"))
        let end = try #require(vm.range(of: "var rowsPendingReexpression: [TransactionItem] {", range: start.upperBound..<vm.endIndex))
        #expect(!vm[start.upperBound..<end.lowerBound].contains("rollback()"))
    }
}
