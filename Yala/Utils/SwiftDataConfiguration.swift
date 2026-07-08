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

    /// Schema completo (24 modelos) — usado por ModelContainer.
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
            SyncIdentity.self,
            SyncOutbox.self,
            SyncCursor.self,
            SyncQuarantine.self,
            SyncDanglingRef.self,
            SyncUnitClock.self,
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

    /// Sub-schema: metadata de sync del Modo Nube (I2/I3), en su propio store con
    /// `cloudKitDatabase: .none` — metadata LOCAL por dispositivo que NUNCA se espeja a CloudKit.
    /// `SyncIdentity` (I2), `SyncOutbox` + `SyncCursor` (I3, pipeline de captura), `SyncQuarantine`
    /// + `SyncDanglingRef` (I8f-1, deltas no materializables aún + refs singulares colgadas),
    /// `SyncUnitClock` (I8f-2, HLC por-unidad por fila — señal de los reconciliadores).
    static var syncMetaSchema: Schema {
        Schema([
            SyncIdentity.self,
            SyncOutbox.self,
            SyncCursor.self,
            SyncQuarantine.self,
            SyncDanglingRef.self,
            SyncUnitClock.self,
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
        let env = ProcessInfo.processInfo.environment
        // SEÑAL CANÓNICA: el TestAction de los schemes (Yala / Yala Dev) inyecta
        // `YALA_TEST_MODE=1` en el host. Es la ÚNICA señal disponible de forma
        // determinista en `@main` (cuando YalaApp crea sharedModelContainer), porque
        // ahí XCTest/Testing.framework aún NO están cargados ni `XCTestConfigurationFilePath`
        // está seteado para suites Swift Testing puras. Sin esto el host arrancaba con
        // CloudKit en sims sin cuenta iCloud (CI) → crash loop de NSCloudKitMirroringDelegate
        // (CKAccountStatusNoAccount) aunque las aserciones pasaran. Ver TESTING-STRATEGY.md.
        if env["YALA_TEST_MODE"] == "1" {
            return true
        }
        // XCTest legacy — variables de entorno que setea el runner (fallback si se
        // corre fuera del scheme, p.ej. un `xcodebuild test` con scheme custom).
        if env["XCTestConfigurationFilePath"] != nil
            || env["XCTestBundlePath"] != nil
            || env["XCTestSessionIdentifier"] != nil {
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
            // `cloudKitDatabase: .none` es CRÍTICO: por default ModelConfiguration usa
            // `.automatic`, que hace que SwiftData adjunte NSPersistentCloudKitContainer
            // incluso a stores in-memory (la app tiene entitlement CloudKit + schema con
            // relaciones). En sims SIN cuenta iCloud (CI) ese mirror entra en loop de
            // recoverFromError (CKAccountStatusNoAccount / "store removed from coordinator")
            // que desestabiliza el proceso de test → 0 tests + restart loop, aunque las
            // aserciones pasen. `.none` lo desactiva de raíz. Ver TESTING-STRATEGY.md.
            return ModelConfiguration("YalaPersonal", schema: personalSchema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        }
        if isUITesting {
            return ModelConfiguration("YalaModel-UITest", schema: personalSchema, isStoredInMemoryOnly: false, cloudKitDatabase: .none)
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
            // Ver nota en personalConfiguration: `.none` evita el mirror CloudKit en
            // el store in-memory (crash loop en sims sin cuenta iCloud / CI).
            return ModelConfiguration("YalaGroups", schema: groupsSchema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        }
        if isUITesting {
            return ModelConfiguration("YalaGroups-UITest", schema: groupsSchema, isStoredInMemoryOnly: false, cloudKitDatabase: .none)
        }
        // `cloudKitDatabase: .none` es CRÍTICO en producción. El default de
        // ModelConfiguration es `.automatic`, que adjunta NSPersistentCloudKitContainer
        // al container PRIMARIO del entitlement (`iCloud.com.jurgenschmidt.yala`, el
        // personal) — NO al container de grupos. Sin `.none` se crea un segundo canal de
        // sync redundante (record types `CD_Split*` en la private DB personal) que duplica
        // los datos del grupo y compite con el CKSyncEngine manual (filas SplitGroup
        // duplicadas por mismo `cloudKitZoneID`, resurrección de borrados, doble cuota).
        // Grupos sincroniza SOLO vía CKSyncEngine en `iCloud.com.jurgenschmidt.yala.groups`
        // (ver Services/Groups/). Espeja la decisión de las ramas de test/UITest de arriba.
        return ModelConfiguration(groupsDatabaseName, schema: groupsSchema, cloudKitDatabase: .none)
    }

    /// Database name for groups store, derived from personal databaseName.
    static var groupsDatabaseName: String {
        databaseName.replacing("YalaModel", with: "YalaGroups")
    }

    /// Sync-meta store (Modo Nube, I2) — `SyncIdentity` local, NUNCA CloudKit.
    /// `cloudKitDatabase: .none` SIEMPRE: es metadata por-dispositivo (mapping identidad↔ancla↔
    /// record) que se reconstruye localmente y no debe espejarse. Store propio (URL separada, mismo
    /// directorio que personal/grupos), espejando el patrón de `groupsConfiguration`.
    static var syncMetaConfiguration: ModelConfiguration {
        if isRunningTests {
            return ModelConfiguration("YalaSyncMeta", schema: syncMetaSchema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        }
        if isUITesting {
            return ModelConfiguration("YalaSyncMeta-UITest", schema: syncMetaSchema, isStoredInMemoryOnly: false, cloudKitDatabase: .none)
        }
        return ModelConfiguration(syncMetaDatabaseName, schema: syncMetaSchema, cloudKitDatabase: .none)
    }

    /// Database name for the sync-meta store, derived from personal databaseName.
    static var syncMetaDatabaseName: String {
        databaseName.replacing("YalaModel", with: "YalaSyncMeta")
    }
}
