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
            CloudMigrationMarker.self,
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
            MigrationState.self,
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
            CloudMigrationMarker.self,
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
    /// `MigrationState` (I10-wiring, journal durable de la máquina de migración — single-row).
    static var syncMetaSchema: Schema {
        Schema([
            SyncIdentity.self,
            SyncOutbox.self,
            SyncCursor.self,
            SyncQuarantine.self,
            SyncDanglingRef.self,
            SyncUnitClock.self,
            MigrationState.self,
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

    /// SPIKE S6 — quitar al cerrar I11. Seam DEBUG del harness de remontaje del mirror
    /// (spike S6, Modo Nube Fase 4). Con el arg `-spike-s6-mirror-off` presente, el store
    /// PERSONAL se monta con `cloudKitDatabase: .none` sobre el MISMO archivo de store
    /// (`databaseName`) — a diferencia de `-uitest`, que cambia de nombre de store. Desmonta el
    /// mirror `NSPersistentCloudKitContainer` para simular la fase offline de la reversa; al quitar
    /// el arg y relanzar, el mirror re-monta sobre los mismos datos (= el REMONTAJE que S6 prueba).
    /// Solo lo activa el OWNER con el arg explícito; en release siempre false. Grupos/sync-meta NO
    /// se tocan (su config ya es `.none` siempre).
    static let isSpikeS6MirrorOff: Bool = {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-spike-s6-mirror-off")
        #else
        return false
        #endif
    }()

    // MARK: - Personal store mount witness (I10-wiring w6)

    /// Decisión PURA de qué store personal montar según el `StorageMode`, el flag "mirror-off ARMADO" y
    /// la disponibilidad de iCloud (extraída para testear la rama SIN construir el config —
    /// `isRunningTests` fuerza in-memory y ocultaría la rama real). `.cloud` ARMADO gana ANTES del check
    /// de iCloud: tener cuenta iCloud NO importa (Grupos la usa, pero el store personal ya NO lo espeja
    /// el mirror).
    enum PersonalStoreDecision: Equatable {
        /// `.cloud` + mirror-off ARMADO → `cloudKitDatabase: .none` sobre el MISMO archivo (mirror OFF).
        case cloudMirrorOff
        /// iCloud disponible → mirror `NSPersistentCloudKitContainer` (`.private`) — comportamiento de HOY.
        case iCloudMirror
        /// Sin iCloud → store local plano (sin mirror).
        case localNoMirror
    }

    /// SERIO 1 del review adversarial (ciclo C): `storageMode == .cloud` por sí solo NO basta para
    /// apagar el mirror — `.cloud` se persiste en el paso 2 del cutover (§g.4) y el marcador CloudKit
    /// exporta ASYNC en el paso 3; un kill involuntario en esa ventana relanzaría con el mirror OFF y el
    /// marcador JAMÁS exportaría (migración enclavada en `markerWritten`, irrecuperable sin la reversa).
    /// El montaje mirror-OFF exige el par COMPLETO: `.cloud` Y `mirrorOffArmed` (que el executor arma
    /// SOLO tras `isMarkerExported()`). Un kill pre-armado → mirror remonta ON → el marcador exporta en
    /// el resume → recién el relaunch posterior apaga el mirror. R9: JAMÁS caer a `.automatic`.
    static func personalStoreDecision(
        storageMode: StorageMode, mirrorOffArmed: Bool, iCloudAvailable: Bool
    ) -> PersonalStoreDecision {
        if storageMode == .cloud && mirrorOffArmed { return .cloudMirrorOff }
        return iCloudAvailable ? .iCloudMirror : .localNoMirror
    }

    /// Testigo de QUÉ modo montó realmente ESTE proceso el store personal (NO lo persistido). Lo captura
    /// UNA sola vez, en la PRIMERA evaluación de `personalConfiguration` en el path de producción (= el
    /// build de `sharedModelContainer` al arrancar). Es el árbitro de `isMirrorConfirmedOff()`: en-sesión,
    /// tras `persistLocalMode` escribir `.cloud`, el mirror SIGUE montado (se montó al arrancar) → este
    /// testigo permanece en su valor de arranque hasta el RELANZAMIENTO, cuando un proceso nuevo lo captura
    /// como `.cloud`. Default `.icloud` (los paths test/uitest/spike no lo capturan → mirror asumido vivo).
    nonisolated(unsafe) static private(set) var personalStoreMountedMode: StorageMode = .icloud
    nonisolated(unsafe) private static var personalStoreMountedModeCaptured = false

    private static func capturePersonalStoreMountedModeOnce(_ mode: StorageMode) {
        guard !personalStoreMountedModeCaptured else { return }
        personalStoreMountedModeCaptured = true
        personalStoreMountedMode = mode
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
        // SPIKE S6 — quitar al cerrar I11. MISMO archivo de store personal (databaseName), pero sin
        // mirror: `.none` sobre el store de prod para la fase offline del remontaje. NO cambia el
        // nombre del store (a diferencia de UITest) → al quitar el arg, el mirror re-monta sobre los
        // mismos datos. Va ANTES del check de iCloud a propósito: fuerza mirror OFF haya o no cuenta.
        if isSpikeS6MirrorOff {
            return ModelConfiguration(databaseName, schema: personalSchema, cloudKitDatabase: .none)
        }
        // I10-wiring w6: rama `.cloud` ANTES del check de iCloud (mirror OFF sobre el MISMO archivo de
        // store, patrón SpikeS6), gateada ADEMÁS por el flag mirror-off-ARMADO (SERIO 1 — ver doc de
        // `personalStoreDecision`). DARK: nadie escribe `storageMode=.cloud` ni arma el flag en
        // producción hasta que el cutover de una migración real ejecute sus pasos.
        let decision = personalStoreDecision(
            storageMode: CloudSyncFlags.storageMode,
            mirrorOffArmed: StorageModePersistence.isMirrorOffArmed(),
            iCloudAvailable: isICloudAvailable())
        capturePersonalStoreMountedModeOnce(decision == .cloudMirrorOff ? .cloud : .icloud)
        switch decision {
        case .cloudMirrorOff:
            return ModelConfiguration(databaseName, schema: personalSchema, cloudKitDatabase: .none)
        case .iCloudMirror:
            return ModelConfiguration(
                databaseName,
                schema: personalSchema,
                cloudKitDatabase: .private(cloudKitContainerIdentifier)
            )
        case .localNoMirror:
            return ModelConfiguration(databaseName, schema: personalSchema)
        }
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
