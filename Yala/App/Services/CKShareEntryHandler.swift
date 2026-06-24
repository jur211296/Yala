//
//  CKShareEntryHandler.swift
//  Yala
//
//  Single source of truth for CKShare acceptance routing. The Universal
//  Link path and the UIApplicationDelegate `userDidAcceptCloudKitShareWith`
//  callback both delegate to `handle(metadata:branded:source:)`. The handler
//  reads CKShare custom keys (`isHiddenForAll`, `isArchived`), local member
//  status, and `AppBootstrapper.inviteRouteDecision` to choose between
//  invite-onboarding vs reconnect, then enqueues via `RouterEntryGate`.
//

import CloudKit
import Foundation
import OSLog

@MainActor
enum CKShareEntryHandler {

    /// Source of the CKShare acceptance (for telemetry/logs).
    enum Source: String {
        case universalLink   // CKShare embedded inside a Universal Link
        case shareAccepted   // UIApplicationDelegate userDidAccept callback
    }

    private static let logger = Logger(subsystem: "com.yala", category: "CKShareEntry")

    /// Dispatches a CKShare acceptance to the right router intent.
    /// - Parameters:
    ///   - metadata: the CKShare metadata received from CloudKit.
    ///   - branded: optional branded metadata (name/icon/color/members) from a
    ///              Universal Link payload. Nil for direct CKShare acceptance.
    ///   - source: where the acceptance came from (for diagnostics only).
    static func handle(
        metadata: CKShare.Metadata,
        branded: InviteLinkService.BrandedMetadata = .empty,
        source: Source
    ) async {
        // Gate beta de Grupos (validación v2.0.1): quien llega por enlace de invitación
        // queda desbloqueado sin código (decisión owner — los invitados pasan). Este es
        // el SSOT de aceptación de TODO link → cubre todos los sub-modos (invite
        // onboarding, reconnect, alreadyMember, etc.), incl. los que no llaman acceptShare.
        UserDefaults.standard.set(true, forKey: AppPreferences.Keys.groupsBetaUnlocked)

        // SSOT de persistencia para AMBOS entry points (universal link +
        // `userDidAcceptCloudKitShareWith` nativo): los intents de invite son
        // transient y `AppRouter.resetTransients()` los dropea en `.background`.
        // Guardamos la share URL (re-resoluble) para re-emitir en cold launch /
        // foreground. El `CKShare.Metadata` opaco nunca se serializa.
        if let shareURL = metadata.share.url {
            PendingInviteStore.save(PendingInviteEntry(shareURL: shareURL, branded: branded))
        }

        let sessionState = SessionState.shared
        let hasCompletedOnboarding = UserDefaults.standard.bool(
            forKey: AppPreferences.Keys.hasCompletedOnboarding
        )
        let isHiddenForAll = (metadata.share[CKShareCustomKey.isHiddenForAll] as? Int) == 1
        let isArchived = (metadata.share[CKShareCustomKey.isArchived] as? Int) == 1
        let zoneName = metadata.share.recordID.zoneID.zoneName
        let currentMemberStatus = SplitSyncManager.shared.currentMemberStatus(zoneName: zoneName)

        // Parte F: solo evaluamos la señal de returning user (KV, con espera corta)
        // cuando aplica — fresh-install sin modo grupo, grupo no archivado/oculto.
        // Evita retrasar el routing en los casos comunes (returning con onboarding hecho).
        let needsReturningCheck = !hasCompletedOnboarding
            && sessionState.onboardingMode != .groupInvite
            && !isHiddenForAll && !isArchived
        let hasReturningSignal = needsReturningCheck ? await awaitReturningSignal() : false

        let decision = AppBootstrapper.inviteRouteDecision(
            hasCompletedOnboarding: hasCompletedOnboarding,
            onboardingMode: sessionState.onboardingMode,
            isHiddenForAll: isHiddenForAll,
            isArchived: isArchived,
            currentMemberStatus: currentMemberStatus,
            hasReturningSignal: hasReturningSignal
        )

        #if DEBUG
        logger.debug("CKShareEntryHandler: source=\(source.rawValue, privacy: .public) decision=\(String(describing: decision), privacy: .public)")
        #endif

        switch decision {
        case .acceptAndShowInviteOnboarding:
            let invite = InviteMetadata(
                groupName: branded.name,
                groupIcon: branded.icon,
                groupColor: branded.color,
                groupMembers: branded.members,
                shareMetadata: metadata,
                mode: .standardReconnect
            )
            await SplitSyncManager.shared.acceptShare(metadata: metadata, skipNavigation: true)
            RouterEntryGate.shared.submit(.presentGroupInviteOnboarding(invite))

        case .showReconnect(let mode):
            // NO acceptShare eagerly — GroupReconnectView.onJoin invokes
            // acceptShare on user confirmation (per the chosen mode).
            let invite = InviteMetadata(
                groupName: branded.name,
                groupIcon: branded.icon,
                groupColor: branded.color,
                groupMembers: branded.members,
                shareMetadata: metadata,
                mode: mode
            )
            RouterEntryGate.shared.submit(.presentGroupReconnect(invite))

        case .offerRestoreThenInvite:
            // Parte F: NO acceptShare aún. El invite ya quedó en PendingInviteStore
            // (arriba) y se re-emite tras restaurar / empezar de cero; el accept ocurre
            // en el reconnect resultante. Aquí solo presentamos la oferta.
            let invite = InviteMetadata(
                groupName: branded.name,
                groupIcon: branded.icon,
                groupColor: branded.color,
                groupMembers: branded.members,
                shareMetadata: metadata,
                mode: .standardReconnect
            )
            RouterEntryGate.shared.submit(.offerRestoreBeforeInvite(invite))
        }
    }

    /// Espera corta a que el KV-store baje la señal de returning user (mismo enfoque
    /// que el Welcome Hero). Si no baja en `timeout`, devuelve la última lectura; la
    /// re-emisión del invite desde `PendingInviteStore` la re-evalúa más tarde
    /// (foreground/bootstrap), de modo que el gap no queda fijado en `false`.
    private static func awaitReturningSignal(timeout: TimeInterval = 5) async -> Bool {
        let deadline = Date.now.addingTimeInterval(timeout)
        func signal() -> Bool {
            RestoreOfferGate.hasReturningSignal(
                lastOnboarding: PreferenceSyncService.shared.lastOnboardingTimestamp,
                lastWipe: PreferenceSyncService.shared.lastWipeTimestamp
            )
        }
        func wiped() -> Bool {
            RestoreOfferGate.wasWiped(
                lastOnboarding: PreferenceSyncService.shared.lastOnboardingTimestamp,
                lastWipe: PreferenceSyncService.shared.lastWipeTimestamp
            )
        }
        while Date.now < deadline {
            if signal() { return true }
            if wiped() { return false }  // wipe presente → no tiene sentido esperar más
            try? await Task.sleep(for: .seconds(1))
        }
        return signal()
    }
}
