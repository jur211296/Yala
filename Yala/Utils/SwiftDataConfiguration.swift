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

    /// CloudKit container for SwiftData auto-sync (personal data).
    static var cloudKitContainerIdentifier: String {
        if let appGroup = Bundle.main.object(forInfoDictionaryKey: "APP_GROUP_IDENTIFIER") as? String,
           appGroup.hasSuffix(".dev") {
            return "iCloud.com.jurgenschmidt.yala.dev"
        }
        return "iCloud.com.jurgenschmidt.yala"
    }

    /// CloudKit container dedicated to CKSyncEngine (groups).
    /// Separated from SwiftData auto-sync to prevent NSCloudKitMirroringDelegate interference.
    static var groupsCloudKitContainerIdentifier: String {
        if let appGroup = Bundle.main.object(forInfoDictionaryKey: "APP_GROUP_IDENTIFIER") as? String,
           appGroup.hasSuffix(".dev") {
            return "iCloud.com.jurgenschmidt.yala.groups.dev"
        }
        return "iCloud.com.jurgenschmidt.yala.groups"
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

    // MARK: - Schemas

    /// Schema completo (21 modelos) — usado por ModelContainer.
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
            GroupBridgePreference.self,
            SplitGroup.self,
            SplitMember.self,
            SplitExpense.self,
            SplitShare.self,
            SplitSettlement.self,
        ])
    }

    /// Sub-schema: 16 modelos personales (CloudKit synced via private DB).
    /// `GroupBridgePreference` vive aquí porque es preferencia personal por-user
    /// (synced cross-device del mismo Apple ID, NO compartida con otros miembros
    /// del grupo). Distinto de los Split* que viven en `groupsSchema` (CKSyncEngine).
    static var personalSchema: Schema {
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
            GroupBridgePreference.self,
        ])
    }

    /// Sub-schema: 5 modelos de grupos (local only — CKSyncEngine maneja sync).
    static var groupsSchema: Schema {
        Schema([
            SplitGroup.self,
            SplitMember.self,
            SplitExpense.self,
            SplitShare.self,
            SplitSettlement.self,
        ])
    }

    // MARK: - Configurations

    /// Detect if running inside a test host. Cubre XCTest legacy y Swift Testing.
    /// Sin esta detección, el host (Yala.app) bootea con CloudKit durante el test
    /// runner y crashea repetidamente con `CKAccountStatusNoAccount` → process
    /// restarts en `/test-ios` completos.
    ///
    /// Cacheado en `let` para que sea estable durante el ciclo del proceso (evita
    /// que la decisión cambie entre boot temprano y boot tardío del host).
    static let isRunningTests: Bool = {
        // XCTest legacy — variable de entorno que setea el runner
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return true
        }
        // Swift Testing y XCTest cargan el framework XCTest.framework en el process.
        // `XCTestObservationCenter` es la clase pública del framework — si está
        // disponible, estamos en un test runner.
        if NSClassFromString("XCTestObservationCenter") != nil {
            return true
        }
        // Swift Testing puro (sin XCTest) — detectar la clase del framework Testing.
        if NSClassFromString("Testing.Test") != nil {
            return true
        }
        // Fallback: scan loaded bundles
        if Bundle.allBundles.contains(where: { $0.bundlePath.hasSuffix(".xctest") }) {
            return true
        }
        return false
    }()

    /// UI-testing seam (mirror de `isRunningTests`). En release siempre false.
    /// Fuerza store local dedicado sin CloudKit para aislar los XCUITests del
    /// CloudKit del Apple ID (espejo del bypass de tests unitarios).
    static let isUITesting: Bool = {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-uitest")
        #else
        return false
        #endif
    }()

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

    /// Personal data — CloudKit synced (same databaseName = same SQLite file).
    static var personalConfiguration: ModelConfiguration {
        if isRunningTests {
            return ModelConfiguration("YalaPersonal", schema: personalSchema, isStoredInMemoryOnly: true)
        }
        if isUITesting {
            return ModelConfiguration("YalaModel-UITest", schema: personalSchema, isStoredInMemoryOnly: false)
        }
        if isICloudAvailable() {
            return ModelConfiguration(
                databaseName,
                schema: personalSchema,
                cloudKitDatabase: .private(cloudKitContainerIdentifier)
            )
        }
        return ModelConfiguration(databaseName, schema: personalSchema)
    }

    /// Group data — local only (CKSyncEngine syncs via groups container).
    static var groupsConfiguration: ModelConfiguration {
        if isRunningTests {
            return ModelConfiguration("YalaGroups", schema: groupsSchema, isStoredInMemoryOnly: true)
        }
        if isUITesting {
            return ModelConfiguration("YalaGroups-UITest", schema: groupsSchema, isStoredInMemoryOnly: false)
        }
        return ModelConfiguration(groupsDatabaseName, schema: groupsSchema)
    }

    /// Database name for groups store, derived from personal databaseName.
    static var groupsDatabaseName: String {
        databaseName.replacing("YalaModel", with: "YalaGroups")
    }
}
