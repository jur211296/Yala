//
//  ZeroChangeSignTests.swift
//  YalaTests
//
//  Card «El neto del mes del flujo de caja y la variación del widget de Saldo ponen signo o flecha a un cero» (mismo
//  origen que «€ -0.00» de Cuentas, `ZeroBalanceSignTests`). Una cifra que se pinta como cero no lleva signo, ni flecha
//  de subida o bajada, ni «te faltan»:
//
//  - la cápsula del mes del flujo de caja escribía «+0» con un neto exacto de 0 y «-0» con un residuo negativo;
//  - el rótulo del mes y el resumen del plan decían «te faltan S/ 0.00» con un residuo negativo;
//  - la píldora de variación de los widgets de Saldo y de Entradas y salidas elegía la flecha con `> 0` y el tono con
//    `abs(change) >= 0.5`: medio sol se pinta «S/ 0» (redondeo al par) y salía con flecha.
//
//  Cada caso lleva su control: lo que SÍ se pinta distinto de cero conserva su signo. La extensión de widgets no se
//  compila en `YalaTests`, así que su cableado se fija por su código (regla de `testing.md`).
//

import Foundation
import Testing

@testable import Yala

@MainActor
@Suite("Una variación o un neto que se pinta como cero no lleva signo ni flecha")
struct ZeroChangeSignTests {

    private let floatResidue = -1e-9

    // MARK: - Cápsula del mes del flujo de caja

    @Test func capsule_exactZero_hasNoPlus() {
        #expect(CashFlowMonthSummaryLogic.capsuleNetText(0) == "0")
    }

    @Test func capsule_negativeResidue_hasNoMinus() {
        #expect(CashFlowMonthSummaryLogic.capsuleNetText(floatResidue) == "0")
        #expect(CashFlowMonthSummaryLogic.capsuleNetText(-0.4) == "0")
        #expect(CashFlowMonthSummaryLogic.capsuleNetText(0.4) == "0")
    }

    @Test func capsule_realAmounts_keepTheirSign() {
        #expect(CashFlowMonthSummaryLogic.capsuleNetText(5) == "+5")
        #expect(CashFlowMonthSummaryLogic.capsuleNetText(-5) == "-5")
        #expect(CashFlowMonthSummaryLogic.capsuleNetText(-0.6) == "-1")
    }

    // MARK: - «Te sobran / te faltan»

    @Test func shortfall_residueIsNotAShortfall_aRealOneIs() {
        #expect(!CashFlowMonthSummaryLogic.isShortfall(floatResidue))
        #expect(!CashFlowMonthSummaryLogic.isShortfall(0))
        #expect(CashFlowMonthSummaryLogic.isShortfall(-0.01))
        #expect(CashFlowMonthSummaryLogic.isShortfall(-5))
    }

    // MARK: - Dirección de una variación del widget

    @Test func shownSign_zeroAndResidues_point_nowhere() {
        let locale = Locale(identifier: "en_US")
        #expect(WidgetAmountSplitter.shownSign(of: 0, fractionDigits: 0, locale: locale) == 0)
        #expect(WidgetAmountSplitter.shownSign(of: floatResidue, fractionDigits: 0, locale: locale) == 0)
        #expect(WidgetAmountSplitter.shownSign(of: 0.3, fractionDigits: 0, locale: locale) == 0)
        // Medio sol se pinta «0» (redondeo al par): con `abs(change) >= 0.5` salía con flecha de subida.
        #expect(WidgetAmountSplitter.shownSign(of: 0.5, fractionDigits: 0, locale: locale) == 0)
        #expect(WidgetAmountSplitter.shownSign(of: -0.5, fractionDigits: 0, locale: locale) == 0)
    }

    @Test func shownSign_realChanges_keepTheirDirection() {
        let locale = Locale(identifier: "en_US")
        #expect(WidgetAmountSplitter.shownSign(of: 1, fractionDigits: 0, locale: locale) == 1)
        #expect(WidgetAmountSplitter.shownSign(of: 1.5, fractionDigits: 0, locale: locale) == 1)
        #expect(WidgetAmountSplitter.shownSign(of: -0.6, fractionDigits: 0, locale: locale) == -1)
        #expect(WidgetAmountSplitter.shownSign(of: -320, fractionDigits: 0, locale: locale) == -1)
    }
}

@Suite("Widgets · la flecha y el tono de una variación salen de lo que se pinta (cableado)")
struct ZeroChangeSignWidgetWiringTests {

