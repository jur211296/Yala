//
//  YalaAppDelegate.swift
//  Yala
//
//  UIApplicationDelegate for:
//  - APNs registration (required by CKSyncEngine for silent push)
//  - CKShare acceptance when user taps a group invitation link
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

    // MARK: - CKShare Acceptance

    func application(
        _ application: UIApplication,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        Task { @MainActor in
            await SplitSyncManager.shared.acceptShare(metadata: cloudKitShareMetadata)
        }
    }
}
