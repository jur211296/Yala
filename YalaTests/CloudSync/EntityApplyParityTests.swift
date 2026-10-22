//
//  EntityApplyParityTests.swift
//  YalaTests / CloudSync
//
//  Paridad apply↔emission (I8f-1, fix F-7 del review adversarial): para cada una de las 6 entidades
//  CABLEADAS, el set de appliers de `EntityApplyMap` debe ser EXACTAMENTE `EntityEmissionMap.columns`
//  menos `local_day` (derivada de `date`, sin storage local — única excepción declarada). Una columna
//  emitida SIN applier se DROPEA en silencio en el round-trip push→pull (pérdida invisible); un applier
//  sin columna emitida = drift del mapa. Ambas direcciones fallan aquí.
//

import Foundation
import Testing

@testable import Yala

@Suite("CloudSync · EntityApplyMap parity (I8f-1)")
@MainActor
struct EntityApplyParityTests {

    /// Columnas emitidas que NO tienen (ni deben tener) applier. Solo `local_day` (D-7).
    private let applyExempt: Set<String> = ["local_day"]

    private func assertParity<M>(
        _ emission: EntityEmission<M>, _ apply: EntityApply<M>,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        let expected = emission.columns.subtracting(applyExempt)
        let actual = Set(apply.appliers.keys)
        let missing = expected.subtracting(actual)   // emitida sin applier → se dropea en el round-trip
        let extra = actual.subtracting(expected)     // applier sin columna emitida → drift
        #expect(missing.isEmpty,
                "\(apply.table): columnas emitidas SIN applier (se dropearían): \(missing.sorted())",
                sourceLocation: sourceLocation)
        #expect(extra.isEmpty,
                "\(apply.table): appliers sin columna emitida (drift): \(extra.sorted())",
                sourceLocation: sourceLocation)
        // Y las tablas deben coincidir (el reverse map espeja el forward).
        #expect(emission.table == apply.table, sourceLocation: sourceLocation)
    }

    @Test func transactionItem_applyMatchesEmission() {
        assertParity(EntityEmissionMap.transactionItem, EntityApplyMap.transactionItem)
    }

    @Test func inboxDraft_applyMatchesEmission() {
        assertParity(EntityEmissionMap.inboxDraft, EntityApplyMap.inboxDraft)
    }

    @Test func category_applyMatchesEmission() {
        assertParity(EntityEmissionMap.category, EntityApplyMap.category)
    }

    @Test func favoritePayment_applyMatchesEmission() {
        assertParity(EntityEmissionMap.favoritePayment, EntityApplyMap.favoritePayment)
    }

    @Test func merchantMemory_applyMatchesEmission() {
        assertParity(EntityEmissionMap.merchantMemory, EntityApplyMap.merchantMemory)
    }

    @Test func exchangeRate_applyMatchesEmission() {
        assertParity(EntityEmissionMap.exchangeRate, EntityApplyMap.exchangeRate)
    }

    @Test func budget_applyMatchesEmission() {
        assertParity(EntityEmissionMap.budget, EntityApplyMap.budget)
    }

    @Test func scheduledPayment_applyMatchesEmission() {
        assertParity(EntityEmissionMap.scheduledPayment, EntityApplyMap.scheduledPayment)
    }

    // Commit B: las 8 restantes.
    @Test func account_applyMatchesEmission() {
        assertParity(EntityEmissionMap.account, EntityApplyMap.account)
    }

    @Test func subcategory_applyMatchesEmission() {
        assertParity(EntityEmissionMap.subcategory, EntityApplyMap.subcategory)
    }

    @Test func tag_applyMatchesEmission() {
        assertParity(EntityEmissionMap.tag, EntityApplyMap.tag)
    }

    @Test func notificationItem_applyMatchesEmission() {
        assertParity(EntityEmissionMap.notificationItem, EntityApplyMap.notificationItem)
    }

    @Test func cashFlowPlan_applyMatchesEmission() {
        assertParity(EntityEmissionMap.cashFlowPlan, EntityApplyMap.cashFlowPlan)
    }

    @Test func cashFlowLine_applyMatchesEmission() {
        assertParity(EntityEmissionMap.cashFlowLine, EntityApplyMap.cashFlowLine)
    }

    @Test func cashFlowOverride_applyMatchesEmission() {
        assertParity(EntityEmissionMap.cashFlowOverride, EntityApplyMap.cashFlowOverride)
    }

    @Test func groupBridgePreference_applyMatchesEmission() {
        assertParity(EntityEmissionMap.groupBridgePreference, EntityApplyMap.groupBridgePreference)
    }

    /// El groupByColumn del apply debe ser EL MISMO objeto lógico que el de emission (LWW por-unidad
    /// coherente con las unidades que viajan en field_hlcs).
    @Test func groupByColumn_isSharedWithEmission() {
        #expect(EntityApplyMap.transactionItem.groupByColumn == EntityEmissionMap.transactionItem.groupByColumn)
        #expect(EntityApplyMap.inboxDraft.groupByColumn == EntityEmissionMap.inboxDraft.groupByColumn)
        #expect(EntityApplyMap.category.groupByColumn == EntityEmissionMap.category.groupByColumn)
        #expect(EntityApplyMap.favoritePayment.groupByColumn == EntityEmissionMap.favoritePayment.groupByColumn)
        #expect(EntityApplyMap.merchantMemory.groupByColumn == EntityEmissionMap.merchantMemory.groupByColumn)
        #expect(EntityApplyMap.exchangeRate.groupByColumn == EntityEmissionMap.exchangeRate.groupByColumn)
        #expect(EntityApplyMap.budget.groupByColumn == EntityEmissionMap.budget.groupByColumn)
        #expect(EntityApplyMap.scheduledPayment.groupByColumn == EntityEmissionMap.scheduledPayment.groupByColumn)
        #expect(EntityApplyMap.account.groupByColumn == EntityEmissionMap.account.groupByColumn)
        #expect(EntityApplyMap.subcategory.groupByColumn == EntityEmissionMap.subcategory.groupByColumn)
        #expect(EntityApplyMap.tag.groupByColumn == EntityEmissionMap.tag.groupByColumn)
        #expect(EntityApplyMap.notificationItem.groupByColumn == EntityEmissionMap.notificationItem.groupByColumn)
        #expect(EntityApplyMap.cashFlowPlan.groupByColumn == EntityEmissionMap.cashFlowPlan.groupByColumn)
        #expect(EntityApplyMap.cashFlowLine.groupByColumn == EntityEmissionMap.cashFlowLine.groupByColumn)
        #expect(EntityApplyMap.cashFlowOverride.groupByColumn == EntityEmissionMap.cashFlowOverride.groupByColumn)
        #expect(EntityApplyMap.groupBridgePreference.groupByColumn == EntityEmissionMap.groupBridgePreference.groupByColumn)
    }
}
