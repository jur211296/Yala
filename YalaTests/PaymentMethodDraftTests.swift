//
//  PaymentMethodDraftTests.swift
//  YalaTests
//
//  El borrador del chat (`DraftBuilder.build`) y la lectura del modelo (`parseMultipleResponse`) con el medio de pago
//  (card «Yala IA: detectar medio de pago», 2026-11-04). La lógica pura va en `PaymentMethodAccountLogicTests`.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite(.serialized)
struct PaymentMethodDraftTests {

    private func account(_ context: ModelContext, _ name: String, _ currency: String, _ type: AccountType) -> Account {
        let account = Account(name: name, currencyCode: currency, colorHex: "#6366F1", iconName: "creditcard.fill", type: type.rawValue)
        context.insert(account)
        return account
    }

    private func parsed(amount: Decimal = 25, currency: String? = nil, hint: String?, answered: Bool? = true) -> ParsedTransaction {
        var tx = ParsedTransaction(
            amount: amount, date: nil, note: "almuerzo", isExpense: true, subcategoryHint: nil, tagHints: [],
            currencyHint: currency,
            confidence: .init(amount: 1, date: 0.5, merchant: 0.5, subcategory: 0, tags: 0)
        )
        tx.paymentHint = hint
        tx.paymentHintAnswered = answered
        return tx
    }

    // MARK: - El borrador del chat

    @Test("«25 almuerzo yape» con dos cuentas en soles: el borrador sale con Yape y no pide la cuenta")
    func yapeAmongTwoAccountsInTheSameCurrency() throws {
        let context = try makeTestContext()
        let yape = account(context, "Yape", "PEN", .checking)
        _ = account(context, "Efectivo", "PEN", .cash)

        let draft = DraftBuilder.build(
            parsed: parsed(hint: "yape"), defaultCurrency: "PEN", context: context, sourceText: "25 almuerzo yape")

        #expect(draft.accountID == yape.persistentModelID)
        #expect(!draft.needsUserInput.contains("account"))
    }

    @Test("Control: la misma frase sin mención deja la cuenta por elegir (dos cuentas en soles)")
    func withoutMentionTheDraftAsks() throws {
        let context = try makeTestContext()
        _ = account(context, "Yape", "PEN", .checking)
        _ = account(context, "Efectivo", "PEN", .cash)

        let draft = DraftBuilder.build(
            parsed: parsed(hint: nil), defaultCurrency: "PEN", context: context, sourceText: "25 almuerzo")

        #expect(draft.accountID == nil)
        #expect(draft.needsUserInput.contains("account"))
    }

    @Test("Sin divisa dicha, la cuenta nombrada pone su divisa al borrador")
    func namedAccountSetsTheCurrency() throws {
        let context = try makeTestContext()
        let yape = account(context, "Yape", "PEN", .checking)
        _ = account(context, "Chase", "USD", .checking)

        let draft = DraftBuilder.build(
            parsed: parsed(hint: "yape"), defaultCurrency: "USD", context: context, sourceText: "25 almuerzo yape")

        #expect(draft.accountID == yape.persistentModelID)
        #expect(draft.currencyCode == "PEN")
    }

    @Test("Con otra divisa dicha, la cuenta nombrada no se fuerza: vuelve la regla por divisa")
    func dictatedCurrencyConflictFallsBack() throws {
        let context = try makeTestContext()
        _ = account(context, "Yape", "PEN", .checking)
        let chase = account(context, "Chase", "USD", .checking)

        let draft = DraftBuilder.build(
            parsed: parsed(currency: "USD", hint: "yape"), defaultCurrency: "PEN", context: context,
            sourceText: "25 dólares de almuerzo con yape")

        #expect(draft.accountID == chase.persistentModelID)
        #expect(draft.currencyCode == "USD")
    }

