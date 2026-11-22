//
//  CuentaSolaReglasFormularioTests.swift
//  YalaTests
//
//  Reglas de captura (parte 2), hallazgo del revisor del 22-nov: guardar Editar cuenta sin tocar las reglas no puede
//  reescribir el campo. Volver a codificar lo leído pierde lo que esta versión no entiende de una regla (un campo de una
//  versión futura) y lo sube con un reloj nuevo a todos los aparatos.
//
//  Fichero propio: `makeTestContext()` reusa el container por `#fileID`. Guardar la cuenta pide una foto de los widgets
//  (`WidgetDataCache.updateCache`); cada caso la retira al acabar, o la foto pedida corre durante la suite siguiente
//  (medido el 22-nov: `FotoWidgetPorEtapasTests` caía 3 de 3 detrás de esta suite).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Editar cuenta no reescribe las reglas que no se tocaron", .serialized)
@MainActor
struct CuentaSolaReglasFormularioTests {

    /// Una regla de texto con un campo que esta versión no conoce (`futuro`).
    private static let rawConCampoFuturo =
        #"[{"createdAt":"2026-11-20T00:00:00Z","futuro":"x","id":"6F1C2D3E-4A5B-4C6D-8E7F-901234567890","kind":"text","mode":"allWords","value":"zip"}]"#

    private func makeFixture() throws -> (ModelContext, Account, AccountFormViewModel) {
        let context = try makeTestContext()
        let account = makeTestAccount(context: context, name: "Zip Visa", currencyCode: "PEN")
        account.captureRulesRaw = Self.rawConCampoFuturo
        try context.save()
        let vm = AccountFormViewModel(accountToEdit: account, existingNames: [])
        vm.setContext(context)
        return (context, account, vm)
    }

    @Test func cambiarSoloElNombre_dejaLasReglasComoEstaban() throws {
        let (context, account, vm) = try makeFixture()
        defer { WidgetDataCache.cancelPendingUpdate() }
        #expect(vm.captureRules.map(\.value) == ["zip"], "Control: la regla se lee aunque traiga un campo de más.")

        vm.name = "Zip Visa oro"
        #expect(vm.saveAccount(context: context))

        #expect(account.name == "Zip Visa oro")
        #expect(account.captureRulesRaw == Self.rawConCampoFuturo)
    }

    @Test func tocarLasReglas_siLasEscribe() throws {
        let (context, account, vm) = try makeFixture()
        defer { WidgetDataCache.cancelPendingUpdate() }

        vm.captureRules.append(AccountCaptureRule(kind: .merchant, value: "Wong"))
        #expect(vm.saveAccount(context: context))

        let guardadas = AccountCaptureRule.decode(account.captureRulesRaw).map(\.value)
        #expect(guardadas == ["zip", "Wong"])
    }
}
