//
//  GroupJoinReconcileLogic.swift
//  Yala
//
//  Pure-logic de decisión del reconciliador de join intents (unión a grupos).
//  Extraído de GroupJoinReconciler para test sin SwiftData/CloudKit (patrón
//  SplitSyncStartGate / MemberChangeNotificationLogic).
//
//  Contexto (bug 2026-07-11): el member del invitado solo se creaba si el
//  SplitGroup local ya existía al momento del accept — una carrera perdida casi
//  siempre por la ventana export-only (≥60s). Estas decisiones gobiernan el
//  reintento persistente en accept/remoteInsert/boot/foreground.
//

import CloudKit
import Foundation

enum GroupJoinReconcileLogic {

    /// Qué hacer con un join intent en un trigger dado.
    enum Decision: Equatable {
        /// Grupo local presente y engine vivo → asegurar el member ahora.
        case reconcile
        /// La zona aún no materializó localmente → no-op, reintenta en el
        /// próximo trigger (log notice, telemetría deferred).
        case waitForGroup
        /// Grupo presente pero el engine destino es nil (pre-initialize /
        /// post-signOut) → no-op con telemetría (el enqueue sería un drop).
        case waitForEngines
        /// Sin intent para esa zona.
        case skip
    }

    static func decide(hasIntent: Bool, groupExistsLocally: Bool, engineReady: Bool) -> Decision {
        guard hasIntent else { return .skip }
        guard groupExistsLocally else { return .waitForGroup }
        guard engineReady else { return .waitForEngines }
        return .reconcile
    }

    /// El intent solo se limpia cuando el member quedó asegurado Y el enqueue
    /// tocó un engine real (un enqueue contra engine nil es un no-op silencioso
    /// — ver markPendingChange). Cualquier otro resultado conserva el intent
    /// para el próximo trigger.
    static func shouldClearIntent(memberEnsured: Bool, enqueueReachedEngine: Bool) -> Bool {
        memberEnsured && enqueueReachedEngine
    }

    // MARK: - Modo backend (G4-invites, DARK)

    /// Qué hacer con un join intent BACKEND (`entry.isBackendJoin`) en un trigger. Discriminado por
    /// `entry.isBackendJoin` con PRIORIDAD sobre el flag (R5): una entry backend con el flag rolled-back
    /// (`.skipFlagOff`) JAMÁS cae al camino CloudKit (mis-enqueue) — se conserva hasta TTL.
    enum BackendDecision: Equatable {
        /// Flag OFF (rollback): conservar el intent sin procesar por NINGÚN canal (R5).
        case skipFlagOff
        /// El member local ya materializó (pull llegó): corregir displayName si procede + limpiar intent.
        case correctAndClear
        /// Sin sesión Nube → presentar sign-in; el intent se conserva.
        case presentSignIn
        /// Sesión pero sin consent de grupos → presentar consent; el intent se conserva.
        case presentConsent
        /// Listo (sesión + consent, member aún no local) → (re)intentar el join RPC (idempotente server).
        case join
    }

    static func decideBackend(
        flagEnabled: Bool,
        hasSession: Bool,
        isConsented: Bool,
        memberLocallyPresent: Bool
    ) -> BackendDecision {
        guard flagEnabled else { return .skipFlagOff }       // R5: prioridad sobre el flag
        if memberLocallyPresent { return .correctAndClear }
        if !hasSession { return .presentSignIn }
        if !isConsented { return .presentConsent }
        return .join
    }

    /// Backend: el intent solo se limpia cuando el member local ya materializó (pull) — NO el
    /// `enqueueReachedEngine` de CloudKit (el server crea la membresía síncronamente; el intent solo
    /// cubre el reintento de join transitorio y la aplicación de displayName/currency al materializar).
    static func shouldClearBackendIntent(memberLocallyPresent: Bool) -> Bool {
        memberLocallyPresent
    }

    /// S1: ¿este SplitMember materializado por el PULL backend es el current user? Match directo por
    /// `userID == sub` (lo escribe `applyMember` desde el wire `user_id`) con fallback `memberKey == sub`
    /// (identidad server-side; para un member propio ambos son el sub). JAMÁS por `isCurrentUser` —
    /// `applyMember` NUNCA lo setea, así que depender de él dejaría `memberLocallyPresent` false para
    /// siempre (intent nunca limpiado + falso canario `groupJoinIntentExpired` a los 7d).
    /// Case-insensitive (paridad con el re-drive A2 de `applyMember`).
    static func backendMemberMatchesCurrentUser(
        memberUserID: String?,
        memberKey: String?,
        currentUserID: String?
    ) -> Bool {
        guard let currentUserID, !currentUserID.isEmpty else { return false }
        let current = currentUserID.lowercased()
        if let uid = memberUserID?.lowercased(), uid == current { return true }
        if let key = memberKey?.lowercased(), key == current { return true }
        return false
    }

    /// El displayName del intent solo se aplica si no pisa un rename manual:
    /// member recién nacido o displayName actual vacío/default.
    static func shouldApplyIntentDisplayName(
        memberWasCreated: Bool,
        currentDisplayName: String,
        defaultName: String
    ) -> Bool {
        if memberWasCreated { return true }
        let trimmed = currentDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed == defaultName
    }

    /// La moneda del grupo solo se re-aplica si la pref actual sigue siendo el
    /// fallback regional que `performSilentSetup` detectó cuando el grupo aún no
    /// había llegado (el usuario no la cambió a mano).
    static func shouldApplyGroupCurrency(
        currentPreferenceCode: String?,
        regionFallbackCode: String?,
        groupCode: String
    ) -> Bool {
        guard let regionFallbackCode, let currentPreferenceCode else { return false }
        guard currentPreferenceCode == regionFallbackCode else { return false }
        return groupCode != currentPreferenceCode
    }

    // MARK: - Contenido esperado del enqueue (oráculo: CKConstants / enqueueSharedSave)

    /// Proyección testeable de lo que `enqueueSave(modelID:group:)` encolará —
    /// el mismo cálculo que SplitSyncManager hace por dentro (lección d49d2e47:
    /// assertar el contenido real, no solo que "no lanza").
    struct EnqueuePlan: Equatable {
        let recordName: String
        let zoneName: String
        let zoneOwnerName: String
        let routesToSharedEngine: Bool
    }

    static func enqueuePlan(
        memberID: UUID,
        zoneName: String,
        zoneOwnerName: String,
        isOwner: Bool
    ) -> EnqueuePlan {
        let resolvedOwner = zoneOwnerName.isEmpty ? CKCurrentUserDefaultName : zoneOwnerName
        let zoneID = CKRecordZone.ID(
            zoneName: zoneName,
            ownerName: isOwner ? CKCurrentUserDefaultName : resolvedOwner
        )
        let recordID = CKConstants.recordID(for: memberID, in: zoneID)
        return EnqueuePlan(
            recordName: recordID.recordName,
            zoneName: recordID.zoneID.zoneName,
            zoneOwnerName: recordID.zoneID.ownerName,
            routesToSharedEngine: !isOwner
        )
    }
}
