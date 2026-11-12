//
//  AccountLineOfferAfterCreateTests.swift
//  YalaTests
//
//  S12j (Jürgen, 2026-10-27): al terminar de crear una cuenta, la hoja ofrece añadirle una línea en otra divisa. Solo al
//  CREAR (editar no pregunta) y solo si la cuenta nueva puede tener líneas. Lo que decide es el ViewModel
//  (`createdAccount` + `offersLineAfterCreate`); la vista solo cambia de fase.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite(.serialized)
@MainActor
struct AccountLineOfferAfterCreateTests {

    private func newAccountViewModel(_ context: ModelContext, name: String, archived: Bool = false) -> AccountFormViewModel {
        let vm = AccountFormViewModel(accountToEdit: nil, existingNames: [])
        vm.setContext(context)
        vm.name = name
        vm.balanceText = "100"
        vm.isArchived = archived
        return vm
    }

    @Test func crear_ofreceOtraDivisa_sobreLaCuentaRecienCreada() throws {
        let context = try makeTestContext()
        let vm = newAccountViewModel(context, name: "Sueldo")
        #expect(vm.offersLineAfterCreate == false, "Antes de guardar no hay nada que ofrecer.")

        #expect(vm.saveAccount(context: context))

        let created = try #require(vm.createdAccount)
        #expect(created.name == "Sueldo")
        #expect(vm.offersLineAfterCreate)
        // La hoja de «Añadir línea» trabaja sobre esa cuenta: sus divisas son todas menos la de la cuenta.
        let lineVM = AccountFormViewModel(accountToEdit: created, existingNames: [])
        lineVM.setContext(context)
        #expect(lineVM.canManageLines)
        #expect(!lineVM.addableLineCurrencies.isEmpty)
        #expect(!lineVM.addableLineCurrencies.map(\.rawValue).contains(normalizeCurrencyCode(created.currencyCode)))
    }

    @Test func editar_noPregunta() throws {
        let context = try makeTestContext()
        let account = makeTestAccount(context: context, name: "Ahorros", currencyCode: "PEN")
        try context.save()
        let vm = AccountFormViewModel(accountToEdit: account, existingNames: [])
        vm.name = "Ahorros"
        vm.setContext(context)

        #expect(vm.saveAccount(context: context))

        #expect(vm.createdAccount == nil)
        #expect(vm.offersLineAfterCreate == false)
    }

    /// Una cuenta creada ya archivada no admite líneas (`AccountCardLogic.canHaveLines`): no se ofrece nada.
    @Test func crearArchivada_noPregunta() throws {
        let context = try makeTestContext()
        let vm = newAccountViewModel(context, name: "Vieja", archived: true)

        #expect(vm.saveAccount(context: context))

        #expect(vm.createdAccount != nil)
        #expect(vm.offersLineAfterCreate == false)
    }

    /// Un guardado que no pasa (sin saldo inicial) no deja cuenta creada ni pregunta.
    @Test func guardadoFallido_noPregunta() throws {
        let context = try makeTestContext()
        let vm = newAccountViewModel(context, name: "Sin saldo")
        vm.balanceText = ""

        #expect(vm.saveAccount(context: context) == false)

        #expect(vm.createdAccount == nil)
        #expect(vm.offersLineAfterCreate == false)
    }
}
