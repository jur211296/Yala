//
//  BalanceCalculatorInputLogicTests.swift
//  YalaTests
//
//  Ticket `reopened-balance-calculator-reads-a-grouped-amount-as-zero`: al reabrir la calculadora del saldo en el
//  onboarding con 1.000 o más, el campo traía «1,800.00» y la calculadora leía 0.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Calculadora del saldo · el campo prefijado se lee igual que se escribe")
struct BalanceCalculatorInputLogicTests {

    /// El camino entero del onboarding: el saldo calculado se guarda en el campo manual con el formato del idioma
    /// (`formatWithGrouping`), se vuelve a leer con ese formato (`parseDecimal`), se prefija la calculadora y la
    /// calculadora lo lee. Con el prefijado de antes (`formatWithGrouping` también en la calculadora) da 0.
    @Test("1.800 sobrevive a reabrir la calculadora", arguments: ["es_PE", "es_ES", "en_US", "de_DE"])
    func reopenKeepsTheAmount(localeID: String) {
        let locale = Locale(identifier: localeID)
        let manualField = AmountInputHelper.formatWithGrouping(1800, locale: locale)
        let amount = AmountInputHelper.parseDecimal(manualField, locale: locale)
        #expect(amount == 1800)

        let calculatorField = BalanceCalculatorInputLogic.prefillText(for: amount)
        #expect(BalanceCalculatorInputLogic.parse(calculatorField) == 1800)
    }

    @Test("Control: el campo con separador de miles es justo lo que la calculadora no entiende")
    func groupedTextIsTheBug() {
        let grouped = AmountInputHelper.formatWithGrouping(1800, locale: Locale(identifier: "es_PE"))
        #expect(grouped == "1,800.00")
        #expect(BalanceCalculatorInputLogic.parse(grouped) == 0)
    }

    @Test("El prefijado no lleva separador de miles y solo lleva decimales si los hay")
    func prefillFormat() {
        #expect(BalanceCalculatorInputLogic.prefillText(for: 1800) == "1800")
        #expect(BalanceCalculatorInputLogic.prefillText(for: 1_234_567.5) == "1234567.50")
        #expect(BalanceCalculatorInputLogic.prefillText(for: 12.05) == "12.05")
        #expect(BalanceCalculatorInputLogic.prefillText(for: -300) == "300")
    }

    @Test("Lo que teclea la persona se sigue leyendo igual")
    func typedInputStillParses() {
        #expect(BalanceCalculatorInputLogic.parse("12,5") == 12.5)
        #expect(BalanceCalculatorInputLogic.parse("1800.25") == 1800.25)
        #expect(BalanceCalculatorInputLogic.parse("") == 0)
    }

    // MARK: - Cableado

    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()

    private static func code(_ relative: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(relative), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    @Test("El onboarding prefija con el formato de la calculadora y la calculadora lee con la misma lógica")
    func wiring() throws {
        let onboarding = try Self.code("Yala/App/Views/Onboarding/OnboardingView.swift")
        let inicio = try #require(onboarding.range(of: "private func prefillCalculatorFromInitialBalance()"))
        let fin = try #require(onboarding.range(of: "switch selectedAccountType", range: inicio.upperBound..<onboarding.endIndex))
        let cuerpo = onboarding[inicio.upperBound..<fin.lowerBound]
        #expect(cuerpo.contains("BalanceCalculatorInputLogic.prefillText(for: amount)"))
        #expect(!cuerpo.contains("formatWithGrouping"))

        let sheet = try Self.code("Yala/App/Views/Shared/BalanceCalculatorSheet.swift")
        #expect(sheet.contains("BalanceCalculatorInputLogic.parse(text)"))
    }
}
