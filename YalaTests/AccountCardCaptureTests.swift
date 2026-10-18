//
//  AccountCardCaptureTests.swift
//  YalaTests
//
//  Tarjeta con varias divisas, entrega 3 (ticket `multi-currency-accounts-3-pickers-and-capture`): con la tarjeta y un
//  importe en dólares, cada entrada guarda en la línea en dólares. Una tarjeta «Visa» en soles con su línea en dólares, y
//  además una cuenta suelta en soles («Ahorros»): por divisa sola, «PEN» no casaría con una cuenta única, y la tarjeta es
//  la que decide.
//
//  Cubre las entradas del punto 3 del ticket que corren en SwiftData: formulario (y favorito), chat, voz e imagen (que
//  eligen por la divisa dictada con `DraftBuilder.findAccount`), Siri, aprobación de un borrador de la Bandeja y pago
//  programado. Apple Pay vive en `ApplePayDraftServiceTests` (necesita su cola aislada). Y las dos reglas de selección: el
//  filtro de sesión que arrastra las líneas y el presupuesto que cuenta sus gastos.
//
//  `.lastUsedAccountIsolated`: guardar desde el formulario escribe la última cuenta usada en el App Group real.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Tarjeta con varias divisas · captura, filtros y presupuestos", .serialized, .lastUsedAccountIsolated)
struct AccountCardCaptureTests {

    private struct Fixture {
        let context: ModelContext
        let card: Account
        let line: Account
        let savings: Account
        let category: YalaCategory
        let subcategory: Subcategory
    }

    private func makeFixture() throws -> Fixture {
        let context = try makeTestContext()
        let card = makeTestAccount(context: context, name: "Visa", currencyCode: "PEN")
        let line = makeTestAccount(context: context, name: "Visa · USD", currencyCode: "USD")
        line.parentAccountID = card.shortcutID
        let savings = makeTestAccount(context: context, name: "Ahorros", currencyCode: "PEN")
        let category = makeTestCategory(context: context, name: "Viajes")
        let subcategory = makeTestSubcategory(context: context, name: "Hotel", category: category)
        try seedRates(on: Date.now, in: context)
        try context.save()
        return Fixture(context: context, card: card, line: line, savings: savings, category: category,
                       subcategory: subcategory)
    }

    /// La fila del día con todas las divisas, con la clave de los dos formateadores que puede usar quien convierte.
    private func seedRates(on date: Date, in context: ModelContext) throws {
        let rates = Dictionary(uniqueKeysWithValues: CurrencyCode.allRawValues.map {
            ($0, CurrencyCode.fallbackRates[$0] ?? 1.0)
        })
        let utc = DateFormatter()
        utc.dateFormat = "yyyy-MM-dd"
        utc.timeZone = TimeZone(identifier: "UTC")
        for key in Set([utc.string(from: date), DayKeyFormatter.string(from: date)]) {
            context.insert(try ExchangeRate(dateKey: key, base: "USD", ratesDictionary: rates))
        }
    }

    private func parsed(currencyHint: String) -> ParsedTransaction {
        ParsedTransaction(
            amount: 80, date: nil, note: "Hotel", isExpense: true, subcategoryHint: nil, tagHints: [],
            currencyHint: currencyHint,
            confidence: ParsedTransaction.TransactionConfidence(amount: 1, date: 0, merchant: 0, subcategory: 0, tags: 0))
    }

    // MARK: - Formulario y favorito

    @Test func form_choosingTheCard_andTheDollarPill_savesInTheUSDLine() throws {
        let f = try makeFixture()
        let vm = NewTransactionViewModel()
        vm.setContext(f.context)

        // Elegir la tarjeta con el importe en soles la deja en la principal; la pastilla de dólares elige la línea.
        vm.currencyCode = "PEN"
        vm.selectedAccount = vm.routed(f.card, toCurrency: vm.currencyCode)
        #expect(vm.selectedAccount?.shortcutID == f.card.shortcutID)
        let members = vm.cardMembers(of: vm.selectedAccount)
        #expect(members.map(\.shortcutID) == [f.card.shortcutID, f.line.shortcutID])
        let dollars = try #require(members.first { $0.currencyCode == "USD" })
        vm.selectCardMember(dollars)
        #expect(vm.currencyCode == "USD")

        vm.amountString = "80"
        vm.transactionType = .expense
        vm.selectedSubcategory = f.subcategory
        let saved = try #require(vm.save(context: f.context)?.first)

        #expect(saved.account?.shortcutID == f.line.shortcutID)
        #expect(normalizeCurrencyCode(saved.currencyCode) == "USD")
        #expect(saved.amount == -80)
    }

