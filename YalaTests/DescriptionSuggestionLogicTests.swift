//
//  DescriptionSuggestionLogicTests.swift
//  YalaTests
//
//  Nuevo registro · sugerencias de descripción (card 2.3 `tablero-nuevo-registro-sugerencias-de-descripcio-y6du`).
//

import Foundation
import Testing

@testable import Yala

@Suite("Sugerencias de descripción")
struct DescriptionSuggestionLogicTests {

    private let base = Date(timeIntervalSince1970: 1_780_000_000)
    private func at(_ days: Int) -> Date { base.addingTimeInterval(Double(days) * 86_400) }

    private var index: [DescriptionSuggestionEntry] {
        DescriptionSuggestionLogic.buildIndex(rows: [
            ("Uber", at(1), false), ("uber", at(2), false), ("Uber", at(3), false),
            ("Uber Eats", at(10), false),
            ("Supermercado Plaza Vea", at(4), false),
            ("Café con Ana", at(5), false), ("Café con Ana", at(6), false),
            ("Cafetería", at(9), false),
            ("Sueldo", at(7), true), ("Sueldo", at(8), true),
            ("  ", at(1), false),
        ])
    }

    private func suggest(_ q: String, income: Bool = false) -> [String] {
        DescriptionSuggestionLogic.suggestions(for: q, isIncome: income, in: index)
    }

    @Test("Una letra no sugiere nada; dos sí")
    func longitudMinima() {
        #expect(suggest("u").isEmpty)
        #expect(suggest("ub") == ["Uber", "Uber Eats"])
    }

    @Test("Propone la grafía más usada, sin repetir por mayúsculas")
    func grafiaMasUsada() {
        #expect(suggest("UB").first == "Uber")
        #expect(suggest("ub").filter { $0.lowercased() == "uber" }.count == 1)
    }

    @Test("Sin tildes ni mayúsculas: «cafe» encuentra «Café con Ana»")
    func sinTildes() {
        #expect(suggest("cafe") == ["Café con Ana", "Cafetería"])
    }

    @Test("Lo más usado va primero; a igualdad, lo más reciente")
    func orden() {
        // «Café con Ana» (2 veces) antes que «Cafetería» (1 vez, aunque más reciente).
        #expect(suggest("caf") == ["Café con Ana", "Cafetería"])
        // «Uber» (3) antes que «Uber Eats» (1, más reciente).
        #expect(suggest("ube") == ["Uber", "Uber Eats"])
    }

    @Test("Empieza por una palabra antes que contener")
    func palabraAntesQueContiene() {
        // «plaza» empieza una palabra de «Supermercado Plaza Vea»; «erca» solo está dentro.
        #expect(suggest("plaza") == ["Supermercado Plaza Vea"])
        #expect(suggest("erca") == ["Supermercado Plaza Vea"])
    }

    @Test("Lo ya escrito igual no se repite")
    func noRepiteLoEscrito() {
        #expect(suggest("uber") == ["Uber Eats"])
        #expect(suggest("Uber Eats").isEmpty)
    }

    @Test("Cada lado con lo suyo: un ingreso no sugiere gastos")
    func porLado() {
        #expect(suggest("su", income: true) == ["Sueldo"])
        #expect(suggest("su", income: false) == ["Supermercado Plaza Vea"])
    }

    @Test("Como mucho cinco")
    func tope() {
        let rows = (0..<8).map { ("Taxi \($0)", at($0), false) }
        let idx = DescriptionSuggestionLogic.buildIndex(rows: rows)
        #expect(DescriptionSuggestionLogic.suggestions(for: "tax", isIncome: false, in: idx).count == 5)
    }

    @Test("Transferencias y ajustes no entran en el índice")
    func excluyeTransferencias() {
        let cuenta = Account(name: "A", currencyCode: "PEN", colorHex: "#000000", iconName: "creditcard", type: "bank")
        let gasto = TransactionItem(date: at(1), amount: -10, currencyCode: "PEN", note: "Pasaje", account: cuenta)
        let transfer = TransactionItem(date: at(1), amount: -10, currencyCode: "PEN", note: "Pasar a ahorros", account: cuenta)
        transfer.balanceAdjustmentType = TransactionItem.adjustmentTypeTransfer
        let idx = DescriptionSuggestionLogic.buildIndex(from: [gasto, transfer])
        #expect(DescriptionSuggestionLogic.suggestions(for: "pas", isIncome: false, in: idx) == ["Pasaje"])
    }
}
