//
//  UITestDemoAccountLogicTests.swift
//  YalaTests
//
//  La cuenta de las demos de foto y voz sin red (`UITestDemoAccountLogic`). Cuentas sin contexto: la lógica es pura.
//

import Foundation
import Testing

@testable import Yala

@MainActor
struct UITestDemoAccountLogicTests {
    private func account(_ name: String, _ currency: String, _ type: AccountType,
                         archived: Bool = false, system: Bool = false) -> Account {
        let a = Account(name: name, currencyCode: currency, colorHex: "#000000", iconName: "x", type: type.rawValue)
        a.isArchived = archived
        a.isSystemAccount = system
        return a
    }

    @Test func singleAccountInTheCurrency_isTheDemoAccountForBoth() {
        let main = account("Main", "PEN", .checking)
        let accounts = [main, account("Savings", "USD", .savings)]
        #expect(UITestDemoAccountLogic.account(for: .photo, among: accounts, currencyCode: "PEN") === main)
        #expect(UITestDemoAccountLogic.account(for: .voice, among: accounts, currencyCode: "pen") === main)
    }

    @Test func severalAccounts_photoTakesChecking_voiceTakesTheCreditCard() {
        let main = account("Main", "USD", .checking)
        let cash = account("Cash", "USD", .cash)
        let card = account("Card", "USD", .creditCard)
        let accounts = [cash, card, main, account("Travel", "EUR", .savings)]
        #expect(UITestDemoAccountLogic.account(for: .photo, among: accounts, currencyCode: "USD") === main)
        #expect(UITestDemoAccountLogic.account(for: .voice, among: accounts, currencyCode: "USD") === card)
    }

    @Test func severalAccounts_withoutASingleOfTheType_leavesItToThePerson() {
        let accounts = [account("A", "USD", .checking), account("B", "USD", .checking), account("Cash", "USD", .cash)]
        #expect(UITestDemoAccountLogic.account(for: .photo, among: accounts, currencyCode: "USD") == nil)
        #expect(UITestDemoAccountLogic.account(for: .voice, among: accounts, currencyCode: "USD") == nil)
    }

    @Test func archivedAndSystemAccounts_doNotCount() {
        let main = account("Main", "USD", .checking)
        let accounts = [main, account("Old card", "USD", .creditCard, archived: true),
                        account("Grupos USD", "USD", .creditCard, system: true)]
        #expect(UITestDemoAccountLogic.account(for: .voice, among: accounts, currencyCode: "USD") === main,
                "Solo queda una cuenta viva en dólares")
    }
}
