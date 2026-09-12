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

    /// Marca "en ESTE dispositivo se creó una cuenta en la nube desde cero" (born-cloud). La escribe el alta
    /// born-cloud y NADIE más — el adopt de un 2.º device también arma el par, así que colgarla de
    /// `writeCloudArmed` la haría mentir.
    ///
    /// **Existe para que la puerta de «Volver a iCloud» pueda FALLAR CERRADO, y ese matiz es todo el punto.**
    /// El guardarraíl `ReverseEligibility` exige un mapa de coordenadas CloudKit porque sin él remontar el
    /// mirror puede RESUCITAR lo que el usuario borró durante la época nube (la zona CloudKit sigue teniendo
    /// esos records). A un born-cloud no le aplica: nunca tuvo zona. Pero «no tengo pruebas de que migrara»
    /// **no es** «nació en la nube», y derivarlo de la AUSENCIA de algo abre el guardarraíl justo cuando la
    /// señal falla. Medido el 2026-09-10 con el `CloudMigrationMarker`, que era el candidato obvio: falta en
    /// un 2.º device adoptado cuyo marcador no llegó por el mirror (su propio belt lo registra y sigue,
    /// `MigrationWorkExecutor.adoptBackendAccount`) y lo borra un botón del panel DEBUG. En los dos casos, un
    /// migrado habría pasado por born-cloud.
    ///
    /// ⇒ Es una afirmación POSITIVA sobre algo que ocurrió aquí. Si no está, se exige el mapa como siempre.
    /// El precio es un falso negativo conservador: un born-cloud que entra en un SEGUNDO dispositivo (por
    /// adopt) no la tiene y no verá el botón — ticket `reverse-hidden-on-a-born-cloud-second-device`.
    static let bornCloudKey = "cloudSync.bornCloud"

    /// La escribe `BornCloudSignUpService.activateBornCloudStorage`, junto al par. Idempotente.
    static func markBornCloud(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: bornCloudKey)
    }

    /// ¿Nació en la nube EN ESTE DISPOSITIVO? Ausente = no se sabe ⇒ `false`, y el gate exige el mapa.
    static func isBornCloud(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: bornCloudKey)
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

    /// **R4 · el NEUTRO DURABLE.** Marca "este device no ha elegido nada y debe montar el store personal
    /// NEUTRO (`cloudKitDatabase: .none` explícito)". Lo escribe el wipe de cierre de sesión —el mismo
    /// código en sus DOS caminos, el boot-hook y el swap in-process— justo después de reponer el par a
    /// `.icloud`.
    ///
    /// **Por qué hace falta una key y no basta con `isFreshInstallForNeutralMount` (R2).** El predicado de
    /// R2 exige que NO exista el archivo del store, y eso es cierto para un device que acaba de ejecutar el
    /// boot-wipe... pero deja de serlo en el instante en que el swap in-process **remonta**: el archivo
    /// vuelve a existir, con el proceso todavía vivo. Sin este estado explícito, matar la app justo
    /// entonces y reabrirla montaría `.iCloudMirror` sobre el store recién vaciado — adjuntando el mirror
    /// al corpus del humano que se acaba de ir y obligando al SIGUIENTE a pagar el relanzamiento que este
    /// chip existe para quitar.
    ///
    /// **Estado EXPLÍCITO, jamás ausencia de key** (§R4(a)): la ausencia de `cloudSync.storageMode`
    /// significa `.icloud` por contrato, así que "neutro" no se puede expresar borrando nada.
    ///
    /// **Caduca sola con `hasShownWelcomeChooser`, y eso es lo que hace IMPOSIBLE el bucle.** El mount
    /// neutro solo se honra mientras el usuario no haya elegido (ver `shouldMountNeutralDurable`). Si
    /// eligiera un destino que SÍ necesita el mirror —onboarding privado, restaurar de iCloud—,
    /// `WelcomeMirrorRelaunchLogic` le pide reabrir, y en ese arranque el flag del chooser ya es `true` ⇒
    /// esta key queda INERTE y la tabla de mounts vuelve a la normal. Sin ese segundo término, el
    /// relanzamiento del restore volvería a montar neutro y el usuario giraría para siempre.
    static let neutralMountArmedKey = "cloudSync.neutralMountArmed"

    static func armNeutralMount(_ defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: neutralMountArmedKey)
    }

    static func isNeutralMountArmed(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: neutralMountArmedKey)
    }

    static func clearNeutralMountArm(_ defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: neutralMountArmedKey)
    }

    /// **El NEUTRO DURABLE de una sesión SOLO-GRUPOS** (paso 5 del rediseño de sesiones, ADR 2026-09-09
    /// §2-3). Marca «este device entró por Grupos y NO ha elegido dónde viven sus datos personales», así
    /// que su store personal monta neutro (`cloudKitDatabase: .none`) en **todos** los arranques.
    ///
    /// **Por qué es una key APARTE de `neutralMountArmedKey` y no un tercer escritor de aquélla.** La de
    /// arriba caduca con `hasShownWelcomeChooser`, y esa caducidad es su anti-bucle: sin ella, un destino
    /// que necesita el mirror pediría reabrir y el arranque siguiente volvería a montar neutro. Aquí la
    /// caducidad **no puede aplicarse**, y no es una preferencia: `onSelectPrivateAccount`
    /// (`ContentView`) marca el chooser en el acto, ANTES de escribir nada. El recorrido MEDIDO que llegaba
    /// al alta con el flag ya en `true` era éste: «Primera vez → privado» sin datos ⇒ flag `true` y
    /// onboarding montado; dentro del onboarding, la card «Solo grupos» cedía a la cadena del organizador
    /// ⇒ `writePreferences`. Con la key de arriba, ese neutro nacía INERTE.
    ///
    /// **Ese recorrido ya no existe (2026-09-10):** la card se retiró del onboarding (ADR 2026-09-09 §7) y
    /// hoy el alta solo se alcanza por «Vengo por un grupo». Este párrafo no se re-evaluó con eso, y la key
    /// se queda como está.
    ///
    /// **Volver al Welcome NO es ese recorrido, y conviene saberlo antes de re-verificar esto**:
    /// `onCancelFromStep1` repone `hasShownWelcomeChooser` a `false`, así que por ahí se llega limpio. Es
    /// la razón de que el bug sea intermitente y no constante — el camino limpio de grupos tampoco marca
    /// el chooser, y eso es deliberado.
    ///
    /// **Y por qué no se deriva de `onboardingMode == .groupInvite`, que parecería el eje del ADR §2.**
    /// Porque ese modo viaja SINCRONIZADO por iKV con merge never-downgrade, así que un device que
    /// **restaura de iCloud** puede heredarlo (`RestoreRouter.decide` → `.groupsOnly`) con el mirror ya
    /// adjunto y su histórico bajado. Derivar de ahí le apagaría el espejo en el arranque siguiente, que
    /// es el daño CONTRARIO al que este ticket arregla. La marca es un hecho de ESTE device: la escriben
    /// las dos ALTAS solo-grupos y nadie más.
    ///
    /// **Quién la levanta** — las dos son necesarias, y la segunda es el anti-bucle que sustituye a la
    /// caducidad:
    ///  1. `FullModeActivationView.completeFullActivation` — el usuario activó Yala completo, que es
    ///     exactamente «ya elegí dónde viven mis datos personales» (decisión de Jürgen, 2026-09-09).
    ///  2. `onNeedsMirrorRelaunch` (`ContentView`) — el punto ÚNICO donde se decide que un destino
    ///     necesita el espejo. Sin esto, un device solo-grupos que pide restaurar giraría para siempre:
    ///     marca puesta ⇒ mount neutro ⇒ «reabre Yala» ⇒ mount neutro otra vez. Es el mismo sitio que ya
    ///     rompe el predicado hermano poniendo `hasShownWelcomeChooser`, y por eso van juntos.
    ///
    /// **No hay migración para el parque instalado, y es una decisión** (Jürgen, 2026-09-10): armarla a
    /// todo el que tenga `.groupInvite` alcanzaría a los restaurados del párrafo anterior. Quien ya está
    /// afectado se cura al reinstalar.
    static let groupsOnlyNeutralMountKey = "cloudSync.groupsOnlyNeutralMount"

    static func armGroupsOnlyNeutralMount(_ defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: groupsOnlyNeutralMountKey)
        // Paso 8 · armar esta marca es EMPEZAR (o volver a) una sesión solo-grupos en este dispositivo, así que
        // ninguna activación de Yala completo a medias sigue en pie. Va aquí, en el escritor, porque la marca de
        // reanudación sobrevive a un cierre de sesión solo-grupos y a vaciar los datos: sin esto, quien vuelve
        // a entrar por «Vengo por un grupo» retomaría una activación de su sesión anterior, con una puerta de
        // iCloud que ya no mide nada de lo que tiene hoy.
        FullModeActivationResumeStore.clear(defaults)
    }

    static func isGroupsOnlyNeutralMountArmed(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: groupsOnlyNeutralMountKey)
    }

    static func clearGroupsOnlyNeutralMount(_ defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: groupsOnlyNeutralMountKey)
    }

    /// **La frontera M1, DENTRO del escritor y no repetida en cada call-site.** Los tres sitios que tocan
    /// esta marca —las dos altas y la activación de Yala completo— tienen que saltarse la escritura en
    /// sesión secundaria, porque ahí el `UserDefaults` es el del DUEÑO y esto es una decisión de MOUNT de
    /// su teléfono: armarla le apagaría el espejo de su iCloud, y desarmarla se lo devolvería, en los dos
    /// casos por una sesión que no es suya.
    ///
    /// **Vive aquí y no en los tres `if` que había antes por una razón de VERIFICABILIDAD, no de estilo.**
    /// Dos de esos tres call-sites son vistas SwiftUI, así que su único test posible era un source-scan de
    /// un literal — y un scan así no distingue `if !SecondarySessionStore.isActive()` de `if
    /// SecondarySessionStore.isActive()`: con el guard invertido, borrado o movido, el literal de la
    /// llamada no cambia y la suite se queda verde mientras el daño sale a producción. Con el guard aquí,
    /// `isSecondary` es un parámetro y la frontera se prueba con una tabla.
    ///
    /// El molde es el de `GroupsOrganizerOnboarding.writePreferences`, que ya recibe `isSecondarySession`
    /// por parámetro por lo mismo.
    static func armGroupsOnlyNeutralMountIfPrimary(
        _ defaults: UserDefaults = .standard,
        isSecondary: Bool = SecondarySessionStore.isActive()
    ) {
        guard !isSecondary else { return }
        armGroupsOnlyNeutralMount(defaults)
    }

    /// El gemelo del anterior, y la simetría es la regla: **quien no arma, no desarma.** Un desarme sin
    /// guard en secundaria le devolvería el espejo al dueño solo-grupos en su próximo arranque — o sea le
    /// causaría el bug de este ticket desde la sesión de otra persona.
    static func clearGroupsOnlyNeutralMountIfPrimary(
        _ defaults: UserDefaults = .standard,
        isSecondary: Bool = SecondarySessionStore.isActive()
    ) {
        guard !isSecondary else { return }
        clearGroupsOnlyNeutralMount(defaults)
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

    /// **Marker «el usuario confirmó borrar su corpus del iCloud privado desde el Welcome» (paso 4 del
    /// rediseño de sesiones).** Lo escribe la puerta `WelcomePrivateICloudGateView` ANTES de la primera
    /// llamada a CloudKit, y lo limpia ella misma cuando el borrado termina — el orden es el de
    /// `performSignOutWipeIfArmed`: **desarmar es el último paso**, para que un kill a mitad reintente.
    ///
    /// **No lo consume el boot-hook, y no es una omisión.** Los otros cuatro arms de este fichero borran
    /// ARCHIVOS y por eso caben en `PersonalContainerHost.makeContainer()`, que corre **pre-mount y
    /// síncrono**. Éste borra una zona de CloudKit: es red, es `async`, y puede tardar. Vive en la puerta
    /// del Welcome, que es donde el usuario está mirando; el arranque solo lo mira para volver a llevarlo
    /// ahí (`presentNextOnboardingScreen`).
    ///
    /// **Se arma JUNTO a `armNeutralMount`, y sin eso el arreglo tendría el mismo bug que arregla.** El
    /// mount neutro dura un solo arranque —`isFreshInstallForNeutralMount` exige que el archivo del store
    /// no exista, y el primer arranque lo crea—, así que un kill durante el borrado dejaría al arranque
    /// siguiente montando `.iCloudMirror` y el espejo importaría justo el corpus que se estaba borrando.
    /// El predicado del neutro durable (`armado && !hasShownWelcomeChooser`) encaja exacto aquí: en la
    /// puerta nadie ha marcado el chooser todavía —lo marcan las SALIDAS, no la puerta— y en cuanto el
    /// usuario cruza el portal la marca queda inerte sola. El anti-bucle es el término que ya tenía.
    static let icloudCorpusWipeArmedKey = "cloudSync.icloudCorpusWipeArmed"

    static func armICloudCorpusWipe(_ defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: icloudCorpusWipeArmedKey)
        armNeutralMount(defaults)
    }

    static func isICloudCorpusWipeArmed(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: icloudCorpusWipeArmedKey)
    }

    /// Desarmar — SIEMPRE el ÚLTIMO paso, y limpia también el neutro durable que `arm` puso. Dejarlo
    /// puesto no cuelga a nadie (`hasShownWelcomeChooser` ya lo inhabilita en cuanto el usuario sale del
    /// Welcome), pero un estado que sobrevive a su motivo es exactamente lo que hace que la próxima
    /// lectura de la tabla de mounts signifique otra cosa.
    static func clearICloudCorpusWipeArm(_ defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: icloudCorpusWipeArmedKey)
        clearNeutralMountArm(defaults)
    }

    /// Paso 8 · el desarme desde la activación de Yala completo, con la frontera M1 DENTRO del escritor (molde
    /// de `clearGroupsOnlyNeutralMountIfPrimary`): el arm vive en el `UserDefaults` del DUEÑO, y una sesión
    /// secundaria que activara Yala completo no puede retirarle un borrado que él pidió.
    static func clearICloudCorpusWipeArmIfPrimary(
        _ defaults: UserDefaults = .standard,
        isSecondary: Bool = SecondarySessionStore.isActive()
    ) {
        guard !isSecondary else { return }
        clearICloudCorpusWipeArm(defaults)
    }

    /// **Marker «este device eligió privado SIN poder preguntarle a iCloud» (estado K de la matriz).**
    ///
    /// Sin él, el bug de este ticket vuelve por la puerta de atrás y así lo encontró Jürgen el
    /// 2026-09-09: eliges privado con iCloud apagado, la app te informa y sigue en local, haces tu
    /// onboarding entero… y el día que activas iCloud en Ajustes el espejo se adjunta y **te baja el
    /// histórico viejo encima de lo que acabas de crear**, sin decirte nada. La validación no ocurrió
    /// nunca, solo se aplazó.
    ///
    /// Lo escribe la puerta cuando la persona continúa desde el aviso de «sin iCloud», y lo consume el
    /// primer arranque en que `isICloudAvailable()` diga que sí. **Se limpia en los tres desenlaces** —hay
    /// datos y la persona decide, o no los hay— porque a partir de ahí no queda nada que vigilar.
    ///
    /// **No caduca por tiempo, y es deliberado**: entre elegir privado sin iCloud y activarlo pueden pasar
    /// meses, y el hecho que describe sigue siendo verdad el día que pase. Un TTL solo lo apagaría justo
    /// en los casos lentos, que son los que tienen más histórico que perder.
    static let privateChoseWithoutICloudKey = "cloudSync.privateChoseWithoutICloud"

    static func markPrivateChoseWithoutICloud(_ defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: privateChoseWithoutICloudKey)
    }

    static func privateChoseWithoutICloud(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: privateChoseWithoutICloudKey)
    }

    static func clearPrivateChoseWithoutICloud(_ defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: privateChoseWithoutICloudKey)
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

    /// CAPACIDAD COMPILADA del feature "sesión secundaria" (M1 multi-cuenta). Gatea ÚNICAMENTE la
    /// ENTRADA (la tercera salida de `CrossAccountEntryGuardLogic`) — el mount y el wipe honran el
    /// descriptor (`SecondarySessionStore`) incondicionalmente, para que una sesión YA activa
    /// jamás quede brickeada si el flag se apagara. En builds DEV, la key
    /// `debugSecondarySessionEnabledKey` (panel DEBUG) sigue mandando: enciende la capacidad sin
    /// recompilar (QA device).
    ///
    /// **Desde el chip M2 el ROLLOUT no vive aquí: vive en `secondarySessionEntryAvailable`**, que
    /// compone esta capacidad con el percent remoto PROPIO (`CloudRemoteFlags.secondarySessionEnabled`).
    /// Por eso el compilado pasa a `true` sin encender nada en producción — el patrón exacto de
    /// `bornCloudChoiceEnabled` y de Grupos (D-R1): `SECONDARY_SESSION_ROLLOUT_PERCENT = "0"` en el
    /// bloque de producción de `gateway/wrangler.toml` y `absentDefault` fail-closed antes del primer
    /// fetch ⇒ la entrada nace DARK en prod y la palanca operativa de release es ese percent (chip M5).
    /// A cambio, un build DEV contra staging —que sirve 100— puede ejercitar la entrada sin recompilar.
    ///
    /// No hay getter público de capacidad separado A PROPÓSITO: a diferencia de Grupos, aquí ningún
    /// teardown consulta el flag (mount y wipe van por el descriptor), así que un
    /// `secondarySessionCompiledCapability` nacería sin un solo call-site — la familia
    /// `AppAttestClient.ensureRegistered()`. Setter = override en memoria (tests).
    static var secondarySessionEnabled: Bool {
        get {
            if let override = secondarySessionEnabledTestOverride { return override }
            #if DEV_BUILD
            if UserDefaults.standard.bool(forKey: debugSecondarySessionEnabledKey) { return true }
            #endif
            return secondarySessionCompiledDefault
        }
        set { secondarySessionEnabledTestOverride = newValue }
    }

    /// Encendido COMPILADO de la capacidad (la palanca de release del binario; el percent remoto es
    /// el rollout Y el kill). Estuvo en `true` desde el chip M2.
    ///
    /// **A `false` desde el 2026-09-12, y es una precondición del cambio de ese día, no una preferencia:**
    /// ese mismo día se retiró la puerta de dominio por sesión —lo que aislaba las preferencias de la
    /// invitada del `UserDefaults` del dueño— porque en producción nunca llegó a actuar. Pero el apagado
    /// de la ENTRADA vivía solo en el percent remoto (`SECONDARY_SESSION_ROLLOUT_PERCENT`), que es un
    /// valor de servidor: **staging sirve 100**, así que un build DEV podía abrir la entrada sin
    /// recompilar, y en producción bastaría subir el percent. Con el aislamiento fuera, eso deja de ser
    /// un rollout y pasa a ser una fuga: la invitada escribiría su nombre y su divisa encima de los del
    /// dueño. Apagarlo aquí es local y no depende de nadie.
    ///
    /// M1 se retira entera en `shell-derives-from-two-session-axes`; esto solo adelanta el cierre de su
    /// puerta de entrada para que las dos mitades no queden nunca desparejadas.
    private static let secondarySessionCompiledDefault = false
    static let debugSecondarySessionEnabledKey = "cloudSync.debug.secondarySessionEnabled"
    nonisolated(unsafe) private static var secondarySessionEnabledTestOverride: Bool?

    /// Solo tests: vuelve el getter a la lectura real (mismo racional que `_testResetStorageModeOverride`).
    static func _testResetSecondarySessionEnabledOverride() {
        secondarySessionEnabledTestOverride = nil
    }

    /// Composición completa del gate de ENTRADA secundaria: capacidad compilada, backend configurado
    /// (sin auth no hay sesión nube), wiring del motor encendido y **DOS flags remotos** — el percent
    /// PROPIO del feature (chip M2) y el kill-switch del Modo Nube. Los dos se conservan a propósito:
    /// son palancas independientes y cualquiera corta la entrada, que es un kill-switch doble y gratis.
    ///
    /// Es una ENTRADA: el kill la corta, pero una secundaria YA ACTIVA no se toca — mount y wipe
    /// honran el descriptor incondicionalmente. Eso es lo que hace barato usar el kill-switch.
    /// Con el percent ausente (fresh install de producción antes del primer fetch) el término remoto
    /// es `absentDefault` = `false` ⇒ `CrossAccountEntryGuardLogic` degrada la celda a
    /// `blockedForeignData`: el usuario ve la pantalla honesta de hoy, jamás un error.
    static var secondarySessionEntryAvailable: Bool {
        secondarySessionEnabled && syncRuntimeEnabled && CloudBackendConfig.isConfigured
            && CloudRemoteFlags.secondarySessionEnabled && CloudRemoteFlags.cloudModeEnabled
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

    /// Encendido COMPILADO de la choice card born-cloud del Welcome (A4 de D-A7). `true` desde el
    /// PROPIO A4 — no lo flipa A7, y esa es una corrección al plan de julio (`WelcomeAccountChoiceLogic`
    /// decía «queda cableado a `false` en el callsite»).
    ///
    /// **Por qué PUDO nacer en `true` sin encender nada:** `visibleNewOptions` exige además los DOS
    /// flags remotos (`cloudModeEnabled && cloudOnboardingChoiceEnabled`), así que mientras el segundo
    /// valió "0" la card nacía DARK en prod sin trabajo extra. La palanca operativa de release es ese
    /// percent (A7), exactamente el patrón de Grupos (`groupsBackendCompiledDefault = true` + percent,
    /// D-R1). A cambio, A5 puede ejercitar el alta entera contra staging/DEV sin recompilar.
    ///
    /// **YA NO nace DARK: producción sirve ese percent EN 100** — medido con `curl` al `/config` el
    /// 2026-09-09; `gateway/wrangler.toml` arrastró un "0" desfasado hasta el 2026-09-10. Con snapshot
    /// fetcheado, la card born-cloud se ofrece en prod; sin snapshot todavía, `absentDefault`
    /// fail-closed la sigue ocultando hasta el primer fetch.
    ///
    /// No lleva override de tests a propósito: la lógica que decide recibe el booleano por PARÁMETRO
    /// (`WelcomeAccountChoiceLogic.visibleNewOptions`), así que los tests no necesitan tocar el flag.
    static let bornCloudChoiceEnabled = true

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
