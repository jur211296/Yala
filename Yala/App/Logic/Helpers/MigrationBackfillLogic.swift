//
//  MigrationBackfillLogic.swift
//  Yala
//
//  Pure-logic plan for the CSV-mirror backfill step of the unified migration.
//  Decides per-relation whether to write the CSV from M2M (eager) or nuke
//  the stale CSV (M2M lazy nil → red de seguridad, retry next launch).
//

import Foundation

enum MigrationBackfillLogic {

    enum CSVAction: Equatable {
        /// M2M is non-nil — encode UUIDs and write CSV.
        case writeFromM2M
        /// M2M is nil (CloudKit lazy hydration in progress) — nuke stale CSV.
        /// Caller marks `sawRace=true` so the sentinel is not advanced.
        case nukeStale
    }

    /// Decision for a single M2M relation.
    /// `nil` M2M = lazy hydration in progress → nuke stale CSV + mark race.
    /// `[]` M2M = "no filter / no tags" → write empty CSV (encodes to nil internally).
    static func decideAction<T>(m2m: [T]?) -> CSVAction {
        m2m == nil ? .nukeStale : .writeFromM2M
    }

    // MARK: - Budget Plan (3 relations)

    struct BudgetPlan: Equatable {
        let accountIDsAction: CSVAction
        let subcategoryIDsAction: CSVAction
        let tagIDsAction: CSVAction
        let sawRace: Bool
    }

    /// Computes per-Budget plan for its 3 M2M relations.
    /// `sawRace=true` if ANY relation is lazy nil — others still process normally.
    static func planForBudget<A, S, Tg>(
        accounts: [A]?,
        subcategories: [S]?,
        tags: [Tg]?
    ) -> BudgetPlan {
        let accountAction = decideAction(m2m: accounts)
        let subAction = decideAction(m2m: subcategories)
        let tagAction = decideAction(m2m: tags)
        let race = accountAction == .nukeStale
            || subAction == .nukeStale
            || tagAction == .nukeStale
        return BudgetPlan(
            accountIDsAction: accountAction,
            subcategoryIDsAction: subAction,
            tagIDsAction: tagAction,
            sawRace: race
        )
    }

    // MARK: - Eager CSV-mirror backfill (repetible, sin colisión)

    /// Decide si reconstruir el CSV mirror desde el M2M. Reconstruye cuando el M2M
    /// APORTA ids que el CSV no tiene (CSV nil, o M2M ⊄ CSV) y NUNCA cuando el M2M es
    /// subconjunto del CSV: ese caso es indistinguible de una hidratación lazy PARCIAL de
    /// CloudKit (el M2M entrega un subconjunto mientras llegan los demás records) y
    /// reconstruir ahí DEGRADARÍA un CSV correcto y completo (el CSV viaja eager en el
    /// record; el M2M se materializa lazy). Tampoco nukea: M2M vacío (vacío legítimo o aún
    /// no hidratado) → false, no hay fuente y no resucitamos un filtro quitado. Esta regla
    /// hace el pase seguro AUNQUE corra sin gate de quiescencia (ej. `forceSync`): un M2M a
    /// medio hidratar nunca empeora el CSV; a lo sumo no repara en esa pasada y converge en
    /// la siguiente oleada (cuando el M2M aporte los ids que faltan).
    static func shouldRebuildCSVMirror(csvIDs: Set<UUID>?, m2mIDs: Set<UUID>) -> Bool {
        guard !m2mIDs.isEmpty else { return false }
        guard let csvIDs else { return true }
        return !m2mIDs.isSubset(of: csvIDs)
    }
}
