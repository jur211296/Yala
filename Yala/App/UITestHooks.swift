//
//  UITestHooks.swift
//  Yala
//
//  Hooks de UI testing controlados por launch arguments (`-uitest*`).
//  En release `isActive` es siempre false y todo es no-op — no afecta producción.
//  El seeding y la activación Pro (APIs `#if DEBUG`) se aplican desde
//  AppBootstrapper dentro de bloques `#if DEBUG`; aquí solo viven los flags
//  (lectura de ProcessInfo) y la señal observable de readiness para los XCUITests.
//

import Foundation
import Observation

@MainActor
@Observable
final class UITestHooks {
    static let shared = UITestHooks()
    private init() {}

    // MARK: - Flags (false en release)

    /// True solo cuando la app se lanza con `-uitest` (y solo en builds DEBUG).
    nonisolated static var isActive: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-uitest")
        #else
        return false
        #endif
    }

    /// `-uitest-reset`: wipe de datos locales al arranque (estado limpio / vacío).
    nonisolated static var shouldReset: Bool { hasArg("-uitest-reset") }

    /// `-uitest-pro`: fuerza Pro (devForceProTier) al arranque.
    nonisolated static var forcePro: Bool { hasArg("-uitest-pro") }

    /// `-uitest-skip-onboarding`: marca onboarding/chooser completados.
    nonisolated static var skipOnboarding: Bool { hasArg("-uitest-skip-onboarding") }

    /// `-uitest-onboarding`: presenta el OnboardingView directo (salta Welcome Hero/Chooser),
    /// SIN marcar onboarding completado. Para testear el flujo de onboarding aislado.
    nonisolated static var startAtOnboarding: Bool { hasArg("-uitest-onboarding") }

    /// `-uitest-group-invite`: arranca en modo solo-grupos (el eje 1 apagado — no hay sesión privada
    /// en este dispositivo), con onboarding saltado y el tab Grupos seleccionado. Para testear el
    /// Perfil reducido.
    nonisolated static var forceGroupInvite: Bool { hasArg("-uitest-group-invite") }

    /// `-uitest-cloud-chooser`: destapa las cards de sign-in cloud (Apple/Google) del
    /// 2º nivel del Welcome bajo uitest — opt-in EXPLÍCITO del XCUITest del chooser
    /// (sesión 2 Google). Sin él, uitest conserva el bypass a restore (byte-idéntico).
    /// Solo NAVEGACIÓN determinista: el test jamás tapea el botón de sign-in real.
    /// La card de la nube de «Es mi primera vez» pide además `-uitest-fake-attest-support`: ver abajo.
    nonisolated static var forceCloudChooser: Bool { hasArg("-uitest-cloud-chooser") }

    /// `-uitest-fake-attest-support`: finge que este teléfono puede conseguir token de App Attest, **solo en la entrada
    /// de las puertas que ofrecen la nube**: `WelcomeNewOptionsGate` (la card de «Es mi primera vez» y las salidas al alta
    /// de la pantalla de entrar) y, desde el 2026-09-16, la card de migración de Ajustes
    /// (`StorageSettingsView.offersCloudMigrationEntry`). El simulador no tiene App Attest, así que sin
    /// este arg no sale ninguna de las dos: ni la del Welcome aunque se pida `-uitest-cloud-chooser`, ni la de Ajustes.
    /// No toca `AppAttestClient`: el cliente sigue sin poder conseguir token.
    ///
    /// Los dos args son ortogonales a propósito. `-uitest-cloud-chooser` sin este es el caso que prueba la CONDICIÓN: la
    /// card desaparece porque el host no tiene App Attest, y un mutante que quite el término lo pone en rojo. Un seam que
    /// fingiera las dos cosas a la vez dejaría ciegos a todos sus tests (`.claude/rules/testing.md`). Solo DEBUG.
    nonisolated static var fakeAttestSupport: Bool { hasArg("-uitest-fake-attest-support") }

    /// Valor de `-uitest-fake-beacon <apple|google|…>`: finge que el faro de iCloud-KV dice que este Apple ID
    /// YA tiene una cuenta en la nube creada con ese método (el `#if DEBUG` vive en las lecturas de
    /// `CloudBeacon`). Existe para el XCUITest de «Crear otra cuenta» (ticket
    /// `beacon-routes-only-never-blocks`): sin él, el encaminamiento por faro solo se veía en un teléfono
    /// con una cuenta real detrás.
    ///
    /// **Finge la ENTRADA, no la decisión**: `WelcomeAccountChoiceLogic.routeNewBranch` sigue decidiendo
    /// entero con el faro fingido y la disponibilidad REAL de la entrada nube, que bajo `-uitest` exige
    /// además `-uitest-cloud-chooser`. Y **no persiste**: no escribe en el iCloud-KV del simulador. Un valor
    /// que no sea un método conocido se pasa tal cual, que es justo el caso del faro con método
    /// desconocido. Solo DEBUG.
    nonisolated static var fakeBeaconProvider: String? {
        #if DEBUG
        guard isActive else { return nil }
        return parseValue(after: "-uitest-fake-beacon", from: ProcessInfo.processInfo.arguments)
        #else
        return nil
        #endif
    }

    /// `-uitest-fake-icloud`: fuerza `iCloudSyncService.isAccountAvailable = true` en el
    /// simulador (que NO tiene cuenta iCloud). Desbloquea los flujos cuyo único obstáculo
    /// es el guard de disponibilidad de cuenta —prompts de restore de iCloud, por ejemplo—
    /// que de otro modo bloquean ANTES de poder ejercitarlos en sim.
    /// NO habilita CloudKit real: crear grupo/CKShare/sync bidireccional siguen sin
    /// funcionar en sim (el store uitest es local, `cloudKitDatabase: .none`). El
    /// AppBootstrapper también marca el primer import como asentado para que los gates
    /// de boot no esperen un import de CloudKit que en sim nunca llega. Solo DEBUG.
    nonisolated static var fakeICloudAvailable: Bool { hasArg("-uitest-fake-icloud") }

    /// `-uitest-fake-backend-session`: fuerza el input `hasSession` de «Eliminar mi cuenta» (desde el paso 9 vive en «Tu cuenta de Yala»)
    /// (ProfileView) a `true`, para QA/XCUITest del diálogo de D5 (aviso de deudas + «Ver mis grupos»)
    /// SIN un sign-in backend real —SIWA/Google no corren en sim—. NO crea una sesión Supabase real
    /// (`CloudAuthService.hasSession` global NO se toca): solo hace visible la fila + el diálogo; tocar
    /// «Continuar → Eliminar» no completa (no hay backend). Combinar con `-uitest-seed grupos` para que
    /// el usuario tenga saldos pendientes → aparece el aviso. Solo DEBUG (inerte en release vía `hasArg`).
    ///
    /// NO CONFUNDIR con `-uitest-fake-cloud-session` (abajo), su vecino tipográfico: aquel fuerza el
    /// predicado GLOBAL de sesión y este solo el input de DOS filas de Perfil. Fusionarlos rompería
    /// `YalaAccountUITests` y `DeleteAccountDialogUITests`, que dependen de que con este arg el path de
    /// cierre siga siendo el privado (`.privateSignOut`) y no el del «equipo» con grupos.
    nonisolated static var fakeBackendSession: Bool { hasArg("-uitest-fake-backend-session") }

    /// `-uitest-fake-cloud-session`: fuerza el predicado GLOBAL `CloudAuthService.hasSession` a `true`
    /// (el `#if DEBUG` vive en `CloudAuthService.swift`). Existe porque con `groupsBackendEnabled` ON
    /// —lo que ocurre en TODO XCUITest bajo `Yala Dev`, donde el default-ausente de remote-config es ON—
    /// Grupos exige sesión POR DISEÑO: sin ella el tab pinta el empty state de re-entrada
    /// (`GroupsEmptyStateLogic.decide` → `.signInToView`) y «Nuevo grupo» rutea al sign-in
    /// (`GroupCreateRoutingLogic.route` → `.needsSignIn`), así que los XCUI escritos para el canal
    /// CloudKit no llegan ni al empty state estándar ni al formulario.
    ///
    /// NO crea una sesión Supabase real, y eso es deliberado: `currentUserID`, `sessionExpiry`,
    /// `canRenewSession` y `accessToken()` quedan intactos (`nil`/`false`). Es justo lo que mantiene el
    /// tráfico HTTP en CERO —cada cliente del canal tiene un SEGUNDO guard sobre el JWT y lanza antes de
    /// tocar `URLSession`— y lo que deja byte-idéntica la resolución de identidad por `sub`. Fabricar un
    /// JWT mandaría credenciales basura a un backend real. Solo DEBUG (inerte en release vía `hasArg`).
    nonisolated static var fakeCloudSession: Bool { hasArg("-uitest-fake-cloud-session") }

    /// `-uitest-icloud-identity`: siembra la identidad iCloud de Grupos con un recordName fijo
    /// (`uitestICloudRecordName`), síncrono y SIN red — `GroupICloudIdentitySeed.adopt` no toca
    /// CloudKit.
    ///
    /// Existe porque sin él NINGÚN XCUITest puede ejercitar la resolución de identidad, que es la
    /// que decide si la app te reconoce como miembro. Las dos fuentes están apagadas bajo test a
    /// propósito: `CloudAuthService.currentUserID` es nil incluso con `-uitest-fake-cloud-session`
    /// (para que el tráfico HTTP siga en cero) y el fetch real de `seedIfNeededBestEffort` falla en
    /// un simulador sin cuenta iCloud. ⇒ el resolvedor caía siempre al primer criterio, el flag, y
    /// como los seeds lo siembran a mano la suite entera era ciega al estado que SÍ ocurre en
    /// producción: «mi member llegó por el pull y el flag no está puesto».
    ///
    /// Es ORTOGONAL a `-uitest-fake-cloud-session`: aquel finge el predicado de sesión, este siembra
    /// una identidad. No fuerza ningún predicado de la lógica bajo prueba — el resolvedor sigue
    /// decidiendo entero, que es lo que hace que el test pueda ponerse rojo.
    nonisolated static var seedICloudIdentity: Bool { hasArg("-uitest-icloud-identity") }

    /// El recordName que siembra `-uitest-icloud-identity`. Mismo literal que usan los perfiles de
    /// `DevSeedGroups` para el member propio, que es lo que hace que casen.
    nonisolated static let uitestICloudRecordName = "uitest-current-user"

    /// `-uitest-groups-consent`: da por aceptado el consent de Grupos (§C5) sembrando sus dos keys de
    /// `UserDefaults` desde `AppBootstrapper`, SIN pasar por `GroupsConsentState.register()` —ese camino
    /// escribe por `PreferenceSyncService` (iKV en `.icloud`, outbox en `.cloud`) y un XCUITest no debe
    /// encolar preferencias—. Es ORTOGONAL a `-uitest-fake-cloud-session` porque el gate de crear grupo
    /// tiene dos escalones: sin sesión rutea a sign-in, y CON sesión pero sin consent rutea al consent
    /// (`GroupCreateRoutingLogic.route`). Separados, mañana se puede cubrir ese segundo escalón sin tocar
    /// el seam. Solo DEBUG (inerte en release vía `hasArg`).
    nonisolated static var groupsConsentAccepted: Bool { hasArg("-uitest-groups-consent") }

    /// `-uitest-groups-educativo`: **invierte el early-return que desmonta el educativo bajo `-uitest`**
    /// (`GroupsContainerView.evaluateGroupsOnboarding`). Ese early-return existe porque el sheet
    /// interceptaría los taps de toda la suite de Grupos, y por eso NO se retira: lo que este seam hace es
    /// permitir que las corridas que ejercitan el educativo lo monten a propósito.
    ///
    /// **Sin él, C2 dejaría su primer escalón sin ninguna red determinista.** El educativo pasa a ser el
    /// paso 1 de las puertas de Grupos y era, medido, inalcanzable desde XCUITest — `qa/coverage-index.json`
    /// ya anotaba el hueco. La alternativa era cubrirlo solo con unit + device-qa, y el spec lo dice: el
    /// primer escalón de la cadena nacería sin red.
    ///
    /// Es ORTOGONAL a `-uitest-fake-cloud-session` y a `-uitest-groups-consent`, por la misma razón que
    /// ellos entre sí: cada uno abre un escalón distinto de la cadena y combinarlos en uno impediría
    /// ejercitar los intermedios. Solo DEBUG (inerte en release vía `hasArg`).
    nonisolated static var groupsEducativo: Bool { hasArg("-uitest-groups-educativo") }

    /// `-uitest-groups-gate-mirror-live`: le dice a la puerta de «Vengo por un grupo» que el store personal
    /// de este proceso **espeja a iCloud**, para poder recorrer su vuelta al neutro en simulador.
    ///
    /// **Existe porque el testigo del mount MIENTE en los hosts de test, y eso está medido:**
    /// `SwiftDataConfiguration.personalConfiguration` sale por su rama `YalaModel-UITest` —con
    /// `cloudKitDatabase: .none`— **antes** de llamar a `capturePersonalStoreMountedDecisionOnce`, así que
    /// `personalStoreMountedDecision` se queda en el default de su declaración, que es `.iCloudMirror`. La
    /// consecuencia muerde aquí en el sentido contrario al que parece.
    ///
    /// Por eso el default de este seam es **`false`, que es la VERDAD del host de test** (ese store no
    /// espeja), y no una inversión: sin él, la puerta leería `true` en toda corrida y ningún XCUITest
    /// podría volver a ver su rama buena.
    ///
    /// **Quien lo encienda tiene que saber lo que compra:** con él la puerta ejecuta el cierre de sesión
    /// privado de verdad, y ése ARMA el boot-wipe (`StorageModePersistence.armSignOutWipe`) sin guard de
    /// uitest — el guard está en el EJECUTOR. La key es `cloudSync.*`, que ni `-uitest-reset` limpia ni
    /// `DataWipeService` toca, así que una corrida que llegue hasta el arm deja el simulador con el borrado
    /// puesto para el siguiente arranque MANUAL, donde el ejecutor sí corre. Un test que use este seam
    /// tiene que limpiar el arm al terminar.
    nonisolated static var groupsGateMirrorLive: Bool { hasArg("-uitest-groups-gate-mirror-live") }

    /// `-uitest-groups-batch-demo`: QA/XCUITest del batch "salir de todos mis grupos" (D10) SIN backend ni
    /// iCloud (imposibles en sim — la ejecución real de leave/transfer es device/TestFlight). Fuerza que la
    /// hoja de Vaciar OFREZCA «También salir de mis grupos» (input `canLeaveAllGroups` de `UserDataResetView`)
    /// y hace que la vista del batch (`GroupBatchLeaveView`) muestre un RESULTADO determinista fabricado
    /// (2 salidos + 1 transferido + 1 «necesita tu decisión») en vez de ejecutar el orquestador real. Solo
    /// verifica el CABLEADO/UI; la lógica del orquestador va por unit tests (kill-sim). Inerte en release
    /// vía `hasArg`; el seed demo del store está bajo `#if DEBUG`.
    nonisolated static var groupsBatchDemo: Bool { hasArg("-uitest-groups-batch-demo") }

    /// `-uitest-groups-batch-running`: variante EN CURSO del seam anterior, para el botón «Detener» (D3).
    /// Siembra el intent con entries `.pending` SIN ejecutar el orquestador real (imposible en sim), de modo
    /// que la vista muestre el progreso con «Detener». El tap SÍ recorre la mecánica real
    /// (`requestStop` → `stopPending` → marcador + resultado honesto): esto no fabrica el resultado, solo el
    /// punto de partida. Inerte en release vía `hasArg`; el seed está bajo `#if DEBUG`.
    nonisolated static var groupsBatchRunning: Bool { hasArg("-uitest-groups-batch-running") }

    /// `-uitest-inbox-alert`: tras el seed, encola `.showInboxAlert` con un payload de
    /// muestra para presentar el InboxAlertModal sin depender del sync de CloudKit.
    nonisolated static var showInboxAlert: Bool { hasArg("-uitest-inbox-alert") }

    /// `-uitest-remote-wipe-notice`: tras el seed, encola `.presentRemoteWipeNotice` — el aviso de «tus
    /// datos fueron eliminados de iCloud».
    ///
    /// **Cubre la mitad de la PRESENTACIÓN, no la del productor.** Quien pide el aviso en producción es
    /// la gracia de cinco segundos de `ContentView`, que arranca cuando las filas personales
    /// desaparecen del store bajo el proceso vivo — y para eso no hay seam (ticket
    /// `remote-wipe-receiver-has-no-behaviour-test`). Encolando el intent a mano se ejercita lo que este
    /// hook sí puede probar y ningún escáner alcanza: que el aviso entra por la cola del router, que la
    /// red de presentación efectiva NO lo desarma cuando de verdad está en pantalla, y a dónde aterrizan
    /// sus dos botones.
    ///
    /// El eje de sesión que el drenaje re-mide no hace falta armarlo: con el onboarding dado por hecho
    /// (`-uitest-skip-onboarding`), el backfill del arranque ya escribe la marca privada por el camino de
    /// producción. Y el store arranca vacío con `-uitest-reset`, que es la otra condición viva.
    nonisolated static var showRemoteWipeNotice: Bool { hasArg("-uitest-remote-wipe-notice") }

    /// `-uitest-apple-id-changed`: tras el seed, encola `.appleIDChangedClosePrivate` — la hoja «Cambiaste
    /// de cuenta de iCloud».
    ///
    /// **Cubre la hoja y el cierre, no la detección.** La detección sale a CloudKit
    /// (`AppBootstrapper.checkForAppleIDChange`) y está apagada bajo test a propósito: el simulador no
    /// tiene cuentas de iCloud reales. Desde el intent en adelante —la cola, la hoja, sus fases y el cierre
    /// del coordinador— todo es el camino de producción.
    ///
    /// **Ningún test debe CONFIRMAR con este hook solo.** Un cierre que termina bien arma un boot-wipe
    /// REAL (`armSignOutWipe` no tiene guard de test) y su key sobrevive a `-uitest-reset`: el arranque
    /// manual siguiente del simulador borraría el store. Para recorrer la fase de bloqueo, acompáñalo de
    /// `-uitest-groups-outbox-pending`.
    nonisolated static var showAppleIDChangedNotice: Bool { hasArg("-uitest-apple-id-changed") }

    /// `-uitest-groups-outbox-pending`: tras el seed, deja UNA fila viva en el outbox de Grupos, sin sesión.
    ///
    /// **Es el estado real que bloquea un cierre privado, no un seam que fuerce el veredicto.** La celda C
    /// no sube grupos, así que con cambios de grupos sin subir el coordinador se bloquea con
    /// `.sessionExpired` (`CloudSessionSignOut.blockIfGroupsCannotUpload`) ANTES de tocar nada. Así se
    /// recorre la fase de bloqueo de la hoja del cambio de Apple ID sin fingir el coordinador: un seam que
    /// forzara `.blocked` dejaría ciego al test (`.claude/rules/testing.md`).
    ///
    /// Sin sesión no hay canal que la suba, y `-uitest-reset` la purga (`DevSeedGroups.reset`): el store
    /// `YalaSyncMeta-UITest` es persistente y, sin esa purga, bloquearía los cierres de la corrida siguiente.
    nonisolated static var seedPendingGroupsOutboxRow: Bool { hasArg("-uitest-groups-outbox-pending") }

    /// `-uitest-groups-attest-terminal`: deja este teléfono con el veredicto de App Attest TERMINAL — tres
    /// rechazos repartidos en más de 24 h, sin un solo acierto.
    ///
    /// **Es el estado real, escrito por el camino de producción, no un seam que fuerce el predicado.** La siembra
    /// llama a `GroupsAttestStreakStore.recordRejection(now:)` tres veces con relojes separados, igual que harían
    /// tres 401 `yala_attest_required`, y deja que `GroupsAttestVerdictLogic` decida. Un seam que devolviera
    /// `isTerminal = true` dejaría ciegos a los tests que entran por él (`.claude/rules/testing.md`): pasarían en
    /// verde con la tabla del veredicto rota.
    ///
    /// **La racha NO la borra `-uitest-reset`**, y es a propósito en producción: describe al teléfono, así que
    /// `DataWipeService.removeUserPreferenceKeys` no la lleva y cerrar sesión no la arregla. Por eso la siembra
    /// tiene su propia purga en el `else` de `AppBootstrapper.applyUITestSeed`: sin ella, una corrida que la
    /// sembrara dejaría el aviso puesto para todas las siguientes del mismo simulador.
    ///
    /// Para VER el aviso del tab Grupos hace falta además sesión en la nube (`-uitest-fake-cloud-session`): sin
    /// ella el veredicto es cierto y la frase sería mentira (`GroupsAttestTabNoticeLogic`). Los dos args son
    /// ortogonales a propósito — el caso «racha sí, sesión no» es justo el que prueba esa mitad.
    nonisolated static var groupsAttestTerminal: Bool { hasArg("-uitest-groups-attest-terminal") }

    /// `-uitest-trial-offer`: tras el seed, encola `.presentTrialOffer` para presentar
    /// el ProTrialOfferSheet sin depender de StoreKit ni del post-onboarding real —
    /// las emisiones AUTOMÁTICAS de monetización están suprimidas en uitest, este
    /// hook explícito es el único camino (escenario paywall + alert en cola).
    nonisolated static var showTrialOffer: Bool { hasArg("-uitest-trial-offer") }

    /// `-uitest-force-update`: fuerza el estado "hay update disponible" en AppUpdateService
    /// (sin red) para testear el UpdateAvailableBanner del Panel.
    nonisolated static var forceUpdateBanner: Bool { hasArg("-uitest-force-update") }

    /// `-uitest-force-required`: fuerza la pantalla BLOQUEANTE de forzado (min-version) sin red ni
    /// snapshot, para QA/XCUITest del cover terminal. Inerte en release (hasArg + seam DEBUG).
    nonisolated static var forceUpdateRequired: Bool { hasArg("-uitest-force-required") }

    /// `-uitest-ai-consent`: marca el consentimiento de datos IA aceptado, para poder
    /// abrir entradas IA Pro (voz/imagen) sin el alert de consentimiento. No graba ni
    /// transcribe — solo destraba la navegación a la vista.
    nonisolated static var aiConsent: Bool { hasArg("-uitest-ai-consent") }

    /// `-uitest-invite-onboarding`: presenta el cover de GroupInviteOnboarding directo
    /// (sin CKShare real — no funciona en sim). Combinar con `-uitest-join-phase` para
    /// congelar la fase del GroupJoinIntentTracker y testear cada step determinista.
    nonisolated static var startAtInviteOnboarding: Bool { hasArg("-uitest-invite-onboarding") }

    /// Valor de `-uitest-join-phase <waitingForZone|creatingMember|pendingApproval|active|failed>`:
    /// congela la fase del tracker para los XCUI del onboarding de invitación.
    nonisolated static var joinPhaseOverride: String? {
        #if DEBUG
        guard isActive else { return nil }
        return parseValue(after: "-uitest-join-phase", from: ProcessInfo.processInfo.arguments)
        #else
        return nil
        #endif
    }

    /// Valor de `-uitest-join-soft-timeout <segundos>`: acorta el soft-timeout del
    /// onboarding de invitación (default 20s) para no dormir en los XCUI.
    var joinSoftTimeoutOverride: TimeInterval? {
        #if DEBUG
        guard Self.isActive,
              let raw = Self.parseValue(after: "-uitest-join-soft-timeout", from: ProcessInfo.processInfo.arguments)
        else { return nil }
        return TimeInterval(raw)
        #else
        return nil
        #endif
    }

    /// `-uitest-seed-desync`: siembra un set MÍNIMO y determinista de transacciones
    /// "desincronizadas" (categoría income con monto NEGATIVO y categoría expense con
    /// monto POSITIVO) para el XCUI de clasificación income/expense por CATEGORÍA
    /// (fix `8347a776`/`13f2cbb0`). Excluyente con `-uitest-seed <perfil>`: el test lo
    /// lanza SIN perfil para no contaminar los totales. Ver `DevSeedTransactions.createDesyncFixtures`.
    nonisolated static var seedDesync: Bool { hasArg("-uitest-seed-desync") }

    /// `-uitest-scheduled-due-today`: añade al seed UN pago planificado «una sola vez» que vence
    /// HOY (`DevSeedScheduledPayments.dueTodayName`). Los 8 del fixture base se reparten por el
    /// mes y `min(day, 28)` capa los días 29-31, así que NINGUNO vence hoy de forma garantizada.
    ///
    /// Por qué existe: el escenario de vencimiento se alcanzaba solo eligiendo «Una sola vez» en
    /// el segmentado de Recurrencia, y los `Picker` segmentados NO se enumeran en el árbol de
    /// accesibilidad de `snapshot_ui` ⇒ el QA por referencia de elemento no podía llegar. Este
    /// seam produce el mismo estado sin la interacción imposible.
    ///
    /// Es ADITIVO y apagado por defecto a propósito: el pago que vence hoy encabeza la lista, y
    /// `ScheduledPaymentSkipUITests` opera sobre el `firstMatch` de las filas.
    nonisolated static var scheduledDueToday: Bool { hasArg("-uitest-scheduled-due-today") }

    /// `-uitest-fail-wipe`: hace que los borrados LANCEN antes de tocar nada, dejando los datos
    /// intactos. Es la superficie que faltaba para ver en pantalla las ramas de FALLO que en producción
    /// son mudas.
    ///
    /// **Cubre TRES caminos, y desde el 2026-09-11 por un solo sitio.** `wipeAllUserData` lo consulta
    /// aparte; los otros dos lo heredan de `DataWipeService.deleteLocalGroupsRows`, el escritor común
    /// del dominio Grupos: «Empiezo de cero» (`wipeLocalGroupsDomain` → canario `freshStartWipeFailed`
    /// + alert) y **el desasociar del paso 10** (`CloudSessionSignOut.purgeGroupsDomainForDetach` →
    /// canario `groupsDetachPurgeFailed` + su propio aviso). Ese tercero estuvo fuera hasta entonces:
    /// el seam se repetía en cada llamador en vez de vivir en el escritor, así que el camino que no se
    /// acordó de copiarlo se quedó sin forma de verse en pantalla.
    ///
    /// NO simula un wipe a medias: lanza ANTES del primer borrado, así que el estado observable
    /// tras el fallo es «todo sigue ahí», que es exactamente el caso que el alert debe cubrir.
    /// Un wipe parcial es otro escenario y este seam no lo representa.
    ///
    /// **Gateado por `isReady` a propósito, y esto es lo que lo hace utilizable:** `-uitest-reset`
    /// limpia el estado llamando al MISMO `wipeAllUserData` desde `applyUITestHooksEarly`, en
    /// `YalaApp.init()`. Sin el gate, combinar los dos seams hacía fallar el reset del ARRANQUE —
    /// y su `catch` solo imprime, así que el test habría corrido sobre un estado sucio en
    /// silencio. `markReady()` corre al final del bootstrap (`applyUITestSeed`), después del
    /// reset y antes de que nadie pueda tocar «Empiezo de cero» ⇒ separa los dos casos exactos.
    @MainActor
    static var shouldFailWipeNow: Bool {
        hasArg("-uitest-fail-wipe") && shared.isReady
    }

    /// Valor de `-uitest-seed <perfil>` (ej. "realista", "pesado", "dead-pointer"). Nil si ausente.
    /// `dead-pointer` siembra UNA TX personal cuyo puntero de grupo no resuelve — AC (c) de
    /// `qa_groups-tx-fantasma-al-borrar-gasto-de-grupo`. Ver `DevSeedTransactions.createDeadPointerFixture`.
    nonisolated static var seedProfile: String? {
        #if DEBUG
        guard isActive else { return nil }
        return parseSeedProfile(from: ProcessInfo.processInfo.arguments)
        #else
        return nil
        #endif
    }

    /// Pure-logic: extrae el valor que sigue a `-uitest-seed`. Nil si ausente, si es el
    /// último token, o si el siguiente token es otro flag (`-...`). Separado para test.
    nonisolated static func parseSeedProfile(from args: [String]) -> String? {
        parseValue(after: "-uitest-seed", from: args)
    }

    /// Valor de `-uitest-seed-foreign-account <ISO>`: siembra una cuenta en esa divisa con gasto e
    /// ingreso, para el estado de partida que necesita toda la familia FX — **una divisa AUSENTE de
    /// la fila de tasas del día**. Ver `DevSeedForeignCurrencyAccount`.
    ///
    /// Existe porque a ese estado no se llegaba por ninguna de las dos vías: el selector de Moneda
    /// del formulario de cuenta es un `NavigationLink` y no responde a los taps sintéticos de la
    /// automatización (medido el 2026-09-08, cuatro técnicas; el otro `NavigationLink` del mismo
    /// formulario tampoco abre, así que va con el patrón y no es un bug de la app), y el seed crea
    /// PEN + USD sembrando tasas de PEN/EUR/USD — multi-divisa, pero nunca una divisa fuera de la
    /// fila, que es el único estado en el que este módulo falla.
    ///
    /// Es **ADITIVO** al perfil y ortogonal a él: se aplica después de `-uitest-seed <perfil>` y
    /// también funciona a solas (siembra las categorías que le falten). Aditivo y apagado por
    /// defecto a propósito — la cuenta añade filas con tasa aproximada, y encenderlas siempre le
    /// pondría «≈» a los totales de toda la suite, que es justo el control negativo que hoy
    /// sostiene los tickets de FX.
    nonisolated static var foreignAccountCurrency: String? {
        #if DEBUG
        guard isActive else { return nil }
        return parseValue(after: "-uitest-seed-foreign-account", from: ProcessInfo.processInfo.arguments)
        #else
        return nil
        #endif
    }

    /// Valor de `-uitest-seed-chat-sealed-rate <ISO>`: siembra UNA fila **envenenada por el chat
    /// viejo** —monto convertido correcto, `exchangeRate` sellado a 1,0— que es el corpus que el
    /// barrido `fxOneToOneRepairSweep.v2` cura en el sitio. Ver `DevSeedChatSealedRate`.
    ///
    /// Es el caso CONTRARIO al de `foreignAccountCurrency`, y por eso son dos args y no uno: aquél
    /// siembra filas sanas-pero-aproximadas (tasa buena, flag encendido) y éste una fila con la
    /// tasa falsa y el flag apagado, que es lo que la deja fuera del reparador de arranque.
    ///
    /// **El veredicto necesita dos arranques**: el que siembra deja la fila envenenada (el barrido
    /// ya había corrido sobre un store vacío) y el siguiente, sin `-uitest-reset`, la cura. El seed
    /// es idempotente para que ese segundo arranque no plante una fila nueva al lado de la curada.
    nonisolated static var chatSealedRateCurrency: String? {
        #if DEBUG
        guard isActive else { return nil }
        return parseValue(after: "-uitest-seed-chat-sealed-rate", from: ProcessInfo.processInfo.arguments)
        #else
        return nil
        #endif
    }

    /// Valor de `-uitest-seed-group-bridge-fx <ISO>`: siembra un gasto de grupo bridgeado cuyas dos
    /// patas tienen **coberturas de tasa distintas** —la real exacta, la de préstamo provisional—,
    /// que es el escenario de `bridge-de-grupos-pierde-la-marca-de-sus-patas`.
    /// Ver `DevSeedGroupBridgeFXLegs`.
    ///
    /// No se llega a él con los otros seeds: `GroupTransactionBridge` crea las dos patas con la
    /// misma divisa y la misma fecha, así que **nacen con el mismo flag**; la asimetría solo
    /// aparece después (aprobar un draft tarde, el reparador por cola, o editar la pata real).
    nonisolated static var groupBridgeFXCurrency: String? {
        #if DEBUG
        guard isActive else { return nil }
        return parseValue(after: "-uitest-seed-group-bridge-fx", from: ProcessInfo.processInfo.arguments)
        #else
        return nil
        #endif
    }

    /// `-uitest-deeplink <target>`: simula un deeplink externo a un tab al arranque
    /// (panel/statistics/records/planning/budgets/groups/inbox/scheduledPayments/categories).
    /// Ejercita el wiring de routing a tabs ocultos (bug review-deeplinks).
    nonisolated static var deeplinkTarget: String? {
        #if DEBUG
        guard isActive else { return nil }
        return parseValue(after: "-uitest-deeplink", from: ProcessInfo.processInfo.arguments)
        #else
        return nil
        #endif
    }

    /// `-uitest-deeplink-url <url>`: a diferencia de `-uitest-deeplink <target>` (que
    /// mapea un target BARE a un tab POST-seed vía `uitestDeeplinkDestination`), esta URL
    /// COMPLETA entra PRE-init por `AppBootstrapper.handleIncomingURL(_:)` → el intent se
    /// DIFIERE al DeferredIntentBuffer y se re-emite en el drain (bootstrap paso 20),
    /// ejercitando el defer→drain REAL de un deep link en cold launch (fix `ba8513e5`).
    /// Soporta el token `seeded-first` en el path (`yala://groups/seeded-first`), que el
    /// hook sustituye por el id del primer grupo sembrado (persistido en `seededGroupIDKey`).
    nonisolated static var deeplinkURL: String? {
        #if DEBUG
        guard isActive else { return nil }
        return parseValue(after: "-uitest-deeplink-url", from: ProcessInfo.processInfo.arguments)
        #else
        return nil
        #endif
    }

    /// Key en `UserDefaults.standard` donde `DevSeedGroups.create` publica el
    /// `SplitGroup.id.uuidString` del primer grupo sembrado, para que el hook de
    /// `-uitest-deeplink-url` resuelva el token `seeded-first` a un id real en una
    /// corrida posterior (patrón de 2 launches del XCUI de deep link en cold launch).
    nonisolated static let seededGroupIDKey = "uitest.seededGroupID"

    /// Pure-logic: extrae el valor que sigue a `flag`. Nil si ausente, si es el último
    /// token, o si el siguiente token es otro flag (`-...`). Separado para test.
    nonisolated static func parseValue(after flag: String, from args: [String]) -> String? {
        guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
        let value = args[i + 1]
        return value.hasPrefix("-") ? nil : value
    }

    nonisolated private static func hasArg(_ flag: String) -> Bool {
        #if DEBUG
        return isActive && ProcessInfo.processInfo.arguments.contains(flag)
        #else
        return false
        #endif
    }

    // MARK: - Readiness (observado por ContentView)

    /// Flip a true cuando bootstrap + seed terminan. Los XCUITests esperan a que
    /// el root exponga `uitest_ready` antes de interactuar (evita sleeps frágiles).
    private(set) var isReady = false

    func markReady() { isReady = true }

    /// accessibilityIdentifier del root: "" en release / sin uitest, "uitest_loading"
    /// mientras arranca, "uitest_ready" cuando todo está listo.
    var rootIdentifier: String {
        guard Self.isActive else { return "" }
        return isReady ? "uitest_ready" : "uitest_loading"
    }
}
