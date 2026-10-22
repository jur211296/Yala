//
//  ApplePayAmountParser.swift
//  Yala
//
//  Parseo PURO (sin SwiftData) del monto/divisa que envía la automatización de Apple Pay.
//  Extraído de `ApplePayTransactionIntent.parseAmountAndCurrency` para poder correr en dos
//  lados sin base de datos:
//   - el intent lo usa para formatear la notificación (background, sin container),
//   - `ApplePayDraftService` lo usa al materializar el borrador — y ahí resuelve la divisa
//     ambigua `$`/`kr` contra las cuentas del usuario (eso sí necesita `context`).
//
//  Ver `Bugs/applepay-shortcut-ios27-warm-launch-datos-vacios`.
//

import Foundation

enum ApplePayAmountParser {

    struct Parsed: Equatable {
        /// Valor numérico parseado. El signo lo aplica el consumidor (Apple Pay siempre es gasto →
        /// `-abs(amount)`), así que aquí se devuelve tal cual sale del texto.
        let amount: Double
        /// Divisa detectada por símbolo o por código de 3 letras al final. Para `$`/`kr` es el
        /// default del símbolo (USD/NOK) y `ambiguousSymbol` queda no-nil para refinarla luego.
        let currency: String?
        /// `"$"` o `"kr"` si el símbolo detectado es ambiguo (podría refinarse por la cuenta del
        /// usuario); `nil` si la divisa es inequívoca (símbolo único o código explícito al final).
        let ambiguousSymbol: String?
    }

    /// Parseo puro: detecta símbolo prefijado, código de divisa al final ("25 ARS") y el valor
    /// numérico (formato europeo o americano). NO toca SwiftData. `nil` si no hay número parseable.
    nonisolated static func parse(_ text: String) -> Parsed? {
        // Symbols ordered by priority (más específicos primero — "MX$" antes de "$")
        let prefixedSymbols: [(symbol: String, code: String)] = [
            ("MX$", "MXN"), ("COP$", "COP"), ("R$", "BRL"),
            ("A$", "AUD"), ("C$", "CAD"), ("NZ$", "NZD"), ("HK$", "HKD"),
            ("S/.", "PEN"), ("S/", "PEN"),
            ("€", "EUR"), ("£", "GBP"), ("¥", "JPY"),
            ("Fr", "CHF"), ("₣", "CHF"),
            ("kr", "NOK"),  // Ambiguo (NOK/SEK/DKK) — resolver por account
            ("$", "USD")     // Ambiguo (USD/ARS/CLP/MXN/etc) — resolver por account
        ]

        var detectedCurrency: String?
        var detectedSymbol: String?

        for entry in prefixedSymbols {
            if text.contains(entry.symbol) {
                detectedCurrency = entry.code
                detectedSymbol = entry.symbol
                break
            }
        }

        // Trailing currency code: "25.00 ARS" → ARS (override de símbolo ambiguo, inequívoco).
        // Se valida contra `CurrencyCode` (divisas soportadas): sin esto, cualquier palabra de 3
        // caracteres se tomaba como código ("kr 150" → "150"; "$50 FEE" → "FEE"), corrompiendo la
        // divisa. Solo un código ISO real de una divisa soportada hace override.
        let words = text.components(separatedBy: .whitespaces)
        if let lastWord = words.last,
           lastWord.count == 3,
           CurrencyCode(rawValue: lastWord.uppercased()) != nil {
            detectedCurrency = lastWord.uppercased()
            detectedSymbol = nil
        }

        // Símbolos ambiguos ($ y kr): NO se resuelven aquí (requiere las cuentas del usuario).
        // Se reporta el símbolo para que `ApplePayDraftService` lo refine con `context`.
        let ambiguousSymbol: String? = (detectedSymbol == "$" || detectedSymbol == "kr") ? detectedSymbol : nil

        // Extract numeric value
        var cleaned = text.replacingOccurrences(of: "[^\\d.,\\-]", with: "", options: .regularExpression)

        // Handle European format (comma as decimal separator)
        if cleaned.contains(",") {
            if !cleaned.contains(".") {
                // Only comma: 25,50 -> 25.50
                cleaned = cleaned.replacing(",", with: ".")
            } else if let commaIndex = cleaned.lastIndex(of: ","),
                      let dotIndex = cleaned.lastIndex(of: "."),
                      commaIndex > dotIndex {
                // Comma after dot: 1.234,56 -> 1234.56
                cleaned = cleaned.replacing(".", with: "")
                cleaned = cleaned.replacing(",", with: ".")
            } else {
                // Dot after comma: 1,234.56 -> 1234.56 (US format with thousands separator)
                cleaned = cleaned.replacing(",", with: "")
            }
        }

        guard let amount = Double(cleaned) else {
            return nil
        }

        return Parsed(amount: amount, currency: detectedCurrency, ambiguousSymbol: ambiguousSymbol)
    }
}
