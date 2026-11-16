//
//  PanelMoneyScopeLogicTests.swift
//  YalaTests
//
//  Qué cuentas suman en «Tu dinero hoy» y cómo se guarda el ajuste (encargo del 2026-11-16): valores por defecto por tipo
//  de cuenta, la preferencia sincronizada «id:1,id:0» con solo lo que la persona cambió, el interruptor del formulario de
//  la cuenta y que la preferencia viaje por el canal de siempre, sin campo nuevo en ningún esquema.
//

import Foundation
import Testing

@testable import Yala

@MainActor
@Suite("Panel · qué cuentas suman en «Tu dinero hoy»")
struct PanelMoneyScopeLogicTests {

    private func account(_ type: AccountType, archived: Bool = false) -> Account {
        Account(
            name: type.rawValue, currencyCode: "PEN", colorHex: "#000", iconName: "creditcard",
            type: type.rawValue, isArchived: archived
        )
    }

    // MARK: - Valores por defecto por tipo

    @Test("Por defecto suman corriente, ahorro, efectivo y general; la tarjeta de crédito no")
    func defaultsByType() {
        #expect(PanelMoneyScopeLogic.countsByDefault(type: .checking))
        #expect(PanelMoneyScopeLogic.countsByDefault(type: .savings))
        #expect(PanelMoneyScopeLogic.countsByDefault(type: .cash))
        #expect(PanelMoneyScopeLogic.countsByDefault(type: .general))
        #expect(!PanelMoneyScopeLogic.countsByDefault(type: .creditCard))
        // Cada tipo de Yala tiene su valor: un tipo nuevo obliga a decidirlo aquí (el `switch` no tiene `default`).
        #expect(AccountType.allCases.count == 5)
    }

    @Test("Un tipo guardado que la app no conoce se lee «General» y suma")
    func unknownTypeCounts() {
        let legacy = Account(name: "Vieja", currencyCode: "PEN", colorHex: "#000", iconName: "x", type: "checking")
        #expect(PanelMoneyScopeLogic.accountType(legacy) == .general)
        #expect(PanelMoneyScopeLogic.counts(legacy, among: [legacy], overrides: [:]))
    }

    // MARK: - La preferencia

    @Test("La preferencia guarda solo lo que la persona cambió, en un orden fijo")
    func preferenceKeepsOnlyChanges() throws {
        let a = try #require(UUID(uuidString: "00000000-0000-0000-0000-00000000000A"))
        let b = try #require(UUID(uuidString: "00000000-0000-0000-0000-00000000000B"))

        // Apagar una cuenta de ahorro sí se guarda.
        var stored = PanelMoneyScopeLogic.setting(false, for: b, type: .savings, in: "")
        // Encender una tarjeta también.
        stored = PanelMoneyScopeLogic.setting(true, for: a, type: .creditCard, in: stored)
        #expect(stored == "\(a.uuidString):1,\(b.uuidString):0")
        #expect(PanelMoneyScopeLogic.decode(stored) == [a: true, b: false])

        // Volver al valor del tipo quita la entrada.
        stored = PanelMoneyScopeLogic.setting(true, for: b, type: .savings, in: stored)
        #expect(stored == "\(a.uuidString):1")
        stored = PanelMoneyScopeLogic.setting(false, for: a, type: .creditCard, in: stored)
        #expect(stored.isEmpty)
    }

    @Test("Una entrada que no se entiende se ignora: la cuenta vuelve al valor de su tipo")
    func garbageIsIgnored() throws {
        let a = try #require(UUID(uuidString: "00000000-0000-0000-0000-00000000000A"))
        let decoded = PanelMoneyScopeLogic.decode("no-es-un-id:1,\(a.uuidString):1,\(a.uuidString)x:0,:,,\(a.uuidString):sí")
        #expect(decoded == [a: true])
        #expect(PanelMoneyScopeLogic.decode("").isEmpty)
    }

    @Test("La preferencia viaja por el canal de preferencias de siempre: string donde «» vale (sin campo en ningún esquema)")
    func preferenceTravelsAsASyncedString() {
        #expect(PrefSyncKey.panelMoneyAccountOverrides.rawValue == AppPreferences.Keys.panelMoneyAccountOverrides)
        #expect(PrefSyncKey.panelMoneyAccountOverrides.family == .panelPresenceEmptyValid)
        // Volver a «nada cambiado» en otro teléfono tiene que llegar aquí: «» se aplica, no se salta.
        let decision = PreferenceMergeLogic.decide(key: .panelMoneyAccountOverrides, remote: .string(""), local: .string("x:1"))
        #expect(decision.write == .set(.string("")))
    }

    @Test("Un almacén aislado guarda la preferencia y la relee")
    func appPreferencesPersistsIt() {
        let defaults = makeIsolatedDefaults(prefix: "saldo.panel.money")
        let prefs = AppPreferences(defaults: defaults)
        #expect(prefs.panelMoneyAccountOverrides.isEmpty)
        prefs.panelMoneyAccountOverrides = "00000000-0000-0000-0000-00000000000A:1"
        #expect(defaults.string(forKey: AppPreferences.Keys.panelMoneyAccountOverrides) == "00000000-0000-0000-0000-00000000000A:1")
        let reread = AppPreferences(defaults: defaults)
        #expect(reread.panelMoneyAccountOverrides == "00000000-0000-0000-0000-00000000000A:1")
    }

