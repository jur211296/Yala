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
            GroupSyncOutbox.self,
            GroupSyncCursor.self,
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
            // G2: cola + cursor del canal de sync de Grupos → backend (DARK; store `.none`, sin deploy).
            GroupSyncOutbox.self,
            GroupSyncCursor.self,
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

    // MARK: - Personal store mount witness (I10-wiring w6)

    /// Decisión PURA de qué store personal montar según el `StorageMode`, el flag "mirror-off ARMADO" y
    /// la disponibilidad de iCloud (extraída para testear la rama SIN construir el config —
    /// `isRunningTests` fuerza in-memory y ocultaría la rama real). `.cloud` ARMADO gana ANTES del check
    /// de iCloud: tener cuenta iCloud NO importa (Grupos la usa, pero el store personal ya NO lo espeja
    /// el mirror).
    enum PersonalStoreDecision: Equatable {
        /// Sesión SECUNDARIA activa (M1) → `cloudKitDatabase: .none` sobre el archivo SECUNDARIO
        /// (`YalaModel-Secondary`). Gana ANTES que todo — el archivo del dueño ni se lee ni se
        /// escribe, y el mirror JAMÁS se adjunta al secundario.
        case secondaryCloudSession
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
    ///
    /// M1: `secondarySessionActive` (descriptor de `SecondarySessionStore`) gana ANTES que todo —
    /// SIN acoplarse a `mirrorOffArmed` (ese par protege el kill-window del cutover de MIGRACIÓN;
    /// la sesión secundaria no migra, adopta sobre un archivo propio que nunca tuvo mirror).
    static func personalStoreDecision(
        storageMode: StorageMode, mirrorOffArmed: Bool, iCloudAvailable: Bool,
        secondarySessionActive: Bool = false
    ) -> PersonalStoreDecision {
        if secondarySessionActive { return .secondaryCloudSession }
        if storageMode == .cloud && mirrorOffArmed { return .cloudMirrorOff }
        return iCloudAvailable ? .iCloudMirror : .localNoMirror
    }

    // MARK: - Groups store mount decision (M1 / D8 — G5-C)

    /// Decisión PURA de qué store de GRUPOS montar. Simetría con `PersonalStoreDecision`, pero BINARIA:
    /// el store de grupos es SECUNDARIO solo cuando el canal grupos→backend está encendido (`flagOn`) Y hay
    /// sesión secundaria activa. Con el flag OFF (TODO device de producción esta fase) es SIEMPRE `.primary`
    /// — el store del dueño (`YalaGroups`), byte-idéntico a hoy: en secundaria+flag OFF el tab de Grupos
    /// está filtrado y el canal backend NO corre (`AppBootstrapper`/`GroupsSyncClient` lo gatean), así que
    /// el archivo del dueño queda inerte (nunca se lee ni se escribe). Con flag ON la invitada monta SU
    /// propio `YalaGroups-Secondary` y el canal backend corre bajo su sesión (mueren M1-2/M1-3 por
    /// construcción). Espeja `syncMetaConfiguration` pero ANDeado por el flag (el sync-meta secundario es
    /// obligatorio SIEMPRE; el store de grupos solo cuando el canal backend participa).
    enum GroupsStoreDecision: Equatable {
        case primary
        case secondary

        static func decide(flagOn: Bool, secondaryActive: Bool) -> GroupsStoreDecision {
            (flagOn && secondaryActive) ? .secondary : .primary
        }
    }

    /// Testigo de QUÉ modo montó realmente ESTE proceso el store personal (NO lo persistido). Lo captura
    /// UNA sola vez, en la PRIMERA evaluación de `personalConfiguration` en el path de producción (= el
    /// build de `sharedModelContainer` al arrancar). Es el árbitro de `isMirrorConfirmedOff()`: en-sesión,
    /// tras `persistLocalMode` escribir `.cloud`, el mirror SIGUE montado (se montó al arrancar) → este
    /// testigo permanece en su valor de arranque hasta el RELANZAMIENTO, cuando un proceso nuevo lo captura
    /// como `.cloud`. Default `.icloud` (los paths test/uitest/spike no lo capturan → mirror asumido vivo).
    nonisolated(unsafe) static private(set) var personalStoreMountedMode: StorageMode = .icloud
    nonisolated(unsafe) private static var personalStoreMountedModeCaptured = false

    /// Testigo M1: ¿ESTE proceso montó el store SECUNDARIO? Capturado junto al modo, misma
    /// semántica una-sola-vez. Es el árbitro de la VENTANA DE ENTRADA (descriptor persistido pero
    /// proceso viejo con el store del DUEÑO montado): el guard de mount-mismatch del runtime y el
    /// blocker `secondaryEntryRelaunch` lo consultan — `SecondarySessionStore.isActive() && !este
    /// testigo` ⇒ nada puede sincronizar ni presentarse hasta el relaunch. Default `false` (paths
    /// test/uitest no lo capturan).
    nonisolated(unsafe) static private(set) var secondaryStoreMounted = false

    /// Solo tests: fuerza el testigo del mount secundario. El host de tests JAMÁS monta el store
    /// secundario (default `false`), así que los tests del guard D8 de mount-mismatch
    /// (`GroupsLoopRestartLogic` / `startIfEligible` mid-session) necesitan ambas celdas: secundaria
    /// OPERATIVA (montado, post-relaunch) y VENTANA DE ENTRADA (no montado). Restaurar en `defer`
    /// bajo `@Suite(.serialized)` (molde `SecondarySessionStore._testSetActiveOverride`).
    static func _testSetSecondaryStoreMounted(_ value: Bool) {
        secondaryStoreMounted = value
    }

    private static func capturePersonalStoreMountedModeOnce(_ mode: StorageMode, secondary: Bool = false) {
        guard !personalStoreMountedModeCaptured else { return }
        personalStoreMountedModeCaptured = true
        personalStoreMountedMode = mode
        secondaryStoreMounted = secondary
    }

    // MARK: - Sign-out wipe (H4 — "Cerrar sesión" en `.cloud`)

    /// BOOT-CLEANUP del cierre de sesión en `.cloud`. DEBE correr ANTES de construir el
    /// ModelContainer (pre-mount): borra los ARCHIVOS de los stores personal y sync-meta y deja el
    /// device como recién instalado. Se borran ARCHIVOS y no FILAS a propósito — los deletes de
    /// filas quedan en la SwiftData History y el remount mirror-ON los REPLAYARÍA hacia iCloud
    /// destruyendo el backup congelado pre-migración (qa/cloud/README HALLAZGO 3). Un archivo
    /// nuevo no tiene History: el remount hace fresh import de iCloud = semántica de reinstalación.
    ///
    /// Precondiciones: el coordinador de sign-out ya subió TODO el outbox (verificado), cerró la
    /// sesión y armó `signOutWipeArmed`. El store de GRUPOS legacy (CKSyncEngine, atado al iCloud del
    /// OS) NO se toca por defecto; SOLO si el sign-out marcó `signOutWipeIncludesGroups` (G5-B — flag
    /// `groupsBackendEnabled` ON, canal de grupos→backend: el store de grupos es re-descargable desde
    /// el backend y debe olvidarse junto a la sesión). Con el flag OFF (TODO device prod) el marker
    /// jamás existe ⇒ este hook es byte-idéntico. El claim-store (UserDefaults keyed por userID)
    /// sobrevive → la misma cuenta re-entra por adopt sin migración.
    ///
    /// Orden IDEMPOTENTE ante kill a mitad (el arm se limpia AL FINAL; re-entrada re-ejecuta:
    /// archivos ya ausentes = no-op, escrituras de flags idempotentes):
    /// 1) archivos personal + sync-meta → 2) par storageMode/mirrorOffArmed a `.icloud` fresh
    /// (invariante SERIO-1: juntos) → 3) prefs/caches/onboarding a estado recién instalada →
    /// 4) desarmar.
    static func performSignOutWipeIfArmed() {
        guard !isRunningTests, !isUITesting else { return }
        guard StorageModePersistence.isSignOutWipeArmed() else { return }

        // S3 del review: si el borrado del archivo BASE falla (≠ no-existe), ABORTAR sin
        // escribir `.icloud` ni desarmar — continuar remontaría el mirror SOBRE el archivo
        // de la época `.cloud` y el replay de su History destruiría el backup de iCloud
        // (exactamente el fallo que el borrado-por-archivos existe para impedir). El arm
        // persiste → el próximo boot reintenta; mientras tanto el par SERIO-1 sigue
        // consistente (`.cloud`+mirrorOffArmed → mount mirror-OFF, sin riesgo).
        guard deleteStoreFiles(named: databaseName, schema: personalSchema),
              deleteStoreFiles(named: syncMetaDatabaseName, schema: syncMetaSchema) else {
            CloudSyncBreadcrumb.signOutWipeAborted(reason: "store file deletion failed")
            return
        }

        // G5-B: si el sign-out marcó incluir grupos (canal grupos→backend, flag ON), borrar TAMBIÉN el
        // trío de archivos del store de grupos. Un fallo aquí NO aborta el wipe personal (ya consumado);
        // el trío -wal/-shm huérfano es inerte y el store se recrea vacío al montar. El marker se limpia
        // JUNTO al arm (AL FINAL, orden kill-safe existente).
        if StorageModePersistence.signOutWipeIncludesGroups() {
            _ = deleteStoreFiles(named: groupsDatabaseName, schema: groupsSchema)
        }

        StorageModePersistence.write(.icloud)
        UserDefaults.standard.removeObject(forKey: StorageModePersistence.mirrorOffArmedKey)

        DataWipeService.resetForSignOutWipe()

        // #37 (A3 del review): retirar los sentinels del drenaje iKV→outbox — `removeUserPreferenceKeys`
        // EXCLUYE `cloudSync.*` a propósito (los gestiona este boot-hook en el orden kill-safe). Sin
        // esto, un migrar → sign-out `.cloud` → borrado de cuenta → RE-migración como líder haría skip
        // del drenaje (la misma clase de H3/reversa). Idempotente; el arm se desarma DESPUÉS.
        for key in PrefsCutoverDrain.sentinelKeys(
            in: Array(UserDefaults.standard.dictionaryRepresentation().keys)
        ) {
            UserDefaults.standard.removeObject(forKey: key)
        }

        StorageModePersistence.clearSignOutWipeIncludesGroups()
        StorageModePersistence.clearSignOutWipeArm()
        CloudSyncBreadcrumb.signOutWipeExecuted()
    }

    // MARK: - Sign-out solo-grupos (G5-B) — hook de frontera pre-mount

    /// BOOT-CLEANUP de la salida de una sesión SOLO-GRUPOS (personal `.icloud`, sesión backend viva,
    /// flag `groupsBackendEnabled` ON). Borra SOLO los archivos del store de GRUPOS — NUNCA `YalaModel`
    /// ni `YalaSyncMeta`, NO resetea onboarding ni prefs personales, NO escribe `storageMode` (el device
    /// sigue en `.icloud`). El store de grupos→backend es re-descargable: un archivo nuevo sin History
    /// re-importa del backend al re-iniciar sesión (semántica de reinstalación del canal de grupos).
    ///
    /// Idempotente / kill-safe: el arm se limpia AL FINAL; una re-entrada tras kill re-ejecuta (archivos
    /// ya ausentes = no-op). Un fallo del borrado del archivo BASE conserva el arm → reintento en el
    /// próximo boot; el personal jamás corre riesgo (solo se tocan archivos de grupos).
    static func performGroupsOnlySignOutWipeIfArmed() {
        guard !isRunningTests, !isUITesting else { return }
        performGroupsOnlySignOutWipeIfArmed(
            defaults: .standard,
            deleteFiles: { deleteStoreFiles(named: $0, schema: $1) })
    }

    /// Variante inyectable (tests del ORDEN/idempotencia sin archivos reales; el wrapper de producción
    /// mantiene los guards de test/uitest).
    static func performGroupsOnlySignOutWipeIfArmed(
        defaults: UserDefaults,
        deleteFiles: (String, Schema) -> Bool
    ) {
        guard StorageModePersistence.isGroupsOnlyWipeArmed(defaults) else { return }

        guard deleteFiles(groupsDatabaseName, groupsSchema) else {
            CloudSyncBreadcrumb.signOutGroupsOnlyWipeAborted(reason: "groups store file deletion failed")
            return
        }

        StorageModePersistence.clearGroupsOnlyWipeArm(defaults)
        CloudSyncBreadcrumb.signOutGroupsOnlyWipeExecuted()
    }

    // MARK: - Sesión secundaria (M1) — hooks de frontera pre-mount

    /// BOOT-CLEANUP de la SALIDA de la sesión secundaria. Molde de `performSignOutWipeIfArmed`
    /// (incl. patrón S3 de abort) pero sobre los archivos `-Secondary` — **JAMÁS toca**
    /// `storageMode`/`mirrorOffArmed`, los archivos del dueño ni `DataWipeService.resetForSignOutWipe`
    /// (nukearía las prefs del DUEÑO, que sobreviven por decisión 7 del diseño M1).
    ///
    /// Orden idempotente ante kill a mitad (el arm se limpia AL FINAL):
    /// 1) los 3 archivos secundarios EN ORDEN — personal → sync-meta → GRUPOS (M1/D8: `YalaGroups-Secondary`
    ///    con montos de la invitada; borrado INCONDICIONAL, no-op real si no existe [flag OFF] ⇒ byte-idéntico;
    ///    el guard abort-S3 cubre los 3: fallo en el BASE de CUALQUIERA aborta, el arm y el descriptor
    ///    persisten, el mount sigue siendo el secundario y el próximo boot reintenta) → 2) purga E2E-M1
    ///    (incl. el espejo App Group de grupos) → 3) descriptor + marker de entrada → 3.5) los 3 flags de
    ///    onboarding a `false` (EN EL BOOT y jamás in-session: con el proceso vivo montaría la cadena Welcome
    ///    DEBAJO del cover de relaunch — doble presentación mismo anchor, clase toolbar-muerta) → 4) desarmar.
    static func performSecondaryWipeIfArmed() {
        guard !isRunningTests, !isUITesting else { return }
        performSecondaryWipeIfArmed(
            defaults: .standard,
            deleteFiles: { deleteStoreFiles(named: $0, schema: $1) },
            purge: { SecondarySessionBoundaryPurge.purge() })
    }

    /// Variante inyectable (tests del ORDEN sin archivos reales — el wrapper de producción
    /// mantiene los guards de test/uitest).
    static func performSecondaryWipeIfArmed(
        defaults: UserDefaults,
        deleteFiles: (String, Schema) -> Bool,
        purge: () -> Void
    ) {
        guard SecondarySessionStore.isWipeArmed(defaults) else { return }

        guard deleteFiles(secondaryDatabaseName, personalSchema),
              deleteFiles(secondarySyncMetaDatabaseName, syncMetaSchema),
              deleteFiles(secondaryGroupsDatabaseName, groupsSchema) else {
            CloudSyncBreadcrumb.secondaryWipeAborted(reason: "store file deletion failed")
            return
        }

        purge()

        SecondarySessionStore.clear(defaults)
        SecondarySessionStore.clearEntryPurgeMark(defaults)

        defaults.set(false, forKey: AppPreferences.Keys.hasCompletedOnboarding)
        defaults.set(false, forKey: "hasShownWelcomeChooser")
        defaults.set(false, forKey: AppPreferences.Keys.hasShownYalaAIOnboarding)

        SecondarySessionStore.clearWipeArm(defaults)
        CloudSyncBreadcrumb.secondaryWipeExecuted()
    }

    /// Tareas de ENTRADA de la sesión secundaria (one-shot idempotente, pre-mount): purga las
    /// superficies App Group del dueño (sus colas Apple Pay/Siri/imágenes no deben materializarse
    /// en el store de la invitada), cancela sus notificaciones locales pendientes (se reprograman
    /// con sus boot-reconcilers cuando vuelva) y sana los flags de onboarding si un kill se comió
    /// la ventana descriptor→flags de la entrada (sin el healing, el boot mostraría el Welcome
    /// sobre el store secundario vacío y un re-sign-in caería en el adopt CLÁSICO, que escribe el
    /// PAR global `.cloud`+`mirrorOffArmed` del dueño). Marker AL FINAL (kill a mitad ⇒ re-purga
    /// completa, todo idempotente).
    static func performSecondaryEntryTasksIfNeeded() {
        guard !isRunningTests, !isUITesting else { return }
        performSecondaryEntryTasksIfNeeded(
            defaults: .standard,
            purge: { SecondarySessionBoundaryPurge.purge() },
            cancelNotifications: { NotificationService.shared.cancelAllNotifications() })
    }

    /// Variante inyectable (tests). El healing escribe DIRECTO el mínimo (no
    /// `completeOnboardingAsRestoreSkip`, que es de ContentView y setea el trial): perder el
    /// trial-offer en este camino de kill-recovery es aceptable — un brick no.
    static func performSecondaryEntryTasksIfNeeded(
        defaults: UserDefaults,
        purge: () -> Void,
        cancelNotifications: () -> Void
    ) {
        guard SecondarySessionStore.isActive(defaults),
              !SecondarySessionStore.isEntryPurgeDone(defaults) else { return }

        purge()
        cancelNotifications()

        if !defaults.bool(forKey: AppPreferences.Keys.hasCompletedOnboarding) {
            defaults.set(true, forKey: AppPreferences.Keys.hasCompletedOnboarding)
            defaults.set(true, forKey: "hasShownWelcomeChooser")
        }

        SecondarySessionStore.markEntryPurgeDone(defaults)
        CloudSyncBreadcrumb.secondaryEntryPurged()
    }

    /// Borra el trío de archivos SQLite de un store (base + -wal + -shm). La URL se deriva de una
    /// ModelConfiguration efímera (misma name+schema ⇒ misma URL) SIN pasar por `personalConfiguration`
    /// para no capturar el testigo `personalStoreMountedMode` antes del wipe.
    /// Devuelve `false` solo si el archivo BASE no pudo borrarse (≠ no-existe) — los sidecars
    /// -wal/-shm huérfanos sin base son inertes (SQLite los descarta al recrear el store).
    private static func deleteStoreFiles(named name: String, schema: Schema) -> Bool {
        let url = ModelConfiguration(name, schema: schema, cloudKitDatabase: .none).url
        var baseDeleted = true
        for (index, path) in [url.path, url.path + "-wal", url.path + "-shm"].enumerated() {
            do {
                try FileManager.default.removeItem(atPath: path)
            } catch let error as NSError
                where error.domain == NSCocoaErrorDomain && error.code == NSFileNoSuchFileError {
                // Ya ausente (re-entrada idempotente tras kill a mitad) — no-op.
            } catch {
                #if DEBUG
                print("SwiftDataConfiguration: Error borrando store \(name): \(error)")
                #endif
                if index == 0 { baseDeleted = false }
            }
        }
        return baseDeleted
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
        // I10-wiring w6: rama `.cloud` ANTES del check de iCloud (mirror OFF sobre el MISMO archivo de
        // store, patrón device-validado por el spike S6 — harness retirado al cerrar I11), gateada
        // ADEMÁS por el flag mirror-off-ARMADO (SERIO 1 — ver doc de
        // `personalStoreDecision`). DARK: nadie escribe `storageMode=.cloud` ni arma el flag en
        // producción hasta que el cutover de una migración real ejecute sus pasos.
        // M1: el descriptor de sesión secundaria gana ANTES que todo (archivo propio, JAMÁS `.private`).
        let decision = personalStoreDecision(
            storageMode: CloudSyncFlags.storageMode,
            mirrorOffArmed: StorageModePersistence.isMirrorOffArmed(),
            iCloudAvailable: isICloudAvailable(),
            secondarySessionActive: SecondarySessionStore.isActive())
        capturePersonalStoreMountedModeOnce(
            decision == .cloudMirrorOff || decision == .secondaryCloudSession ? .cloud : .icloud,
            secondary: decision == .secondaryCloudSession)
        switch decision {
        case .secondaryCloudSession:
            return ModelConfiguration(secondaryDatabaseName, schema: personalSchema, cloudKitDatabase: .none)
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

    /// M1 — nombres de los stores SECUNDARIOS (1 slot ⇒ nombre FIJO; el `userID` del descriptor
    /// valida la identidad del ocupante). Derivados de `databaseName` ⇒ heredan la variante `-Dev`.
    static var secondaryDatabaseName: String {
        databaseName + "-Secondary"
    }

    /// El sync-meta secundario es OBLIGATORIO: cursor/journal/identidades/outbox de la cuenta
    /// invitada jamás deben caer en el `YalaSyncMeta` del dueño (contaminación silenciosa de
    /// Merkle y del journal de migración del dueño).
    static var secondarySyncMetaDatabaseName: String {
        syncMetaDatabaseName + "-Secondary"
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
        //
        // M1 / D8 (G5-C): en sesión secundaria + canal grupos→backend ENCENDIDO, la invitada monta su
        // propio archivo `YalaGroups-Secondary` (los grupos de SU cuenta bajan del backend bajo su
        // sesión). Lectura DIRECTA de `SecondarySessionStore.isActive()` (NO `capturePersonalStore...`:
        // ese testigo lo captura SOLO el mount personal). Con flag OFF → `.primary` = byte-idéntico.
        switch GroupsStoreDecision.decide(
            flagOn: CloudSyncFlags.groupsBackendEnabled,
            secondaryActive: SecondarySessionStore.isActive()) {
        case .secondary:
            return ModelConfiguration(secondaryGroupsDatabaseName, schema: groupsSchema, cloudKitDatabase: .none)
        case .primary:
            return ModelConfiguration(groupsDatabaseName, schema: groupsSchema, cloudKitDatabase: .none)
        }
    }

    /// Database name for groups store, derived from personal databaseName.
    static var groupsDatabaseName: String {
        databaseName.replacing("YalaModel", with: "YalaGroups")
    }

    /// M1 / D8 — nombre del store de GRUPOS SECUNDARIO (1 slot ⇒ nombre FIJO; el `userID` del descriptor
    /// valida la identidad del ocupante). Derivado de `groupsDatabaseName` ⇒ hereda la variante `-Dev`.
    static var secondaryGroupsDatabaseName: String {
        groupsDatabaseName + "-Secondary"
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
        // M1: en sesión secundaria el sync-meta TAMBIÉN es un archivo propio — misma condición que
        // el mount personal (ambas se evalúan una vez, al construir el container en el boot).
        if SecondarySessionStore.isActive() {
            return ModelConfiguration(secondarySyncMetaDatabaseName, schema: syncMetaSchema, cloudKitDatabase: .none)
        }
        return ModelConfiguration(syncMetaDatabaseName, schema: syncMetaSchema, cloudKitDatabase: .none)
    }

    /// Database name for the sync-meta store, derived from personal databaseName.
    static var syncMetaDatabaseName: String {
        databaseName.replacing("YalaModel", with: "YalaSyncMeta")
    }
}
