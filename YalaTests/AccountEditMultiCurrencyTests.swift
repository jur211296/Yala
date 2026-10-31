//
//  AccountEditMultiCurrencyTests.swift
//  YalaTests
//
//  S30 (card «editar cuenta de doble línea»): en una cuenta con líneas, Editar cuenta enseña un selector de moneda; cada
//  línea guarda su saldo inicial con el «Guardar» del formulario y se puede eliminar; renombrar la cuenta arrastra el
//  nombre de sus líneas, y una reparación del arranque arregla las que se quedaron con el nombre viejo.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

// MARK: - Lógica pura

@Suite("S30 · nombre de las líneas")
struct AccountLineNameFollowsCardTests {

    @Test func renombrar_arrastraLaLineaConElPrefijoViejo() {
        #expect(AccountCardLogic.renamedLineName(
            current: "BCP Débito Soles · USD", oldCardName: "BCP Débito Soles", newCardName: "BCP Débito",
            currencyCode: "USD", taken: ["BCP Débito"]) == "BCP Débito · USD")
    }

    @Test func renombrar_noTocaUnNombrePersonalizado() {
        #expect(AccountCardLogic.renamedLineName(
            current: "Mis dólares", oldCardName: "Visa", newCardName: "Visa BCP",
            currencyCode: "USD", taken: []) == nil)
        // «Visa Oro · USD» no empieza por «Visa · »: es otra cosa, aunque empiece por «Visa».
        #expect(AccountCardLogic.renamedLineName(
            current: "Visa Oro · USD", oldCardName: "Visa", newCardName: "Visa BCP",
            currencyCode: "USD", taken: []) == nil)
    }

    @Test func renombrar_sinCambioDeNombre_noToca() {
        #expect(AccountCardLogic.renamedLineName(
            current: "Visa · USD", oldCardName: "Visa", newCardName: " Visa ",
            currencyCode: "USD", taken: []) == nil)
    }

    @Test func renombrar_respetaLosNombresUnicos() {
        #expect(AccountCardLogic.renamedLineName(
            current: "Visa · USD", oldCardName: "Visa", newCardName: "Amex",
            currencyCode: "USD", taken: ["amex · usd"]) == "Amex · USD 2")
    }

    @Test func reparar_elCasoReal() {
        #expect(AccountCardLogic.repairedLineName(
            current: "BCP Débito Soles · USD", cardName: "BCP Débito", currencyCode: "USD",
            taken: ["BCP Débito"]) == "BCP Débito · USD")
    }

    @Test func reparar_conNumero_yDivisaEnMinusculas_yAlReves() {
        #expect(AccountCardLogic.repairedLineName(
            current: "Visa Oro · USD 2", cardName: "Visa", currencyCode: "usd", taken: []) == "Visa · USD")
        #expect(AccountCardLogic.repairedLineName(
            current: "BCP · USD", cardName: "BCP Débito", currencyCode: "USD", taken: []) == "BCP Débito · USD",
            "La tarjeta se alargó: también es su nombre de antes.")
    }

    /// Sin relación de prefijo no se sabe si X salió de la tarjeta: la renombrada a mano y la vinculada con su nombre se
    /// quedan como están (review S30).
    @Test func reparar_sinRelacionDePrefijo_noToca() {
        #expect(AccountCardLogic.repairedLineName(
            current: "Viajes · USD", cardName: "BCP", currencyCode: "USD", taken: []) == nil)
        #expect(AccountCardLogic.repairedLineName(
            current: "Interbank · USD", cardName: "BCP", currencyCode: "USD", taken: []) == nil)
        #expect(AccountCardLogic.repairedLineName(
            current: "BCPX · USD", cardName: "BCP", currencyCode: "USD", taken: []) == nil,
            "El prefijo va por palabras, no por letras.")
    }

    @Test func reparar_noTocaLoQueYaCasaNiLoPersonalizado() {
        #expect(AccountCardLogic.repairedLineName(
            current: "BCP Débito · USD", cardName: "BCP Débito", currencyCode: "USD", taken: []) == nil)
        #expect(AccountCardLogic.repairedLineName(
            current: "bcp débito · USD", cardName: "BCP Débito", currencyCode: "USD", taken: []) == nil,
            "Solo cambian mayúsculas: no se reescribe.")
        #expect(AccountCardLogic.repairedLineName(
            current: "BCP Débito · USD 2", cardName: "BCP Débito", currencyCode: "USD", taken: []) == nil,
            "El prefijo ya es el de la tarjeta: el número se queda.")
        #expect(AccountCardLogic.repairedLineName(
            current: "Mis dólares", cardName: "BCP", currencyCode: "USD", taken: []) == nil)
        #expect(AccountCardLogic.repairedLineName(
            current: "Otra · EUR", cardName: "BCP", currencyCode: "USD", taken: []) == nil,
            "La divisa del nombre no es la de la línea: no es el nombre automático.")
        #expect(AccountCardLogic.repairedLineName(
            current: "Otra · USDT", cardName: "BCP", currencyCode: "USD", taken: []) == nil)
        #expect(AccountCardLogic.repairedLineName(
            current: "Otra · USD 1", cardName: "BCP", currencyCode: "USD", taken: []) == nil,
            "El nombre automático numera desde el 2.")
    }

    @Test func prefijoAutomatico_usaElUltimoSeparador() {
        #expect(AccountCardLogic.automaticLinePrefix(of: "A · B · USD", currencyCode: "USD") == "A · B")
        #expect(AccountCardLogic.automaticLinePrefix(of: " · USD", currencyCode: "USD") == nil)
    }
}

