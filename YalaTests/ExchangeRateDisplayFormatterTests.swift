//
//  ExchangeRateDisplayFormatterTests.swift
//  YalaTests
//
//  Cómo se escribe un tipo de cambio en pantalla. Tickets
//  `exchange-rate-detail-shows-zero-for-low-denomination-currencies` y
//  `widget-de-tc-no-localiza-separadores`.
//
//  La tasa se guarda como «divisa preferida por unidad de divisa nativa». Con cuatro decimales fijos
//  (`String(format: "%.4f")`, el código de antes) VND→USD salía «0.0000» y el widget escribía
//  «3.8000» con punto a quien lee «3,8». Control rojo: con el cuerpo de `string(_:locale:)` vuelto a
//  `String(format: "%.4f", rate)`, caen todos los casos de denominación baja y todos los de `es`.
//

import Foundation
import Testing

@testable import Yala

@Suite("Formato de tipos de cambio")
struct ExchangeRateDisplayFormatterTests {

    private static let es = Locale(identifier: "es")
    private static let en = Locale(identifier: "en")

    /// Tasas reales «preferida (USD) por unidad nativa», las del ticket más JPY, KWD y PEN.
    struct Case: Sendable, CustomTestStringConvertible {
        let pair: String
        let rate: Double
        let es: String
        let en: String
        var testDescription: String { pair }
    }

    static let againstUSD: [Case] = [
        Case(pair: "VND→USD", rate: 0.0000408163, es: "0,00004082", en: "0.00004082"),
        Case(pair: "IDR→USD", rate: 0.0000632911, es: "0,00006329", en: "0.00006329"),
        Case(pair: "KRW→USD", rate: 0.0007407407, es: "0,0007407", en: "0.0007407"),
        Case(pair: "JPY→USD", rate: 0.0066666667, es: "0,006667", en: "0.006667"),
        Case(pair: "KWD→USD", rate: 3.2534, es: "3,2534", en: "3.2534"),
        // El caso normal no cambia de forma: cuatro cifras, como antes.
        Case(pair: "PEN→USD", rate: 0.2666667, es: "0,2667", en: "0.2667"),
    ]

    @Test("Contra USD, en español", arguments: againstUSD)
    func againstUSD_es(_ c: Case) {
        #expect(ExchangeRateDisplayFormatter.string(c.rate, locale: Self.es) == c.es)
    }

    @Test("Contra USD, en inglés", arguments: againstUSD)
    func againstUSD_en(_ c: Case) {
        #expect(ExchangeRateDisplayFormatter.string(c.rate, locale: Self.en) == c.en)
    }

    @Test("El widget escribe «3,80» en español y «3.80» en inglés, como la hoja de ganancia cambiaria")
    func widgetRateUsesTheLocaleSeparator() throws {
        #expect(ExchangeRateDisplayFormatter.string(3.8, locale: Self.es) == "3,80")
        #expect(ExchangeRateDisplayFormatter.string(3.8, locale: Self.en) == "3.80")
        // La hoja de ganancia cambiaria escribe con el mismo formateador: no pueden divergir.
        let decimal = try #require(Decimal(string: "3.8"))
        #expect(FXPnLDetailSheet.rateString(decimal) == ExchangeRateDisplayFormatter.string(3.8))
    }

    @Test("Una tasa grande no pierde la parte entera y lleva separador de miles")
    func largeRateKeepsTheIntegerPart() {
        #expect(ExchangeRateDisplayFormatter.string(24_500.0, locale: Self.es) == "24.500,00")
        #expect(ExchangeRateDisplayFormatter.string(24_500.0, locale: Self.en) == "24,500.00")
        #expect(ExchangeRateDisplayFormatter.string(Double(24_512.3456), locale: Self.en) == "24,512.3456")
    }

    @Test("Ningún par de la tabla de divisas sale en cero ni pierde más del 0,1 %")
    func everyPairOfTheTableIsReadable() throws {
        let perUSD = CurrencyCode.fallbackRates
        let formatter = NumberFormatter()
        formatter.locale = Self.en
        formatter.numberStyle = .decimal
        var checked = 0
        for (native, nativePerUSD) in perUSD {
            for (preferred, preferredPerUSD) in perUSD where native != preferred {
                guard nativePerUSD > 0, preferredPerUSD > 0 else { continue }
                // preferida por unidad nativa, la dirección en que se guarda `exchangeRate`.
                let rate = preferredPerUSD / nativePerUSD
                let text = ExchangeRateDisplayFormatter.string(rate, locale: Self.en)
                let parsed = try #require(formatter.number(from: text)?.doubleValue, "\(native)→\(preferred): «\(text)»")
                #expect(parsed > 0, "\(native)→\(preferred) se lee «\(text)»")
                #expect(abs(parsed - rate) / rate < 0.001, "\(native)→\(preferred): \(rate) se lee «\(text)»")
                checked += 1
            }
        }
        #expect(checked > 2_000, "la tabla tiene que dar todos los pares, no un puñado")
    }

    @Test("Una tasa no finita no se escribe como número")
    func nonFiniteRate() {
        #expect(ExchangeRateDisplayFormatter.string(Double.nan) == "—")
        #expect(ExchangeRateDisplayFormatter.string(Double.infinity) == "—")
    }
}

@Suite("Cableado del formato de tipos de cambio (source-scan)")
struct ExchangeRateDisplayFormatterWiringTests {

    private static func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    /// Las pantallas que enseñan una tasa. `TransferAmountInputView` queda fuera a propósito: allí la
    /// tasa es un campo editable que se vuelve a parsear, y ya se invierte cuando es menor que 1.
    static let screens = [
        "Yala/App/Views/Records/TransactionDetailSheet.swift",
        "Yala/App/Views/Panel/ExchangeRateWidget.swift",
        "Yala/App/Views/Panel/Sheets/FXPnLDetailSheet.swift",
        "Yala/App/Views/Settings/CurrencySettingsView.swift",
        "Yala/App/Views/Settings/ExchangeRatesSheet.swift",
        "Yala/App/Views/Transactions/NewTransactionView.swift",
    ]

    @Test("Ninguna pantalla vuelve a los cuatro decimales fijos", arguments: screens)
    func noFixedFourDecimals(_ path: String) throws {
        let src = try Self.source(path)
        #expect(!src.contains("\"%.4f"), "\(path) vuelve a escribir una tasa con %.4f, que no localiza y borra VND→USD")
        #expect(src.contains("ExchangeRateDisplayFormatter.string("), "\(path) no usa el formateador de tasas")
    }
}
