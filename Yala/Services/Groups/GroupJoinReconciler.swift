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
            TelemetryService.track(.groupJoinIntentDeferred, parameters: ["reason": "importNotQuiescent"])
            return
        }

        for entry in entries {
            let group = groupLookup?(entry.zoneName) ?? SplitSyncManager.shared.group(for: entry.zoneName)
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
                TelemetryService.track(.groupJoinIntentDeferred, parameters: ["reason": "waitForGroup"])
                GroupJoinIntentTracker.shared.rehydrate(zoneName: entry.zoneName)

            case .waitForEngines:
                logger.notice("JoinReconcile[\(trigger.rawValue, privacy: .public)]: engines not ready for \(entry.zoneName, privacy: .public)")
                TelemetryService.track(.groupJoinIntentDeferred, parameters: ["reason": "enginesNotReady"])

            case .reconcile:
                guard let group else { continue }
                GroupJoinIntentTracker.shared.noteGroupInserted(zoneName: entry.zoneName)
                await reconcileEntry(entry, group: group, trigger: trigger, context: providedContext)
            }
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
            TelemetryService.track(.groupJoinIntentReconciled, parameters: [
                "trigger": trigger.rawValue,
                "status": member.memberStatus.rawValue
            ])
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

    /// `true` si ya existe un SplitMember del current user para la zona (por
    /// `cachedRecordName` o flag `isCurrentUser`). Identidad no resuelta → false
    /// (el ensure la resuelve y matchea; el guard del displayName queda laxo,
    /// aceptable: member "recién creado" solo relaja el anti-pisado).
    private static func currentUserMemberExists(zoneName: String, context providedContext: ModelContext?) -> Bool {
        guard let context = providedContext else {
            // Producción: helper del manager sobre su propio contexto.
            return SplitSyncManager.shared.currentUserMember(zoneID: zoneName) != nil
        }
        let recordName = GroupUserIdentityService.shared.cachedRecordName ?? ""
        let descriptor = FetchDescriptor<SplitMember>(
            predicate: #Predicate { $0.groupZoneID == zoneName }
        )
        do {
            let members = try context.fetch(descriptor)
            return members.contains {
                $0.isCurrentUser || (!recordName.isEmpty && $0.cloudKitUserRecordID == recordName)
            }
        } catch {
            #if DEBUG
            logger.error("JoinReconcile: member existence fetch failed: \(error.localizedDescription, privacy: .public)")
            #endif
            return false
        }
    }
}
