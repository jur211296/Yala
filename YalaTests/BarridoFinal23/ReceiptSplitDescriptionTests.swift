//
//  ReceiptSplitDescriptionTests.swift
//  YalaTests
//
//  Card 120i (detalles menores del barrido final de 2.3): Yala IA en Grupos repartía bien un gasto escrito, pero dejaba la
//  descripción vacía —un texto escrito no trae comercio— y guardar fallaba con «Falta la descripción». Ahora, sin comercio,
//  la descripción son las líneas leídas.
//

import Foundation
import Testing

@testable import Yala

@Suite("Barrido final 2.3 · Yala IA en Grupos no deja la descripción vacía")
struct ReceiptSplitDescriptionTests {

    private func line(_ text: String, _ kind: ReceiptLineKind = .item) -> ReceiptSplitLine {
        ReceiptSplitLine(description: text, amount: 10, kind: kind, assignees: [], extraShare: .excluded, needsReview: false)
    }

    @Test("Con comercio, el comercio")
    func merchant_wins() {
        #expect(ReceiptSplitLogic.expenseDescription(merchant: "  Cusco Grill ", lines: [line("Lomo")]) == "Cusco Grill")
    }

    @Test("Sin comercio (lo escrito), las líneas de consumo, sin extras ni repetidas")
    func withoutMerchant_usesTheItems() {
        let lines = [line("Pizza"), line("Chicha"), line("Pizza"), line("Servicio 10 %", .service), line("  ")]
        #expect(ReceiptSplitLogic.expenseDescription(merchant: nil, lines: lines) == "Pizza, Chicha")
        #expect(ReceiptSplitLogic.expenseDescription(merchant: "   ", lines: [line("Taxi")]) == "Taxi")
    }

    @Test("Una lista larga se corta con «…» y nunca queda vacía si hay algo leído")
    func longList_isCut() {
        let lines = (1...12).map { line("Plato número \($0)") }
        let text = ReceiptSplitLogic.expenseDescription(merchant: nil, lines: lines)
        #expect(text.count <= ReceiptSplitLogic.descriptionLimit)
        #expect(text.hasSuffix("…"))
        #expect(text.hasPrefix("Plato número 1, "))
    }

    @Test("Sin comercio ni líneas de consumo, una de las líneas que haya")
    func onlyExtras_fallsBackToAnyLine() {
        #expect(ReceiptSplitLogic.expenseDescription(merchant: nil, lines: [line("Propina", .tip)]) == "Propina")
        #expect(ReceiptSplitLogic.expenseDescription(merchant: nil, lines: []) == "")
    }

    @Test("La hoja usa esta descripción al pasar el reparto al formulario")
    func wiring() throws {
        let view = try BarridoFinal23Source.code("Yala/App/Views/Groups/Captura/GroupCaptureModel.swift")
        #expect(view.contains("let description = ReceiptSplitLogic.expenseDescription(merchant: merchant, lines: lines)"))
    }
}
