//
//  GroupBackendInviteEntryHandler.swift
//  Yala
//
//  Sucesor DARK de `CKShareEntryHandler` para links de invitación BACKEND (contrato C1: `g`+`t`).
//  Flujo (§A1): desbloquea beta → persiste el join intent (regla inviolable: post-accept = intent
//  PERSISTENTE reconciliable) → decide el paso encadenado sign-in → consent → join (pure logic en
//  `GroupBackendInviteEntryLogic`). El reconciler (`GroupJoinReconciler`) completa el join en boot/
//  foreground y limpia el intent cuando el member local materializa por pull.
//
//  DARK: la rama C2 en `AppBootstrapper.handleInviteLink` solo lo invoca con `groupsBackendEnabled` ON.
//  Providers/joinProvider inyectables para tests. Logs fuera de #if DEBUG (excepción SplitSync
//  consciente, sin PII — el displayName JAMÁS se loguea).
//

import Foundation
import OSLog
import SwiftData

@MainActor
enum GroupBackendInviteEntryHandler {

    /// Origen de la invocación (telemetría/logs + discriminador de presentación).
    enum Source: String {
        case universalLink   // tap de un universal link (warm, initialized)
        case boot            // reconciler trigger boot
        case foreground      // reconciler trigger foreground
        case remoteInsert    // reconciler trigger remoteInsert
        /// CTA del propio GroupInviteOnboardingView (join tap / retry) — JAMÁS re-presenta onboarding.
        case userAction
        /// Continuación post sign-in/consent desde los sheets de ContentView (A2).
        case continuation
    }

    private static let logger = Logger(subsystem: "com.yala", category: "SplitSync")

    // MARK: - Dependencias inyectables (default = cadena real de producción)

    static var hasSessionProvider: @MainActor () -> Bool = { CloudAuthService.shared.hasSession }
    static var isConsentedProvider: @MainActor () -> Bool = { GroupsConsentState.isAccepted }
    /// Señal de routing del invitado fresco (paso 6 §A1 / A2): sin onboarding → invite onboarding
    /// primero (captura el nombre antes del join).
    static var hasCompletedOnboardingProvider: @MainActor () -> Bool = {
        UserDefaults.standard.bool(forKey: AppPreferences.Keys.hasCompletedOnboarding)
    }
    static var profileNameProvider: @MainActor () -> String = {
        UserDefaults.standard.string(forKey: "userName") ?? ""
    }
    /// `join_group` RPC. Default = servicio real (gate `groupsBackendEnabled && hasSession`).
    static var joinProvider: @MainActor (_ token: String, _ displayName: String, _ legacyMemberKey: String?) async throws -> JoinGroupResult = {
        token, displayName, legacyMemberKey in
        try await GroupBackendMembershipService(client: GroupsMembershipClient())
            .join(token: token, displayName: displayName, legacyMemberKey: legacyMemberKey)
    }
    /// `update_member_display_name` RPC (corrección R1). Default = servicio real.
    static var updateDisplayNameProvider: @MainActor (_ groupID: String, _ displayName: String) async throws -> UpdateDisplayNameResult = {
        groupID, displayName in
        try await GroupBackendMembershipService(client: GroupsMembershipClient())
            .updateDisplayName(groupID: groupID, displayName: displayName)
    }

    // MARK: - Entry point (warm tap)

    /// Warm path: universal link backend tapeado con la app inicializada.
    static func handle(
        groupID: String,
        token: String,
        branded: InviteLinkService.BrandedMetadata = .empty,
        source: Source = .universalLink
    ) async {
        // 1. Desbloquea beta (igual que CKShareEntryHandler).
        UserDefaults.standard.set(true, forKey: AppPreferences.Keys.groupsBetaUnlocked)
        // 2. Persiste el intent ANTES de cualquier await.
        persistIntent(groupID: groupID, token: token)
        MetricsService.canary(.groupJoinIntentPersisted)
        // 3-4. Decide y ejecuta.
        await drive(groupID: groupID, token: token, source: source)
    }

    /// Upsert del join intent backend (keying `zoneName == groupID`). Preserva displayName/currency ya
    /// capturados (silent-setup) en un re-tap. G6-2: captura el `legacyMemberKey` del device (member local del
    /// grupo migrado) para un RE-JOIN — `SplitSyncManager` da el grupo + su `ModelContext` (persistIntent no
    /// tiene contexto propio); si el grupo no está local aún, preserva el ya capturado en un re-tap.
    static func persistIntent(groupID: String, token: String) {
        let existing = PendingJoinStore.entry(zoneName: groupID)
        var legacyMemberKey: String?
        if let group = GroupService.shared.group(for: groupID),
           let context = group.modelContext {
            legacyMemberKey = legacyMemberKeyForRejoin(group: group, context: context)
        }
        PendingJoinStore.save(PendingJoinEntry(
            zoneName: groupID,
            zoneOwnerName: "",
            displayName: existing?.displayName,
            regionFallbackCurrency: existing?.regionFallbackCurrency,
            backendGroupID: groupID,
            inviteToken: token,
            legacyMemberKey: legacyMemberKey ?? existing?.legacyMemberKey
        ))
    }

