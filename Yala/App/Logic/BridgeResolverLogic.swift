//
//  BridgeResolverLogic.swift
//  Yala
//
//  Pure-logic SSOT del bridge `SplitExpense ↔ TransactionItem` opt-out.
//  Decide si el bridge debe crear TX real en cuenta personal para un grupo dado.
//
//  Regla (clarificada en sesión planning 2026-05-27):
//    - global=false → effective=false (override per-grupo ignorado por completo)
//    - global=true  → override ?? true (default es bridgear; override=false excluye)
//
//  Override solo restringe — nunca habilita contra global=OFF. Esto simplifica el
//  modelo mental y la UI (toggle per-grupo queda bloqueado si global está OFF).
//
//  Testeable sin SwiftData/ModelContext (regla R8). El callsite real
//  (`BridgeModeResolver`) hace el fetch del `GroupBridgePreference` y pasa los
//  valores planos aquí.
//

import Foundation

enum BridgeResolverLogic {

    /// Resuelve el modo efectivo del bridge para un grupo.
    /// - Parameters:
    ///   - global: valor de `AppPreferences.bridgeGroupExpensesToPersonalAccounts`.
    ///   - override: `GroupBridgePreference.bridgeOverride` (nil si no hay registro).
    /// - Returns: `true` si el bridge debe crear TX real, `false` si solo virtual.
    static func computeEffective(global: Bool, override: Bool?) -> Bool {
        guard global else { return false }
        return override ?? true
    }

    /// Calcula qué zoneIDs de `GroupBridgePreference` son huérfanos dado el set
    /// activo (excluyendo grupos `isHiddenForAll==true` — FU-02 soft-delete).
    /// - Parameters:
    ///   - allPreferenceZoneIDs: zoneIDs presentes en la tabla `GroupBridgePreference`.
    ///   - activeZoneIDs: zoneIDs de grupos vivos del user (`isActive` member, no hidden).
    /// - Returns: subset a borrar.
    static func computeOrphanZoneIDs(
        allPreferenceZoneIDs: Set<String>,
        activeZoneIDs: Set<String>
    ) -> Set<String> {
        allPreferenceZoneIDs.subtracting(activeZoneIDs)
    }
}
