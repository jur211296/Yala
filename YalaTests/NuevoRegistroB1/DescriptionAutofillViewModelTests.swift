//
//  DescriptionAutofillViewModelTests.swift
//  YalaTests
//
//  Ajuste 4 de Jürgen sobre la hoja B1 (2026-11-20): al elegir una sugerencia de descripción («SmartFit J1»), si los
//  registros anteriores con esa descripción tuvieron la misma cuenta, la misma subcategoría o las mismas etiquetas, se
//  asignan solas; lo que no coincide no se toca y lo elegido a mano no se pisa. Aquí, contra el ViewModel y un store
//  real (la lógica pura está en `NuevoRegistroB1LogicTests`).
//
//  Fichero propio: `makeTestContext()` reusa el container por `#fileID`. `.serialized` por lo mismo.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Nuevo registro B1 · autocompletar al elegir una sugerencia", .serialized)
struct DescriptionAutofillViewModelTests {

    private struct Fixture {
        let context: ModelContext
        let bcp: Account
        let interbank: Account
        let gym: Subcategory
        let food: Subcategory
        let tag: Yala.Tag
    }

    /// Dos «SmartFit J1» con Interbank, Gimnasio y la etiqueta «Salud»; dos «Almuerzo» con cuentas distintas y la misma
    /// subcategoría.
    private func makeFixture() throws -> Fixture {
        let context = try makeTestContext()
        let bcp = makeTestAccount(context: context, name: "BCP")
        let interbank = makeTestAccount(context: context, name: "Interbank")
        let category = makeTestCategory(context: context, name: "Salud y deporte")
        let gym = makeTestSubcategory(context: context, name: "Gimnasio", category: category)
        let foodCategory = makeTestCategory(context: context, name: "Comida")
        let food = makeTestSubcategory(context: context, name: "Restaurantes", category: foodCategory)
        let tag = makeTestTag(context: context, name: "Salud")
        for day in [1, 8] {
            let tx = makeTestTransaction(
                context: context, amount: -120, date: Date(timeIntervalSince1970: 1_790_000_000 + Double(day) * 86_400),
                account: interbank, category: category, subcategory: gym, tags: [tag])
            tx.note = "SmartFit J1"
        }
        let lunchA = makeTestTransaction(context: context, amount: -20, account: bcp, category: foodCategory,
                                         subcategory: food)
        lunchA.note = "Almuerzo"
        let lunchB = makeTestTransaction(context: context, amount: -25, account: interbank, category: foodCategory,
                                         subcategory: food)
        lunchB.note = "Almuerzo"
        try context.save()
        return Fixture(context: context, bcp: bcp, interbank: interbank, gym: gym, food: food, tag: tag)
    }

    /// Un registro nuevo abierto con la cuenta precargada BCP.
    private func openNew(_ fixture: Fixture) -> NewTransactionViewModel {
        let vm = NewTransactionViewModel()
        vm.setContext(fixture.context)
        vm.transactionType = .expense
        vm.selectedAccount = fixture.bcp
        return vm
    }

    @Test func todoCoincide_ponenCuentaSubcategoriaYEtiqueta() throws {
        let fixture = try makeFixture()
        let vm = openNew(fixture)
        vm.applyDescriptionSuggestion("SmartFit J1", baselineAccount: fixture.bcp.persistentModelID, autofills: true)
        #expect(vm.note == "SmartFit J1")
        #expect(vm.selectedAccount?.persistentModelID == fixture.interbank.persistentModelID)
        #expect(vm.selectedSubcategory?.persistentModelID == fixture.gym.persistentModelID)
        #expect(vm.selectedTags.map(\.id) == [fixture.tag.id])
    }

    @Test func cuentasDistintas_laCuentaSeQueda_yLaSubcategoriaSePone() throws {
        let fixture = try makeFixture()
        let vm = openNew(fixture)
        vm.applyDescriptionSuggestion("Almuerzo", baselineAccount: fixture.bcp.persistentModelID, autofills: true)
        #expect(vm.selectedAccount?.persistentModelID == fixture.bcp.persistentModelID)
        #expect(vm.selectedSubcategory?.persistentModelID == fixture.food.persistentModelID)
        #expect(vm.selectedTags.isEmpty)
    }

    @Test func cuentaElegidaAMano_noSePisa() throws {
        let fixture = try makeFixture()
        let vm = openNew(fixture)
        let other = makeTestAccount(context: fixture.context, name: "Scotiabank")
        try fixture.context.save()
        vm.loadData()
        vm.selectedAccount = vm.accounts.first { $0.persistentModelID == other.persistentModelID }
        vm.applyDescriptionSuggestion("SmartFit J1", baselineAccount: fixture.bcp.persistentModelID, autofills: true)
        #expect(vm.selectedAccount?.persistentModelID == other.persistentModelID)
        #expect(vm.selectedSubcategory?.persistentModelID == fixture.gym.persistentModelID)
    }

    @Test func subcategoriaYaPuesta_noSePisa() throws {
        let fixture = try makeFixture()
        let vm = openNew(fixture)
        vm.selectedSubcategory = fixture.food
        vm.applyDescriptionSuggestion("SmartFit J1", baselineAccount: fixture.bcp.persistentModelID, autofills: true)
        #expect(vm.selectedSubcategory?.persistentModelID == fixture.food.persistentModelID)
        #expect(vm.selectedAccount?.persistentModelID == fixture.interbank.persistentModelID)
    }

    @Test func etiquetasYaPuestas_noSePisan() throws {
        let fixture = try makeFixture()
        let vm = openNew(fixture)
        let other = makeTestTag(context: fixture.context, name: "Trabajo")
        try fixture.context.save()
        vm.loadData()
        vm.selectedTags = vm.tags.filter { $0.id == other.id }
        vm.applyDescriptionSuggestion("SmartFit J1", baselineAccount: fixture.bcp.persistentModelID, autofills: true)
        #expect(vm.selectedTags.map(\.id) == [other.id])
    }

    @Test func sinAutocompletar_soloElNombre() throws {
        let fixture = try makeFixture()
        let vm = openNew(fixture)
        vm.applyDescriptionSuggestion("SmartFit J1", baselineAccount: fixture.bcp.persistentModelID, autofills: false)
        #expect(vm.note == "SmartFit J1")
        #expect(vm.selectedAccount?.persistentModelID == fixture.bcp.persistentModelID)
        #expect(vm.selectedSubcategory == nil)
        #expect(vm.selectedTags.isEmpty)
    }

    @Test func enUnIngreso_noUsaLosGastos() throws {
        let fixture = try makeFixture()
        let vm = openNew(fixture)
        vm.transactionType = .income
        vm.applyDescriptionSuggestion("SmartFit J1", baselineAccount: fixture.bcp.persistentModelID, autofills: true)
        #expect(vm.selectedAccount?.persistentModelID == fixture.bcp.persistentModelID)
        #expect(vm.selectedSubcategory == nil)
    }
}
