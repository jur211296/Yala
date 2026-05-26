//
//  YalaAppDelegate.swift
//  Yala
//
//  UIApplicationDelegate for:
//  - APNs registration (required by CKSyncEngine for silent push)
//  - CKShare acceptance with segment-based routing (GC-08)
//

import CloudKit
import UIKit

class YalaAppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // CKSyncEngine requires APNs registration for silent push notifications.
        // The engine handles push routing internally via CKDatabaseSubscription.
        application.registerForRemoteNotifications()
        return true
    }

    // MARK: - Universal Link Handling (GC-11)

    func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([any UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL,
              InviteLinkService.isInviteLink(url)
        else { return false }

        Task { @MainActor in
            AppBootstrapper.shared.handleInviteLink(url)
        }
        return true
    }

    // MARK: - CKShare Acceptance (GC-08: segment-based routing)

    func application(
        _ application: UIApplication,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        Task { @MainActor in
            await CKShareEntryHandler.handle(metadata: cloudKitShareMetadata, source: .shareAccepted)
        }
    }
}
