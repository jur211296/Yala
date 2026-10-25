//
//  AccountDeletionDebtLogicTests.swift
//  YalaTests
//
//  D5 (§3.3.4 del estudio MODO-NUBE-GESTION-DATOS-UX): lógica PURA del aviso de "Eliminar mi cuenta".
//  Tabla de la composición de las
//  líneas del diálogo. Sin UI, sin SwiftData, sin singletons.
//

import Testing

@testable import Yala

@Suite
struct AccountDeletionDebtLogicTests {

    // La detección de deudas salió de aquí con la card aeae (2026-10-24): contar el saldo NETO con `abs > 0.01` tomaba
    // el residuo de redondeo por deuda. Ahora decide `GroupRoundingResidueLogic.memberHasOutstanding` (la misma fuente
    // que Saldos y Ajustes del grupo), y su recorrido contra SwiftData lo fija `AccountDeletionGroupsSummaryTests`.

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
