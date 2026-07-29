//
//  GroupJoinReconciler.swift
//  Yala
//
//  Consume los join intents de `PendingJoinStore`: cuando el SplitGroup de la
//  zona aceptada por fin existe localmente, asegura el SplitMember del current
//  user (pendingApproval para invitados) y lo encola al engine correcto.
//
//  Reemplaza el one-shot silencioso de `acceptShare` (`if let group { ensure }`
//  — bug 2026-07-11: si la zona no había bajado, el member jamás nacía y el
//  owner nunca recibía la solicitud). Triggers: acceptShare (user-tap),
//  remoteInsert (processPendingRemoteChanges, post-fetch), boot
//  (AppBootstrapper, gated por quiescencia) y foreground (ContentView .active).
//
//  Decisiones en `GroupJoinReconcileLogic` (pure, testeable). Logs fuera de
//  #if DEBUG (excepción SplitSync consciente, sin PII — el displayName del
//  intent JAMÁS se loguea).
//

import Foundation
import OSLog
import SwiftData

@MainActor
enum GroupJoinReconciler {

    enum Trigger: String {
        case acceptShare, remoteInsert, boot, foreground
    }

    private static let logger = Logger(subsystem: "com.yala", category: "SplitSync")

    /// S1 (G4): `sub` de la sesión Nube para el match de members backend. Inyectable para tests.
    static var backendUserIDProvider: @MainActor () -> String? = { CloudAuthService.shared.currentUserID }

    /// Recorre los intents vigentes y reconcilia los que ya tienen zona local.
    /// - Parameters:
    ///   - context/groupLookup/engineReady: inyectables para tests; defaults de
    ///     producción (mainContext del sync + SplitSyncManager).
    static func reconcile(
        trigger: Trigger,
        context providedContext: ModelContext? = nil,
        groupLookup: ((String) -> SplitGroup?)? = nil,
        engineReady: ((SplitGroup) -> Bool)? = nil,
        now: Date = .now
    ) async {
        let entries = PendingJoinStore.all(now: now)
        guard !entries.isEmpty else { return }

        // Los triggers no-user esperan la quiescencia del import personal (el
        // save del ensure comitea el mainContext COMPARTIDO — regla CLAUDE.md).
        // acceptShare es user-tap: residual documentado, no se gatea.
        if trigger != .acceptShare, !iCloudSyncService.shared.isImportQuiescent {
            logger.notice("JoinReconcile[\(trigger.rawValue, privacy: .public)]: deferred — import not quiescent (\(entries.count) intents)")
            MetricsService.canary(.groupJoinIntentDeferred, detail: "importNotQuiescent")
            return
        }

        for entry in entries {
            // R5: discriminador backend↔CloudKit por `isBackendJoin` (token presente) con PRIORIDAD
            // sobre el flag — una entry backend JAMÁS se procesa por el camino CloudKit (mis-enqueue de
            // un grupo sin zona). El flag se re-chequea DENTRO (skipFlagOff conserva el intent).
            if entry.isBackendJoin {
                await reconcileBackendEntry(entry, trigger: trigger, context: providedContext)
                continue
            }

            let group = groupLookup?(entry.zoneName) ?? GroupService.shared.group(for: entry.zoneName)
            let engineIsReady: Bool = {
                guard let group else { return false }
                return engineReady?(group) ?? SplitSyncManager.shared.hasEngine(forOwned: group.isOwner)
            }()

            switch GroupJoinReconcileLogic.decide(
                hasIntent: true,
                groupExistsLocally: group != nil,
                engineReady: engineIsReady
            ) {
            case .skip:
                continue

            case .waitForGroup:
                logger.notice("JoinReconcile[\(trigger.rawValue, privacy: .public)]: zone \(entry.zoneName, privacy: .public) not local yet — waiting")
                MetricsService.canary(.groupJoinIntentDeferred, detail: "waitForGroup")
                GroupJoinIntentTracker.shared.rehydrate(zoneName: entry.zoneName)

            case .waitForEngines:
                logger.notice("JoinReconcile[\(trigger.rawValue, privacy: .public)]: engines not ready for \(entry.zoneName, privacy: .public)")
                MetricsService.canary(.groupJoinIntentDeferred, detail: "enginesNotReady")

            case .reconcile:
                guard let group else { continue }
                GroupJoinIntentTracker.shared.noteGroupInserted(zoneName: entry.zoneName)
                await reconcileEntry(entry, group: group, trigger: trigger, context: providedContext)
            }
        }
    }