// MARK: - SwiftData

@Suite("S30 · editar cuenta con varias divisas", .serialized)
@MainActor
struct AccountEditMultiCurrencyTests {

    private func card(_ context: ModelContext, name: String = "BCP Débito Soles",
                      lineName: String? = nil) throws -> (Account, Account) {
        let principal = makeTestAccount(context: context, name: name, currencyCode: "PEN")
        let line = makeTestAccount(context: context, name: lineName ?? "\(name) · USD", currencyCode: "USD")
        line.parentAccountID = principal.shortcutID
        try context.save()
        return (principal, line)
    }

    private func editor(_ context: ModelContext, _ account: Account) -> AccountFormViewModel {
        let vm = AccountFormViewModel(accountToEdit: account, existingNames: [])
        vm.name = account.name
        vm.setContext(context)
        return vm
    }

    private func initialBalance(of account: Account, _ context: ModelContext) throws -> [Double] {
        try context.fetch(FetchDescriptor<TransactionItem>())
            .filter { $0.account?.persistentModelID == account.persistentModelID
                && $0.balanceAdjustmentType == InitialBalanceService.typeInitialBalance }
            .map(\.amount)
    }

    @Test func selector_soloEnLaPrincipalConLineas() throws {
        let context = try makeTestContext()
        let (principal, line) = try card(context)
        let suelta = makeTestAccount(context: context, name: "Ahorros", currencyCode: "PEN")
        try context.save()

        #expect(editor(context, principal).showsLineCurrencyPicker)
        #expect(!editor(context, line).showsLineCurrencyPicker, "Una línea no enseña el selector.")
        #expect(!editor(context, suelta).showsLineCurrencyPicker, "Sin líneas no hay nada que elegir.")
        #expect(!AccountFormViewModel(accountToEdit: nil, existingNames: []).showsLineCurrencyPicker)
    }

    @Test func cadaLinea_guardaSuSaldoInicial_conElGuardarDelFormulario() throws {
        let context = try makeTestContext()
        let (principal, line) = try card(context)
        let vm = editor(context, principal)
        let draft = try #require(vm.lineDraft(for: line))
        #expect(draft.text.isEmpty && !draft.hasChanges, "Sin saldo inicial, el campo arranca vacío.")
        #expect(!vm.hasUnsavedChanges)

        draft.text = "250"
        draft.isPositive = false
        #expect(vm.hasUnsavedChanges, "Cerrar tiraría el saldo escrito en la línea.")
        #expect(vm.saveAccount(context: context))

        #expect(try initialBalance(of: line, context) == [-250])
        #expect(try initialBalance(of: principal, context).isEmpty, "La principal no recibe el saldo de la línea.")

        // Reabrir: el borrador arranca con lo guardado, y cambiarlo no duplica la fila.
        let reopened = editor(context, principal)
        let again = try #require(reopened.lineDraft(for: line))
        #expect(again.parsedAmount == -250 && !again.isPositive)
        again.text = "100"
        again.isPositive = true
        #expect(reopened.saveAccount(context: context))
        #expect(try initialBalance(of: line, context) == [100])
    }

    @Test func saldoDeLinea_invalido_noDejaGuardar() throws {
        let context = try makeTestContext()
        let (principal, line) = try card(context)
        let vm = editor(context, principal)
        let draft = try #require(vm.lineDraft(for: line))
        draft.text = "abc"
        #expect(!vm.canSave)
    }

    @Test func renombrarLaPrincipal_renombraSusLineas() throws {
        let context = try makeTestContext()
        let (principal, line) = try card(context)
        let personalizada = makeTestAccount(context: context, name: "Mis euros", currencyCode: "EUR")
        personalizada.parentAccountID = principal.shortcutID
        try context.save()

        let vm = editor(context, principal)
        vm.name = "BCP Débito"
        #expect(vm.saveAccount(context: context))

        #expect(principal.name == "BCP Débito")
        #expect(line.name == "BCP Débito · USD")
        #expect(personalizada.name == "Mis euros", "Un nombre elegido a mano no se toca.")
    }

