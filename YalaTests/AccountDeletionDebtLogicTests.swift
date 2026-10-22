//
//  AccountDeletionDebtLogicTests.swift
//  YalaTests
//
//  D5 (§3.3.4 del estudio MODO-NUBE-GESTION-DATOS-UX): lógica PURA del aviso de "Eliminar mi cuenta".
//  Tablas para (1) la detección agregada de saldos pendientes del usuario y (2) la composición de las
//  líneas del diálogo. Sin UI, sin SwiftData, sin singletons.
//

import Testing

@testable import Yala

@Suite
struct AccountDeletionDebtLogicTests {

    // MARK: - Detección de deudas (agregado sobre grupos)

    @Test func noGroups_zero() {
        #expect(AccountDeletionDebtLogic.groupsWithOutstandingBalance(perGroupUserNetBalances: []) == 0)
    }

    @Test func userNotParticipating_zero() {
        // Grupo donde el usuario no tiene ninguna entrada de balance.
        #expect(AccountDeletionDebtLogic.groupsWithOutstandingBalance(perGroupUserNetBalances: [[]]) == 0)
    }

    @Test func zeroBalance_zero() {
        #expect(AccountDeletionDebtLogic.groupsWithOutstandingBalance(perGroupUserNetBalances: [[0.0]]) == 0)
    }

    @Test func belowEpsilon_zero() {
        // 0.005 < epsilon (0.01) → no cuenta (residuo de redondeo).
        #expect(AccountDeletionDebtLogic.groupsWithOutstandingBalance(perGroupUserNetBalances: [[0.005]]) == 0)
        #expect(AccountDeletionDebtLogic.groupsWithOutstandingBalance(perGroupUserNetBalances: [[-0.009]]) == 0)
    }

    @Test func exactlyEpsilon_excluded_strictGreaterThan() {
        // Umbral ESTRICTO (`abs > epsilon`): exactamente 0.01 NO cuenta; apenas por encima sí.
        #expect(AccountDeletionDebtLogic.groupsWithOutstandingBalance(perGroupUserNetBalances: [[0.01]]) == 0)
        #expect(AccountDeletionDebtLogic.groupsWithOutstandingBalance(perGroupUserNetBalances: [[-0.01]]) == 0)
        #expect(AccountDeletionDebtLogic.groupsWithOutstandingBalance(perGroupUserNetBalances: [[0.0101]]) == 1)
    }

    @Test func positiveOverEpsilon_counts() {
        #expect(AccountDeletionDebtLogic.groupsWithOutstandingBalance(perGroupUserNetBalances: [[0.02]]) == 1)
    }

    @Test func negativeOwed_counts() {
        // Neto negativo = el usuario DEBE — cuenta igual (|net| > epsilon).
        #expect(AccountDeletionDebtLogic.groupsWithOutstandingBalance(perGroupUserNetBalances: [[-5.0]]) == 1)
    }

    @Test func mixedGroups_countsOnlyThoseWithDebt() {
        // g1 cero, g2 con deuda → 1.
        #expect(AccountDeletionDebtLogic.groupsWithOutstandingBalance(
            perGroupUserNetBalances: [[0.0], [10.0]]) == 1)
    }

    @Test func multipleGroupsWithDebt_countAll() {
        #expect(AccountDeletionDebtLogic.groupsWithOutstandingBalance(
            perGroupUserNetBalances: [[3.0], [-2.0]]) == 2)
    }

    @Test func multiCurrency_anyCurrencyOverEpsilon_counts() {
        // g1: dos monedas, ambas cero → no cuenta. g2: una moneda cero, otra sobre epsilon → cuenta.
        #expect(AccountDeletionDebtLogic.groupsWithOutstandingBalance(
            perGroupUserNetBalances: [[0.0, 0.005], [0.0, 0.02]]) == 1)
    }

    @Test func hasOutstandingBalance_matchesCount() {
        #expect(!AccountDeletionDebtLogic.hasOutstandingBalance(perGroupUserNetBalances: [[0.0], []]))
        #expect(AccountDeletionDebtLogic.hasOutstandingBalance(perGroupUserNetBalances: [[0.0], [0.5]]))
    }

    // MARK: - Composición de líneas del diálogo

    @Test func cloud_noDebt_noLegacy_baseCrossReferFrozen() {
        #expect(AccountDeletionMessageLogic.lines(
            isCloud: true, hasOutstandingDebt: false, hasLegacyCloudKitFootprint: false)
            == [.base, .crossRefer, .frozenICloud])
    }

    @Test func cloud_debt_noLegacy_insertsDebtBeforeCrossRefer() {
        #expect(AccountDeletionMessageLogic.lines(
            isCloud: true, hasOutstandingDebt: true, hasLegacyCloudKitFootprint: false)
            == [.base, .debtWarning, .crossRefer, .frozenICloud])
    }

    @Test func cloud_debt_legacy_allLinesInOrder() {
        #expect(AccountDeletionMessageLogic.lines(
            isCloud: true, hasOutstandingDebt: true, hasLegacyCloudKitFootprint: true)
            == [.base, .debtWarning, .crossRefer, .frozenICloud, .legacyFootprint])
    }

    @Test func groupsOnly_noDebt_noLegacy_noFrozenLine() {
        // Solo-grupos (personal aún en .icloud) → sin línea de copia congelada.
        #expect(AccountDeletionMessageLogic.lines(
            isCloud: false, hasOutstandingDebt: false, hasLegacyCloudKitFootprint: false)
            == [.base, .crossRefer])
    }

    @Test func groupsOnly_debt_legacy_debtAndLegacyButNoFrozen() {
        #expect(AccountDeletionMessageLogic.lines(
            isCloud: false, hasOutstandingDebt: true, hasLegacyCloudKitFootprint: true)
            == [.base, .debtWarning, .crossRefer, .legacyFootprint])
    }

    @Test func baseAlwaysFirst_crossReferAlwaysPresent() {
        for isCloud in [true, false] {
            for debt in [true, false] {
                for legacy in [true, false] {
                    let lines = AccountDeletionMessageLogic.lines(
                        isCloud: isCloud, hasOutstandingDebt: debt, hasLegacyCloudKitFootprint: legacy)
                    #expect(lines.first == .base)
                    #expect(lines.contains(.crossRefer))
                    #expect(lines.contains(.frozenICloud) == isCloud)
                    #expect(lines.contains(.debtWarning) == debt)
                    #expect(lines.contains(.legacyFootprint) == legacy)
                }
            }
        }
    }
}
