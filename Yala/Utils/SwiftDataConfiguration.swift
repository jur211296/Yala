//
//  SwiftDataConfiguration.swift
//  Yala
//
//  Configuración centralizada de SwiftData para aislamiento entre builds.
//  Incluye soporte opcional para CloudKit sync.
//

import CloudKit
import Foundation
import SwiftData

enum SwiftDataConfiguration {
    // MARK: - CloudKit

    static let cloudKitContainerIdentifier = "iCloud.com.jurgenschmidt.yala"

    /// User preference for iCloud sync (default: OFF)
    static var iCloudSyncEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "iCloudSyncEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "iCloudSyncEnabled") }
    }

    /// Check if iCloud account is available
    static func isICloudAvailable() -> Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    // MARK: - Database

    /// Database name diferenciado por build.
    /// Usa APP_GROUP_IDENTIFIER de Info.plist (consistente con SharedContainerService).
    static var databaseName: String {
        if let appGroup = Bundle.main.object(forInfoDictionaryKey: "APP_GROUP_IDENTIFIER") as? String,
           appGroup.hasSuffix(".dev") {
            return "YalaModel-Dev"
        }
        return "YalaModel"
    }

    /// Schema completo de la app.
    static var schema: Schema {
        Schema([
            Category.self,
            Subcategory.self,
            Tag.self,
            Account.self,
            TransactionItem.self,
            Budget.self,
            ExchangeRate.self,
            FavoritePayment.self,
            ScheduledPayment.self,
            InboxDraft.self,
            MerchantMemory.self,
            NotificationItem.self,
        ])
    }

    /// ModelConfiguration - with or without CloudKit based on user preference
    static var configuration: ModelConfiguration {
        if iCloudSyncEnabled && isICloudAvailable() {
            return ModelConfiguration(
                databaseName,
                cloudKitDatabase: .private(cloudKitContainerIdentifier)
            )
        } else {
            return ModelConfiguration(databaseName)
        }
    }
}