    @Test func form_chosenWithTheAmountAlreadyInDollars_goesStraightToTheLine() throws {
        let f = try makeFixture()
        let vm = NewTransactionViewModel()
        vm.setContext(f.context)
        // Prellenado de un favorito o del chat en dólares sobre la tarjeta.
        #expect(vm.routed(f.card, toCurrency: "USD").shortcutID == f.line.shortcutID)
        // Una cuenta sin líneas no tiene pastillas.
        #expect(vm.cardMembers(of: f.savings).isEmpty)
    }

    // MARK: - Chat

    @Test func chat_dictatedInDollars_choosingTheCard_savesInTheUSDLine() async throws {
        let f = try makeFixture()
        let draft = ChatTransactionDraft(
            amount: 80, currencyCode: "USD", isExpense: true, note: "Hotel",
            date: Date.now, accountID: nil, subcategoryID: f.subcategory.persistentModelID)
        let message = ChatMessage(role: .assistant, text: "Te propongo esto", timestamp: Date.now,
                                  attachments: [.drafts([draft])])
        let defaults = makeIsolatedDefaults()
        defaults.set(try JSONEncoder().encode(ChatPersistedSession(messages: [message], allTurns: [])),
                     forKey: "chat_session_" + DayKeyFormatter.string(from: Date.now))
        let vm = ChatAssistantViewModel(defaults: defaults)
        vm.setContext(f.context, autoLoadSuggestions: false)

        vm.updateDraft(messageID: message.id, draftID: draft.id, accountID: .some(f.card.persistentModelID))

        await vm.saveDraft(messageID: message.id, draftID: draft.id)
        let all = try f.context.fetch(FetchDescriptor<TransactionItem>())
        #expect(all.count == 1)
        let saved = try #require(all.first)
        #expect(saved.account?.shortcutID == f.line.shortcutID)
        #expect(normalizeCurrencyCode(saved.currencyCode) == "USD")
    }