    private static func source(_ relative: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
    }

    /// Código sin comentarios, una línea por sentencia y sin sangría.
    private static func codeOnly(_ text: String) -> String {
        text.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("//") }
            .joined(separator: "\n")
    }

    private static func scope(_ text: String, from start: String, to end: String) throws -> String {
        let lower = try #require(text.range(of: start), "No encuentro «\(start)»")
        let upper = try #require(text.range(of: end, range: lower.upperBound..<text.endIndex), "No encuentro «\(end)»")
        return String(text[lower.lowerBound..<upper.lowerBound])
    }

    @Test("Saldo y Entradas y salidas deciden tono y flecha con lo que se pinta",
          arguments: ["YalaWidgets/Widgets/BalanceWidget.swift", "YalaWidgets/Widgets/CashFlowWidget.swift"])
    func balanceAndFlow_decideFromTheShownSign(file: String) throws {
        let code = Self.codeOnly(try Self.source(file))
        let tone = try Self.scope(code, from: "var changeDirection: Int {", to: "default: return .neutral")
        #expect(tone.contains("return WidgetAmountSplitter.shownSign(of: change, fractionDigits: 0)"))
        #expect(tone.contains("switch changeDirection {\ncase 1: return .good\ncase -1: return .bad"))
        #expect(code.contains(
            "systemImage: entry.changeDirection == 0 ? \"equal\" : (entry.changeDirection > 0 ? \"arrow.up\" : \"arrow.down\"),"
        ))
        #expect(!code.contains("change > 0 ? \"arrow.up\""))
        #expect(!code.contains("abs(change) >= 0.5"))
    }

    @Test("La lectura de VoiceOver del widget de Saldo no pone signo a un cero")
    func balanceAccessibility_signFollowsTheShownDirection() throws {
        let code = Self.codeOnly(try Self.source("YalaWidgets/Widgets/BalanceWidget.swift"))
        #expect(code.contains("(entry.changeDirection > 0 ? \"+\" : entry.changeDirection < 0 ? \"-\" : \"\")"))
        #expect(!code.contains("(change > 0 ? \"+\" : change < 0 ? \"-\" : \"\")"))
    }

    @Test("La lectura de VoiceOver del widget de Gastos no pone signo a un «0 %»")
    func expenseAccessibility_zeroPercentHasNoSign() throws {
        let code = Self.codeOnly(try Self.source("YalaWidgets/Widgets/ExpenseWidget.swift"))
        let helper = try Self.scope(code, from: "static func signedPercent(_ fraction: Double) -> String {", to: "var hasChart")
        #expect(helper.contains("guard shown != Double(0).formatted(.percent.precision(.fractionLength(0))) else { return shown }"))
        #expect(code.contains("ExpenseEntry.signedPercent(fraction),"))
        #expect(!code.contains("(fraction >= 0 ? \"+\" : \"-\") + abs(fraction)"))
    }

    @Test("La cápsula del mes y el resumen del plan usan la lógica del cero")
    func cashFlowViews_useTheZeroAwareLogic() throws {
        let capsule = Self.codeOnly(try Self.source("Yala/App/Views/Reports/CashFlow/CashFlowMonthCapsule.swift"))
        #expect(capsule.contains("CashFlowMonthSummaryLogic.capsuleNetText(month.netFlow)"))
        let setup = Self.codeOnly(try Self.source("Yala/App/Views/Reports/CashFlow/CashFlowSetupView.swift"))
        // Desde la decisión 33 de 2.3 el resumen decide por `CashFlowSetupLogic.summaryOutcome`, que sigue preguntando a
        // la lógica del cero (y suma «Falta tu ingreso» cuando no hay ingresos a la vista).
        #expect(setup.contains("CashFlowSetupLogic.summaryOutcome("))
        #expect(setup.contains("case .shortfall(let amount):"))
        let setupLogic = Self.codeOnly(try Self.source("Yala/App/Logic/CashFlowSetupLogic.swift"))
        #expect(setupLogic.contains("return CashFlowMonthSummaryLogic.isShortfall(net) ? .shortfall(abs(net)) : .surplus(abs(net))"))
        let logic = Self.codeOnly(try Self.source("Yala/App/Logic/CashFlowMonthSummaryLogic.swift"))
        #expect(logic.contains("let surplus = !isShortfall(month.netFlow)"))
    }
}
