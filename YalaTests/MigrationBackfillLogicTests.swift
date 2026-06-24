//
//  MigrationBackfillLogicTests.swift
//  YalaTests
//
//  Pure-logic tests for `MigrationBackfillLogic.decideAction` and `planForBudget`.
//  No SwiftData — covers per-relation race detection and Budget aggregation.
//

import Foundation
import Testing

@testable import Yala

@Suite("Migration Backfill Logic")
struct MigrationBackfillLogicTests {

    // MARK: - decideAction

    @Test func nilM2M_nukesStale() {
        let action = MigrationBackfillLogic.decideAction(m2m: [Int]?.none)
        #expect(action == .nukeStale)
    }

    @Test func populatedM2M_writesFromM2M() {
        let m2m: [Int]? = [1, 2, 3]
        let action = MigrationBackfillLogic.decideAction(m2m: m2m)
        #expect(action == .writeFromM2M)
    }

    @Test func emptyM2M_writesFromM2M() {
        // [] is "no filter / no tags" — write empty CSV (encodes to nil internally).
        // Distinct from nil which is "lazy hydration in progress".
        let m2m: [Int]? = []
        let action = MigrationBackfillLogic.decideAction(m2m: m2m)
        #expect(action == .writeFromM2M)
    }

    // MARK: - planForBudget

    @Test func budgetPlan_allM2MPopulated_noRace() {
        let plan = MigrationBackfillLogic.planForBudget(
            accounts: [1] as [Int]?,
            subcategories: [2] as [Int]?,
            tags: [3] as [Int]?
        )
        #expect(plan.sawRace == false)
        #expect(plan.accountIDsAction == .writeFromM2M)
        #expect(plan.subcategoryIDsAction == .writeFromM2M)
        #expect(plan.tagIDsAction == .writeFromM2M)
    }

    @Test func budgetPlan_oneM2MNil_marksRace_processesOthers() {
        let plan = MigrationBackfillLogic.planForBudget(
            accounts: [1] as [Int]?,
            subcategories: [Int]?.none,
            tags: [3] as [Int]?
        )
        #expect(plan.sawRace == true)
        #expect(plan.subcategoryIDsAction == .nukeStale)
        #expect(plan.accountIDsAction == .writeFromM2M)
        #expect(plan.tagIDsAction == .writeFromM2M)
    }

    @Test func budgetPlan_allM2MNil_marksRace() {
        let plan = MigrationBackfillLogic.planForBudget(
            accounts: [Int]?.none,
            subcategories: [Int]?.none,
            tags: [Int]?.none
        )
        #expect(plan.sawRace == true)
        #expect(plan.accountIDsAction == .nukeStale)
        #expect(plan.subcategoryIDsAction == .nukeStale)
        #expect(plan.tagIDsAction == .nukeStale)
    }

    @Test func budgetPlan_allM2MEmpty_noRace() {
        // [] != nil — empty filter is a legitimate state, not a race.
        let plan = MigrationBackfillLogic.planForBudget(
            accounts: [Int]() as [Int]?,
            subcategories: [Int]() as [Int]?,
            tags: [Int]() as [Int]?
        )
        #expect(plan.sawRace == false)
        #expect(plan.accountIDsAction == .writeFromM2M)
    }

    // MARK: - shouldRebuildCSVMirror (eager backfill, repetible)

    @Test func rebuild_m2mEmpty_csvNil_false() {
        // Sin fuente (M2M vacío o no hidratado) y sin CSV → nada que reconstruir.
        #expect(MigrationBackfillLogic.shouldRebuildCSVMirror(csvIDs: nil, m2mIDs: []) == false)
    }

    @Test func rebuild_m2mEmpty_csvPopulated_false() {
        // M2M vacío con CSV poblado → NUNCA nukear (no resucitar/borrar un filtro).
        #expect(MigrationBackfillLogic.shouldRebuildCSVMirror(csvIDs: [UUID()], m2mIDs: []) == false)
    }

    @Test func rebuild_m2mPopulated_csvNil_true() {
        // El bug: filtro en M2M hidratado pero espejo CSV vacío → reconstruir.
        #expect(MigrationBackfillLogic.shouldRebuildCSVMirror(csvIDs: nil, m2mIDs: [UUID()]) == true)
    }

    @Test func rebuild_m2mPopulated_csvEqual_false() {
        // Idempotencia: CSV ya refleja el M2M → no-op.
        let ids: Set<UUID> = [UUID(), UUID()]
        #expect(MigrationBackfillLogic.shouldRebuildCSVMirror(csvIDs: ids, m2mIDs: ids) == false)
    }

    @Test func rebuild_m2mPopulated_csvSubset_true() {
        // Convergencia: hidratación parcial previa dejó un CSV incompleto → corregir.
        let a = UUID(), b = UUID()
        #expect(MigrationBackfillLogic.shouldRebuildCSVMirror(csvIDs: [a], m2mIDs: [a, b]) == true)
    }

    @Test func rebuild_m2mPopulated_csvDisjoint_true() {
        #expect(MigrationBackfillLogic.shouldRebuildCSVMirror(csvIDs: [UUID()], m2mIDs: [UUID()]) == true)
    }

    @Test func rebuild_m2mStrictSubsetOfCsv_false() {
        // CRÍTICO: M2M es subconjunto del CSV = hidratación lazy a medias → NO reconstruir
        // (degradaría el CSV completo). Hace el pase seguro sin gate de quiescencia (force-sync).
        let a = UUID(), b = UUID()
        #expect(MigrationBackfillLogic.shouldRebuildCSVMirror(csvIDs: [a, b], m2mIDs: [a]) == false)
    }
}
