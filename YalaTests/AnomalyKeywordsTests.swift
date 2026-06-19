//
//  AnomalyKeywordsTests.swift
//  YalaTests
//
//  Cobertura del matcher multi-idioma — el plan acepta sobreincluir (falsos positivos
//  son baratos), por eso los assertions están sesgados hacia "matchea cuando hay
//  cualquier señal".
//

import Testing
@testable import Yala

struct AnomalyKeywordsTests {

    // MARK: - Spanish (with and without diacritics)

    @Test func spanish_withTilde_matches() {
        #expect(AnomalyKeywords.matches("¿Hay algo extraño este mes?"))
    }

    @Test func spanish_withoutTilde_matches() {
        #expect(AnomalyKeywords.matches("¿Hay algo extrano este mes?"))
    }

    @Test func spanish_anomalia_matches() {
        #expect(AnomalyKeywords.matches("Quiero ver anomalías de gastos"))
    }

    @Test func spanish_atipico_matches() {
        #expect(AnomalyKeywords.matches("Mostrame gastos atípicos"))
    }

    @Test func spanish_neutral_doesNotMatch() {
        #expect(!AnomalyKeywords.matches("¿Cuánto gasté en transporte?"))
    }

    @Test func spanish_keywordInMiddle_matches() {
        #expect(AnomalyKeywords.matches("hubo algo raro en mis compras de marzo"))
    }

    // MARK: - English

    @Test func english_unusual_matches() {
        #expect(AnomalyKeywords.matches("Any unusual spending lately?"))
    }

    @Test func english_outlier_matches() {
        #expect(AnomalyKeywords.matches("Show me outliers in my expenses"))
    }

    @Test func english_neutral_doesNotMatch() {
        #expect(!AnomalyKeywords.matches("How much did I spend on food?"))
    }

    // MARK: - Other languages

    @Test func german_ungewohnlich_matches() {
        // German "ungewöhnlich" → folded "ungewohnlich"
        #expect(AnomalyKeywords.matches("Gibt es ungewöhnliche Ausgaben?"))
    }

    @Test func french_inhabituel_matches() {
        #expect(AnomalyKeywords.matches("Y a-t-il des dépenses inhabituelles?"))
    }

    @Test func italian_insolito_matches() {
        #expect(AnomalyKeywords.matches("Ci sono spese insolite questo mese?"))
    }

    @Test func portuguese_incomum_matches() {
        #expect(AnomalyKeywords.matches("Há alguma despesa incomum?"))
    }

    // MARK: - Edge cases

    @Test func emptyQuestion_doesNotMatch() {
        #expect(!AnomalyKeywords.matches(""))
    }

    @Test func uppercase_matches() {
        #expect(AnomalyKeywords.matches("¿ALGO RARO ESTE MES?"))
    }

    @Test func acceptedFalsePositive_atipicamente() {
        // "atípicamente buen mes" — semantically NOT about anomalies, but we accept
        // the false positive (over-including is cheap, missing real anomalies isn't)
        #expect(AnomalyKeywords.matches("fue un mes atípicamente bueno"))
    }
}