    @Test func chat_aLineChosenOnPurpose_isRespected() throws {
        let f = try makeFixture()
        // Dictado en soles, pero la persona eligió la línea en dólares a mano: no se la cambiamos.
        #expect(ChatAssistantViewModel.cardAccount(for: f.line, dictatedCurrency: "PEN", in: f.context)
            .shortcutID == f.line.shortcutID)
        #expect(ChatAssistantViewModel.cardAccount(for: f.card, dictatedCurrency: "USD", in: f.context)
            .shortcutID == f.line.shortcutID)
        // Sin línea en esa divisa, la principal (nunca se crea una).
        #expect(ChatAssistantViewModel.cardAccount(for: f.card, dictatedCurrency: "EUR", in: f.context)
            .shortcutID == f.card.shortcutID)
        #expect(try f.context.fetch(FetchDescriptor<Account>()).count == 3)
    }

    // MARK: - Voz, imagen y Siri

    @Test func voice_dictatedInDollars_picksTheUSDLine() throws {
        let f = try makeFixture()
        // La voz elige con `DraftBuilder.findAccount(byCurrency:context:)` desde la entrega 3.
        #expect(DraftBuilder.findAccount(byCurrency: "USD", context: f.context)?.shortcutID == f.line.shortcutID)
    }

    @Test func captures_neverPickAGroupsSystemAccount() throws {
        let f = try makeFixture()
        let groups = makeTestAccount(context: f.context, name: "Grupos USD", currencyCode: "USD")
        groups.isSystemAccount = true
        try f.context.save()
        // Sin la exclusión serían dos cuentas en USD y no se elegiría ninguna.
        #expect(DraftBuilder.findAccount(byCurrency: "USD", context: f.context)?.shortcutID == f.line.shortcutID)
    }

    @Test func image_receiptInDollars_picksTheUSDLine() throws {
        let f = try makeFixture()
        let response = VisionResponse(
            imageType: "receipt",
            transactions: [VisionTransaction(amount: 80, date: nil, merchant: "Hotel", note: nil, currency: "USD")],
            confidence: VisionConfidence(overall: 0.9, imageType: 0.9))
        let drafts = VisionDraftFactory.makeDrafts(from: response, rawText: nil, context: f.context)
        #expect(drafts.first?.account?.shortcutID == f.line.shortcutID)
    }

    @Test func siri_dictatedInDollars_picksTheUSDLine() throws {
        let f = try makeFixture()
        let draft = SiriDraftService.buildDraft(
            from: parsed(currencyHint: "USD"), rawText: "80 dólares de hotel", fallbackDate: Date.now,
            realAccounts: [f.card, f.line, f.savings], visibleSubcategories: [f.subcategory],
            expensesOnlyMode: false, context: f.context)
        #expect(draft?.account?.shortcutID == f.line.shortcutID)
    }

    // MARK: - Bandeja y programados

    @Test func inboxApproval_choosingTheCard_keepsTheDraftCurrency_andApprovesInTheUSDLine() throws {
        let f = try makeFixture()
        DraftService.shared.setContext(f.context)
        defer { DraftService.shared.setContext(nil) }
        let draft = InboxDraft(note: "Hotel", amount: -80, date: Date.now, account: f.line,
                               subcategory: f.subcategory, needsUserInput: [])
        f.context.insert(draft)
        try f.context.save()

        // La hoja abre el selector con la divisa del borrador; tocar la tarjeta vuelve a la línea en dólares.
        let selector = AccountSelectorViewModel()
        selector.setContext(f.context)
        let chosen = selector.resolvedSelection(for: f.card, routingCurrency: f.line.currencyCode)
        #expect(chosen.shortcutID == f.line.shortcutID)
        draft.account = chosen

        let tx = try DraftService.shared.approveDraft(draft, currencyConverter: CurrencyConverter())
        #expect(tx.account?.shortcutID == f.line.shortcutID)
        #expect(normalizeCurrencyCode(tx.currencyCode) == "USD")
    }

    @Test func scheduledPayment_inDollarsOnTheCard_draftsOnTheUSDLine() throws {
        let f = try makeFixture()
        let payment = ScheduledPayment(
            name: "Hotel", amount: 80, currencyCode: "USD", transactionType: "expense", isRecurring: true,
            recurrenceType: "monthly", recurrenceInterval: 1, nextDueDate: Date.now, dayOfMonth: nil, endDate: nil,
            paymentCategory: "recurring", notifyOnDueDate: true, notifyDaysBefore: 0, isActive: true)
        payment.account = f.card
        f.context.insert(payment)
        try f.context.save()
        #expect(ScheduledPaymentDraftService.draftAccount(for: payment, context: f.context)?.shortcutID
            == f.line.shortcutID)

        // Control: en soles, la principal.
        payment.currencyCode = "PEN"
        #expect(ScheduledPaymentDraftService.draftAccount(for: payment, context: f.context)?.shortcutID
            == f.card.shortcutID)
    }

    /// La línea del pago se archivó y la tarjeta no tiene otra cuenta en dólares: el borrador se queda en la cuenta del pago
    /// (en USD), no salta a la principal en soles (review del 2026-10-18).
    @Test func scheduledPayment_onAnArchivedLine_keepsItsAccount() throws {
        let f = try makeFixture()
        let euros = makeTestAccount(context: f.context, name: "Visa · EUR", currencyCode: "EUR")
        euros.parentAccountID = f.card.shortcutID
        f.line.isArchived = true
        let payment = ScheduledPayment(
            name: "Hotel", amount: 80, currencyCode: "USD", transactionType: "expense", isRecurring: true,
            recurrenceType: "monthly", recurrenceInterval: 1, nextDueDate: Date.now, dayOfMonth: nil, endDate: nil,
            paymentCategory: "recurring", notifyOnDueDate: true, notifyDaysBefore: 0, isActive: true)
        payment.account = f.line
        f.context.insert(payment)
        try f.context.save()
        #expect(ScheduledPaymentDraftService.draftAccount(for: payment, context: f.context)?.shortcutID
            == f.line.shortcutID)
    }

    @Test func form_aFavoriteInACurrencyTheCardLacks_keepsItsAccount() throws {
        let f = try makeFixture()
        let vm = NewTransactionViewModel()
        vm.setContext(f.context)
        #expect(vm.routed(f.line, toCurrency: "EUR").shortcutID == f.line.shortcutID)
    }

    // MARK: - Filtro de sesión

    @Test func sessionFilter_choosingTheCard_showsTheMovementsOfBothLines() throws {
        let f = try makeFixture()
        let inSoles = makeTestTransaction(context: f.context, amount: -100, account: f.card, category: f.category,
                                          subcategory: f.subcategory, currencyCode: "PEN")
        let inDollars = makeTestTransaction(context: f.context, amount: -80, account: f.line, category: f.category,
                                            subcategory: f.subcategory, currencyCode: "USD")
        _ = makeTestTransaction(context: f.context, amount: -50, account: f.savings, category: f.category,
                                subcategory: f.subcategory, currencyCode: "PEN")
        try f.context.save()

        let session = SessionState.shared
        let previousSource = session.accountLinesByHead
        defer {
            session.clearFilters()
            session.accountLinesByHead = previousSource
        }
        session.installAccountLinesSource(f.context)

        session.selectedAccountIDs = [f.card.persistentModelID]
        #expect(session.selectedAccountIDs == [f.card.persistentModelID, f.line.persistentModelID])
        // Lo que se pinta: la tarjeta una vez.
        #expect(session.shownAccountSelection(session.selectedAccountIDs) == [f.card.persistentModelID])
        #expect(session.representativeAccountID(in: session.selectedAccountIDs) == f.card.persistentModelID)

        var criteria = FilterCriteria()
        criteria.selectedAccounts = session.selectedAccountIDs
        let all = try f.context.fetch(FetchDescriptor<TransactionItem>())
        let shown = Set(FilterService.filter(transactions: all, criteria: criteria).map(\.persistentModelID))
        #expect(shown == [inSoles.persistentModelID, inDollars.persistentModelID])

        // Vincular otra línea con la tarjeta filtrada la mete en el filtro (review del 2026-10-18).
        let euros = makeTestAccount(context: f.context, name: "Euros", currencyCode: "EUR")
        try f.context.save()
        try AccountLineService.link(euros, to: f.card, in: f.context)
        #expect(session.selectedAccountIDs.contains(euros.persistentModelID))

        // Quitar la tarjeta quita sus líneas.
        session.selectedAccountIDs.remove(f.card.persistentModelID)
        #expect(session.selectedAccountIDs.isEmpty)
    }

    // MARK: - Presupuesto

    @Test func budgetOnTheCard_countsTheUSDLineExpense_converted() throws {
        let f = try makeFixture()
        let interval = DateInterval(start: Date.now.addingTimeInterval(-86_400), end: Date.now.addingTimeInterval(86_400))
        _ = makeTestTransaction(context: f.context, amount: -100, date: Date.now, account: f.card,
                                category: f.category, subcategory: f.subcategory, currencyCode: "PEN")
        let inDollars = makeTestTransaction(context: f.context, amount: -80, date: Date.now, account: f.line,
                                            category: f.category, subcategory: f.subcategory,
                                            currencyCode: "USD")
        _ = makeTestTransaction(context: f.context, amount: -50, date: Date.now, account: f.savings,
                                category: f.category, subcategory: f.subcategory, currencyCode: "PEN")
        let budget = Budget(currencyCode: "PEN", limitAmount: 3_000, name: "Tarjeta", accounts: [f.card])
        f.context.insert(budget)
        try f.context.save()

        // Lo guardado sigue siendo solo la tarjeta: ni el CSV ni el sync cambian.
        #expect(budget.resolvedAccountIDs() == [f.card.shortcutID])
        #expect(budget.spendingAccountIDs() == [f.card.shortcutID, f.line.shortcutID])

        let all = try f.context.fetch(FetchDescriptor<TransactionItem>())
        let counted = BudgetsViewModel.filterTransactions(all, forBudget: budget, in: interval)
        #expect(counted.count == 2)
        #expect(counted.contains { $0.persistentModelID == inDollars.persistentModelID })

        let spent = BudgetsViewModel.calculateSpending(budget: budget, transactions: all, interval: interval)
        // 100 en soles + 80 dólares convertidos: más que los 100 de la principal sola.
        #expect(spent > 100)

        // Archivar la línea no le quita su gasto (archivar no decide la suma).
        f.line.isArchived = true
        try f.context.save()
        #expect(BudgetsViewModel.filterTransactions(all, forBudget: budget, in: interval).count == 2)
    }
}