    @Test("Borrar los datos de la persona borra también qué cuentas suman")
    func wipeRemovesIt() {
        let defaults = makeIsolatedDefaults(prefix: "saldo.panel.wipe")
        defaults.set("x:1", forKey: AppPreferences.Keys.panelMoneyAccountOverrides)
        DataWipeService.removeUserPreferenceKeys(from: defaults)
        #expect(defaults.object(forKey: AppPreferences.Keys.panelMoneyAccountOverrides) == nil)
    }

    // MARK: - Las cuentas con interruptor

    @Test("La lista enseña las cuentas que suman en un saldo, sin archivadas ni líneas de tarjeta")
    func switchableAccounts() {
        let savings = account(.savings)
        let archived = account(.checking, archived: true)
        let card = account(.creditCard)
        let line = account(.creditCard)
        line.parentAccountID = card.shortcutID
        let orphanLine = account(.creditCard)
        orphanLine.parentAccountID = UUID()

        let shown = PanelMoneyScopeLogic.switchableAccounts([savings, archived, card, line, orphanLine])
        #expect(shown.count == 3)
        #expect(shown.contains { $0 === savings })
        #expect(shown.contains { $0 === card })
        // Una línea con el enlace roto se lee suelta: tiene su propio interruptor.
        #expect(shown.contains { $0 === orphanLine })
    }

    // MARK: - El interruptor del formulario

    @Test("El formulario abre con lo guardado o con el valor del tipo")
    func formInitialValue() {
        let id = UUID()
        #expect(AccountMoneyToggleLogic.initialValue(shortcutID: id, type: .creditCard, overrides: [:]) == false)
        #expect(AccountMoneyToggleLogic.initialValue(shortcutID: id, type: .creditCard, overrides: [id: true]) == true)
        #expect(AccountMoneyToggleLogic.initialValue(shortcutID: nil, type: .savings, overrides: [id: false]) == true)
    }

    @Test("Al cambiar el tipo el interruptor lo sigue, salvo que la persona ya lo tocara")
    func formFollowsType() {
        #expect(AccountMoneyToggleLogic.valueAfterTypeChange(current: true, wasChosen: false, newType: .creditCard) == false)
        #expect(AccountMoneyToggleLogic.valueAfterTypeChange(current: false, wasChosen: false, newType: .cash) == true)
        #expect(AccountMoneyToggleLogic.valueAfterTypeChange(current: true, wasChosen: true, newType: .creditCard) == true)
    }

    @Test("El interruptor solo sale si la cuenta suma en un saldo y tiene su propio ajuste")
    func formShowsToggle() {
        #expect(AccountMoneyToggleLogic.showsToggle(isArchived: false, excludeFromStatistics: false, ownsCardSettings: true))
        #expect(!AccountMoneyToggleLogic.showsToggle(isArchived: true, excludeFromStatistics: false, ownsCardSettings: true))
        #expect(!AccountMoneyToggleLogic.showsToggle(isArchived: false, excludeFromStatistics: true, ownsCardSettings: true))
        #expect(!AccountMoneyToggleLogic.showsToggle(isArchived: false, excludeFromStatistics: false, ownsCardSettings: false))
    }

    @Test("El ViewModel del formulario: una tarjeta nueva abre apagada, guardar escribe solo si difiere del tipo")
    func formViewModel() {
        let viewModel = AccountFormViewModel(accountToEdit: nil, existingNames: [])
        viewModel.selectedType = .creditCard
        viewModel.loadCountsInMoney(overrides: [:])
        #expect(viewModel.countsInMoney == false)
        #expect(!viewModel.countsInMoneyWasChosen, "Cargar no cuenta como elegir.")

        // Cambiar a ahorro sin tocarlo lo enciende.
        viewModel.selectedType = .savings
        viewModel.followTypeForCountsInMoney()
        #expect(viewModel.countsInMoney == true)

        let saved = account(.savings)
        #expect(viewModel.moneyOverridesAfterSave(for: saved, stored: "") == "", "Igual al tipo: no se guarda nada.")
        viewModel.countsInMoney = false
        #expect(viewModel.countsInMoneyWasChosen)
        #expect(viewModel.moneyOverridesAfterSave(for: saved, stored: "") == "\(saved.shortcutID.uuidString):0")

        // Cargar otra vez (el `onAppear` al volver de «Moneda») no pisa lo elegido.
        viewModel.loadCountsInMoney(overrides: [:])
        #expect(viewModel.countsInMoney == false, "Volver de una pantalla del formulario borró lo elegido.")

        // Archivada, el interruptor no se enseña y guardar no toca la preferencia.
        viewModel.isArchived = true
        #expect(viewModel.moneyOverridesAfterSave(for: saved, stored: "z") == "z")
    }

    @Test("Una exclusión guardada no se pierde al cambiar el tipo de la cuenta")
    func savedChoiceSurvivesATypeChange() {
        let saved = account(.savings)
        let viewModel = AccountFormViewModel(accountToEdit: saved, existingNames: [])
        viewModel.loadCountsInMoney(overrides: [saved.shortcutID: false])
        #expect(viewModel.countsInMoney == false)
        #expect(viewModel.countsInMoneyWasChosen, "Lo guardado cuenta como elegido.")
        viewModel.selectedType = .checking
        viewModel.followTypeForCountsInMoney()
        #expect(viewModel.countsInMoney == false, "Cambiar el tipo devolvió la cuenta a «Tu dinero hoy».")
        #expect(viewModel.moneyOverridesAfterSave(for: saved, stored: "\(saved.shortcutID.uuidString):0")
                == "\(saved.shortcutID.uuidString):0")
    }
}
