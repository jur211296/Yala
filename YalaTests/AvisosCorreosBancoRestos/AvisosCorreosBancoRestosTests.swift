//
//  AvisosCorreosBancoRestosTests.swift
//  YalaTests
//
//  Restos de «Avisos del banco» y «Correos del banco» (encargo del 24-nov-2026):
//  - El aviso de ejemplo de «Tu banco o app» va en la moneda que toca: soles con los bancos de Perú; fuera, la moneda
//    principal de Yala (o la de la región) y un comercio genérico. Antes decía «S/ 25.00 en Starbucks Larcomar» siempre.
//  - Los textos de la guía vieja de «Correos del banco» que ya no lee nadie no vuelven a los 16 idiomas.
//

import Foundation
import Testing

@testable import Yala

@Suite("Restos de Avisos y Correos del banco")
struct AvisosCorreosBancoRestosTests {

    // MARK: - Aviso de ejemplo según la región

    @Test func enPeru_elEjemploSigueEnSoles() {
        let text = BankNoticeChoiceLogic.sampleText(for: .other, regionCode: "PE", mainCurrencyCode: "PEN")
        #expect(text == BankNoticeSamples.text(for: .other))
        #expect(text.contains("S/ 25.00"))
    }

    @Test func conElSolComoMoneda_fueraDePeru_tambienEnSoles() {
        let text = BankNoticeChoiceLogic.sampleText(for: .other, regionCode: "US", mainCurrencyCode: "PEN")
        #expect(text.contains("S/ 25.00"))
    }

    @Test func enPeruConOtraMoneda_siguenLosBancosDePeruYElEjemploEnSoles() {
        let text = BankNoticeChoiceLogic.sampleText(for: .other, regionCode: "PE", mainCurrencyCode: "USD")
        #expect(text == BankNoticeSamples.text(for: .other))
    }

    @Test func enEstadosUnidos_elEjemploVaEnDolaresYSinComercioDeLima() {
        let text = BankNoticeChoiceLogic.sampleText(for: .other, regionCode: "US", mainCurrencyCode: "USD")
        #expect(text.contains("USD 25.00"))
        #expect(!text.contains("S/"))
        #expect(!text.uppercased().contains("LARCOMAR"))
        #expect(!text.uppercased().contains("STARBUCKS"))
        #expect(text.contains("CAFE CENTRAL"))
    }

    @Test(arguments: [("ES", "EUR", "EUR 25.00"), ("MX", "MXN", "MXN 25.00"), ("JP", "JPY", "JPY 25"), ("DE", "GBP", "GBP 25.00")])
    func fueraDePeru_mandaLaMonedaPrincipal(_ region: String, _ currency: String, _ expected: String) {
        let text = BankNoticeChoiceLogic.sampleText(for: .other, regionCode: region, mainCurrencyCode: currency)
        #expect(text.contains(expected), "\(region)/\(currency): \(text)")
    }

    @Test func sinMonedaPrincipal_usaLaDeLaRegion_ySinNadaDolares() {
        #expect(BankNoticeChoiceLogic.sampleCurrencyCode(regionCode: "FR", mainCurrencyCode: nil) == "EUR")
        #expect(BankNoticeChoiceLogic.sampleCurrencyCode(regionCode: nil, mainCurrencyCode: nil) == "USD")
        #expect(BankNoticeChoiceLogic.sampleCurrencyCode(regionCode: "us", mainCurrencyCode: "usd") == "USD")
    }

    @Test func losBancosDePeru_conservanSuEjemplo() {
        for bank in BankNoticeBank.allCases where bank != .other {
            #expect(BankNoticeChoiceLogic.sampleText(for: bank, regionCode: "US", mainCurrencyCode: "USD")
                == BankNoticeSamples.text(for: bank))
        }
    }

    /// La pantalla del banco enseña y prueba el ejemplo de la regla, no el fijo en soles.
    @Test func laPantallaDelBanco_usaElEjemploSegunLaRegion() throws {
        let view = try Self.source("Yala/App/Views/Settings/AtajoBanco/BankNoticeBankView.swift")
        #expect(!view.contains("BankNoticeSamples.text(for:"))
        #expect(view.contains("BankNoticeChoiceLogic.sampleText("))
        #expect(view.components(separatedBy: "sampleText.replacingOccurrences").count - 1 == 1)
        #expect(view.contains("text: sampleText, bankHint: bank"))
    }

    // MARK: - Textos viejos de la guía de Correos del banco

    static let retiredKeys = [
        "stepCopyTitle", "stepCopyDetail", "gmailAddTitle", "gmailAddDetail", "gmailConfirmTitle",
        "gmailConfirmWaiting", "gmailFilterTitle", "gmailFilterDetail", "ruleTitle", "outlookRuleDetail",
        "icloudRuleDetail", "stepWaitTitle", "stepWaitDetail", "gmailConfirmCode", "guideLine",
    ]

    @Test(arguments: SupportedLocale.allCases.map(\.code))
    func losTextosRetirados_noEstanEnNingunIdioma(_ code: String) {
        let strings = StringsFileParser.parseStrings(forLocale: code)
        #expect(strings["bankEmail.title"] != nil, "\(code): no se leyó el catálogo")
        for key in Self.retiredKeys {
            #expect(strings["bankEmail.\(key)"] == nil, "\(code): bankEmail.\(key) volvió")
        }
    }

    @Test func losTextosRetirados_noTienenAccesor() throws {
        let accessors = try Self.source("Yala/Utils/L10n+BankEmail.swift")
        for key in Self.retiredKeys {
            #expect(!accessors.contains("\"bankEmail.\(key)\""), "L10n.BankEmail.\(key) volvió")
        }
    }

    private static func source(_ relative: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
    }
}