    // MARK: - Reconcile de una entry BACKEND (G4-invites, DARK)

    /// Camino backend (R5): NUNCA `ensureCurrentUserMemberExists` (crearía un SplitMember + enqueueSave
    /// al CKSyncEngine de un grupo sin zona CloudKit). El server crea la membresía síncronamente vía el
    /// `join_group` RPC; el intent solo cubre (i) reintento de join transitorio, (ii) presentación
    /// encadenada sign-in/consent y (iii) aplicar displayName/currency al materializar por pull.
    private static func reconcileBackendEntry(
        _ entry: PendingJoinEntry,
        trigger: Trigger,
        context providedContext: ModelContext?
    ) async {
        guard let groupID = entry.backendGroupID, let token = entry.inviteToken else {
            logger.error("JoinReconcile[\(trigger.rawValue, privacy: .public)]: backend intent \(entry.zoneName, privacy: .public) sin groupID/token — conservado")
            return
        }
        // S1: la presencia del member backend se detecta por match directo userID/memberKey == sub —
        // JAMÁS por `isCurrentUser` (`GroupsSyncClient.applyMember` nunca lo setea → con el check de
        // CloudKit `memberLocallyPresent` sería false para siempre: intent nunca limpiado, corrección R1
        // nunca corrida, y falso `groupJoinIntentExpired` a los 7 días).
        let backendMember = backendCurrentUserMember(zoneName: entry.zoneName, context: providedContext)

        switch GroupJoinReconcileLogic.decideBackend(
            flagEnabled: CloudSyncFlags.groupsBackendEnabled,
            hasSession: CloudAuthService.shared.hasSession,
            isConsented: GroupsConsentState.isAccepted,
            memberLocallyPresent: backendMember != nil
        ) {
        case .skipFlagOff:
            // R5: flag rolled back — conservar hasta TTL, jamás procesar por CloudKit.
            logger.notice("JoinReconcile[\(trigger.rawValue, privacy: .public)]: backend intent \(entry.zoneName, privacy: .public) skip — flag OFF (conservado)")

        case .correctAndClear:
            await GroupBackendInviteEntryHandler.correctDisplayNameIfNeeded(
                groupID: groupID, intentName: entry.displayName,
                currentMemberDisplayName: backendMember?.displayName ?? "")
            if let group = GroupService.shared.group(for: entry.zoneName) {
                applyGroupCurrencyIfNeeded(entry: entry, group: group)
            }
            if GroupJoinReconcileLogic.shouldClearBackendIntent(memberLocallyPresent: true) {
                PendingJoinStore.clear(zoneName: entry.zoneName)
            }
            if let status = backendMember?.memberStatus {
                GroupJoinIntentTracker.shared.rehydrate(zoneName: entry.zoneName)
                GroupJoinIntentTracker.shared.noteMemberResolved(zoneName: entry.zoneName, status: status)
            }
            MetricsService.canary(.groupJoinIntentReconciled, detail: "\(trigger.rawValue)|backendMemberPresent")
            logger.notice("JoinReconcile[\(trigger.rawValue, privacy: .public)]: backend member present for \(entry.zoneName, privacy: .public) → intent cleared")

        case .presentSignIn, .presentConsent, .join:
            // El driver del handler re-evalúa las mismas condiciones vivas y presenta o (re)intenta join.
            await GroupBackendInviteEntryHandler.drive(
                groupID: groupID, token: token, source: mapTrigger(trigger))
        }
    }

