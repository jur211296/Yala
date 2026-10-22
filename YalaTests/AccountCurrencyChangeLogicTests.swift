//
//  AccountCurrencyChangeLogicTests.swift
//  YalaTests
//
//  Qué se puede hacer con la divisa de una cuenta según lo que cuelgue de ella.
//  Ticket `changing-an-account-currency-orphans-its-whole-history`.
//
//  Lógica pura: sin `ModelContext` y sin `@MainActor`. La decisión de qué frena un cambio de divisa
//  no depende de SwiftData, y montarle un contenedor la ataría al reuso por `#fileID` sin ganar nada.
//

import Foundation
import Testing

@testable import Yala

@Suite("La divisa de una cuenta: cuándo se puede cambiar")
struct AccountCurrencyChangeLogicTests {

    private typealias Logic = AccountCurrencyChangeLogic
    private typealias Row = AccountCurrencyChangeLogic.RowShape

    /// Una fila corriente: ni transferencia, ni grupo.
    private var plain: Row { Row() }

    // MARK: - Sin histórico

    @Test func sinMovimientos_laDivisaEsLibre() {
        #expect(Logic.verdict(for: []) == .free)
    }

    // MARK: - Todo convertible

    @Test func soloFilasCorrientes_pideConversion() {
        #expect(Logic.verdict(for: [plain, plain, plain]) == .needsConversion(rowCount: 3))
    }

    @Test func elConteoEsElDeFilasReales_noUnBooleano() {
        // Siete y no una: si alguien devolviera `.needsConversion(rowCount: 1)` como centinela, o
        // contara solo las no bloqueadas de una lista sin bloqueadas, este número lo delata.
        let rows = Array(repeating: plain, count: 7)
        #expect(Logic.verdict(for: rows) == .needsConversion(rowCount: 7))
    }

    // MARK: - Motivos de bloqueo, uno a uno

    @Test func transferenciaPorTipo_bloquea() {
        let rows = [Row(isTransferType: true)]
        #expect(Logic.verdict(for: rows) == .blocked(reasons: [.transfer], blockedCount: 1))
    }

    /// El caso que fija por qué se miran los DOS campos de transferencia y no solo el tipo.
    ///
    /// Al desligar un par, `NewTransactionViewModel` deja el `transferPairID` en `nil` conservando el
    /// tipo — y la simetría contraria existe igual. Preguntar por uno solo dejaría pasar la mitad de
    /// las formas de «esto es media transferencia». Si alguien reduce el `||` a un solo campo, este
    /// test o su hermano de arriba se pone rojo.
    @Test func transferenciaSoloPorPairID_bloquea() {
        let rows = [Row(hasTransferPairID: true)]
        #expect(Logic.verdict(for: rows) == .blocked(reasons: [.transfer], blockedCount: 1))
    }

    @Test func gastoDeGrupo_bloquea() {
        let rows = [Row(hasSplitExpenseID: true)]
        #expect(Logic.verdict(for: rows) == .blocked(reasons: [.groupExpense], blockedCount: 1))
    }

    @Test func liquidacionDeGrupo_bloquea() {
        let rows = [Row(hasSplitSettlementID: true)]
        #expect(Logic.verdict(for: rows) == .blocked(reasons: [.groupSettlement], blockedCount: 1))
    }

    // MARK: - Basta una

    /// El corazón de la política: cinco filas convertibles y **una** que no, y el veredicto es
    /// bloqueo. Convertir las cinco y dejar la sexta produciría una cuenta con el histórico partido
    /// entre dos divisas — el bug original, más pequeño y más difícil de ver.
    ///
    /// El `blockedCount` es 1 sobre 6 a propósito: un `.needsConversion(rowCount: 6)` o un
    /// `.blocked(blockedCount: 6)` fallan los dos.
    @Test func unaSolaFilaBloqueada_bloqueaElConjunto() {
        let rows = [plain, plain, Row(isTransferType: true), plain, plain, plain]
        #expect(Logic.verdict(for: rows) == .blocked(reasons: [.transfer], blockedCount: 1))
    }

    @Test func variosMotivos_seReportanTodos() {
        let rows = [
            plain,
            Row(isTransferType: true),
            Row(hasSplitExpenseID: true),
            Row(hasSplitSettlementID: true),
        ]
        #expect(
            Logic.verdict(for: rows)
                == .blocked(
                    reasons: [.transfer, .groupExpense, .groupSettlement],
                    blockedCount: 3
                )
        )
    }

    // MARK: - Precedencia del motivo

    /// Una fila puede cumplir varias condiciones a la vez. Cuál se enseña no cambia el veredicto,
    /// pero sí el texto que lee el usuario, así que conviene que sea estable y el más concreto.
    @Test func liquidacionGanaAGasto_cuandoLaFilaEsLasDos() {
        let row = Row(hasSplitExpenseID: true, hasSplitSettlementID: true)
        #expect(Logic.blockReason(for: row) == .groupSettlement)
    }

    @Test func grupoGanaATransferencia_cuandoLaFilaEsLasDos() {
        let row = Row(isTransferType: true, hasSplitExpenseID: true)
        #expect(Logic.blockReason(for: row) == .groupExpense)
    }

    @Test func filaCorriente_noTieneMotivo() {
        #expect(Logic.blockReason(for: plain) == nil)
    }
}
