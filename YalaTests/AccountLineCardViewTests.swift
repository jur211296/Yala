//
//  AccountLineCardViewTests.swift
//  YalaTests
//
//  Tarjeta con varias divisas, entrega 2: lo que las pantallas escriben y leen sobre SwiftData. Vincular no cambia
//  ningún movimiento (leído del STORE con un contexto nuevo, no de los objetos en memoria), añadir y desvincular una
//  línea, archivar en cascada, el orden de Ajustes al reordenar, la notificación única de una tarjeta con dos líneas y
//  lo que el formulario ofrece y rechaza.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Tarjeta con varias divisas · pantallas", .serialized)
@MainActor
struct AccountLineCardViewTests {

    private func account(_ context: ModelContext, _ name: String, _ currency: String,
                         type: String = AccountType.creditCard.rawValue) -> Account {
        let account = Account(name: name, currencyCode: currency, colorHex: "#6366F1",
                              iconName: "creditcard", type: type)
        context.insert(account)
        return account
    }

    private func transaction(_ context: ModelContext, _ amount: Double, _ account: Account,
                             _ subcategory: Subcategory, day: Double) -> TransactionItem {
        let tx = TransactionItem(date: Date(timeIntervalSince1970: 1_760_000_000 + day * 86_400), amount: amount,
                                 currencyCode: account.currencyCode, note: "tx\(day)", category: subcategory.category,
                                 subcategory: subcategory, account: account)
        context.insert(tx)
        return tx
    }

    private func isolatedDefaults() throws -> UserDefaults {
        try #require(UserDefaults(suiteName: "test.\(UUID().uuidString)"))
    }

    /// Lo que hay en el store de cada movimiento, leído con un contexto NUEVO.
    private struct StoredMovement: Hashable {
        let note: String
        let amount: Double
        let currency: String
        let accountID: UUID?
    }

    private func storedMovements(_ context: ModelContext) throws -> Set<StoredMovement> {
        let fresh = ModelContext(context.container)
        return Set(try fresh.fetch(FetchDescriptor<TransactionItem>()).map {
            StoredMovement(note: $0.note ?? "", amount: $0.amount, currency: $0.currencyCode,
                           accountID: $0.account?.shortcutID)
        })
    }

    // MARK: - Vincular no cambia ningún movimiento

    @Test func link_twoAccountsWithMovements_storeHasTheSameMovementsAfter() throws {
        let context = try makeTestContext()
        let category = makeTestCategory(context: context)
        let subcategory = makeTestSubcategory(context: context, category: category)
        let visa = account(context, "Visa", "PEN")
        let dollars = account(context, "Dólares", "USD", type: AccountType.savings.rawValue)
        _ = transaction(context, -120, visa, subcategory, day: 0)
        _ = transaction(context, -35.5, dollars, subcategory, day: 1)
        _ = transaction(context, 300, dollars, subcategory, day: 2)
        try context.save()
        let before = try storedMovements(context)

        let form = AccountFormViewModel(accountToEdit: visa, existingNames: [])
        form.setContext(context)
        let candidate = try #require(form.linkCandidates.first { $0.account.persistentModelID == dollars.persistentModelID })
        #expect(candidate.reason == nil)
        #expect(form.link(dollars))

        #expect(try storedMovements(context) == before, "vincular solo escribe el enlace")
        let freshAccounts = try ModelContext(context.container).fetch(FetchDescriptor<Account>())
        #expect(freshAccounts.first { $0.shortcutID == dollars.shortcutID }?.parentAccountID == visa.shortcutID)
        #expect(form.cardLines.map(\.shortcutID) == [dollars.shortcutID])
    }

    @Test func linkCandidates_explainSameCurrencyAndAccountWithLines() throws {
        let context = try makeTestContext()
        let visa = account(context, "Visa", "PEN")
        let savings = account(context, "Ahorros", "PEN", type: AccountType.savings.rawValue)
        let otherCard = account(context, "Master", "EUR")
        let otherLine = account(context, "Master MXN", "MXN")
        otherLine.parentAccountID = otherCard.shortcutID
        try context.save()

        let form = AccountFormViewModel(accountToEdit: visa, existingNames: [])
        form.setContext(context)
        let reasons = Dictionary(uniqueKeysWithValues: form.linkCandidates.map { ($0.account.name, $0.reason) })
        #expect(reasons["Ahorros"] == .some(L10n.Account.Lines.rejectSameCurrency))
        #expect(reasons["Master"] == .some(L10n.Account.Lines.rejectHasLines))
        #expect(reasons["Master MXN"] == .some(nil), "una línea de otra tarjeta se puede mover a esta")
        #expect(form.link(savings) == false)
        #expect(form.lineActionError == L10n.Account.Lines.rejectSameCurrency, "la hoja dice por qué")
        #expect(!form.isShowingLineActionError, "el aviso es de la hoja, no del formulario que queda debajo")
        #expect(savings.parentAccountID == nil)
    }