    @Test("El modelo no puede colar una cuenta que la frase no nombra")
    func hintNotInTheTextIsDropped() throws {
        let context = try makeTestContext()
        _ = account(context, "Yape", "PEN", .checking)
        _ = account(context, "Efectivo", "PEN", .cash)

        let draft = DraftBuilder.build(
            parsed: parsed(hint: "yape"), defaultCurrency: "PEN", context: context, sourceText: "25 almuerzo")

        #expect(draft.accountID == nil)
    }

    @Test("Sin el campo (gateway sin desplegar), un solo movimiento: se encuentra «yape» en la frase")
    func fallbackWithoutTheField() throws {
        let context = try makeTestContext()
        let yape = account(context, "Yape", "PEN", .checking)
        _ = account(context, "Efectivo", "PEN", .cash)

        let draft = DraftBuilder.build(
            parsed: parsed(hint: nil, answered: nil), defaultCurrency: "PEN", context: context,
            sourceText: "25 almuerzo yape")

        #expect(draft.accountID == yape.persistentModelID)
    }

    @Test("Una cuenta archivada o de Grupos no se elige aunque se llame igual")
    func archivedAndSystemAreNotCandidates() throws {
        let context = try makeTestContext()
        let archived = account(context, "Yape", "PEN", .checking)
        archived.isArchived = true
        let system = account(context, "Yape grupo", "PEN", .checking)
        system.isSystemAccount = true
        _ = account(context, "Efectivo", "PEN", .cash)
        _ = account(context, "BCP", "PEN", .checking)

        let draft = DraftBuilder.build(
            parsed: parsed(hint: "yape"), defaultCurrency: "PEN", context: context, sourceText: "25 almuerzo yape")

        #expect(draft.accountID == nil)
    }

    // MARK: - La lectura del modelo

    @Test("La respuesta con paymentHint lo trae; con null dice que contestó; sin el campo, que no")
    func parserReadsThePresenceOfTheField() throws {
        let parser = TranscriptionParserService()
        func wrap(_ fields: String) -> String { #"{"transactions":[{"# + fields + "}]}" }
        let base = #""amount":25,"date":"2026-11-04","note":"almuerzo","isExpense":true,"subcategoryHint":null,"tagHints":[],"currencyHint":null,"confidence":{"amount":1,"date":0.5,"merchant":0.5,"subcategory":0,"tags":0}"#

        let withHint = try parser.parseMultipleResponse(wrap(base + #","paymentHint":"yape""#))
        #expect(withHint.first?.paymentHint == "yape")
        #expect(withHint.first?.paymentHintAnswered == true)

        let withNull = try parser.parseMultipleResponse(wrap(base + #","paymentHint":null"#))
        #expect(withNull.first?.paymentHint == nil)
        #expect(withNull.first?.paymentHintAnswered == true)

        let without = try parser.parseMultipleResponse(wrap(base))
        #expect(without.first?.paymentHint == nil)
        #expect(without.first?.paymentHintAnswered == false)
    }

    @Test("Un pendiente de Siri guardado antes de este cambio se sigue leyendo")
    func oldSiriPendingStillDecodes() throws {
        let json = #"{"amount":25,"note":"almuerzo","isExpense":true,"tagHints":[],"confidence":{"amount":1,"date":0.5,"merchant":0.5,"subcategory":0,"tags":0}}"#
        let decoded = try JSONDecoder().decode(ParsedTransaction.self, from: Data(json.utf8))
        #expect(decoded.paymentHint == nil)
        #expect(decoded.paymentHintAnswered == nil)
    }

    @Test("El prompt pide el medio de pago, con su ejemplo «25 almuerzo yape»")
    func promptAsksForThePaymentMethod() {
        let prompt = TranscriptionParserService().buildSystemPrompt(
            expenseSubcategories: ["Restaurantes"], incomeSubcategories: [], currency: .unknown)
        #expect(prompt.contains("Reglas de medio de pago"))
        #expect(prompt.contains("Input: \"25 almuerzo yape\""))
        #expect(prompt.contains("\"paymentHint\":\"yape\""))
    }
}
