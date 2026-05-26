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
        let sessionState = SessionState.shared
        let hasCompletedOnboarding = UserDefaults.standard.bool(
            forKey: AppPreferences.Keys.hasCompletedOnboarding
        )
        let isHiddenForAll = (metadata.share[CKShareCustomKey.isHiddenForAll] as? Int) == 1
        let isArchived = (metadata.share[CKShareCustomKey.isArchived] as? Int) == 1
        let zoneName = metadata.share.recordID.zoneID.zoneName
        let currentMemberStatus = SplitSyncManager.shared.currentMemberStatus(zoneName: zoneName)

        let decision = AppBootstrapper.inviteRouteDecision(
            hasCompletedOnboarding: hasCompletedOnboarding,
            onboardingMode: sessionState.onboardingMode,
            isHiddenForAll: isHiddenForAll,
            isArchived: isArchived,
            currentMemberStatus: currentMemberStatus
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
        }
    }
}
