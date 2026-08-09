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

    /// Escritor ÚNICO del par completo (`.cloud` + mirror-off ARMADO) para los caminos que YA cruzaron el
    /// gate del marcador —el ADOPT (`runAdoptFlow`), donde el marcador lo exportó el LÍDER— **y para el
    /// ALTA BORN-CLOUD** (A3 de D-A7, `BornCloudSignUpService.activateBornCloudStorage`). C-1 colapsa aquí
    /// las dos escrituras sueltas para que no puedan divergir por descuido.
    ///
    /// **Por qué el born-cloud puede escribir el par SIN gate de marcador, que es la pregunta obvia:** el
    /// gate existe para que un corpus que vive en CloudKit no se quede sin el `CloudMigrationMarker` que
    /// avisa a los 2º devices (SERIO-1). En un alta born-cloud **no hay corpus en CloudKit**: la cuenta
    /// acaba de nacer, el usuario no tiene datos que exportar y no existe nadie de quien divergir ⇒ no hay
    /// marcador que esperar. Es el mismo razonamiento que `ICloudChannelVerdict.noChannelNoFootprint`
    /// (`ICloudCutoverGateLogic.swift`): sin canal y sin huella, el gate del marcador no protege nada.
    /// Lo que el born-cloud SÍ hereda del adopt es el relanzamiento: escribir el par no remonta el store
    /// (`personalConfiguration` se evalúa una sola vez), y hasta que el proceso muera el mirror sigue vivo
    /// — por eso `MigrationRuntimeGate.isPersonalMountMismatch` deja el motor quieto en esa ventana.
    ///
    /// **`UserDefaults` NO tiene transacción**, así que esto NO da atomicidad: un kill entre las dos keys
    /// sigue siendo posible. E **invertir el orden tampoco arregla nada**: la mitad `armado + .icloud` hace
    /// que `CloudMigrationUIStateDeriver.derive` pinte `needsRelaunch(.toCloud)` — mira `mirrorOffArmed` sin
    /// mirar el modo — y tras el relanzamiento el modo seguiría `.icloud`, así que la tarjeta "cierra y vuelve
    /// a abrir" saldría en bucle sin salida. Por eso el orden se queda como siempre (modo → armado) y el
    /// invariante se enforcea en el CONSUMIDOR: `MigrationRuntimeGate.canRun` apaga el motor mientras el par
    /// esté incompleto en una fase estable.
    static func writeCloudArmed(defaults: UserDefaults = .standard) {
        write(.cloud, defaults: defaults)
        defaults.set(true, forKey: mirrorOffArmedKey)
    }

    /// INVARIANTE C-1, como aserción comprobable sin leer el journal: `.cloud` persistido con el mirror-off
    /// SIN armar significa "el mirror de CloudKit sigue VIVO en modo nube".
    ///
    /// Ese estado es **legítimo y transitorio** durante la ventana de export del cutover (pasos 2→4) y durante
    /// toda la reversa post-mount; es el estado **PROHIBIDO** en cualquier fase estable (`done`/`notStarted`),
    /// donde significaría motor + mirror escribiendo a la vez. En `.icloud` es SIEMPRE `false` por
    /// construcción ⇒ el gate que lo consume es inerte para el 99 % de usuarios de 2.x.
    static func isCloudWithMirrorOn(_ defaults: UserDefaults = .standard) -> Bool {
        read(defaults) == .cloud && !isMirrorOffArmed(defaults)
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

    /// Marker "el wipe de sign-out en `.cloud` DEBE incluir el store de GRUPOS" (G5-B, camino `.cloud`
    /// ampliado). Lo escribe el coordinador ANTES de `armSignOutWipe` (CR-4: el arm es el disparador y
    /// va ÚLTIMO — kill entre marker y arm = no-op re-armable; kill entre arm y marker habría dejado un
    /// wipe personal SIN grupos).
    ///
    /// **D-R1 paso 2 (2026-07-30): se escribe con la capacidad COMPILADA, no con el getter compuesto.**
    /// Antes decía "SOLO con `groupsBackendEnabled == true` ⇒ con el flag OFF el marker jamás existe y
    /// `performSignOutWipeIfArmed` es byte-idéntico", y esa frase describía la fase DARK, en la que el
    /// compilado cortaba por construcción. Con el compilado en `true` el término que quedaría vivo es el
    /// REMOTO, y un kill remoto no borra lo que ya subió al servidor ni exime de olvidar la copia local:
    /// condicionar el marker a él dejaba el store de grupos del usuario saliente en un device que este
    /// mismo hook devuelve a "recién instalado". Ver `groupsBackendCompiledCapability`.
    /// Lo lee y limpia el boot hook `performSignOutWipeIfArmed` JUNTO al arm (orden kill-safe existente).
    static let signOutWipeIncludesGroupsKey = "cloudSync.signOutWipeIncludesGroups"

    static func markSignOutWipeIncludesGroups(_ defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: signOutWipeIncludesGroupsKey)
    }

    static func signOutWipeIncludesGroups(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: signOutWipeIncludesGroupsKey)
    }

    static func clearSignOutWipeIncludesGroups(_ defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: signOutWipeIncludesGroupsKey)
    }

    /// Marker "wipe de sesión SOLO-GRUPOS ARMADO" (G5-B, camino `groupsOnlySignOut`). Lo escribe el
    /// coordinador como ÚLTIMO write del cierre solo-grupos (kill-safe); el BOOT siguiente (pre-mount,
    /// `SwiftDataConfiguration.performGroupsOnlySignOutWipeIfArmed`) borra SOLO los archivos del store de
    /// GRUPOS — NO toca `YalaModel`/`YalaSyncMeta`, NO resetea onboarding/prefs personales, NO escribe
    /// `storageMode` (el device sigue en `.icloud`). Se limpia AL FINAL del boot-cleanup (idempotente).
    static let groupsOnlyWipeArmedKey = "cloudSync.groupsOnlyWipeArmed"

    static func armGroupsOnlyWipe(_ defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: groupsOnlyWipeArmedKey)
    }

    static func isGroupsOnlyWipeArmed(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: groupsOnlyWipeArmedKey)
    }

    static func clearGroupsOnlyWipeArm(_ defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: groupsOnlyWipeArmedKey)
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
    ///  (a) sin sesión de nube → `currentUserID == nil` → `start()` cae en `idleSignedOut` sin tocar nada.
    ///      (Antes de D-R1 paso 1 este punto era más fuerte: producción ni siquiera componía el provider
    ///      vivo, porque `CloudBackendConfig.isConfigured` era `false`. Ya no — hoy lo compone.);
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
    /// configurado (sin auth no hay sesión nube), el wiring del motor encendido y el flag
    /// REMOTO vivo (DIFERIDOS #34 — es una ENTRADA: el kill-switch la corta; una secundaria
    /// YA ACTIVA no se toca — mount/wipe honran el descriptor incondicionalmente).
    static var secondarySessionEntryAvailable: Bool {
        secondarySessionEnabled && syncRuntimeEnabled && CloudBackendConfig.isConfigured
            && CloudRemoteFlags.cloudModeEnabled
    }

    /// Gate del canal de sync de GRUPOS → backend (incremento G2). Cuando `true`,
    /// `GroupsSyncClient.startIfEligible()` arranca el drain/push/pull del store de Grupos contra el
    /// gateway (`/groups/*`). El sync de Grupos anterior lo hacía CKSyncEngine (`SplitSyncManager`);
    /// este canal es la clase nueva (backend propio) que lo reemplaza.
    ///
    /// DIFERIDOS #34 (decisión owner 2026-07-17): getter COMPUESTO `compilado && remoto` — el flag
    /// remote-config (`CloudRemoteFlags.groupsBackendEnabled`) solo puede MATAR, nunca encender solo
    /// (kill-switch sin release para el encendido de Grupos).
    ///
    /// **QUÉ LEE CADA CLASE DE CALL-SITE, resuelto en D-R1 paso 2 (2026-07-30).** La nota que este
    /// docblock difería a la sesión de encendido («revisar entonces si los paths de teardown deben leer
    /// el compilado directo») queda cerrada así:
    ///  - **ENTRADAS** (arranque del loop, crear grupo, unirse, invitar, aprobar/expulsar/salir, la
    ///    superficie de invitación, el batch D10): este getter COMPUESTO. Es lo que el kill-switch
    ///    existe para cortar.
    ///  - **TEARDOWNS** (sign-out en sus cuatro caminos y el cierre local tras un borrado de cuenta):
    ///    `groupsBackendCompiledCapability`. Un kill remoto apaga el CANAL; no borra lo que ya subió al
    ///    servidor ni retira la copia local. Un teardown que se saltara la limpieza porque el flag está
    ///    muerto dejaría datos del usuario en el device tras cerrar sesión, y filas suyas en Supabase
    ///    tras un borrado GDPR. Además, el término remoto ni siquiera es un testigo de ese corpus: es
    ///    fail-closed ante snapshot ausente o corrupto y depende del bucket de rollout, así que un
    ///    device con todo su corpus en el backend puede leerlo `false` por razones ajenas a él.
    ///
    /// Setter = override en memoria (source-compatible con el idiom de tests `= true; defer { = false }`).
    static var groupsBackendEnabled: Bool {
        get {
            if let override = groupsBackendEnabledTestOverride { return override }
            return groupsBackendCompiledDefault && CloudRemoteFlags.groupsBackendEnabled
        }
        set { groupsBackendEnabledTestOverride = newValue }
    }

    /// Encendido COMPILADO del canal de Grupos (la palanca de release; el remoto es el kill).
    /// `true` desde D-R1 paso 2 (2026-07-30). Encenderlo aquí NO enciende el canal por sí solo: el
    /// getter compuesto sigue exigiendo el remoto, y `GROUPS_BACKEND_ROLLOUT_PERCENT` lo sube el owner
    /// en el gateway DESPUÉS de tener este build instalado en los dos devices de la sesión de QA.
    private static let groupsBackendCompiledDefault = true

    /// C-10: capacidad COMPILADA del canal de Grupos, SIN el kill remoto. La consumen la presentación del
    /// congelado (`GroupBackendCapability.current`) y —desde D-R1 paso 2— **todos los paths de TEARDOWN**
    /// (`CloudSessionSignOut` en sus cuatro caminos, `AccountDeletionService` y el gate de
    /// `GroupBackendMembershipService.forgetUser`). El tercer consumidor original, el beacon de capacidad
    /// (`GroupCapabilityBeacon`), se fue con el uploader en `5010db6a`.
    ///
    /// Deliberadamente NO compuesta con `CloudRemoteFlags.groupsBackendEnabled`: un kill remoto apaga el
    /// CANAL, no la capacidad del BINARIO. Confundirlos tendría dos consecuencias malas: (a) un kill
    /// transitorio le diría al usuario "actualiza la app" teniendo la app perfecta, y (b) —la que abrió
    /// D-R1 paso 2— un cierre de sesión o un borrado de cuenta se saltaría la limpieza de lo que el canal
    /// YA subió, que sigue existiendo con el canal apagado.
    ///
    /// Override de tests: reusa `groupsBackendEnabledTestOverride` a propósito — un test que enciende el
    /// canal enciende también la capacidad (no existe un build capaz-pero-sin-canal que valga la pena
    /// simular; para el kill remoto se togglea `CloudRemoteFlags.groupsBackendEnabled`).
    static var groupsBackendCompiledCapability: Bool {
        if let override = groupsBackendEnabledTestOverride { return override }
        return groupsBackendCompiledDefault
    }

    nonisolated(unsafe) private static var groupsBackendEnabledTestOverride: Bool?

    /// Solo tests: vuelve el getter a la composición real (mismo racional que
    /// `_testResetStorageModeOverride` — aislamiento explícito > coincidencia).
    static func _testResetGroupsBackendEnabledOverride() {
        groupsBackendEnabledTestOverride = nil
    }

    /// Gate de la RESOLUCIÓN del derecho Pro por CUENTA (C-8, 2026-07-27). DARK: hoy `false` en
    /// producción, así que `isProUser` sale EXACTAMENTE de donde salía antes del fix
    /// (`Transaction.currentEntitlements` = el Apple ID del device) y monetización no cambia.
    ///
    /// Lo que NO gatea, a propósito: la EMISIÓN del `appAccountToken` en la compra y el `bind` del
    /// entitlement. Esos corren siempre que haya sesión de nube — son los que van poblando el vínculo
    /// cuenta ↔ suscripción para que el día del encendido el derecho ya esté donde tiene que estar.
    /// Encenderlo antes de desplegar el gateway es inocuo (el `GET` falla → snapshot ausente → se
    /// resuelve en local), pero se enciende DESPUÉS del deploy por higiene.
    ///
    /// En builds DEV la key `debugAccountEntitlementEnabledKey` (panel DEBUG) lo activa sin
    /// recompilar, para QA en device; producción IGNORA la key. Setter = override en memoria (tests).
    static var accountEntitlementEnabled: Bool {
        get {
            if let override = accountEntitlementEnabledTestOverride { return override }
            #if DEV_BUILD
            if UserDefaults.standard.bool(forKey: debugAccountEntitlementEnabledKey) { return true }
            #endif
            return accountEntitlementCompiledDefault
        }
        set { accountEntitlementEnabledTestOverride = newValue }
    }

    /// Encendido COMPILADO de la resolución por cuenta (la palanca de release del owner).
    private static let accountEntitlementCompiledDefault = false
    static let debugAccountEntitlementEnabledKey = "cloudSync.debug.accountEntitlementEnabled"
    nonisolated(unsafe) private static var accountEntitlementEnabledTestOverride: Bool?

    /// Solo tests: vuelve el getter a la lectura real (mismo racional que los otros `_testReset*`).
    static func _testResetAccountEntitlementEnabledOverride() {
        accountEntitlementEnabledTestOverride = nil
    }

    /// SUB-flag de la purga de SwiftData History tras un ciclo completo del runtime. Exige además
    /// `syncRuntimeEnabled` — hoy `true` (encendido I14/P1), así que con ambos en `true` la purga SÍ
    /// corre en producción para quien esté en `.cloud` (donde corre el runtime; en `.icloud` el gate
    /// de dominio la deja inalcanzable).
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