    /// FUENTE del legacy recordName de CloudKit para un RE-JOIN de grupo migrado (G6-2): (1º) el `SplitMember`
    /// local del grupo con `isCurrentUser == true` → su `cloudKitUserRecordID` si no está vacío; (2º fallback)
    /// `GroupUserIdentityService.cachedRecordName`. Device fresco sin ninguno → `nil` (entra como member
    /// nuevo — residual §9.3b documentado). `#Predicate` CONCRETO por tipo (regla inviolable).
    static func legacyMemberKeyForRejoin(group: SplitGroup, context: ModelContext) -> String? {
        // C-3 (D1): si este device revocó las credenciales de re-join del grupo (cambio/cierre del Apple ID
        // con la fila RETENIDA), no hay legacy key que ofrecer. Corta las DOS fuentes de un golpe: el
        // `SplitMember` con `isCurrentUser` —hijo de un grupo retenido, o sea que SOBREVIVE, y cuyo
        // `cloudKitUserRecordID` es el recordName del Apple ID que se fue— y el fallback del cache. El
        // re-join entra entonces como member NUEVO (residual §9.3b, ya documentado) en vez de rebindear
        // server-side la membresía CloudKit-era del humano anterior.
        guard group.rejoinRevokedAt == nil else { return nil }
        let zoneID = group.cloudKitZoneID
        var descriptor = FetchDescriptor<SplitMember>(
            predicate: #Predicate { $0.groupZoneID == zoneID && $0.isCurrentUser == true })
        descriptor.fetchLimit = 1
        do {
            if let member = try context.fetch(descriptor).first,
               !member.cloudKitUserRecordID.isEmpty {
                return member.cloudKitUserRecordID
            }
        } catch {
            // Cero silencios: la fila del current user no fue legible → cae al fallback del cache.
            logger.error("BackendInvite: legacyMemberKeyForRejoin fetch failed for \(zoneID, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
        if let cached = GroupUserIdentityService.shared.cachedRecordName, !cached.isEmpty {
            return cached
        }
        return nil
    }

    // MARK: - Driver compartido (handler + reconciler)

    /// Decide el siguiente paso (sign-in / consent / invite-onboarding / join) re-evaluando condiciones
    /// VIVAS y lo ejecuta. Reusado por el reconciler backend (§A1 pasos 3-4) y por la continuación de
    /// los sheets de A2.
    static func drive(groupID: String, token: String, source: Source) async {
        switch GroupBackendInviteEntryLogic.nextStep(
            hasSession: hasSessionProvider(),
            isConsented: isConsentedProvider(),
            hasCompletedOnboarding: hasCompletedOnboardingProvider(),
            canPresentOnboarding: source != .userAction
        ) {
        case .presentSignIn:
            RouterEntryGate.shared.submit(.presentGroupsSignIn(pendingJoin: groupID))
            logger.notice("BackendInvite[\(source.rawValue, privacy: .public)]: no session → present sign-in for \(groupID, privacy: .public)")
        case .presentConsent:
            RouterEntryGate.shared.submit(.presentGroupsConsent(pendingJoin: groupID))
            logger.notice("BackendInvite[\(source.rawValue, privacy: .public)]: no consent → present consent for \(groupID, privacy: .public)")
        case .presentInviteOnboarding:
            RouterEntryGate.shared.submit(.presentGroupBackendInviteOnboarding(pendingJoin: groupID))
            logger.notice("BackendInvite[\(source.rawValue, privacy: .public)]: fresh user → present invite onboarding for \(groupID, privacy: .public)")
        case .join:
            await attemptJoin(groupID: groupID, token: token, source: source)
        }
    }

    /// Continuación del flujo encadenado desde los sheets de A2 (sign-in OK / consent aceptado) o desde
    /// el drain con condición viva stale: re-lee el intent persistido y re-evalúa el siguiente paso.
    static func continueFlow(zoneName: String) async {
        guard let entry = PendingJoinStore.entry(zoneName: zoneName),
              let groupID = entry.backendGroupID,
              let token = entry.inviteToken
        else {
            logger.notice("BackendInvite[continuation]: no live backend intent for \(zoneName, privacy: .public) — nothing to continue")
            return
        }
        await drive(groupID: groupID, token: token, source: .continuation)
    }

    /// Ejecuta el `join_group` RPC + clasifica el resultado. G6-2: el `legacyMemberKey` se LEE del intent
    /// persistido (lo capturó `persistIntent` con el member local del grupo migrado) — cubre el warm path y el
    /// reconciler de un golpe; `nil` en un join normal (token fresco). Presencia ⇒ RE-JOIN: el server rebindea
    /// la membresía CloudKit-era; el canario `groupLegacyRebindFailed` se dispara si se envió y no matcheó.
    static func attemptJoin(
        groupID: String,
        token: String,
        source: Source
    ) async {
        let intent = PendingJoinStore.entry(zoneName: groupID)
        let legacyMemberKey = intent?.legacyMemberKey
        // R1: displayName SIEMPRE no-vacío (btrim='' → yala_bad_input permanente).
        let displayName = GroupBackendInviteEntryLogic.resolveJoinDisplayName(
            intentName: intent?.displayName,
            profileName: profileNameProvider(),
            defaultName: L10n.Profile.defaultName
        )
        do {
            let result = try await joinProvider(token, displayName, legacyMemberKey)
            // C6: canario de rebind legacy (solo si se ENVIÓ legacyMemberKey y no matcheó).
            if legacyMemberKey != nil, !result.rebound {
                MetricsService.canary(.groupLegacyRebindFailed)
            }
            handleJoinSuccess(groupID: groupID, result: result, source: source)
        } catch let error as GroupsRPCError {
            handleJoinError(groupID: groupID, error: error, source: source)
        } catch {
            // No-GroupsRPCError → tratar como transient (conserva el intent, reintenta el reconciler).
            logger.error("BackendInvite[\(source.rawValue, privacy: .public)]: join threw non-RPC error for \(groupID, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Resultado

    private static func handleJoinSuccess(groupID: String, result: JoinGroupResult, source: Source) {
        // Tracker: fase desde el status del RPC (pendingApproval → espera-aprobación; active → éxito).
        GroupJoinIntentTracker.shared.rehydrate(zoneName: groupID)
        if let status = SplitMemberStatus(rawValue: result.status) {
            GroupJoinIntentTracker.shared.noteMemberResolved(zoneName: groupID, status: status)
        }
        MetricsService.canary(.groupJoinIntentReconciled, detail: "\(source.rawValue)|\(result.status)")
        logger.notice("BackendInvite[\(source.rawValue, privacy: .public)]: join OK for \(groupID, privacy: .public) status=\(result.status, privacy: .public) rebound=\(result.rebound, privacy: .public)")
        // Intent CONSERVADO: se limpia cuando el member local materialice (pull) vía el reconciler —
        // misma semántica actual (jamás "todo listo" sin member).
    }

    private static func handleJoinError(groupID: String, error: GroupsRPCError, source: Source) {
        let kind = GroupBackendAcceptErrorLogic.classify(error)
        switch kind {
        case .sessionRequired:
            // Sesión cayó a mitad → re-presentar sign-in; intent conservado, reconciler reintenta.
            RouterEntryGate.shared.submit(.presentGroupsSignIn(pendingJoin: groupID))
            logger.notice("BackendInvite[\(source.rawValue, privacy: .public)]: session required for \(groupID, privacy: .public) → present sign-in")
        case .transient:
            // Sin alerta; conserva intent (el reconciler reintenta).
            logger.notice("BackendInvite[\(source.rawValue, privacy: .public)]: transient join error for \(groupID, privacy: .public) → retry later")
        case .invalidInvite, .notAuthorized, .generic:
            // PERMANENTE: canario + limpiar intent + alerta localizada (cero silencios).
            MetricsService.canary(.groupJoinFailed, detail: GroupBackendAcceptErrorLogic.slug(for: error))
            PendingJoinStore.clear(zoneName: groupID)
            // Señala el fallo a la vista de onboarding (failedStep) en vez de dejarla en
            // joining/takingLong con el alert retenido detrás del cover; recoverable: false
            // porque el intent ya se limpió (invalidInvite/permanente no se reintenta).
            GroupJoinIntentTracker.shared.noteAcceptFailed(zoneName: groupID, recoverable: false)
            if kind == .invalidInvite {
                RouterEntryGate.shared.submit(.showInviteError(String(localized: "groups.invite.linkInvalidDetail")))
            } else {
                RouterEntryGate.shared.submit(.showGroupSyncError(L10n.Groups.Errors.actionFailed))
            }
            logger.error("BackendInvite[\(source.rawValue, privacy: .public)]: PERMANENT join failure for \(groupID, privacy: .public) kind=\(String(describing: kind), privacy: .public)")
        }
    }

    // MARK: - Corrección R1 del displayName (llamada por el reconciler al materializar el member)

    /// Si el silent-setup capturó el nombre real y el member ya existe con el placeholder, corrige vía
    /// `update_member_display_name` UNA vez (guard anti-pisado en la pure logic).
    static func correctDisplayNameIfNeeded(
        groupID: String,
        intentName: String?,
        currentMemberDisplayName: String
    ) async {
        guard GroupBackendInviteEntryLogic.shouldCorrectMemberDisplayName(
            intentName: intentName,
            currentMemberDisplayName: currentMemberDisplayName,
            defaultName: L10n.Profile.defaultName
        ) else { return }
        let name = (intentName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            _ = try await updateDisplayNameProvider(groupID, name)
            logger.notice("BackendInvite: display name corrected for \(groupID, privacy: .public)")
        } catch {
            logger.error("BackendInvite: display name correction failed for \(groupID, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }
}
