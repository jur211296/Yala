//
//  ApplePayCurrencyHintTests.swift
//  YalaTests
//
//  La pista de moneda de la notificación de Apple Pay dice la moneda en que la Bandeja enseñará el borrador (auditoría
//  UX 2.2, lote 15, L15-8): la notificación no puede decir una moneda y la Bandeja otra. La Bandeja enseña un borrador
//  pendiente en la moneda de su cuenta, o en la moneda por defecto si aún no tiene. Una tarjeta «Visa» en soles con su
//  línea en dólares, y una cuenta suelta en soles.
//

import Foundation
import SwiftData
import Testing
@testable import Yala

@Suite("Lote 15 · L15-8 La pista de moneda dice lo que enseñará la Bandeja", .serialized)
@MainActor
struct ApplePayCurrencyHintTests {

    /// Lo que enseña la Bandeja para un borrador creado con esa entrada: la moneda de su cuenta, o `nil` (la de por defecto).
    private func shownByTheInbox(
        _ raw: String, lastUsed: String?, accounts: [Account]
    ) throws -> String? {
        let parsed = try #require(ApplePayAmountParser.parse(raw))
        let (currency, card) = ApplePayDraftService.resolveCurrency(
            parsedCurrency: parsed.currency, ambiguousSymbol: parsed.ambiguousSymbol, lastUsedShortcutID: lastUsed, in: accounts)
        return ApplePayDraftService.matchedAccount(currency: currency, cardAccount: card, in: accounts)?.currencyCode
    }

    @Test func laPista_esLoQueEnsenaraLaBandeja() throws {
        let context = try makeTestContext()
        let card = makeTestAccount(context: context, name: "Visa", currencyCode: "PEN")
        let line = makeTestAccount(context: context, name: "Visa · USD", currencyCode: "USD")
        line.parentAccountID = card.shortcutID
        let savings = makeTestAccount(context: context, name: "Ahorros", currencyCode: "EUR")
        try context.save()
        let accounts = [card, line, savings]

        for lastUsed in [card.shortcutID.uuidString, line.shortcutID.uuidString, savings.shortcutID.uuidString, nil] {
            let hint = ApplePayDraftService.currencyHint(lastUsedShortcutID: lastUsed, accounts: accounts)
            #expect(hint.lastUsedAccountID == lastUsed)
            #expect(hint.noSymbolCurrency == (try shownByTheInbox("25.90", lastUsed: lastUsed, accounts: accounts)))
            #expect(hint.currencyBySymbol["$"] == (try shownByTheInbox("$25.90", lastUsed: lastUsed, accounts: accounts)))
            #expect(hint.currencyBySymbol["kr"] == (try shownByTheInbox("kr 25.90", lastUsed: lastUsed, accounts: accounts)))
        }

        // La tarjeta en soles: sin símbolo, soles; con `$`, su línea en dólares.
        let onCard = ApplePayDraftService.currencyHint(lastUsedShortcutID: card.shortcutID.uuidString, accounts: accounts)
        #expect(onCard.noSymbolCurrency == "PEN")
        #expect(onCard.currencyBySymbol["$"] == "USD")
        // Sin última cuenta usada: sin símbolo no hay cuenta (la moneda por defecto); `$` son dólares y hay una cuenta.
        let none = ApplePayDraftService.currencyHint(lastUsedShortcutID: nil, accounts: accounts)
        #expect(none.noSymbolCurrency == nil)
        #expect(none.currencyBySymbol["$"] == "USD")
    }

    /// Sin símbolo, el borrador toma la moneda de la última cuenta usada (antes quedaba sin moneda ni cuenta). Un código
    /// inequívoco manda.
    @Test func elBorrador_sinSimbolo_tomaLaMonedaDeLaUltimaCuentaUsada() throws {
        let context = try makeTestContext()
        let savings = makeTestAccount(context: context, name: "Ahorros", currencyCode: "PEN")
        try context.save()
        let id = savings.shortcutID.uuidString
        #expect(ApplePayDraftService.resolveCurrency(
            parsedCurrency: nil, ambiguousSymbol: nil, lastUsedShortcutID: id, in: [savings]).currency == "PEN")
        #expect(ApplePayDraftService.resolveCurrency(
            parsedCurrency: "EUR", ambiguousSymbol: nil, lastUsedShortcutID: id, in: [savings]).currency == "EUR")
        #expect(ApplePayDraftService.resolveCurrency(
            parsedCurrency: nil, ambiguousSymbol: nil, lastUsedShortcutID: nil, in: [savings]).currency == nil)
    }
}
