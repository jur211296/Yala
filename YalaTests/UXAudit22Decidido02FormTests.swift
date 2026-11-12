//
//  UXAudit22Decidido02FormTests.swift
//  YalaTests
//
//  El formulario de registro del lote decidido 2.2 · 02 (sesión A) sobre SwiftData: lo que falta para guardar (L2-2), la
//  foto que decide si cerrar pregunta (L2-4), el «Deshacer» del aviso (L2-5), el destino de una transferencia (L2-1), y
//  la divisa del importe en favoritos, pagos planificados y copias (card 4k2q).
//
//  Fichero propio con UNA suite: `makeTestContext()` reusa el container por `#fileID`.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Lote decidido 2.2 · 02 · formulario", .serialized)
struct UXAudit22Decidido02FormTests {

    private struct Fixture {
        let context: ModelContext
        let soles: Account
        let dollars: Account
        let category: YalaCategory
        let subcategory: Subcategory
    }

    private func makeFixture() throws -> Fixture {
        let context = try makeTestContext()
        let soles = makeTestAccount(context: context, name: "Soles", currencyCode: "PEN")
        let dollars = makeTestAccount(context: context, name: "Dólares", currencyCode: "USD")
        let category = makeTestCategory(context: context)
        let subcategory = makeTestSubcategory(context: context, category: category)
        try context.save()
        return Fixture(context: context, soles: soles, dollars: dollars, category: category, subcategory: subcategory)
    }

    private func newForm(_ fixture: Fixture) -> NewTransactionViewModel {
        let vm = NewTransactionViewModel()
        vm.setContext(fixture.context)
        return vm
    }

    // MARK: - L2-2 · Lo que falta

