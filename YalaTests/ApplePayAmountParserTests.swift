//
//  ApplePayAmountParserTests.swift
//  YalaTests
//
//  Tests del parseo PURO (sin SwiftData) del monto/divisa de Apple Pay, extraído del intent
//  para poder correr sin base de datos. Ver ApplePayAmountParser.
//

import Foundation
import Testing

@testable import Yala

struct ApplePayAmountParserTests {

    @Test func dollar_isDetectedAsUSDAndAmbiguous() {
        let parsed = ApplePayAmountParser.parse("$32.04")
        #expect(parsed != nil)
        #expect(abs((parsed?.amount ?? 0) - 32.04) < 0.001)
        #expect(parsed?.currency == "USD")
        #expect(parsed?.ambiguousSymbol == "$")   // $ es ambiguo (USD/ARS/CLP/…) → refina la app
    }

    @Test func euro_isUnambiguous() {
        let parsed = ApplePayAmountParser.parse("€25,50")
        #expect(abs((parsed?.amount ?? 0) - 25.50) < 0.001)
        #expect(parsed?.currency == "EUR")
        #expect(parsed?.ambiguousSymbol == nil)
    }

    @Test func soles_prefixIsUnambiguous() {
        let parsed = ApplePayAmountParser.parse("S/ 25.90")
        #expect(abs((parsed?.amount ?? 0) - 25.90) < 0.001)
        #expect(parsed?.currency == "PEN")
        #expect(parsed?.ambiguousSymbol == nil)
    }

    @Test func mexicanPeso_specificPrefixWinsOverDollar() {
        // "MX$" se evalúa antes que "$" → MXN, no ambiguo (aunque el texto contenga "$").
        let parsed = ApplePayAmountParser.parse("MX$100.00")
        #expect(abs((parsed?.amount ?? 0) - 100.00) < 0.001)
        #expect(parsed?.currency == "MXN")
        #expect(parsed?.ambiguousSymbol == nil)
    }

    @Test func trailingCode_overridesAndIsUnambiguous() {
        let parsed = ApplePayAmountParser.parse("25.00 ARS")
        #expect(abs((parsed?.amount ?? 0) - 25.00) < 0.001)
        #expect(parsed?.currency == "ARS")
        #expect(parsed?.ambiguousSymbol == nil)
    }

    @Test func krona_isAmbiguous() {
        let parsed = ApplePayAmountParser.parse("kr 150")
        #expect(abs((parsed?.amount ?? 0) - 150) < 0.001)
        #expect(parsed?.currency == "NOK")
        #expect(parsed?.ambiguousSymbol == "kr")
    }

    @Test func europeanThousands_parsedCorrectly() {
        // 1.234,56 → 1234.56
        let parsed = ApplePayAmountParser.parse("€1.234,56")
        #expect(abs((parsed?.amount ?? 0) - 1234.56) < 0.001)
    }

    @Test func usThousands_parsedCorrectly() {
        // 1,234.56 → 1234.56
        let parsed = ApplePayAmountParser.parse("$1,234.56")
        #expect(abs((parsed?.amount ?? 0) - 1234.56) < 0.001)
        #expect(parsed?.currency == "USD")
    }

    @Test func onlyComma_treatedAsDecimal() {
        // 25,50 (solo coma) → 25.50
        let parsed = ApplePayAmountParser.parse("25,50")
        #expect(abs((parsed?.amount ?? 0) - 25.50) < 0.001)
    }

    @Test func noNumber_returnsNil() {
        #expect(ApplePayAmountParser.parse("sin monto") == nil)
        #expect(ApplePayAmountParser.parse("") == nil)
    }

    @Test func trailingWord_notACurrency_isIgnored() {
        // "$50 FEE" — "FEE" no es una divisa ISO soportada → NO hace override; queda USD (símbolo
        // $) y ambiguo. Evita que una palabra de 3 letras corrompa la divisa.
        let parsed = ApplePayAmountParser.parse("$50 FEE")
        #expect(abs((parsed?.amount ?? 0) - 50) < 0.001)
        #expect(parsed?.currency == "USD")
        #expect(parsed?.ambiguousSymbol == "$")
    }

    @Test func trailingLowercaseCode_isNormalized() {
        // "25 ars" — código en minúscula: se valida contra CurrencyCode y se normaliza a "ARS".
        let parsed = ApplePayAmountParser.parse("25 ars")
        #expect(parsed?.currency == "ARS")
        #expect(parsed?.ambiguousSymbol == nil)
    }

    @Test func zeroAmount_parsesButIsCaughtByCaller() {
        // El parser SÍ parsea "0" (es puro); el guard de "no es gasto real" vive en el intent/
        // servicio (parsed.amount != 0). Documenta el contrato.
        let parsed = ApplePayAmountParser.parse("$0.00")
        #expect(parsed?.amount == 0)
    }
}
