//
//  GroupBatchLeaveLogic.swift
//  Yala
//
//  Lógica PURA (nonisolated, sin efectos) del batch "salir de todos mis grupos" (D10). Clasifica cada grupo
//  debt-free en la acción segura que le corresponde y modela las fases del intent kill-safe. La ejecuta
//  `GroupBatchLeaveOrchestrator`; los facts se derivan EN MEMORIA (nunca `#Predicate` sobre opcionales —
//  `SplitMember.userID` es opcional y un predicado sobre él crashea el SQL de SwiftData, CLAUDE.md).
//
//  Reglas (estudio MODO-NUBE-GESTION-DATOS-UX §2.1 + D10, decisiones owner A1/B1 2026-07-20):
//    - member (cualquier canal) → salir (leaveGroup)
//    - owner sin co-members activos → soft-delete ("Eliminar grupo")
//    - owner + co-members, canal BACKEND, con heredero elegible → transferir + salir
//    - resto owner+co-members (CloudKit-legacy, o backend sin heredero) → "necesitan tu decisión" (NO muta)
//  El heredero elegible replica EXACTAMENTE la elegibilidad server-side de `groups_forget_user`
//  (activo + `user_id` no-NULL + ≠ yo). NUNCA se migra un grupo CloudKit-legacy (decisión A1: migrar
//  dispararía tarjetas "Moved" a los co-members sin completar la salida — no vale la disrupción a terceros).
//

import Foundation

enum GroupBatchLeaveLogic {

    /// Facts por grupo, derivados EN MEMORIA por el orquestador (jamás vía `#Predicate` sobre opcionales).
    struct GroupFacts: Equatable {
        /// `SplitGroup.isOwner` (device-local).
        let isOwner: Bool
        /// `CloudSyncFlags.groupsBackendEnabled && group.isBackendGroup` — el grupo enruta al canal backend.
        let isBackendChannel: Bool
        /// Co-members `.isActive && !isCurrentUser`.
        let activeCoMemberCount: Int
        /// Herederos elegibles: co-members `.isActive && userID != nil && !isCurrentUser` (solo tiene
        /// sentido en canal backend). Replica la elegibilidad de `transfer_group_ownership`.
        let eligibleHeirCount: Int
        /// `abs(netBalance) > 0.01` del usuario en el grupo (read-only, molde `recomputeOutstandingDebt`).
        let hasOutstandingDebt: Bool
    }

    /// Acción segura para un grupo. `plannedAction` congelado del intent (se re-clasifica solo en `.pending`).
    enum Action: String, Codable, Equatable {
        /// Red de seguridad: el batch solo se OFRECE con cero deudas globales; cubre la carrera
        /// deuda-sobrevenida (otro device liquida/agrega entre clasificar y ejecutar).
        case skipHasDebt
        /// Member (cualquier canal) → `GroupService.batchLeave`.
        case leave
        /// Owner sin co-members activos → `GroupService.softDelete`.
        case deleteSolo
        /// Owner + co-members backend con heredero → `GroupService.transferOwnershipThenLeave`.
        case transferThenLeave
        /// Resto owner+co-members (CloudKit-legacy o backend sin heredero) → sin mutación.
        case needsDecision
    }

    /// Por qué un grupo cae a "necesitan tu decisión" (copy honesto + telemetría).
    enum NeedsDecisionReason: String, Codable, Equatable {
        /// Owner + co-members en CloudKit-legacy: CloudKit no soporta transferir ownership (limitación CKShare).
        case cloudKitOwnerWithCoMembers
        /// Owner + co-members backend pero ningún heredero re-joineó aún (`user_id NULL`).
        case backendNoEligibleHeir
        /// La deuda apareció entre la clasificación y la ejecución (carrera).
        case debtAppeared
        /// El transfer o el leave falló de forma permanente (no reintentable).
        case operationFailed
    }

    /// Fase persistida por grupo (write-ahead: se graba ANTES de la red que la avanza). Resume kill-safe.
    enum Phase: String, Codable, Equatable {
        /// Clasificado, aún no se tocó la red. En resume SÍ se re-clasifica (facts locales frescos).
        case pending
        /// La operación mutante (RPC/save) pudo haber salido. En resume se RE-EJECUTA la `plannedAction`
        /// congelada (todas las primitivas son idempotentes) — NUNCA se re-clasifica.
        case inProgress
        // Terminales:
        case done
        case needsDecision
        case failed
    }

    // MARK: - Clasificación (tabla)

    static func classify(_ facts: GroupFacts) -> Action {
        if facts.hasOutstandingDebt { return .skipHasDebt }
        if !facts.isOwner { return .leave }
        if facts.activeCoMemberCount == 0 { return .deleteSolo }
        // owner + co-members activos:
        if facts.isBackendChannel && facts.eligibleHeirCount >= 1 { return .transferThenLeave }
        return .needsDecision
    }

    /// Motivo del `.needsDecision` derivado de la clasificación (llamar solo cuando `classify == .needsDecision`).
    static func needsDecisionReason(_ facts: GroupFacts) -> NeedsDecisionReason {
        facts.isBackendChannel ? .backendNoEligibleHeir : .cloudKitOwnerWithCoMembers
    }

    /// `true` si la fase es terminal (el orquestador no la reanuda).
    static func isTerminal(_ phase: Phase) -> Bool {
        switch phase {
        case .done, .needsDecision, .failed: return true
        case .pending, .inProgress: return false
        }
    }

    /// Resultado de EJECUTAR un paso del batch para un grupo (`GroupService.executeBatchStep`). El orquestador
    /// lo traduce a la fase persistida.
    enum StepResult: Equatable {
        /// Grupo salido/borrado/transferido con éxito (o ya no existía local → idempotente).
        case done
        /// Cae a "necesitan tu decisión" (sin mutar). El orquestador NO reanuda.
        case needsDecision(NeedsDecisionReason)
        /// Transitorio (red / sesión / sin contexto): deja la entry `.inProgress`; el resume la retoma.
        case deferred
        /// Fallo PERMANENTE (no reintentable): marca `.failed`.
        case failed(String)
    }

    /// Resultado de `GroupService.transferOwnershipThenLeave`.
    enum TransferLeaveOutcome: Equatable {
        case left
        case needsDecision(NeedsDecisionReason)
    }
}
