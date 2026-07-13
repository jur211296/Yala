//
//  CloudSyncFlags.swift
//  Yala
//
//  Feature flags del Modo Nube (épica de sync). Incremento I2 (Identidad de sync).
//
//  Todo el subsistema de identidad se construye DARK: mergeable sin cambio de comportamiento
//  para los usuarios actuales. El único gate en runtime es `identityCaptureEnabled`, y HOY es
//  SIEMPRE `false` — ningún path de producción lo activa. Lo encenderá el propio Modo Nube en un
//  incremento posterior (I12/I14, cuando el pipeline de sync consuma las identidades), nunca antes.
//
//  `nonisolated`: son constantes/flags puros sin relación con el main actor; se leen tanto desde
//  hubs `@MainActor` (creación de entidades) como desde lógica de sync fuera del main actor.
//

import Foundation

/// Modo de almacenamiento del store personal (SSOT del enrutado de quiescencia y de las redes de
/// arranque/teardown del motor). `nonisolated`: es un valor puro leído tanto desde el main actor
/// (bootstrap) como desde la lógica pura de enrutado (`StorageModeSignalRouter`).
///
/// - `.icloud`: el store personal lo espeja NSPersistentCloudKitContainer (comportamiento de HOY,
///   SIEMPRE). La quiescencia la manda `iCloudSyncService.isImportQuiescent`.
/// - `.cloud`: el store personal lo sincroniza el propio motor Modo Nube (CKit apagado). La
///   quiescencia la manda el `SyncQuiescenceCoordinator` del motor. NO alcanzable en I9 — la
///   persistencia real del modo + su transición llegan en I10/I14.
nonisolated enum StorageMode: String {
    case icloud
    case cloud
}

/// Persistencia DURABLE del `StorageMode` elegido (I10-wiring w6). UserDefaults key `cloudSync.storageMode`.
/// DARK: NADIE escribe la key en producción hasta que el cutover de una migración REAL ejecute
/// `persistLocalMode` (`MigrationWorkExecutor`). Ausencia de la key ⇒ `.icloud` (comportamiento de HOY,
/// SIEMPRE). `defaults` inyectable para tests (nunca `.standard` directo en tests — regla del repo).
nonisolated enum StorageModePersistence {
    static let key = "cloudSync.storageMode"

    /// Flag "mirror-off ARMADO" (§g.4 paso 4 — el `relaunchRequested` del executor, MISMA key). SERIO 1
    /// del review adversarial del ciclo C: el montaje mirror-OFF NO puede decidirse por `storageMode`
    /// solo — `.cloud` se persiste en el paso 2 y el marcador CloudKit exporta ASYNC en el paso 3; un
    /// kill involuntario en esa ventana relanzaría con el mirror OFF → el marcador JAMÁS exportaría →
    /// migración enclavada en `markerWritten` para siempre. Este flag lo escribe el executor SOLO al
    /// ejecutar `.disableMirrorAndRelaunch` (que el runner emite ÚNICAMENTE tras `isMarkerExported()`
    /// == true) → un kill pre-armado remonta el mirror ON, el marcador exporta en el resume, y solo el
    /// relaunch posterior apaga el mirror. INVARIANTE: el par (`storageMode=.cloud`, armado=true) se
    /// mueve JUNTO en operación normal post-done; limpiarlos por separado dejaría `.cloud`+mirror ON =
    /// dual-write (la reversa I11 y el escape hatch DEBUG limpian AMBOS).
    static let mirrorOffArmedKey = "cloudSync.migration.relaunchRequested"

    /// Lee el modo persistido; `.icloud` si la key no existe o trae un rawValue desconocido.
    static func read(_ defaults: UserDefaults = .standard) -> StorageMode {
        guard let raw = defaults.string(forKey: key), let mode = StorageMode(rawValue: raw) else {
            return .icloud
        }
        return mode
    }

    /// Persiste el modo (lo escribe SOLO el cutover — `persistLocalMode`, paso 2 del §g.4).
    static func write(_ mode: StorageMode, defaults: UserDefaults = .standard) {
        defaults.set(mode.rawValue, forKey: key)
    }

    /// ¿El mirror-off está ARMADO? (ver doc de `mirrorOffArmedKey`).
    static func isMirrorOffArmed(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: mirrorOffArmedKey)
    }

    /// Flag "wipe de cierre de sesión ARMADO" (H4 — "Cerrar sesión" en `.cloud`). Lo escribe el
    /// coordinador de sign-out DESPUÉS de subir todo el outbox y cerrar la sesión; el BOOT siguiente
    /// (pre-mount, `SwiftDataConfiguration.performSignOutWipeIfArmed`) borra los ARCHIVOS de los
    /// stores personal + sync-meta y devuelve el device a `.icloud` fresh. Se borra ARCHIVOS y no
    /// FILAS porque los deletes de filas quedan en la History y el remount mirror-ON los REPLAYARÍA
    /// hacia iCloud (qa/cloud/README HALLAZGO 3 — la red primaria de propagación de borrados).
    /// El par `.cloud`+mirrorOffArmed NO se toca al armar (invariante SERIO-1): lo resuelve el boot.
    static let signOutWipeArmedKey = "cloudSync.signOutWipeArmed"

    static func armSignOutWipe(_ defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: signOutWipeArmedKey)
    }

    static func isSignOutWipeArmed(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: signOutWipeArmedKey)
    }

    /// Desarmar — SIEMPRE el ÚLTIMO paso del boot-cleanup (un kill a mitad re-entra idempotente).
    static func clearSignOutWipeArm(_ defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: signOutWipeArmedKey)
    }
}