    @Test func renombrarUnaLinea_noTocaNadaMas() throws {
        let context = try makeTestContext()
        let (principal, line) = try card(context)
        let vm = editor(context, line)
        vm.name = "Dólares BCP"
        #expect(vm.saveAccount(context: context))
        #expect(line.name == "Dólares BCP")
        #expect(principal.name == "BCP Débito Soles")
    }

    @Test func reparacion_arreglaLaLineaConElNombreViejo_yEsIdempotente() throws {
        let context = try makeTestContext()
        let (_, line) = try card(context, name: "BCP Débito", lineName: "BCP Débito Soles · USD")
        let (_, buena) = try card(context, name: "Visa")
        let otra = makeTestAccount(context: context, name: "Ahorros · USD", currencyCode: "USD")
        try context.save()

        #expect(try AccountLineService.repairStaleLineNames(in: context) == 1)
        #expect(line.name == "BCP Débito · USD")
        #expect(buena.name == "Visa · USD")
        #expect(otra.name == "Ahorros · USD", "Una cuenta suelta no es una línea: no se toca.")
        #expect(try AccountLineService.repairStaleLineNames(in: context) == 0, "La segunda pasada no escribe nada.")
    }

    @Test func reparacion_conPrincipalAmbigua_noElige() throws {
        let context = try makeTestContext()
        let (principal, line) = try card(context, name: "BCP", lineName: "BCP Viejo · USD")
        let gemela = makeTestAccount(context: context, name: "Otra", currencyCode: "EUR")
        gemela.shortcutID = principal.shortcutID
        try context.save()
        #expect(try AccountLineService.repairStaleLineNames(in: context) == 0)
        #expect(line.name == "BCP Viejo · USD")
    }

    @Test func reparacion_noTocaUnEnlaceRoto() throws {
        let context = try makeTestContext()
        // Misma divisa que la principal: la app la lee como cuenta suelta, así que su nombre es suyo.
        let principal = makeTestAccount(context: context, name: "BCP", currencyCode: "PEN")
        let rota = makeTestAccount(context: context, name: "BCP Viejo · PEN", currencyCode: "PEN")
        rota.parentAccountID = principal.shortcutID
        try context.save()
        #expect(try AccountLineService.repairStaleLineNames(in: context) == 0)
        #expect(rota.name == "BCP Viejo · PEN")
    }

    /// Una línea añadida desde el propio formulario sale en el selector con su borrador: sin él, su segmento enseñaba el
    /// saldo de la principal y lo escrito iba a la cuenta equivocada (review S30).
    @Test func lineaAnadidaDesdeElFormulario_tieneSuBorrador() throws {
        let context = try makeTestContext()
        let principal = makeTestAccount(context: context, name: "BCP", currencyCode: "PEN")
        try context.save()
        let vm = editor(context, principal)
        #expect(!vm.showsLineCurrencyPicker)
        #expect(vm.addLine(currency: .usd, initialBalance: nil))
        let line = try #require(vm.cardLines.first)
        #expect(vm.showsLineCurrencyPicker)
        #expect(vm.lineDraft(for: line) != nil)
    }

    /// Archivar la tarjeta «con sus líneas» guarda antes el saldo escrito en una línea (review S30).
    @Test func archivarConLasLineas_noTiraElSaldoEscrito() throws {
        let context = try makeTestContext()
        let (principal, line) = try card(context)
        let vm = editor(context, principal)
        let draft = try #require(vm.lineDraft(for: line))
        draft.text = "200"
        vm.isArchived = true
        vm.archiveLinesChoice = true
        #expect(vm.saveAccount(context: context))
        #expect(line.isArchived)
        #expect(try initialBalance(of: line, context) == [200])
    }

    @Test func eliminarUnaLinea_vacia_noPregunta_conRegistros_pregunta() throws {
        let context = try makeTestContext()
        let (principal, line) = try card(context)
        let vm = editor(context, principal)
        #expect(try vm.lineRemovalNeedsQuestion(line) == false)

        let tx = TransactionItem(date: .now, amount: -10, currencyCode: "USD", note: "Hotel", account: line)
        context.insert(tx)
        try context.save()
        #expect(try vm.lineRemovalNeedsQuestion(line))
    }

    @Test func trasEliminarUnaLinea_elFormularioVuelveALaCuenta() throws {
        let context = try makeTestContext()
        let (principal, line) = try card(context)
        let vm = editor(context, principal)
        vm.selectedLineID = line.shortcutID
        #expect(vm.selectedLine === line)

        context.delete(line)
        try context.save()
        vm.afterLineRemoved()

        #expect(vm.selectedLineID == nil)
        #expect(vm.lineDrafts.isEmpty)
        #expect(!vm.showsLineCurrencyPicker, "Sin líneas, el selector desaparece y la cuenta sigue con su divisa.")
    }
}
