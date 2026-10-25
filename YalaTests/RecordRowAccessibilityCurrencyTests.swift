//
//  RecordRowAccessibilityCurrencyTests.swift
//  YalaTests
//
//  Card cvlu: VoiceOver leía un gasto en dongs con el símbolo de la divisa preferida («S/ 9.064.482,03»). El arreglo
//  entró en el lote 8 (47aa34f6c) y solo lo fijaba un escaneo de literales. Aquí se fija con un registro de verdad en
//  una divisa distinta de la preferida: con la etiqueta formateada en la preferida, el caso cae.
//

import Foundation
import Testing
@testable import Yala

@MainActor
@Suite("cvlu · VoiceOver lee el importe en la divisa del registro")
struct RecordRowAccessibilityCurrencyTests {

    private func makePrefs() throws -> AppPreferences {
        let defaults = try #require(UserDefaults(suiteName: "RecordRowAccessibilityCurrencyTests.\(UUID().uuidString)"))
        let prefs = AppPreferences(defaults: defaults)
        prefs.defaultCurrencyCode = .pen
        prefs.currencyDisplayFormat = .symbol
        return prefs
    }

    @Test("Un gasto en dongs se lee en dongs, no en soles")
    func foreignExpense_isReadInItsOwnCurrency() throws {
        let prefs = try makePrefs()
        let record = TransactionItem(date: .now, amount: -9_064_482.03, currencyCode: "VND", note: "QA-FX VND",
                                     amountInPreferredCurrency: -1_250, preferredCurrencyCode: "PEN")

        let label = RecordRowView.accessibilityDescription(for: record, appPreferences: prefs)

        let dong = prefs.currencyIdentifier(for: "VND")
        let sol = prefs.currencyIdentifier(for: "PEN")
        #expect(dong != sol, "El escenario no discrimina: las dos divisas pintan el mismo identificador.")
        #expect(label.contains(prefs.currency(9_064_482.03, currencyCode: "VND")), "\(label)")
        #expect(!label.contains(sol), "La etiqueta lleva el símbolo de la divisa preferida: \(label)")
    }

    @Test("Con el código en vez del símbolo, también la del registro")
    func foreignExpense_withCodeFormat_saysTheRecordCode() throws {
        let prefs = try makePrefs()
        prefs.currencyDisplayFormat = .code
        let record = TransactionItem(date: .now, amount: -40, currencyCode: "USD", preferredCurrencyCode: "PEN")

        let label = RecordRowView.accessibilityDescription(for: record, appPreferences: prefs)

        #expect(label.contains("USD"), "\(label)")
        #expect(!label.contains("PEN"), "\(label)")
    }
}