    /// S1: el SplitMember del current user materializado por el PULL backend, o nil. Match por
    /// `userID`/`memberKey == sub` (pure logic `backendMemberMatchesCurrentUser`) — SIN depender de
    /// `isCurrentUser`, que `applyMember` no setea. Contexto: el inyectado (tests) o el del propio
    /// `SplitGroup` local (mismo mainContext donde el pull materializa; sin grupo local tampoco hay
    /// member local — el pull trae ambos). Internal para test directo.
    static func backendCurrentUserMember(
        zoneName: String,
        context providedContext: ModelContext?
    ) -> SplitMember? {
        guard let context = providedContext
            ?? GroupService.shared.group(for: zoneName)?.modelContext
        else { return nil }
        let descriptor = FetchDescriptor<SplitMember>(
            predicate: #Predicate { $0.groupZoneID == zoneName }
        )
        do {
            let members = try context.fetch(descriptor)
            let currentID = backendUserIDProvider()
            return members.first {
                GroupJoinReconcileLogic.backendMemberMatchesCurrentUser(
                    memberUserID: $0.userID, memberKey: $0.memberKey, currentUserID: currentID)
            }
        } catch {
            logger.error("JoinReconcile: backend member fetch failed for \(zoneName, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private static func mapTrigger(_ trigger: Trigger) -> GroupBackendInviteEntryHandler.Source {
        switch trigger {
        // .acceptShare = user-tap (CTA del invite onboarding / retry del tracker) → el drive NO debe
        // re-presentar el onboarding (discriminador canPresentOnboarding de A2).
        case .acceptShare: return .userAction
        case .foreground: return .foreground
        case .boot: return .boot
        case .remoteInsert: return .remoteInsert
        }
    }

    // MARK: - Reconcile de una entry

    private static func reconcileEntry(
        _ entry: PendingJoinEntry,
        group: SplitGroup,
        trigger: Trigger,
        context providedContext: ModelContext?
    ) async {
        // Pre-check de existencia para el guard anti-pisado del displayName
        // (el ensure no distingue crear de encontrar).
        let memberExisted = currentUserMemberExists(zoneName: entry.zoneName, context: providedContext)

        do {
            let member = try await GroupService.shared.ensureCurrentUserMemberExists(
                in: group,
                reactivateInactive: true,
                context: providedContext
            )

            applyIntentDisplayNameIfNeeded(
                entry: entry, member: member, group: group,
                memberWasCreated: !memberExisted, context: providedContext
            )
            applyGroupCurrencyIfNeeded(entry: entry, group: group)

            if GroupJoinReconcileLogic.shouldClearIntent(memberEnsured: true, enqueueReachedEngine: true) {
                PendingJoinStore.clear(zoneName: entry.zoneName)
            }
            GroupJoinIntentTracker.shared.noteMemberResolved(
                zoneName: entry.zoneName, status: member.memberStatus
            )
            MetricsService.canary(.groupJoinIntentReconciled, detail: "\(trigger.rawValue)|\(member.memberStatus.rawValue)")
            logger.notice("JoinReconcile[\(trigger.rawValue, privacy: .public)]: member ensured for zone \(entry.zoneName, privacy: .public) status=\(member.memberStatus.rawValue, privacy: .public)")
        } catch {
            // Intent NO se limpia → reintento en el próximo trigger.
            logger.error("JoinReconcile[\(trigger.rawValue, privacy: .public)]: ensure failed for \(entry.zoneName, privacy: .public): \(error.localizedDescription, privacy: .public)")
            GroupJoinIntentTracker.shared.noteMemberSaveFailed(zoneName: entry.zoneName)
        }
    }

    /// Aplica el displayName tecleado en el onboarding al member de ESTA zona
    /// (per-zone, no el barrido global de `updateCurrentUserDisplayName`) — solo
    /// si no pisa un rename manual posterior.
    private static func applyIntentDisplayNameIfNeeded(
        entry: PendingJoinEntry,
        member: SplitMember,
        group: SplitGroup,
        memberWasCreated: Bool,
        context providedContext: ModelContext?
    ) {
        guard let name = entry.displayName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty,
              member.displayName != name,
              GroupJoinReconcileLogic.shouldApplyIntentDisplayName(
                  memberWasCreated: memberWasCreated,
                  currentDisplayName: member.displayName,
                  defaultName: L10n.Profile.defaultName
              )
        else { return }
        member.displayName = name
        SplitSyncManager.shared.enqueueSave(modelID: member.id, group: group)
        guard let context = providedContext ?? member.modelContext else { return }
        do {
            try context.save()
        } catch {
            logger.error("JoinReconcile: displayName save failed for \(entry.zoneName, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Re-aplica la moneda del grupo si la pref sigue en el fallback regional
    /// que `performSilentSetup` detectó cuando el grupo aún no había llegado.
    private static func applyGroupCurrencyIfNeeded(entry: PendingJoinEntry, group: SplitGroup) {
        let current = UserDefaults.standard.string(forKey: "defaultCurrencyCode")
        guard GroupJoinReconcileLogic.shouldApplyGroupCurrency(
            currentPreferenceCode: current,
            regionFallbackCode: entry.regionFallbackCurrency,
            groupCode: group.currencyCode
        ) else { return }
        PreferenceSyncService.shared.set(string: group.currencyCode, forKey: "defaultCurrencyCode")
        logger.notice("JoinReconcile: currency re-applied from group for zone \(entry.zoneName, privacy: .public)")
    }

    /// `true` si ya existe un SplitMember del current user para la zona: por el flag `isCurrentUser`, por
    /// `cachedRecordName` (identidad iCloud) o por identidad del canal BACKEND (`userID`/`memberKey == sub`).
    /// Identidad no resuelta → false (el ensure la resuelve y matchea; el guard del displayName queda laxo,
    /// aceptable: member "recién creado" solo relaja el anti-pisado).
    ///
    /// 2.6 — el tercer criterio y la unificación del contexto van juntos, y por el mismo motivo. Este
    /// pre-check alimenta `memberWasCreated`, y un falso `false` hace que `applyIntentDisplayNameIfNeeded`
    /// PISE el displayName de un member que ya existía. En una zona MIGRADA al backend (entry CloudKit,
    /// grupo ya del canal nuevo) el member del usuario tiene `userID` seteado, `cloudKitUserRecordID` vacío
    /// y `isCurrentUser` apagado —`applyMember` NUNCA lo setea— así que los dos criterios viejos fallaban
    /// los dos. El contexto se resuelve como en `backendCurrentUserMember` (inyectado o el del `SplitGroup`
    /// local) porque la rama sin contexto delegaba en `GroupService.currentUserMember(zoneID:)`, que mira
    /// SOLO `isCurrentUser`: dos de los cuatro triggers de producción (`.foreground` y el `.acceptShare` de
    /// la UI) entran por ahí, y sin unificar el re-cableo no los alcanzaría.
    private static func currentUserMemberExists(zoneName: String, context providedContext: ModelContext?) -> Bool {
        guard let context = providedContext
            ?? GroupService.shared.group(for: zoneName)?.modelContext
        else { return false }
        let recordName = GroupUserIdentityService.shared.cachedRecordName ?? ""
        // Flag OFF ⇒ nil ⇒ el criterio backend no matchea nada y el predicado es el de siempre.
        let currentUserID = CloudSyncFlags.groupsBackendEnabled ? backendUserIDProvider() : nil
        let descriptor = FetchDescriptor<SplitMember>(
            predicate: #Predicate { $0.groupZoneID == zoneName }
        )
        do {
            let members = try context.fetch(descriptor)
            return members.contains {
                $0.isCurrentUser
                    || (!recordName.isEmpty && $0.cloudKitUserRecordID == recordName)
                    || GroupJoinReconcileLogic.backendMemberMatchesCurrentUser(
                        memberUserID: $0.userID, memberKey: $0.memberKey, currentUserID: currentUserID)
            }
        } catch {
            #if DEBUG
            logger.error("JoinReconcile: member existence fetch failed: \(error.localizedDescription, privacy: .public)")
            #endif
            return false
        }
    }
}
