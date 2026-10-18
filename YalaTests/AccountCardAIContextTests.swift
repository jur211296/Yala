//
//  AccountCardAIContextTests.swift
//  YalaTests
//
//  Tarjeta con varias divisas, entrega 4 · Paso 0 D5: el contexto de Yala IA describe la tarjeta UNA vez, con sus líneas
//  dentro y el total convertido, en vez de dos cuentas sueltas que el modelo podía sumar en crudo. Las cuentas sin líneas
//  dan el mismo JSON que antes.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite(.serialized)
@MainActor
struct AccountCardAIContextTests {

    private func context(fixedRate: Decimal = 3.7) throws -> (FullFinancialContext, Account, Account) {
        let model = try makeTestContext()
        let card = Account(name: "Visa QA", currencyCode: "PEN", colorHex: "#3D36B3", iconName: "creditcard.fill", type: "creditCard")
        let line = Account(name: "Visa QA · USD", currencyCode: "USD", colorHex: "#3D36B3", iconName: "creditcard.fill", type: "creditCard")
        line.parentAccountID = card.shortcutID
        let dollars = Account(name: "Dólares QA", currencyCode: "USD", colorHex: "#FF7F11", iconName: "dollarsign.circle.fill", type: "savings")
        [card, line, dollars].forEach { model.insert($0) }
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        let txs = [
            TransactionItem(date: now, amount: -1_250, currencyCode: "PEN", account: card, amountInPreferredCurrency: -1_250),
            TransactionItem(date: now, amount: -80, currencyCode: "USD", account: line, amountInPreferredCurrency: -296),
            TransactionItem(date: now, amount: 255, currencyCode: "USD", account: dollars, amountInPreferredCurrency: 943.5),
        ]
        txs.forEach { model.insert($0) }
        try model.save()
        let built = FullFinancialContextBuilder().buildFromArrays(
            transactions: txs, budgets: [], accounts: [card, line, dollars], tags: [], scheduledPayments: [],
            currencyCode: "PEN", currencyDisplay: "S/", converter: MockCurrencyConverter(fixedRate: fixedRate),
            language: "es", country: "PE", includeAnomalies: false, now: now)
        return (built, card, line)
    }

    @Test("La tarjeta sale una vez, con su línea dentro y el total en soles marcado como aproximado")
    func cardIsDescribedOnceWithItsLines() throws {
        let (built, _, _) = try context()
        let accounts = built.balances.accounts
        #expect(accounts.map(\.name) == ["Visa QA", "Dólares QA"])

        let card = try #require(accounts.first { $0.name == "Visa QA" })
        #expect(card.balance == -1_250)
        #expect(card.currency == "PEN")
        #expect(card.lines == [FullFinancialContext.LineEntry(name: "Visa QA · USD", balance: -80, currency: "USD")])
        let total = try #require(card.cardTotal)
        #expect(abs(total - (-1_250 - 80 * 3.7)) < 0.0001)
        #expect(card.cardTotalIsApproximate == true)
    }

    @Test("Una cuenta sin líneas no escribe los campos nuevos: su JSON es el de antes")
    func plainAccountJSONIsUnchanged() throws {
        let (built, _, _) = try context()
        let dollars = try #require(built.balances.accounts.first { $0.name == "Dólares QA" })
        #expect(dollars.lines == nil)
        #expect(dollars.cardTotal == nil)
        let json = try #require(String(data: try JSONEncoder().encode(dollars), encoding: .utf8))
        #expect(!json.contains("lines"))
        #expect(!json.contains("card_total"))

        let cardEntry = try #require(built.balances.accounts.first { $0.name == "Visa QA" })
        let cardJSON = try #require(String(data: try JSONEncoder().encode(cardEntry), encoding: .utf8))
        #expect(cardJSON.contains("\"lines\""))
        #expect(cardJSON.contains("\"card_total\""))
        #expect(cardJSON.contains("\"card_total_is_approximate\":true"))
    }

    @Test("El saldo total no cambia: sigue sumando las mismas cuentas")
    func totalBalanceIsUnchanged() throws {
        let (built, _, _) = try context()
        // −1.250 PEN + (−80 + 255) USD × 3,7 = −602,50
        #expect(abs(built.balances.totalBalance - (-1_250 + 175 * 3.7)) < 0.0001)
    }

    @Test("Una línea archivada sale aparte y no entra en el total de la tarjeta, como en el Panel")
    func archivedLineIsListedApart() throws {
        let model = try makeTestContext()
        let card = Account(name: "Visa QA", currencyCode: "PEN", colorHex: "#3D36B3", iconName: "creditcard.fill", type: "creditCard")
        let line = Account(name: "Visa QA · USD", currencyCode: "USD", colorHex: "#3D36B3", iconName: "creditcard.fill", type: "creditCard")
        line.parentAccountID = card.shortcutID
        line.isArchived = true
        [card, line].forEach { model.insert($0) }
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        let txs = [
            TransactionItem(date: now, amount: -1_000, currencyCode: "PEN", account: card, amountInPreferredCurrency: -1_000),
            TransactionItem(date: now, amount: -100, currencyCode: "USD", account: line, amountInPreferredCurrency: -370),
        ]
        txs.forEach { model.insert($0) }
        try model.save()
        let built = FullFinancialContextBuilder().buildFromArrays(
            transactions: txs, budgets: [], accounts: [card, line], tags: [], scheduledPayments: [],
            currencyCode: "PEN", currencyDisplay: "S/", converter: MockCurrencyConverter(fixedRate: 3.7),
            language: "es", country: "PE", includeAnomalies: false, now: now)
        let entries = built.balances.accounts
        #expect(entries.map(\.name) == ["Visa QA", "Visa QA · USD"])
        let head = try #require(entries.first { $0.name == "Visa QA" })
        #expect(head.lines == nil)
        #expect(head.cardTotal == nil)
        #expect(entries.first { $0.name == "Visa QA · USD" }?.balance == -100)
    }
}
