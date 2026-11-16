//
//  InboxDuplicateCheckTests.swift
//  YalaTests
//
//  Lote 03 de las necesarias 2.3, punto 1 (ticket `inbox-bulk-save-and-swipe-skip-the-duplicate-check`): «Guardar los N
//  listos» y «Aprobar» de la selección guardaban sin buscar duplicados, y el pago que llegaba por el correo del banco y
//  por Apple Pay contaba dos veces. Fichero aparte a propósito: `makeTestContext()` reusa el container por `#fileID`.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Bandeja — el lote no guarda posibles duplicados", .serialized)
struct InboxDuplicateCheckTests {

    /// Un día fijo del pasado a mediodía: ni futuro ni en la frontera de medianoche, corra cuando corra.
    private var day: Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 15, hour: 12)) ?? .distantPast
    }

    private struct Fixture {
        let account: Account
        let otherAccount: Account
        let subcategory: Subcategory
    }

    private func makeFixture(in context: ModelContext) -> Fixture {
        let account = makeTestAccount(context: context, name: "Cuenta", currencyCode: "USD")
        let otherAccount = makeTestAccount(context: context, name: "Otra", currencyCode: "USD")
        let category = makeTestCategory(context: context, name: "Comida")
        let subcategory = makeTestSubcategory(context: context, name: "Restaurantes", category: category)
        return Fixture(account: account, otherAccount: otherAccount, subcategory: subcategory)
    }

    @discardableResult
    private func insertDraft(
        _ note: String,
        amount: Double,
        date: Date,
        account: Account,
        subcategory: Subcategory,
        in context: ModelContext
    ) -> InboxDraft {
        let draft = InboxDraft(
            note: note, amount: amount, date: date, account: account, subcategory: subcategory, needsUserInput: []
        )
        context.insert(draft)
        return draft
    }

    @discardableResult
    private func insertTransaction(amount: Double, date: Date, account: Account, in context: ModelContext) -> TransactionItem {
        let transaction = TransactionItem(date: date, amount: amount, currencyCode: account.currencyCode)
        transaction.account = account
        context.insert(transaction)
        return transaction
    }

    private func transactionCount(in context: ModelContext) throws -> Int {
        try context.fetchCount(FetchDescriptor<TransactionItem>())
    }

    // MARK: - El lote

    /// El caso del ticket: el pago ya está guardado y su borrador va en el lote con otro que no se parece a nada.
    @Test func bulkApprove_leavesThePossibleDuplicatePending_andSavesTheRest() throws {
        let context = try makeTestContext()
        DraftService.shared.setContext(context)
        defer { DraftService.shared.setContext(nil) }
        let fixture = makeFixture(in: context)

        insertTransaction(amount: -42.5, date: day.addingTimeInterval(-3 * 3600), account: fixture.account, in: context)
        let twin = insertDraft("Almuerzo", amount: -42.5, date: day, account: fixture.account, subcategory: fixture.subcategory, in: context)
        let other = insertDraft("Taxi", amount: -18, date: day, account: fixture.account, subcategory: fixture.subcategory, in: context)
        try context.save()
        let before = try transactionCount(in: context)

        let outcome = try DraftService.shared.bulkApproveOutcome([twin, other], currencyConverter: CurrencyConverter())

        #expect(outcome.skippedAsPossibleDuplicate == 1)
        #expect(outcome.transactions.map(\.amount) == [-18])
        #expect(twin.status == .pending, "El posible duplicado tenía que quedarse en la Bandeja.")
        #expect(twin.approvedTransaction == nil)
        #expect(other.status == .approved)
        #expect(try transactionCount(in: context) == before + 1, "Se guardó el pago dos veces.")
    }

    /// El correo del banco y Apple Pay traen el mismo pago y los dos van en el mismo lote: se guarda uno.
    @Test func bulkApprove_twoDraftsOfTheSamePaymentInOneBatch_saveOnce() throws {
        let context = try makeTestContext()
        DraftService.shared.setContext(context)
        defer { DraftService.shared.setContext(nil) }
        let fixture = makeFixture(in: context)

        let fromEmail = insertDraft("Correo", amount: -42.5, date: day, account: fixture.account, subcategory: fixture.subcategory, in: context)
        let fromApplePay = insertDraft("Apple Pay", amount: -42.5, date: day.addingTimeInterval(600), account: fixture.account, subcategory: fixture.subcategory, in: context)
        try context.save()

        let outcome = try DraftService.shared.bulkApproveOutcome([fromEmail, fromApplePay], currencyConverter: CurrencyConverter())

        #expect(outcome.transactions.count == 1)
        #expect(outcome.skippedAsPossibleDuplicate == 1)
        #expect(fromEmail.status == .approved)
        #expect(fromApplePay.status == .pending)
        #expect(try transactionCount(in: context) == 1)
    }

    /// Control: otro importe, otra cuenta u otro día no son el mismo pago, y el lote los guarda todos.
    @Test func bulkApprove_savesWhatOnlyLooksAlikeInPart() throws {
        let context = try makeTestContext()
        DraftService.shared.setContext(context)
        defer { DraftService.shared.setContext(nil) }
        let fixture = makeFixture(in: context)

        insertTransaction(amount: -42.5, date: day, account: fixture.account, in: context)
        let otherAmount = insertDraft("A", amount: -42.51, date: day, account: fixture.account, subcategory: fixture.subcategory, in: context)
        let otherAccount = insertDraft("B", amount: -42.5, date: day, account: fixture.otherAccount, subcategory: fixture.subcategory, in: context)
        let otherDay = insertDraft("C", amount: -42.5, date: day.addingTimeInterval(-86_400), account: fixture.account, subcategory: fixture.subcategory, in: context)
        try context.save()

        let outcome = try DraftService.shared.bulkApproveOutcome(
            [otherAmount, otherAccount, otherDay], currencyConverter: CurrencyConverter()
        )

        #expect(outcome.skippedAsPossibleDuplicate == 0)
        #expect(outcome.transactions.count == 3)
    }

    /// La firma de siempre (`bulkApprove`) pasa por la misma comprobación: sus llamadores no se la saltan.
    @Test func bulkApprove_legacySignature_alsoSkipsThePossibleDuplicate() throws {
        let context = try makeTestContext()
        DraftService.shared.setContext(context)
        defer { DraftService.shared.setContext(nil) }
        let fixture = makeFixture(in: context)

        insertTransaction(amount: -42.5, date: day, account: fixture.account, in: context)
        let twin = insertDraft("Almuerzo", amount: -42.5, date: day, account: fixture.account, subcategory: fixture.subcategory, in: context)
        try context.save()

        let transactions = try DraftService.shared.bulkApprove([twin], currencyConverter: CurrencyConverter())

        #expect(transactions.isEmpty)
        #expect(twin.status == .pending)
    }

    // MARK: - El criterio que comparten el borrador abierto, el lote y deslizar

    @Test func possibleDuplicate_findsTheTwin_onlyForAPersonalDraft() throws {
        let context = try makeTestContext()
        let fixture = makeFixture(in: context)
        let saved = insertTransaction(amount: -42.5, date: day, account: fixture.account, in: context)
        let draft = insertDraft("Almuerzo", amount: -42.5, date: day, account: fixture.account, subcategory: fixture.subcategory, in: context)
        try context.save()

        #expect(try InboxDuplicateCheck.possibleDuplicate(of: draft, in: context) === saved)

        // Un borrador de grupo se guarda por sus hojas y su puente: nunca tuvo esta comprobación.
        draft.sourceType = .groupSettlement
        #expect(try InboxDuplicateCheck.possibleDuplicate(of: draft, in: context) == nil)
    }

    // MARK: - Lo que se dice

    @Test func skippedLine_onlyWhenSomethingWasSkipped() {
        #expect(InboxBulkDuplicatesLogic.skippedLine(0) == nil)
        #expect(InboxBulkDuplicatesLogic.skippedLine(2) == L10n.Inbox.bulkSkippedDuplicates(2))
    }

    /// Con nada guardado porque todo se parecía, la pantalla final sale igual y lo dice; antes no salía nada.
    @Test func summary_showsAlsoWhenOnlyDuplicatesWereLeft() {
        #expect(InboxBulkDuplicatesLogic.showsSummary(saved: 0, skipped: 1))
        #expect(InboxBulkDuplicatesLogic.showsSummary(saved: 1, skipped: 0))
        #expect(!InboxBulkDuplicatesLogic.showsSummary(saved: 0, skipped: 0))
    }
}
