//
//  LiveAnchorEducationLogicTests.swift
//  YalaTests
//
//  «Hoy ⓘ» solo abre «Tu saldo hoy» cuando hay una diferencia por tipo de cambio que explicar
//  (auditoría UX 2.2, lote 3, B1). Con todo el dinero en la divisa principal, la hoja decía
//  «Tienes dinero en otras monedas» a quien no tenía.
//

import Foundation
import Testing

@testable import Yala

@MainActor
struct LiveAnchorEducationLogicTests {

    @Test func soloDivisaPrincipal_noAbreLaHoja() {
        #expect(!LiveAnchorEducationLogic.explainsCurrencyDifference(["PEN": 1800], preferredCurrencyCode: "PEN"))
    }

    @Test func sinDesglose_noAbreLaHoja() {
        #expect(!LiveAnchorEducationLogic.explainsCurrencyDifference(nil, preferredCurrencyCode: "PEN"))
    }

    @Test func principalMasOtraConSaldo_abreLaHoja() {
        #expect(LiveAnchorEducationLogic.explainsCurrencyDifference(
            ["PEN": -25_663, "USD": 33_615], preferredCurrencyCode: "PEN"
        ))
    }

    /// Una sola divisa en el desglose, pero no es la principal: el valor de hoy y la suma histórica
    /// sí se separan. Contar divisas (`count > 1`) lo dejaría fuera.
    @Test func soloOtraDivisa_abreLaHoja() {
        #expect(LiveAnchorEducationLogic.explainsCurrencyDifference(["USD": 500], preferredCurrencyCode: "PEN"))
    }

    /// Movió todo el dinero de dólares a soles: el desglose trae USD a cero y no hay nada que explicar.
    @Test func otraDivisaACero_noAbreLaHoja() {
        #expect(!LiveAnchorEducationLogic.explainsCurrencyDifference(
            ["PEN": 1800, "USD": 0], preferredCurrencyCode: "PEN"
        ))
    }
}
