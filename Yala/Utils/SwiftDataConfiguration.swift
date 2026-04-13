//
//  SwiftDataConfiguration.swift
//  Yala
//
//  Configuración centralizada de SwiftData para aislamiento entre builds.
//  CloudKit sync siempre activo si hay cuenta iCloud.
//

import CloudKit
import Foundation
import SwiftData

enum SwiftDataConfiguration {
    // MARK: - CloudKit

    /// CloudKit container diferenciado por build (igual que databaseName).
    static var cloudKitContainerIdentifier: String {
        if let appGroup = Bundle.main.object(forInfoDictionaryKey: "APP_GROUP_IDENTIFIER") as? String,
           appGroup.hasSuffix(".dev") {
            return "iCloud.com.jurgenschmidt.yala.dev"
        }
        return "iCloud.com.jurgenschmidt.yala"
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
            CashFlowPlan.self,
            CashFlowLine.self,
            CashFlowOverride.self,
        ])
    }

    /// Detect if running inside a test host (XCTest sets this automatically)
    static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    // MARK: - Container CloudKit State

    private static let containerCloudKitKey = "containerCreatedWithCloudKit"

    static func markContainerCloudKitState(_ withCloudKit: Bool) {
        UserDefaults.standard.set(withCloudKit, forKey: containerCloudKitKey)
    }

    static var containerWasCreatedWithCloudKit: Bool {
        // Si la key nunca fue escrita, asumir true (usuario existente pre-update)
        guard UserDefaults.standard.object(forKey: containerCloudKitKey) != nil else { return true }
        return UserDefaults.standard.bool(forKey: containerCloudKitKey)
    }

    /// ModelConfiguration - CloudKit enabled automatically if iCloud account available
    static var configuration: ModelConfiguration {
        // In tests: in-memory, no CloudKit — avoids SEGV on simulators without iCloud
        if isRunningTests {
            return ModelConfiguration(isStoredInMemoryOnly: true)
        }

        if isICloudAvailable() {
            return ModelConfiguration(
                databaseName,
                cloudKitDatabase: .private(cloudKitContainerIdentifier)
            )
        } else {
            return ModelConfiguration(databaseName)
        }
    }
}