/// Flags del Modo Nube. DARK por defecto.
nonisolated enum CloudSyncFlags {

    /// Cuando `true`, los hubs de creación de las 6 entidades sincronizables asignan un `syncID`
    /// (identidad estable de sync) al nacer la fila (born-cloud). HOY es `false` y NUNCA se activa
    /// en producción: la población masiva de identidades para datos preexistentes la hace la
    /// migración (I10, vía `SyncIdentityService.backfillIdentities`), no este flag. La VENTANA en que
    /// debe estar ON la deriva al boot `MigrationPhaseStore.configure` (journal ≥ `assigningIdentity`);
    /// en el estado estable `.cloud` lo cubre el barrido defensivo del drain (I14: se deja como está — no
    /// se enciende globalmente). Es una `var` (no `let`) solo para que los tests puedan togglearlo con
    /// `defer { restore }`.
    static var identityCaptureEnabled = false

    /// Gate del wiring runtime del motor (I9). ENCENDIDO en I14 (P1). Seguridad demostrable de que
    /// encenderlo NO cambia el comportamiento de los usuarios actuales (todos `.icloud`):
    ///  (a) scheme de PRODUCCIÓN → `CloudBackendConfig.isConfigured == false` → `NoopCloudSessionProvider`
    ///      → `start()` cae en `idleSignedOut` sin tocar nada;
    ///  (b) TODOS los devices en producción son `.icloud` → el guard de `storageMode` de `start()` (P0)
    ///      corta ANTES de cualquier red/mutación;
    ///  (c) staging/DEV: el runtime solo corre en `.cloud` con sesión + un claim que pasa
    ///      `shouldStartSync` + registro de identidad (P6).
    /// `var` (no `let`) solo para que los tests lo togglean con `defer { restore }`.
    static var syncRuntimeEnabled = true

    /// SSOT del modo de almacenamiento EFECTIVO. Getter: override de tests > sesión secundaria
    /// (M1: descriptor activo ⇒ `.cloud` — el store montado es el secundario, sincronizado por el
    /// motor; la key PERSISTIDA `cloudSync.storageMode` conserva SIEMPRE el modo del DUEÑO y
    /// durante una secundaria es `.icloud` por invariante estructural) > `StorageModePersistence.
    /// read()`. Los consumidores que necesitan el modo PERSISTIDO del device (UI de migración del
    /// dueño, elegibilidad de reversa, panel DEBUG) leen `StorageModePersistence.read()` directo.
    /// HOY, sin override/descriptor/key, es SIEMPRE `.icloud` (DARK). El setter guarda un override
    /// EN MEMORIA → los tests que asignan `.cloud` con `defer { restore }` siguen funcionando
    /// sin tocar `UserDefaults` (la persistencia real la escribe `StorageModePersistence.write`).
    static var storageMode: StorageMode {
        get {
            if let override = storageModeTestOverride { return override }
            if SecondarySessionStore.isActive() { return .cloud }
            return StorageModePersistence.read()
        }
        set { storageModeTestOverride = newValue }
    }
    nonisolated(unsafe) private static var storageModeTestOverride: StorageMode?

    /// Solo tests: vuelve el getter a la lectura PERSISTIDA (un `defer { storageMode = prev }` deja un
    /// override pegajoso no-nil — inocuo hoy porque el default coincide, pero rompe el aislamiento si un
    /// test posterior quiere ejercitar la key persistida). Aislamiento explícito > coincidencia.
    static func _testResetStorageModeOverride() {
        storageModeTestOverride = nil
    }

    /// Flag del feature "sesión secundaria" (M1 multi-cuenta). DARK: gatea ÚNICAMENTE la ENTRADA
    /// (la tercera salida de `CrossAccountEntryGuardLogic`) — el mount y el wipe honran el
    /// descriptor (`SecondarySessionStore`) incondicionalmente, para que una sesión YA activa
    /// jamás quede brickeada si el flag se apagara. En builds DEV, la key
    /// `debugSecondarySessionEnabledKey` (panel DEBUG) enciende la entrada sin recompilar (QA
    /// device); producción IGNORA la key (sigue DARK). Setter = override en memoria (tests).
    static var secondarySessionEnabled: Bool {
        get {
            if let override = secondarySessionEnabledTestOverride { return override }
            #if DEV_BUILD
            if UserDefaults.standard.bool(forKey: debugSecondarySessionEnabledKey) { return true }
            #endif
            return false
        }
        set { secondarySessionEnabledTestOverride = newValue }
    }
    static let debugSecondarySessionEnabledKey = "cloudSync.debug.secondarySessionEnabled"
    nonisolated(unsafe) private static var secondarySessionEnabledTestOverride: Bool?

    /// Solo tests: vuelve el getter a la lectura real (mismo racional que `_testResetStorageModeOverride`).
    static func _testResetSecondarySessionEnabledOverride() {
        secondarySessionEnabledTestOverride = nil
    }

    /// Composición completa del gate de ENTRADA secundaria: el feature requiere backend
    /// configurado (sin auth no hay sesión nube) y el wiring del motor encendido.
    static var secondarySessionEntryAvailable: Bool {
        secondarySessionEnabled && syncRuntimeEnabled && CloudBackendConfig.isConfigured
    }

    /// SUB-flag de la purga de SwiftData History tras un ciclo completo del runtime (sigue DOBLE-DARK:
    /// exige además `syncRuntimeEnabled`, hoy `false` → la purga NO corre en producción todavía).
    /// `true` desde el veredicto del spike device S2 (owner, 2026-07-08, iPhone real con datos +
    /// grupo activo): una purga de 6284 transacciones de History inmediatamente después de un import
    /// inicial completo NO invalidó el token del mirror personal de NSPersistentCloudKitContainer
    /// (export incremental limpio post-purga, cero re-import) NI afectó al CKSyncEngine de Grupos
    /// (round-trip de systemFields aceptado post-purga; CKSyncEngine no consume History — es
    /// storage-agnóstico, los records se los damos a mano). Veredicto completo en
    /// MODO-NUBE-SPIKES-I0 §S2 (matiz: verificado single-device + análisis de código). El corte de
    /// `purgeHistoryOnce` sigue siendo conservador (`deleteHistorySafeCut`: nunca por delante de la
    /// fila outbox sin-2xx más vieja). `var` solo para tests (`defer { restore }`).
    static var historyPurgeEnabled = true
}
