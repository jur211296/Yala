//
//  GroupsIdentityBootGuardLogic.swift
//  Yala
//
//  Pure decision logic del boot-guard de identidad de Grupos (GAP 1 de
//  gap-estados.md; paquete de endurecimiento Grupos-v1 2026-07-13).
//
//  El escenario: el Apple ID del OS cambia con la app CERRADA. La limpieza
//  reactiva existe (CKSyncEngine entrega `.accountChange` → `handleAccountChange`
//  limpia cache local + state de engines + identidad), pero depende de que el
//  engine corra y procese el evento — `groups_currentUserRecordName` persistido
//  nunca se comparaba proactivamente. Sin esta comparación, Grupos puede operar
//  con la identidad ANTERIOR en silencio (p.ej. `deterministicMemberID` generaría
//  members del usuario equivocado).
//
//  Regla anti-falso-positivo: SOLO se limpia con DOS valores válidos no-vacíos
//  DISTINTOS. Un fetch fallido (red, `.notAuthenticated`) o un cache vacío
//  (primera instalación) JAMÁS disparan la limpieza — es destructiva de cache
//  local (los datos viven en CloudKit y se re-fetchean, pero un falso positivo
//  borraría y re-bajaría todo sin necesidad).
//

import Foundation

nonisolated enum GroupsIdentityBootGuardLogic {

    enum Action: Equatable {
        /// No hacer nada (match, cache vacío, o fetch sin valor).
        case none
        /// Correr la misma limpieza que `handleAccountChange(.switchAccounts)`.
        case runSwitchCleanup
    }

    /// - Parameters:
    ///   - cached: `GroupUserIdentityService.cachedRecordName` (persistido en UserDefaults).
    ///   - fresh: resultado de `fetchFreshRecordName()`; `nil` = el fetch falló
    ///     (el caller convierte el error en nil — un fallo transitorio no es evidencia).
    static func decide(cached: String?, fresh: String?) -> Action {
        guard let cached, !cached.isEmpty,
              let fresh, !fresh.isEmpty,
              cached != fresh else { return .none }
        return .runSwitchCleanup
    }
}
