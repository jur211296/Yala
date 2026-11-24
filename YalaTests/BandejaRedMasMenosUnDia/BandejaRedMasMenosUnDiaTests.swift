//
//  BandejaRedMasMenosUnDiaTests.swift
//  YalaTests
//
//  Lote 0 de la propuesta «Bandeja sin duplicados entre fuentes» (`docs/propuestas/bandeja-sin-duplicados/README.md`,
//  decisión de Jürgen del 24-nov-2026). Al aprobar, el aviso de posible duplicado mira también el día anterior y el
//  siguiente, acepta un registro sin cuenta, exige la misma moneda y un importe ±0,01, y no marca entre sí dos compras
//  de la MISMA fuente que cuenta cada pago una sola vez (Apple Pay, el correo del banco). El aviso nombra el gemelo.
//  Fichero aparte a propósito: `makeTestContext()` reusa el container por `#fileID`.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Bandeja — la red al aprobar mira ±1 día y nombra el gemelo", .serialized)
struct BandejaRedMasMenosUnDiaTests {

    private let calendar = Calendar.current

    /// Octubre de 2026, en el día y la hora dados: fijo y en el pasado, corra cuando corra.
    private func oct(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute)) ?? .distantPast
    }

    private struct Fixture {
        let account: Account
        let otherAccount: Account
        let dollars: Account
        let subcategory: Subcategory
    }

    private func makeFixture(in context: ModelContext) -> Fixture {
        let account = makeTestAccount(context: context, name: "BCP Visa", currencyCode: "PEN")
        let otherAccount = makeTestAccount(context: context, name: "Interbank", currencyCode: "PEN")
        let dollars = makeTestAccount(context: context, name: "Ahorros USD", currencyCode: "USD")
        let category = makeTestCategory(context: context, name: "Comida")
        let subcategory = makeTestSubcategory(context: context, name: "Supermercado", category: category)
        return Fixture(account: account, otherAccount: otherAccount, dollars: dollars, subcategory: subcategory)
    }

    @discardableResult
    private func insertDraft(
        _ note: String,
        amount: Double,
        date: Date,
        source: DraftSourceType,
        fixture: Fixture,
        account: Account? = nil,
        in context: ModelContext
    ) -> InboxDraft {
        let draft = InboxDraft(
            note: note, amount: amount, date: date, account: account ?? fixture.account,
            subcategory: fixture.subcategory, sourceType: source, needsUserInput: []
        )
        context.insert(draft)
        return draft
    }

    /// Un registro ya guardado. Con `fromSource`, enlazado a un borrador aprobado de esa fuente, como lo deja aprobar.
    @discardableResult
    private func insertSaved(
        _ note: String,
        amount: Double,
        date: Date,
        account: Account?,
        currencyCode: String = "PEN",
        fromSource source: DraftSourceType? = nil,
        in context: ModelContext
    ) -> TransactionItem {
        let transaction = TransactionItem(date: date, amount: amount, currencyCode: currencyCode)
        transaction.note = note
        transaction.account = account
        context.insert(transaction)
        if let source {
            let draft = InboxDraft(note: note, amount: amount, date: date, account: account, sourceType: source, needsUserInput: [])
            draft.status = .approved
            context.insert(draft)
            draft.approvedTransaction = transaction
        }
        return transaction
    }

    private func twin(of draft: InboxDraft, in context: ModelContext) throws -> TransactionItem? {
        try InboxDuplicateCheck.possibleDuplicate(of: draft, in: context, calendar: calendar)
    }

    // MARK: - E2 y el cruce de medianoche al revés

    /// E2: Apple Pay a las 23:50 del 15 y el correo del banco fechado el 16, mismo importe. Antes el lote guardaba los dos.
    @Test func e2_applePayAt2350_andTheBankEmailOfTheNextDay_saveOnce() throws {
        let context = try makeTestContext()
        DraftService.shared.setContext(context)
        defer { DraftService.shared.setContext(nil) }
        let fixture = makeFixture(in: context)

        let applePay = insertDraft("Wong", amount: -89.9, date: oct(15, 23, 50), source: .applePay, fixture: fixture, in: context)
        let email = insertDraft("WONG SAN ISIDRO", amount: -89.9, date: oct(16, 12), source: .emailAlert, fixture: fixture, in: context)
        try context.save()

        let outcome = try DraftService.shared.bulkApproveOutcome([applePay, email], currencyConverter: CurrencyConverter())

        #expect(outcome.transactions.count == 1, "El lote guardó el mismo pago dos veces.")
        #expect(outcome.skippedAsPossibleDuplicate == 1)
        #expect(applePay.status == .approved)
        #expect(email.status == .pending, "El correo del día siguiente tenía que quedarse como posible duplicado.")
    }

    /// Al revés: el correo fechado el 15 y Apple Pay a las 00:10 del 16. El gemelo está el día SIGUIENTE.
    @Test func midnightTheOtherWay_aDraftOfThe15_findsTheTwinSavedAt0010OfThe16() throws {
        let context = try makeTestContext()
        let fixture = makeFixture(in: context)
        let saved = insertSaved("Wong", amount: -89.9, date: oct(16, 0, 10), account: fixture.account, fromSource: .applePay, in: context)
        let email = insertDraft("WONG SAN ISIDRO", amount: -89.9, date: oct(15, 12), source: .emailAlert, fixture: fixture, in: context)
        try context.save()

        #expect(try twin(of: email, in: context) === saved)
    }

    /// El día anterior también: el gemelo guardado es del 15 a las 23:50 y el borrador, del 16.
    @Test func theDayBefore_isAlsoChecked() throws {
        let context = try makeTestContext()
        let fixture = makeFixture(in: context)
        let saved = insertSaved("Wong", amount: -89.9, date: oct(15, 23, 50), account: fixture.account, fromSource: .applePay, in: context)
        let email = insertDraft("WONG", amount: -89.9, date: oct(16, 12), source: .emailAlert, fixture: fixture, in: context)
        try context.save()

        #expect(try twin(of: email, in: context) === saved)
    }

    // MARK: - E8: dos compras reales iguales de la misma fuente

    /// E8: dos cafés de S/ 12 por Apple Pay, a las 8:10 y a las 18:40. Son dos compras: el lote guarda las dos.
    @Test func e8_twoEqualApplePayPurchases_areBothSaved() throws {
        let context = try makeTestContext()
        DraftService.shared.setContext(context)
        defer { DraftService.shared.setContext(nil) }
        let fixture = makeFixture(in: context)

        let morning = insertDraft("Starbucks", amount: -12, date: oct(15, 8, 10), source: .applePay, fixture: fixture, in: context)
        let evening = insertDraft("Starbucks", amount: -12, date: oct(15, 18, 40), source: .applePay, fixture: fixture, in: context)
        try context.save()

        let outcome = try DraftService.shared.bulkApproveOutcome([morning, evening], currencyConverter: CurrencyConverter())

        #expect(outcome.transactions.count == 2, "El lote se quedó con la segunda compra real.")
        #expect(outcome.skippedAsPossibleDuplicate == 0)
    }

    /// Lo mismo con dos correos del banco (el correo repetido ya lo filtra su id antes de llegar aquí).
    @Test func e8_twoEqualBankEmails_areNotTwins() throws {
        let context = try makeTestContext()
        let fixture = makeFixture(in: context)
        insertSaved("Starbucks", amount: -12, date: oct(15, 8, 10), account: fixture.account, fromSource: .emailAlert, in: context)
        let second = insertDraft("Starbucks", amount: -12, date: oct(15, 18, 40), source: .emailAlert, fixture: fixture, in: context)
        try context.save()

        #expect(try twin(of: second, in: context) == nil)
    }

    /// Entre fuentes distintas sí: el correo del mismo café ya guardado por Apple Pay es posible duplicado.
    @Test func e8_acrossSources_isStillATwin() throws {
        let context = try makeTestContext()
        let fixture = makeFixture(in: context)
        let saved = insertSaved("Starbucks", amount: -12, date: oct(15, 8, 10), account: fixture.account, fromSource: .applePay, in: context)
        let email = insertDraft("STARBUCKS", amount: -12, date: oct(15, 12), source: .emailAlert, fixture: fixture, in: context)
        try context.save()

        #expect(try twin(of: email, in: context) === saved)
    }

    /// Con un gemelo de la misma fuente y otro de otra, se nombra el de la otra aunque esté más lejos.
    @Test func e8_sameSourceTwinIsSkipped_andTheOtherSourceTwinIsNamed() throws {
        let context = try makeTestContext()
        let fixture = makeFixture(in: context)
        insertSaved("Starbucks", amount: -12, date: oct(15, 12, 5), account: fixture.account, fromSource: .applePay, in: context)
        let byHand = insertSaved("Café", amount: -12, date: oct(15, 8), account: fixture.account, in: context)
        let draft = insertDraft("Starbucks", amount: -12, date: oct(15, 12), source: .applePay, fixture: fixture, in: context)
        try context.save()

        #expect(try twin(of: draft, in: context) === byHand)
    }

    /// Las fuentes que pueden repetir un pago siguen avisando entre sí: la IA que lee el mismo correo dos veces (E5).
    @Test func aSourceThatCanRepeat_stillWarnsAgainstItself() throws {
        let context = try makeTestContext()
        let fixture = makeFixture(in: context)
        let saved = insertSaved("Luz del Sur", amount: -134.8, date: oct(15, 9), account: fixture.account, fromSource: .aiConnector, in: context)
        let again = insertDraft("Luz del Sur", amount: -134.8, date: oct(15, 10), source: .aiConnector, fixture: fixture, in: context)
        try context.save()

        #expect(try twin(of: again, in: context) === saved)
    }

    // MARK: - Lo que entra y lo que no

    @Test func aSavedRecordWithoutAccount_counts() throws {
        let context = try makeTestContext()
        let fixture = makeFixture(in: context)
        let saved = insertSaved("Wong", amount: -89.9, date: oct(15, 20), account: nil, in: context)
        let draft = insertDraft("Wong", amount: -89.9, date: oct(16, 9), source: .emailAlert, fixture: fixture, in: context)
        try context.save()

        #expect(try twin(of: draft, in: context) === saved)
    }

    @Test func withinOneCent_counts() throws {
        let context = try makeTestContext()
        let fixture = makeFixture(in: context)
        let saved = insertSaved("Wong", amount: -89.9, date: oct(15, 20), account: fixture.account, in: context)
        let draft = insertDraft("Wong", amount: -89.91, date: oct(15, 21), source: .emailAlert, fixture: fixture, in: context)
        try context.save()

        #expect(try twin(of: draft, in: context) === saved)
    }

    /// Controles: dos días de distancia, dos céntimos, otra cuenta, otra moneda u otro signo no son el mismo pago.
    @Test func whatOnlyLooksAlikeInPart_isNotATwin() throws {
        let context = try makeTestContext()
        let fixture = makeFixture(in: context)
        insertSaved("Wong", amount: -89.9, date: oct(15, 12), account: fixture.account, in: context)
        insertSaved("Wong", amount: -89.9, date: oct(15, 12), account: nil, currencyCode: "USD", in: context)
        try context.save()

        let twoDaysLater = insertDraft("A", amount: -89.9, date: oct(17, 12), source: .emailAlert, fixture: fixture, in: context)
        let twoDaysBefore = insertDraft("B", amount: -89.9, date: oct(13, 12), source: .emailAlert, fixture: fixture, in: context)
        let twoCents = insertDraft("C", amount: -89.92, date: oct(15, 12), source: .emailAlert, fixture: fixture, in: context)
        let otherAccount = insertDraft(
            "D", amount: -89.9, date: oct(15, 12), source: .emailAlert, fixture: fixture, account: fixture.otherAccount, in: context
        )
        let refund = insertDraft("E", amount: 89.9, date: oct(15, 12), source: .emailAlert, fixture: fixture, in: context)
        try context.save()

        for draft in [twoDaysLater, twoDaysBefore, twoCents, otherAccount, refund] {
            #expect(try twin(of: draft, in: context) == nil, "«\(draft.note)» no es el mismo pago.")
        }
    }

    /// La moneda la pone la cuenta del borrador: en la cuenta en dólares, el registro sin cuenta en dólares sí cuenta.
    @Test func theCurrencyIsTheDraftAccounts() throws {
        let context = try makeTestContext()
        let fixture = makeFixture(in: context)
        let saved = insertSaved("Amazon", amount: -11.3, date: oct(15, 12), account: nil, currencyCode: "USD", in: context)
        insertSaved("Amazon", amount: -11.3, date: oct(15, 12, 30), account: nil, currencyCode: "PEN", in: context)
        let draft = insertDraft(
            "Amazon", amount: -11.3, date: oct(15, 14), source: .emailAlert, fixture: fixture, account: fixture.dollars, in: context
        )
        try context.save()

        #expect(try twin(of: draft, in: context) === saved)
    }

    /// Con dos candidatos se nombra el más cercano en el tiempo.
    @Test func theClosestCandidateIsNamed() throws {
        let context = try makeTestContext()
        let fixture = makeFixture(in: context)
        insertSaved("Lejos", amount: -50, date: oct(14, 9), account: fixture.account, in: context)
        let near = insertSaved("Cerca", amount: -50, date: oct(15, 11), account: fixture.account, in: context)
        let draft = insertDraft("X", amount: -50, date: oct(15, 12), source: .emailAlert, fixture: fixture, in: context)
        try context.save()

        #expect(try twin(of: draft, in: context) === near)
    }

    // MARK: - El aviso nombra el gemelo

    @Test func warning_namesMerchantAmountAndDate() throws {
        let context = try makeTestContext()
        let fixture = makeFixture(in: context)
        let saved = insertSaved("Wong", amount: -89.9, date: oct(15, 23, 50), account: fixture.account, in: context)
        try context.save()

        let summary = InboxDuplicateCheck.twinSummary(saved)
        let message = InboxDuplicateCheck.warningMessage(naming: saved)

        #expect(message == L10n.Inbox.duplicateWarningNamed(summary))
        #expect(summary.contains("Wong"))
        #expect(summary.contains(YalaFormatterStatic.currency(value: 89.9, currencyCode: "PEN", forceFullPrecision: true)))
        #expect(summary.contains(InboxDuplicateCheck.twinDateText(saved.date)))
        #expect(message.contains(summary))
        #expect(!message.contains("%@"))
    }

    /// Sin nota, el aviso dice la subcategoría; sin nada, empieza por el importe.
    @Test func warning_withoutNote_fallsBackToTheSubcategory_thenToNothing() throws {
        let context = try makeTestContext()
        let fixture = makeFixture(in: context)
        let withSubcategory = insertSaved("  ", amount: -20, date: oct(15, 12), account: fixture.account, in: context)
        withSubcategory.subcategory = fixture.subcategory
        let bare = insertSaved("", amount: -30, date: oct(15, 12), account: fixture.account, in: context)
        try context.save()

        #expect(InboxDuplicateCheck.twinSummary(withSubcategory).hasPrefix("Supermercado · "))
        #expect(InboxDuplicateCheck.twinSummary(bare).hasPrefix(YalaFormatterStatic.currency(value: 30, currencyCode: "PEN", forceFullPrecision: true)))
    }

    /// El aviso nuevo existe en los 16 idiomas y lleva su hueco.
    @Test func warning_keyIsInEveryLocale() throws {
        let resources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Yala/Resources")
        let locales = try FileManager.default.contentsOfDirectory(atPath: resources.path).filter { $0.hasSuffix(".lproj") }
        #expect(locales.count == 16)
        for locale in locales {
            let file = resources.appendingPathComponent(locale).appendingPathComponent("Localizable.strings")
            let text = try String(contentsOf: file, encoding: .utf8)
            let line = text.split(separator: "\n").first { $0.hasPrefix("\"inbox.duplicateWarningNamed\"") }
            #expect(line?.contains("%@") == true, "Falta el aviso con el gemelo en \(locale).")
        }
    }
}
