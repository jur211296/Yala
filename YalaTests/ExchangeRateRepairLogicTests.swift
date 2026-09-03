//
//  ExchangeRateRepairLogicTests.swift
//  YalaTests
//
//  Paso 2 de `fx-partial-rate-rows-silent-1to1`: qué transacción ya guardada se reabre.
//

import Foundation
import Testing

@testable import Yala

struct ExchangeRateRepairLogicTests {

    /// El caso que el barrido existe para arreglar: divisas distintas y tasa 1.0. Solo puede haber
    /// salido del 1:1 silencioso.
    @Test func differentCurrenciesWithRateOne_isRepaired() {
        #expect(ExchangeRateRepairLogic.needsRepair(
            exchangeRate: 1.0, currencyCode: "JPY", preferredCurrencyCode: "PEN"))
    }

    /// **La aserción que evita convertir el barrido en un desastre.** `exchangeRate == 1.0` es
    /// legítimo cuando origen y destino coinciden, que es la inmensa mayoría de las transacciones de
    /// cualquiera. Sin este filtro, el barrido reabriría el corpus entero y —como `exchangeRate` viaja
    /// por el canal nube en el grupo `money`— lo emitiría entero también.
    @Test func sameCurrencyWithRateOne_isLeftAlone() {
        #expect(!ExchangeRateRepairLogic.needsRepair(
            exchangeRate: 1.0, currencyCode: "PEN", preferredCurrencyCode: "PEN"))
    }

    /// Las divisas se comparan sin distinguir mayúsculas: el corpus trae códigos de importaciones CSV
    /// y de la nube, y un "pen" contra "PEN" reabriría una fila sana.
    @Test func sameCurrencyInDifferentCase_isStillTheSame() {
        #expect(!ExchangeRateRepairLogic.needsRepair(
            exchangeRate: 1.0, currencyCode: "pen", preferredCurrencyCode: "PEN"))
    }

    /// Una tasa real distinta de 1.0 ya se convirtió: no es candidata, venga de donde venga.
    @Test func anyOtherRate_isNotACandidate() {
        #expect(!ExchangeRateRepairLogic.needsRepair(
            exchangeRate: 3.75, currencyCode: "USD", preferredCurrencyCode: "PEN"))
        #expect(!ExchangeRateRepairLogic.needsRepair(
            exchangeRate: 0.0, currencyCode: "USD", preferredCurrencyCode: "PEN"))
    }
}
