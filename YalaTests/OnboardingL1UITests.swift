//
//  OnboardingL1UITests.swift
//  YalaTests
//
//  La lógica de la pasada UI del lote 1 de la auditoría UX 2.2 (2026-10-13), variantes elegidas por Jürgen:
//   · L1UI-3 la calculadora «Todo junto» dice qué suma y qué resta, y el total sale de esos mismos términos.
//   · L1UI-8 la cuenta de «Todo junto» se llama «Mi dinero <Divisa>».
//

import Foundation
import Testing

@testable import Yala

@Suite("UX 2.2 · L1UI-3 · los signos de la calculadora")
struct BalanceCalculatorTermsLogicTests {

    private typealias Logic = BalanceCalculatorTermsLogic

    @Test("lo que debes resta; lo que tienes y lo que te deben suma")
    func signs() {
        #expect(Logic.sign(of: .bankAccounts) == .plus)
        #expect(Logic.sign(of: .savings) == .plus)
        #expect(Logic.sign(of: .cash) == .plus)
        #expect(Logic.sign(of: .othersOweMe) == .plus)
        #expect(Logic.sign(of: .creditCardSpending) == .minus)
        #expect(Logic.sign(of: .iOwe) == .minus)
    }

    @Test("«Todo junto» cuenta los seis campos, en el orden de la pantalla")
    func patrimonial_usesAllSixFieldsInScreenOrder() {
        #expect(Logic.fields(mindset: "patrimonial")
                == [.bankAccounts, .savings, .cash, .creditCardSpending, .othersOweMe, .iOwe])
    }

    @Test("el disponible solo cuenta lo que tienes, aunque quede algo escrito en las deudas")
    func cashFlow_ignoresDebtFields() {
        #expect(Logic.fields(mindset: "cashFlow") == [.bankAccounts, .savings, .cash])
        let terms = Logic.terms(mindset: "cashFlow", amounts: [
            .bankAccounts: 100, .savings: 50, .cash: 10, .creditCardSpending: 999, .iOwe: 999
        ])
        #expect(Logic.total(terms) == 160)
    }

    @Test("el ejemplo de la auditoría: 1200 + 800 + 150 − 450 + 100 − 0 = 1800")
    func auditExample_totalsTheFormula() {
        let terms = Logic.terms(mindset: "patrimonial", amounts: [
            .bankAccounts: 1200, .savings: 800, .cash: 150, .creditCardSpending: 450, .othersOweMe: 100
        ])
        #expect(terms.map(\.amount) == [1200, 800, 150, 450, 100, 0])
        #expect(terms.map(\.sign) == [.plus, .plus, .plus, .minus, .plus, .minus])
        #expect(Logic.total(terms) == 1800)
    }

    @Test("con más deudas que dinero el total es negativo")
    func moreDebtThanMoney_isNegative() {
        let terms = Logic.terms(mindset: "patrimonial", amounts: [.cash: 100, .iOwe: 300])
        #expect(Logic.total(terms) == -200)
    }

    @Test("la vista suma con la lista de términos, no con una cuenta propia")
    func sheet_totalsWithTheTerms() throws {
        let source = try String(contentsOf: URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Yala/App/Views/Shared/BalanceCalculatorSheet.swift"), encoding: .utf8)
        #expect(source.contains("BalanceCalculatorTermsLogic.total(generalTerms)"))
        #expect(!source.contains("bank + savings + cash - creditSpending"))
    }
}

@Suite("UX 2.2 · L1UI-8 · el nombre de la primera cuenta")
struct OnboardingAccountNameLogicTests {

    private func name(_ mode: OnboardingUsageMode) -> String {
        OnboardingAccountNameLogic.suggestedName(
            mode: mode, accountTypeName: "Ahorros", currencyName: "Soles",
            allTogetherFormat: "Mi dinero %@", expensesWord: "Gastos")
    }

    @Test("«Todo junto» se llama «Mi dinero Soles»")
    func allTogether_isMyMoney() {
        #expect(name(.dayToDay) == "Mi dinero Soles")
    }

    @Test("«Solo anotar mis gastos» sigue en «Gastos Soles»")
    func expensesOnly_keepsExpenses() {
        #expect(name(.expensesOnly) == "Gastos Soles")
    }

    @Test("cada cuenta por separado lleva su tipo")
    func separate_keepsTheType() {
        #expect(name(.fullControl) == "Ahorros Soles")
    }

    @Test("la clave de «Mi dinero» lleva la divisa en los 16 idiomas")
    func allTogetherKey_hasThePlaceholderEverywhere() throws {
        let resources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Yala/Resources")
        let locales = try FileManager.default.contentsOfDirectory(atPath: resources.path)
            .filter { $0.hasSuffix(".lproj") && $0 != "Base.lproj" }
        #expect(locales.count == 16)
        for locale in locales {
            let url = resources.appendingPathComponent(locale).appendingPathComponent("Localizable.strings")
            let dict = try #require(NSDictionary(contentsOf: url) as? [String: String], "\(locale)")
            let value = try #require(dict["onboarding.accountName.allTogether"], "\(locale)")
            #expect(value.components(separatedBy: "%@").count == 2, "\(locale): \(value)")
        }
    }
}