    @Test func reciénAbierto_faltanMontoCuentaYCategoria_sinBordes() throws {
        let fixture = try makeFixture()
        let vm = newForm(fixture)
        #expect(vm.missingFieldsForSave == [.amount, .account, .category])
        #expect(vm.saveBlockedMessage == L10n.UXL2.missingToSave(
            [L10n.UXL2.missingAmount, L10n.UXL2.missingAccount, L10n.UXL2.missingCategory]
                .formatted(.list(type: .and).locale(AppLocale.current))))
        // Sin monto, ningún chip se marca: el formulario recién abierto no se llena de bordes.
        #expect(!vm.marksMissing(.account))
        #expect(!vm.marksMissing(.category))
    }

    @Test func conMontoYCuenta_faltaSoloLaCategoria_ySuChipSeMarca() throws {
        let fixture = try makeFixture()
        let vm = newForm(fixture)
        vm.amountString = "12"
        vm.selectedAccount = fixture.soles
        #expect(vm.missingFieldsForSave == [.category])
        #expect(vm.saveBlockedMessage == L10n.UXL2.missingToSave(L10n.UXL2.missingCategory))
        #expect(vm.marksMissing(.category))
        #expect(!vm.marksMissing(.account))
    }

    @Test func completo_sinLinea() throws {
        let fixture = try makeFixture()
        let vm = newForm(fixture)
        vm.amountString = "12"
        vm.selectedAccount = fixture.soles
        vm.selectedSubcategory = fixture.subcategory
        #expect(vm.canSave)
        #expect(vm.saveBlockedMessage == nil)
    }

    @Test func transferencia_faltaElDestino() throws {
        let fixture = try makeFixture()
        let vm = newForm(fixture)
        vm.transactionType = .transfer
        vm.amountString = "50"
        vm.sourceAccount = fixture.soles
        #expect(vm.missingFieldsForSave == [.destinationAccount])
        #expect(vm.saveBlockedMessage == L10n.UXL2.missingToSave(L10n.UXL2.missingDestinationAccount))
        #expect(vm.marksMissing(.destinationAccount))
    }

    @Test func transferencia_mismaCuenta_eligeDosDistintas() throws {
        let fixture = try makeFixture()
        let vm = newForm(fixture)
        vm.transactionType = .transfer
        vm.amountString = "50"
        vm.sourceAccount = fixture.soles
        vm.destinationAccount = fixture.soles
        #expect(vm.saveBlockedMessage == L10n.UXL2.chooseTwoDifferentAccounts)
    }

    // MARK: - L2-1 · Transferencia

    @Test func pasarATransferencia_conDosCuentas_elDestinoEsLaOtra() throws {
        let fixture = try makeFixture()
        let vm = newForm(fixture)
        vm.selectedAccount = fixture.soles
        vm.transactionType = .transfer
        vm.prepareForTransfer(allAccounts: vm.accounts)
        #expect(vm.sourceAccount?.persistentModelID == fixture.soles.persistentModelID)
        #expect(vm.destinationAccount?.persistentModelID == fixture.dollars.persistentModelID)
    }

    @Test func pasarATransferencia_conTresCuentas_destinoVacio() throws {
        let fixture = try makeFixture()
        _ = makeTestAccount(context: fixture.context, name: "Tercera", currencyCode: "PEN")
        try fixture.context.save()
        let vm = newForm(fixture)
        vm.selectedAccount = fixture.soles
        vm.transactionType = .transfer
        vm.prepareForTransfer(allAccounts: vm.accounts)
        #expect(vm.destinationAccount == nil)
    }

    @Test func laRegla_conLaUltimaUsada_laPrecarga() throws {
        let fixture = try makeFixture()
        let vm = newForm(fixture)
        vm.lastUsedAccountShortcutID = fixture.dollars.shortcutID.uuidString
        vm.applyAccountPrefillRule()
        #expect(vm.selectedAccount?.persistentModelID == fixture.dollars.persistentModelID)
        #expect(vm.currencyCode == "USD")
    }

    // MARK: - L2-4 · ¿Hay algo escrito?

    @Test func laFoto_noCambiaPorLoQueRellenaElFormularioSolo() throws {
        let fixture = try makeFixture()
        let vm = newForm(fixture)
        vm.selectedAccount = fixture.soles
        vm.selectedSubcategory = fixture.subcategory
        let baseline = vm.formSnapshot
        // El `onChange` de la subcategoría pone su naturaleza después de abrir: no es un cambio de la persona.
        vm.selectedNeed = fixture.subcategory.need
        // El foco en el monto borra «0.00».
        vm.amountString = ""
        #expect(vm.formSnapshot == baseline)
    }

    @Test func laFoto_cambiaConMontoDescripcionOCuenta() throws {
        let fixture = try makeFixture()
        let vm = newForm(fixture)
        let baseline = vm.formSnapshot
        vm.amountString = "5"
        #expect(vm.formSnapshot != baseline)
        vm.amountString = "0"
        vm.note = "Café"
        #expect(vm.formSnapshot != baseline)
        vm.note = ""
        vm.selectedAccount = fixture.soles
        #expect(vm.formSnapshot != baseline)
    }

    // MARK: - L2-5 · Deshacer

    @Test func deshacer_borraElRegistro() throws {
        let fixture = try makeFixture()
        let vm = newForm(fixture)
        vm.amountString = "12"
        vm.selectedAccount = fixture.soles
        vm.selectedSubcategory = fixture.subcategory
        let saved = try #require(vm.save(context: fixture.context))
        #expect(try fixture.context.fetchCount(FetchDescriptor<TransactionItem>()) == 1)

        SavedRecordUndo.undo(recordIDs: saved.map(\.persistentModelID), scheduledPaymentID: nil, context: fixture.context)

        #expect(try fixture.context.fetchCount(FetchDescriptor<TransactionItem>()) == 0)
    }

    @Test func deshacer_unaTransferencia_seLlevaLasDosPatas() throws {
        let fixture = try makeFixture()
        let vm = newForm(fixture)
        vm.transactionType = .transfer
        vm.amountString = "50"
        vm.sourceAccount = fixture.soles
        vm.destinationAccount = fixture.dollars
        vm.destinationAmount = 13
        let saved = try #require(vm.save(context: fixture.context))
        #expect(try fixture.context.fetchCount(FetchDescriptor<TransactionItem>()) == 2)

        // Solo con la primera pata: la pareja se va con ella.
        SavedRecordUndo.undo(recordIDs: [saved[0].persistentModelID], scheduledPaymentID: nil, context: fixture.context)

        #expect(try fixture.context.fetchCount(FetchDescriptor<TransactionItem>()) == 0)
    }

    @Test func deshacer_unRecurrente_seLlevaTambienElPago() throws {
        let fixture = try makeFixture()
        let editor = ScheduledPaymentEditorViewModel()
        EntityDeletionService.shared.setContext(fixture.context)
        editor.setContext(fixture.context, deletionService: EntityDeletionService.shared)
        let paymentID = try #require(editor.savePayment(
            existing: nil, name: "Gym", amount: 120, note: "", currencyCode: "PEN", transactionType: "expense",
            paymentCategory: .recurring, account: fixture.soles, subcategory: fixture.subcategory, selectedTags: [],
            isRecurring: true, recurrenceType: .monthly, recurrenceInterval: 1,
            paymentDate: Calendar.current.startOfDay(for: .now), dayOfMonth: 13, selectedWeekdays: [3],
            yearlyMonth: 10, yearlyDay: 13, endDate: nil, notifyOnDueDate: true, notifyDaysBefore: 0, isActive: true))
        let vm = newForm(fixture)
        vm.amountString = "120"
        vm.selectedAccount = fixture.soles
        vm.selectedSubcategory = fixture.subcategory
        let saved = try #require(vm.save(context: fixture.context))
        saved.first?.scheduledPaymentID = paymentID.uuidString
        try fixture.context.save()

        SavedRecordUndo.undo(
            recordIDs: saved.map(\.persistentModelID), scheduledPaymentID: paymentID, context: fixture.context)

        #expect(try fixture.context.fetchCount(FetchDescriptor<TransactionItem>()) == 0)
        #expect(try fixture.context.fetchCount(FetchDescriptor<ScheduledPayment>()) == 0)
    }

    // MARK: - Card 4k2q · la divisa del importe

    /// 50 USD apuntados en una cuenta en soles, abiertos para editar como lo hace `prefillFromContext`.
    private func dollarsInSoles(_ fixture: Fixture) throws -> NewTransactionViewModel {
        let tx = makeTestTransaction(
            context: fixture.context, amount: -50, account: fixture.soles, category: fixture.category,
            subcategory: fixture.subcategory, currencyCode: "USD")
        try fixture.context.save()
        let vm = newForm(fixture)
        vm.editingTransaction = tx
        vm.amountString = "50"
        vm.selectedAccount = fixture.soles
        vm.sourceAccount = fixture.soles
        vm.currencyCode = "USD"
        vm.selectedSubcategory = fixture.subcategory
        return vm
    }

    @Test func favoritoDesdeUnGastoEnDolares_guardaDolares() throws {
        let fixture = try makeFixture()
        let vm = try dollarsInSoles(fixture)
        // Lo que `favoriteSheetContent` pasa a la hoja.
        #expect(vm.amountCurrencyCode == "USD")

        let favorites = SaveAsFavoriteViewModel()
        favorites.setContext(fixture.context)
        try favorites.saveFavorite(
            name: "Netflix", transactionType: .expense, amount: 50, note: nil, account: fixture.soles,
            subcategory: fixture.subcategory, selectedTagIDs: [], needOverride: nil, currencyCode: vm.amountCurrencyCode)
        let favorite = try #require(try fixture.context.fetch(FetchDescriptor<FavoritePayment>()).first)
        #expect(favorite.currencyCode == "USD")
        #expect(favorite.amount == 50)
    }

    @Test func usarUnFavoritoEnDolares_enUnaCuentaEnSoles_conservaDolares() throws {
        let fixture = try makeFixture()
        let vm = newForm(fixture)
        vm.amountString = "50"
        vm.selectedAccount = fixture.soles
        vm.selectedSubcategory = fixture.subcategory
        vm.keepAmountCurrency("USD", for: fixture.soles)
        #expect(vm.amountCurrencyCode == "USD")

        let saved = try #require(vm.save(context: fixture.context))
        #expect(normalizeCurrencyCode(saved[0].currencyCode) == "USD")
        #expect(saved[0].amount == -50)

        // Elegir otra cuenta la descarta: manda la cuenta, como al editar.
        let other = newForm(fixture)
        other.selectedAccount = fixture.soles
        other.keepAmountCurrency("USD", for: fixture.soles)
        other.selectedAccount = fixture.dollars
        #expect(other.amountCurrencyCode == "USD")
        other.selectedAccount = makeTestAccount(context: fixture.context, name: "Otra", currencyCode: "PEN")
        #expect(other.amountCurrencyCode == "PEN")
    }

    @Test func laMismaDivisaQueLaCuenta_noSeFija() throws {
        let fixture = try makeFixture()
        let vm = newForm(fixture)
        vm.keepAmountCurrency("PEN", for: fixture.soles)
        #expect(vm.amountCurrencyOverride == nil)
    }

    @Test func pagoPlanificadoDesdeUnGastoEnDolares_guardaDolares() throws {
        let fixture = try makeFixture()
        let vm = try dollarsInSoles(fixture)
        let editor = ScheduledPaymentEditorViewModel()
        EntityDeletionService.shared.setContext(fixture.context)
        editor.setContext(fixture.context, deletionService: EntityDeletionService.shared)
        // Lo que `createRecurringPayment` pasa al guardar desde la hoja corta.
        let paymentID = try #require(editor.savePayment(
            existing: nil, name: "Netflix", amount: vm.amount, note: "", currencyCode: vm.amountCurrencyCode,
            transactionType: "expense", paymentCategory: .recurring, account: fixture.soles,
            subcategory: fixture.subcategory, selectedTags: [], isRecurring: true, recurrenceType: .monthly,
            recurrenceInterval: 1, paymentDate: Calendar.current.startOfDay(for: .now), dayOfMonth: 1,
            selectedWeekdays: [2], yearlyMonth: 1, yearlyDay: 1, endDate: nil, notifyOnDueDate: true,
            notifyDaysBefore: 0, isActive: true))
        let payment = try #require(try fixture.context.fetch(FetchDescriptor<ScheduledPayment>())
            .first { $0.id == paymentID })
        #expect(payment.currencyCode == "USD")
        #expect(payment.amount == 50)
    }

    // MARK: - L2-14 · favorito de transferencia

    @Test func favoritoDeTransferencia_guardaOrigenYDestino() throws {
        let fixture = try makeFixture()
        let favorites = SaveAsFavoriteViewModel()
        favorites.setContext(fixture.context)
        try favorites.saveFavorite(
            name: "Ahorro", transactionType: .transfer, amount: 200, note: nil, account: fixture.soles,
            destinationAccount: fixture.dollars, subcategory: nil, selectedTagIDs: [], needOverride: nil,
            currencyCode: "PEN")
        let favorite = try #require(try fixture.context.fetch(FetchDescriptor<FavoritePayment>()).first)
        #expect(favorite.type == .transfer)
        #expect(favorite.account?.persistentModelID == fixture.soles.persistentModelID)
        #expect(favorite.destinationAccount?.persistentModelID == fixture.dollars.persistentModelID)
        #expect(fixture.dollars.destinationFavoritePayments?.count == 1)
    }

    @Test func borrarLaCuentaDestino_dejaElFavoritoSinDestino() throws {
        let fixture = try makeFixture()
        let favorite = FavoritePayment(
            name: "Ahorro", transactionType: "transfer", amount: 200, account: fixture.soles,
            destinationAccount: fixture.dollars)
        fixture.context.insert(favorite)
        try fixture.context.save()

        fixture.context.delete(fixture.dollars)
        try fixture.context.save()

        #expect(favorite.destinationAccount == nil)
        #expect(favorite.account?.persistentModelID == fixture.soles.persistentModelID)
    }
}
