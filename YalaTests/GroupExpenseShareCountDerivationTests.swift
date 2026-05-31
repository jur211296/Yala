//
//  GroupExpenseShareCountDerivationTests.swift
//  YalaTests
//
//  Pure-logic tests para `GroupExpenseViewModel.deriveShareCounts(from:)`.
//
//  Bug cubierto: al editar un gasto de grupo dividido por `.shares` con proporciones
//  desiguales (p.ej. 3:1), el prefill hardcodeaba `sharesCounts[id] = "1"` para todos
//  los miembros → al guardar, el split se rebalanceaba silenciosamente a partes iguales,
//  corrompiendo las deudas. El fix reconstruye los conteos enteros desde los montos
//  persistidos en `SplitShare` (proporcionales al conteo): divide cada monto por el menor
//  monto positivo (la "parte unitaria") y redondea, tolerando el ±1 céntimo de redondeo
//  que `adjustLastForRounding` reparte.
//
//  Solo construye `@Model` `SplitShare` en memoria (sin ModelContext ni container) y lee
//  sus propiedades `memberID`/`amount` puestas en el init — sin SwiftData I/O ni UI.
//

import Foundation
import Testing

@testable import Yala

@MainActor
struct GroupExpenseShareCountDerivationTests {

    private func share(_ memberID: String, _ amount: Double) -> SplitShare {
        SplitShare(memberID: memberID, amount: amount)
    }

    // MARK: - Bug case: proporciones desiguales se preservan (no reset a 1:1)

    @Test func derivesUnequalRatio3to1FromAmounts() {
        // Total 100, partes 3:1 => 75 / 25. Parte unitaria 25 => 3 / 1.
        let result = GroupExpenseViewModel.deriveShareCounts(from: [
            share("alice", 75.0),
            share("bob", 25.0),
        ])
        #expect(result["alice"] == "3")
        #expect(result["bob"] == "1")
    }

    @Test func derivesThreeWayUnequalRatio() {
        // 20 / 40 / 60 => parte unitaria 20 => 1:2:3.
        let result = GroupExpenseViewModel.deriveShareCounts(from: [
            share("a", 20.0),
            share("b", 40.0),
            share("c", 60.0),
        ])
        #expect(result["a"] == "1")
        #expect(result["b"] == "2")
        #expect(result["c"] == "3")
    }

    // MARK: - Correct case: montos iguales => partes iguales

    @Test func equalAmountsYieldEqualSingleShares() {
        let result = GroupExpenseViewModel.deriveShareCounts(from: [
            share("a", 50.0),
            share("b", 50.0),
        ])
        #expect(result["a"] == "1")
        #expect(result["b"] == "1")
    }

    // Regresión (code-review): un reparto equitativo 1:1:1 de un monto no divisible exacto
    // queda persistido como 33.33/33.33/33.34 por `adjustLastForRounding`. La heurística por
    // monto-base debe recuperar 1/1/1 — NO los céntimos crudos 3333/3333/3334 que daba el GCD.
    @Test func equalThreeWayWithRoundingRemainderYieldsOnes() {
        let result = GroupExpenseViewModel.deriveShareCounts(from: [
            share("a", 33.33),
            share("b", 33.33),
            share("c", 33.34),
        ])
        #expect(result["a"] == "1")
        #expect(result["b"] == "1")
        #expect(result["c"] == "1")
    }

    @Test func fractionalRatioOneToTwoYieldsSmallIntegers() {
        // 33.33 / 66.67 (≈ 1:2). Parte unitaria 33.33 => 1 / 2 (no 3333 / 6667).
        let result = GroupExpenseViewModel.deriveShareCounts(from: [
            share("a", 33.33),
            share("b", 66.67),
        ])
        #expect(result["a"] == "1")
        #expect(result["b"] == "2")
    }

    // MARK: - Edge cases

    @Test func emptySharesYieldEmptyMap() {
        let result = GroupExpenseViewModel.deriveShareCounts(from: [])
        #expect(result.isEmpty)
    }

    @Test func allZeroAmountsFallBackToOneWithoutCrash() {
        // Sin monto positivo => fallback "1" por miembro (nunca peor que el estado previo).
        let result = GroupExpenseViewModel.deriveShareCounts(from: [
            share("a", 0.0),
            share("b", 0.0),
        ])
        #expect(result["a"] == "1")
        #expect(result["b"] == "1")
    }
}