    // MARK: - Añadir y desvincular

    @Test func addLine_fromASavingsAccount_createsTheLineWithTheCardsLook() throws {
        let context = try makeTestContext()
        let savings = account(context, "Ahorros", "PEN", type: AccountType.savings.rawValue)
        savings.colorHex = "#4CB963"
        try context.save()

        let form = AccountFormViewModel(accountToEdit: savings, existingNames: [])
        form.setContext(context)
        #expect(form.canManageLines)
        #expect(!form.addableLineCurrencies.contains(.pen))
        #expect(form.addLine(currency: .usd, initialBalance: 50))

        let line = try #require(try context.fetch(FetchDescriptor<Account>()).first { $0.currencyCode == "USD" })
        #expect(line.parentAccountID == savings.shortcutID)
        #expect(line.name == "Ahorros · USD")
        #expect(line.type == AccountType.savings.rawValue)
        #expect(line.colorHex == "#4CB963")
        #expect(AccountBalanceCalculator.currentBalance(
            for: line, allTransactions: try context.fetch(FetchDescriptor<TransactionItem>())) == 50)
        #expect(!form.addableLineCurrencies.contains(.usd), "una tarjeta no tiene dos líneas en la misma divisa")
        #expect(context.hasChanges == false, "lo guardó")
    }

    @Test func addLine_inTheCardsCurrency_isRejectedAndWritesNothing() throws {
        let context = try makeTestContext()
        let visa = account(context, "Visa", "PEN")
        try context.save()
        #expect(throws: AccountLineService.AddLineError.rejected(.sameCurrencyAsPrincipal)) {
            try AccountLineService.addLine(currencyCode: "PEN", to: visa, initialBalance: nil, in: context)
        }
        #expect(try context.fetch(FetchDescriptor<Account>()).count == 1)
    }

    @Test func addLine_toALine_isRejected() throws {
        let context = try makeTestContext()
        let visa = account(context, "Visa", "PEN")
        let usd = account(context, "Visa USD", "USD")
        usd.parentAccountID = visa.shortcutID
        try context.save()
        #expect(throws: AccountLineService.AddLineError.cannotHaveLines) {
            try AccountLineService.addLine(currencyCode: "EUR", to: usd, initialBalance: nil, in: context)
        }
    }

    @Test func unlink_returnsTheLineToStandalone_withItsMovements() throws {
        let context = try makeTestContext()
        let category = makeTestCategory(context: context)
        let subcategory = makeTestSubcategory(context: context, category: category)
        let visa = account(context, "Visa", "PEN")
        let usd = account(context, "Visa USD", "USD")
        usd.parentAccountID = visa.shortcutID
        _ = transaction(context, -80, usd, subcategory, day: 0)
        try context.save()
        let before = try storedMovements(context)

        let form = AccountFormViewModel(accountToEdit: usd, existingNames: [])
        form.setContext(context)
        #expect(form.isCurrencyLockedAsLine)
        #expect(!form.ownsCardSettings)
        #expect(form.principalOfLine?.shortcutID == visa.shortcutID)
        form.unlink()

        #expect(usd.parentAccountID == nil)
        #expect(try storedMovements(context) == before)
        #expect(!form.isCurrencyLockedAsLine)
        #expect(form.ownsCardSettings)
    }

    @Test func brokenLink_offersUnlinkAndNotLines() throws {
        let context = try makeTestContext()
        let orphan = account(context, "Huérfana", "USD")
        orphan.parentAccountID = UUID()
        try context.save()
        let form = AccountFormViewModel(accountToEdit: orphan, existingNames: [])
        form.setContext(context)
        #expect(form.hasBrokenLink)
        #expect(!form.canManageLines)
        #expect(form.ownsCardSettings, "se ve suelta: tiene su recordatorio")
    }

    // MARK: - La divisa de la tarjeta no choca con una línea

    @Test func principalSwitchingToALinesCurrency_blocksTheSave() throws {
        let context = try makeTestContext()
        let visa = account(context, "Visa", "PEN")
        let usd = account(context, "Visa USD", "USD")
        usd.parentAccountID = visa.shortcutID
        try context.save()
        let form = AccountFormViewModel(accountToEdit: visa, existingNames: [])
        form.setContext(context)
        #expect(form.canSave)
        form.selectedCurrency = .usd
        #expect(form.currencyCollidingLine == "USD")
        #expect(!form.canSave)
        form.selectedCurrency = .eur
        #expect(form.currencyCollidingLine == nil)
    }

    // MARK: - Archivar

    @Test func archivingTheCard_asks_andArchivesItsLinesWhenTold() throws {
        let context = try makeTestContext()
        let visa = account(context, "Visa", "PEN")
        let usd = account(context, "Visa USD", "USD")
        usd.parentAccountID = visa.shortcutID
        try context.save()

        let form = AccountFormViewModel(accountToEdit: visa, existingNames: [])
        form.setContext(context)
        form.setArchived(true)
        #expect(form.isAskingArchiveLines)
        form.answerArchiveLines(true)
        #expect(form.saveAccount(context: context))

        #expect(visa.isArchived)
        #expect(usd.isArchived)
        #expect(usd.excludeFromStatistics, "como archivar cada una desde su formulario")
    }

    @Test func archivingTheCard_onlyTheCard_leavesTheLinesAsStandalone() throws {
        let context = try makeTestContext()
        let visa = account(context, "Visa", "PEN")
        let usd = account(context, "Visa USD", "USD")
        usd.parentAccountID = visa.shortcutID
        try context.save()

        let form = AccountFormViewModel(accountToEdit: visa, existingNames: [])
        form.setContext(context)
        form.setArchived(true)
        form.answerArchiveLines(false)
        #expect(form.saveAccount(context: context))
        #expect(visa.isArchived)
        #expect(!usd.isArchived)
        let roles = try context.fetch(FetchDescriptor<Account>()).lineRoles
        #expect(roles[usd.shortcutID] == .brokenLine(.principalArchived))
    }

    @Test func archivingTheCard_cancel_doesNotArchive() throws {
        let context = try makeTestContext()
        let visa = account(context, "Visa", "PEN")
        let usd = account(context, "Visa USD", "USD")
        usd.parentAccountID = visa.shortcutID
        try context.save()
        let form = AccountFormViewModel(accountToEdit: visa, existingNames: [])
        form.setContext(context)
        form.setArchived(true)
        form.answerArchiveLines(nil)
        #expect(!form.isArchived)
        #expect(!form.excludeFromStatistics)
    }

    @Test func archivingALine_doesNotTouchTheCard_andDoesNotAsk() throws {
        let context = try makeTestContext()
        let visa = account(context, "Visa", "PEN")
        let usd = account(context, "Visa USD", "USD")
        usd.parentAccountID = visa.shortcutID
        try context.save()
        let form = AccountFormViewModel(accountToEdit: usd, existingNames: [])
        form.setContext(context)
        form.setArchived(true)
        #expect(!form.isAskingArchiveLines)
        #expect(form.saveAccount(context: context))
        #expect(usd.isArchived)
        #expect(!visa.isArchived)
    }

    @Test func downgradeCascade_archivesTheLinesWithoutExcluding() throws {
        let context = try makeTestContext()
        let visa = account(context, "Visa", "PEN")
        let usd = account(context, "Visa USD", "USD")
        usd.parentAccountID = visa.shortcutID
        try context.save()
        let all = try context.fetch(FetchDescriptor<Account>())
        let archived = AccountLineService.archiveLines(of: visa, among: all, excludeFromStatistics: false)
        visa.isArchived = true
        #expect(archived == 1)
        #expect(usd.isArchived)
        #expect(!usd.excludeFromStatistics)
        #expect(try context.fetch(FetchDescriptor<Account>()).billableUserAccounts.isEmpty,
                "la línea no pasa a contar: el downgrade no vuelve a salir")
    }

    // MARK: - Ajustes: reordenar no manda las líneas al final

    @Test func settingsReorder_keepsEachLineRightAfterItsCard() throws {
        let context = try makeTestContext()
        let ahorros = account(context, "Ahorros", "PEN", type: AccountType.savings.rawValue)
        let visa = account(context, "Visa", "PEN")
        let usd = account(context, "Visa · USD", "USD")
        usd.parentAccountID = visa.shortcutID
        let dolares = account(context, "Dólares", "USD", type: AccountType.savings.rawValue)
        try context.save()

        let list = AccountsSettingsListViewModel()
        list.setContext(context)
        list.accountsSortOrderNames = ["Ahorros", "Visa", "Visa · USD", "Dólares"]
        #expect(list.orderedCards.map(\.head.name) == ["Ahorros", "Visa", "Dólares"])
        #expect(list.orderedCards[1].lines.map(\.name) == ["Visa · USD"])

        // La tarjeta pasa al final.
        let saved = list.moveAccount(from: IndexSet(integer: 1), to: 3)
        #expect(saved == ["Ahorros", "Dólares", "Visa", "Visa · USD"])
        _ = (ahorros, dolares)
    }

    @Test func settingsList_showsTheLineNested_notMissing() throws {
        let context = try makeTestContext()
        let visa = account(context, "Visa", "PEN")
        let usd = account(context, "Visa · USD", "USD")
        usd.parentAccountID = visa.shortcutID
        try context.save()
        let list = AccountsSettingsListViewModel()
        list.setContext(context)
        #expect(list.orderedCards.count == 1)
        #expect(list.orderedCards.first?.lines.first?.shortcutID == usd.shortcutID)
    }

    // MARK: - Recordatorio: una sola notificación por tarjeta

    @Test func paymentReminder_aCardWithTwoLines_notifiesOnce() throws {
        let context = try makeTestContext()
        let visa = account(context, "Visa", "PEN")
        visa.creditCardPaymentReminder = true
        let usd = account(context, "Visa USD", "USD")
        usd.creditCardPaymentReminder = true   // lo traía de antes de vincularse
        usd.parentAccountID = visa.shortcutID
        let loose = account(context, "Master", "USD")
        loose.creditCardPaymentReminder = true
        try context.save()

        let service = ScheduledPaymentNotificationService(
            tracker: ScheduledPaymentNotificationTracker(defaults: try isolatedDefaults()))
        let remindable = service.remindableAccounts([visa, usd, loose], context: context)
        #expect(Set(remindable.map(\.shortcutID)) == [visa.shortcutID, loose.shortcutID])
    }

    @Test func paymentReminder_orphanLine_stillNotifies() throws {
        let context = try makeTestContext()
        let orphan = account(context, "Huérfana", "USD")
        orphan.creditCardPaymentReminder = true
        orphan.parentAccountID = UUID()
        try context.save()
        let service = ScheduledPaymentNotificationService(
            tracker: ScheduledPaymentNotificationTracker(defaults: try isolatedDefaults()))
        #expect(service.remindableAccounts([orphan], context: context).count == 1)
    }

    // MARK: - Panel: rótulo de la tarjeta

    @Test func cardAmountKind_sameForAll_orBalanceWhenMixed() {
        #expect(PanelAccountCardLogic.cardAmountKind(lineKinds: [.toPay, .toPay]) == .toPay)
        #expect(PanelAccountCardLogic.cardAmountKind(lineKinds: [.toPay, .balance]) == .balance)
        #expect(PanelAccountCardLogic.showsLineLabel(lineKind: .toPay, cardKind: .balance))
        // Una línea recién creada, en 0, no le quita el «Por pagar» a la tarjeta ni lleva rótulo propio.
        let zero = PanelAccountCardLogic.lineKind(isExpensesOnlyMode: false, isCreditCard: true, value: 0)
        #expect(zero == nil)
        #expect(PanelAccountCardLogic.cardAmountKind(lineKinds: [.toPay, zero]) == .toPay)
        #expect(!PanelAccountCardLogic.showsLineLabel(lineKind: zero, cardKind: .toPay))
        #expect(PanelAccountCardLogic.lineKind(isExpensesOnlyMode: true, isCreditCard: true, value: 0) == .spent)
        #expect(PanelAccountCardLogic.cardAmountKind(lineKinds: [nil, nil]) == .balance)
        #expect(!PanelAccountCardLogic.showsLineLabel(lineKind: .toPay, cardKind: .toPay))
        #expect(PanelAccountCardLogic.subtitle(typeName: "Tarjeta", currencyCodes: ["PEN", "USD"])
                == "Tarjeta · PEN · USD")
    }
}
