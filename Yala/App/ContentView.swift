//
//  ContentView.swift
//  Yala
//
//  Created by Yala Refactoring.
//

import CloudKit
import StoreKit
import SwiftData
import SwiftUI

// MARK: - ContentView (Punto de entrada principal)

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @AppStorage("hasShownWelcomeChooser") private var hasShownWelcomeChooser: Bool = false
    @AppStorage(AppPreferences.Keys.hasShownYalaAIOnboarding) private var hasShownYalaAIOnboarding: Bool = false
    @State private var showOnboarding: Bool = false
    @State private var showLanguageSelection: Bool = false
    @State private var showWelcomeRestore: Bool = false
    // H4: re-entrada a cuenta del Modo Nube desde el Welcome (SIWA → exists → adopt).
    // A5: el MISMO cover sirve el alta born-cloud — lo distingue `welcomeCloudEntry`.
    @State private var showWelcomeCloudSignIn: Bool = false
    /// Qué va a hacer el cover de nube: re-entrar a una cuenta que ya existe (con el provider que
    /// eligió la card, o el que dictó el faro) o dar de ALTA una cuenta nueva (A5, el provider se
    /// elige dentro). Cada productor lo setea EXPLÍCITO antes de presentar — jamás se hereda el del
    /// intento anterior.
    @State private var welcomeCloudEntry: WelcomeCloudSignInView.Entry = .reentry(.apple)
    // H4 + fix carrera 2026-07-14: DUEÑO ÚNICO del cover de relaunch del sign-out
    // `.cloud`/secundario. ProfileView ya NO presenta (ante la fase cierra su sheet) —
    // dos anchors ante el mismo observable tumbaban ambas cadenas. La presentación se
    // VERIFICA por onAppear del contenido real y se reintenta (SignOutRelaunchNetModifier).
    @State private var showSignOutRelaunchCover: Bool = false
    /// Forzado de actualización (min-version): red visual del cover terminal. La CONDICIÓN VIVA es
    /// `ForceUpdateGate.shared.isUpdateRequired` (blocker de la matriz); este @State es la red de
    /// presentación (molde showSignOutRelaunchCover). DARK en prod.
    @State private var showForceUpdateCover: Bool = false
    @State private var showInviteRecovery: Bool = false
    /// Prefilled summary from iCloud restore (rama B). Pasado a OnboardingView
    /// como `prefilledData`. Reseteado tras data wipe para evitar values stale.
    @State private var prefilledOnboardingData: ICloudAccountSummary?
    @State private var showSplash: Bool = true
    @State private var splashOpacity: Double = 1
    /// Hero + Chooser unificados en un solo cover. El step interno (hero/chooser)
    /// lo maneja `WelcomeFlowContainer` — el ContentView solo decide cuándo
    /// presentar el flow y con qué `initialStep`.
    @State private var showWelcomeFlow: Bool = false
    @State private var welcomeFlowInitialStep: WelcomeFlowStep = .hero
    /// Positive confirmation toast for reactive events (remote onboarding / restore).
    /// Replaces the noisy "Syncing…" banner. Nil when hidden.
    @State private var positiveToast: String?
    @State private var toastDismissTask: Task<Void, Never>?
    @State private var wipeGraceTask: Task<Void, Never>?
    @State private var remoteWipeTask: Task<Void, Never>?
    /// **Red VISUAL del aviso de vaciado remoto, no su condición.** El blocker de la matriz es
    /// `remoteWipeNoticePending` (abajo); este flag es sólo el `isPresented` del `.alert`, y la red de
    /// presentación lo apaga y lo vuelve a encender cuando UIKit no llegó a montarlo. Molde exacto de
    /// `showSignOutRelaunchCover`, y por el mismo motivo: si la matriz colgara de este flag, el toggle
    /// del reintento la abriría durante 50 ms y el router montaría otra cosa justo debajo del aviso.
    @State private var showRemoteWipeAlert: Bool = false
    /// **La CONDICIÓN VIVA del aviso de vaciado remoto: hay un aviso pedido y sin contestar.** Es lo que
    /// entra a `ShellReadinessState` y lo que la red de presentación vigila. Lo enciende el drenaje de
    /// `.presentRemoteWipeNotice`; lo apagan las dos ramas del alert —las dos, que un `.alert` no tiene
    /// `onDismiss`— y el desarme de la red cuando la presentación no llega a montar.
    @State private var remoteWipeNoticePending: Bool = false
    /// La red de presentación efectiva del aviso (`RelaunchNetLogic`). Viva sólo mientras dura la
    /// verificación: termina en cuanto UIKit confirma la presentación, el aviso se contesta o el cap
    /// del ciclo se agota.
    @State private var remoteWipeNoticeNetTask: Task<Void, Never>?
    @State private var showICloudRestartAlert: Bool = false
    /// **El Apple ID del teléfono cambió y la sesión privada era del anterior** (ADR §1). Lo enciende
    /// el drain de `.appleIDChangedClosePrivate`; su alert vive en `ShellDataAlertsModifier`.
    @State private var showAppleIDChangedAlert: Bool = false
    @State private var showFreshStartWipeAlert: Bool = false
    /// El wipe de «empiezo de cero» LANZÓ (cualquiera de los dos caminos que borran). Blocker de la
    /// matriz de readiness como sus hermanos: mientras esté puesto, nada del router presenta debajo.
    @State private var showFreshStartWipeFailedAlert: Bool = false
    /// **Paso 4 · el espejo que se adjunta TARDE.** Corpus previo encontrado en el iCloud de este Apple
    /// ID después de que la persona eligiera privado sin poder validarlo. `nil` = nada que avisar.
    ///
    /// **Una sola presentación y no dos alerts encadenados** (review adversarial, 2026-09-10): dos
    /// `.alert` del mismo anchor se pisan, y un `.alert` no tiene `onDismiss` con el que encadenarlos como
    /// hace `UserDataResetView`. La confirmación, el progreso y el fallo son FASES de
    /// `LateICloudMirrorNoticeView`.
    @State private var lateICloudCorpus: ICloudPersonalCorpus?
    @State private var showSyncSettingsSheet: Bool = false
    @State private var showProTrialOffer: Bool = false
    @State private var showWhatsNew: Bool = false
    @State private var whatsNewData: (features: [WhatsNewFeature], version: String)?
    @AppStorage("lastSeenAppVersion") private var lastSeenAppVersion: String = ""
    @State private var isInitialCheckDone: Bool = false
    @State private var showGroupInviteOnboarding: Bool = false
    /// Marca del invite (nombre/icono/color del grupo) para personalizar el welcome de
    /// `GroupInviteOnboardingView`. La FUENTE es `PendingJoinStore` — ver el drain de
    /// `.presentGroupBackendInviteOnboarding`.
    @State private var pendingInviteMetadata: InviteLinkService.BrandedMetadata?
    /// Zona (== `group_id`) del invite que está presentando el cover. La vista la necesita para dos cosas
    /// que no puede hacer sin ella: sellar la confirmación de ESE grupo y no de los otros invites vivos, y
    /// poder decir «más tarde» sobre una invitación concreta.
    @State private var pendingInviteZone: String?
    /// G4-invites (A2): sheets del flujo backend sign-in → consent → join, drenados de
    /// `.presentGroupsConsent` / `.presentGroupsSignIn`. DARK: con `groupsBackendEnabled`
    /// OFF los intents jamás se submitean.
    @State private var showGroupsConsent: Bool = false
    @State private var showGroupsSignIn: Bool = false
    /// **Bloque [I]** · el bloqueo «esa cuenta ya tiene Yala completo». Vive aquí y no en el modifier
    /// porque tiene que entrar en la matriz de readiness, y esa la construye ESTE tipo.
    @State private var showGroupsAccountIsCompleteBlock: Bool = false
    /// **Bloque [I]** · el cover del adopt se abrió con la sesión ya firmada en la puerta de Grupos, así
    /// que arranca en el consentimiento y no en el intro (le ahorra un sign-in que acaba de hacer). Se
    /// repone al cerrarse el cover: la siguiente entrada por el chooser es un recorrido normal.
    @State private var adoptStartsAtConsent: Bool = false
    /// Keying `zoneName` (== group_id backend) del join pendiente que abrió el sheet. `nil` cuando los
    /// mismos dos sheets los abre la rama ORGANIZADOR (G3), que no se une a ninguna zona.
    @State private var pendingGroupsJoinZone: String?
    /// G3 · la rama organizador del Welcome está en curso. Es el discriminador de la continuación del
    /// anchor único de `GroupsBackendInviteModifier`: sin él, ese modifier solo sabe seguir el camino del
    /// INVITADO, que se apoya en `pendingGroupsJoinZone`. Se enciende al salir por el portal con
    /// `.groupsOrganizer` y se apaga cuando el alta termina o cuando el usuario cancela un sheet.
    @State private var groupsOrganizerFlowActive: Bool = false
    /// G3 · la ÚNICA presentación nueva de la rama (paso 6). Blocker propio de la matriz de readiness.
    @State private var showGroupsOrganizerName: Bool = false
    /// G3 · one-shot de resultado del cover del nombre, molde de los dos de `GroupsBackendInviteModifier`:
    /// se arma en el callback de éxito y se consume en `onDismiss`. **No se mira `hasCompletedOnboarding`
    /// en su lugar** aunque el alta lo escriba: ese `@AppStorage` se refresca por notificación y depender
    /// de su timing dentro del `onDismiss` es una carrera; el flag es la señal directa.
    @State private var organizerSetupCompleted: Bool = false
    /// C2 · el educativo como PRIMER escalón de la rama del organizador (la puerta A; la B, la card «Solo
    /// grupos», se retiró el 2026-09-10). Blocker propio de la matriz de readiness, igual que su hermana de
    /// arriba y por la misma regla.
    @State private var showGroupsEducational: Bool = false
    @State private var showFullModeActivation: Bool = false
    /// Paso 8 · «Primera vez → nube» descubrió una cuenta solo-grupos: cuando su sesión quede montada en este
    /// dispositivo (`hasCompletedOnboarding` pasa a `true` en modo solo-grupos) se le ofrece «Activar Yala
    /// completo» (ADR §7). En memoria a propósito: es una OFERTA, no una decisión sobre datos — si la app muere
    /// antes, la persona la tiene igual en Perfil y en los empujones de Grupos, y un estado durable que
    /// sobreviviera a su motivo podría ofrecerla en un momento que nadie pidió.
    @State private var offersFullActivationAfterGroupsEntry = false
    /// Inbox alert payload, driven by .contentView drain of .showInboxAlert.
    @State private var activeInboxNotification: PendingInboxNotification = .init()
    /// Invite error detail, carried by .showInviteError intent.
    @State private var activeInviteError: InviteAlertContent?
    /// Group bridge/sync error message, carried by .showGroupSyncError intent (P0-1).
    @State private var activeGroupSyncError: String?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.yalaTheme) private var theme
    /// C2 · el educativo de las puertas A/B marca `hasShownGroupsOnboarding` AQUÍ, por el espejo observable
    /// y no por `UserDefaults` directo: el tab lee esa property para decidir su empty state y su sheet, y
    /// escribir por debajo dejaría el valor en memoria stale hasta la siguiente recarga por notificación.
    @Environment(AppPreferences.self) private var appPreferences

    /// Lightweight state for existing data detection (replaces @Query to prevent
    /// synchronous SwiftData fetches during iOS snapshot capture — 0x8BADF00D fix).
    @State private var hasExistingData: Bool = false

    /// Señal **solo del store personal** para el detector de wipe remoto (`onChange` abajo).
    /// NO es `hasExistingData`: ese se ensanchó con grupos y bridgeadas para el handover de
    /// dispositivo, y ensancharlo creó un true→false que antes no existía — un usuario de Solo
    /// Grupos (sin cuentas ni categorías propias) pasaba a dar `true`, así que al salir de su
    /// ÚLTIMO grupo veía el alert de «tus datos se borraron en otro dispositivo» y, al confirmar,
    /// `hasCompletedOnboarding = false` lo devolvía al onboarding. El wipe remoto que este detector
    /// existe para ver es el del ESPEJO de CloudKit del store personal; los grupos viven en otro
    /// store, los sincroniza CKSyncEngine, y salir de un grupo es una acción local legítima.
    @State private var hasPersonalData: Bool = false

    /// Increments cuando el idioma cambia (local o sync iCloud). Usado como `.id()`
    /// del root para forzar re-render de strings y formatters localizados.
    @State private var languageVersion: Int = 0
    @Environment(\.modelContext) private var modelContext

    /// Minimum splash duration (2.5 seconds to enjoy the animation)
    private let minimumSplashDuration: Double = 2.5

    var body: some View {
        shellObservers(shellPresentations(rootContent))
    }

    /// El árbol base: shell, toast, banner de sync y splash.
    ///
    /// **`body` está partido en tres y eso NO es estético.** Medido con `-warn-long-function-bodies`:
    /// con la cadena entera inline el getter tardaba **591 s** en type-checkear y la compilación moría
    /// con «unable to type-check this expression in reasonable time». El coste es superlineal en la
    /// LONGITUD de la cadena —eran 33 eslabones—, así que lo que lo baja no es simplificar un closure
    /// sino cortarla en tramos que se resuelven por separado. Si al añadir una presentación vuelve a
    /// reventar, el arreglo es partir otra vez, no revertir el cambio.
    @ViewBuilder
    private var rootContent: some View {
        ZStack {
            // Main content deferred until initial state check completes (~2s after launch).
            // Creating MainTabView during the first commit triggers PanelView data loading
            // synchronously on the main thread. Before the first frame renders, the system
            // considers the app "Background" (WatchdogVisibility), with a 5-second timeout.
            // The heavy SwiftData fetches + calculations exceed that, causing 0x8BADF00D.
            // By waiting for isInitialCheckDone, the first frame (just the splash) renders
            // instantly, promoting the app to Foreground (20s timeout).
            if hasCompletedOnboarding && isInitialCheckDone {
                MainTabView(storeLooksEmpty: !hasExistingData)
                    .environment(SessionState.shared)
                    .modifier(TagCatalogProvider())
                    .id(languageVersion) // re-render on .languageDidChange
                    .accessibilityIdentifier(UITestHooks.shared.rootIdentifier)
            } else {
                theme.background
                    .ignoresSafeArea()
            }

            // Positive toast overlay — only for reactive events (remote onboarding,
            // remote restore). The noisy "Syncing…" banner was removed; failure states
            // are surfaced by SyncStatusBanner below when MainTabView is mounted.
            if let toast = positiveToast {
                Text(toast)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.sm)
                    .glassEffect()
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, DS.Spacing.xxl)
            }

            // Sync status banner overlay — failure/stalled states from iCloudSyncService.
            // Gated to match MainTabView timing: only shows once onboarding/splash/initial
            // check are resolved, avoiding competition with splash, iCloudSyncWaitingView,
            // and onboarding flows.
            if hasCompletedOnboarding && isInitialCheckDone && !showSplash {
                syncStatusBannerOverlay
            }

            // Splash screen overlay — waits for both minimum duration AND initial state check
            if showSplash {
                SplashScreenView()
                    .opacity(splashOpacity)
                    .ignoresSafeArea()
                    .task {
                        try? await Task.sleep(for: .seconds(minimumSplashDuration))
                        // Wait until initial check determines what to show (avoids blank flash)
                        while !isInitialCheckDone {
                            try? await Task.sleep(for: .milliseconds(50))
                        }
                        dismissSplash()
                    }
            }
        }
        .task {
            await checkInitialSyncState()
            // Forzado de actualización (min-version): recomputa desde el snapshot de remote-config
            // + build local. DARK en prod (sin snapshot → false). El fetch de /config lo dispara
            // AppBootstrapper; aquí solo se lee el último snapshot conocido.
            ForceUpdateGate.shared.recompute()
        }
        .onReceive(NotificationCenter.default.publisher(for: .languageDidChange)) { _ in
            languageVersion &+= 1
        }
        .onChange(of: SessionState.shared.dataVersion) { _, _ in
            // Replaces @Query-based observation. dataVersion increments on CRUD, CloudKit sync,
            // and sheet dismissals — covers all cases where data may have arrived or changed.
            // A4 v3.1: el `wipeGraceTask` (onChange abajo) detecta data desaparecida — pero mira
            // `hasPersonalData`, no este flag. El gate isWaitingForSync se eliminó con el rediseño.
            hasExistingData = checkHasExistingData()
            hasPersonalData = checkHasPersonalData()
        }
        .onChange(of: hasCompletedOnboarding) { _, newValue in
            // Paso 8 · la oferta de «Activar Yala completo» a quien vino a estrenar Yala por la nube y resultó
            // tener una cuenta de grupos. Se consume en la primera transición, sea cual sea, y solo se ofrece
            // si lo que quedó montado es de verdad solo-grupos: desde otro modo la activación no tiene chooser.
            // El eje se lee de la marca persistida y no del espejo en memoria: el alta del organizador
            // la escribe ahí antes de que esta transición ocurra.
            if newValue, offersFullActivationAfterGroupsEntry {
                offersFullActivationAfterGroupsEntry = false
                if !PrivateSessionMark.hasPrivateSession() {
                    RouterEntryGate.shared.submit(.presentFullModeActivation)
                }
            }
            // Data wipe path: invalida summary stale + respeta el flag del chooser.
            // `performLocalWipeForRemoteSync` resetea `hasShownWelcomeChooser=false` cuando
            // el wipe requiere re-onboarding completo, así que el chooser vuelve a presentarse.
            if !newValue {
                prefilledOnboardingData = nil
                // **Con el Welcome MONTADO, él manda, y sin este guard el borrado se sabotea a sí mismo.**
                // `DataWipeService.wipeAllUserData` borra `hasCompletedOnboarding`, así que todo camino
                // que borre desde dentro del cover dispara esta transición — y `presentNextOnboardingScreen`
                // **CONSUME el destino del relanzamiento** (`WelcomePendingDestinationStore.consume()`) y
                // enciende `showOnboarding`. Dos daños medidos en el camino de la puerta privada: una
                // segunda presentación ante el mismo anchor que ya está mostrando el terminal «reabre Yala»
                // (regla (4) de Presentaciones, la que puede tumbar ambas cadenas), y el relanzamiento
                // DESARMADO —`RelaunchNetLogic.shouldExitOnBackground` se alimenta de que ese destino siga
                // puesto—, con lo que el onboarding privado correría entero sobre un store sin espejo.
                //
                // Quien está dentro del Welcome ya tiene quien lo encamine: su propio portal. Este
                // `onChange` existe para el wipe REMOTO, que llega con el cover bajado.
                guard !showWelcomeFlow else { return }
                presentNextOnboardingScreen()
            }
        }
        .onChange(of: hasPersonalData) { oldValue, newValue in
            // **`!showFullModeActivation` es un término nuevo (2026-09-14) y cierra un defecto ALTA que
            // introdujo «Restaurar → Empezar desde cero» dentro de la activación.** Ese borrado es
            // DELIBERADO y baja `hasPersonalData` desde su propio envoltorio; cancelar la gracia allí antes
            // del `await` no sirve, porque la tarea la crea ESTE `onChange` en el update siguiente, cuando
            // el `cancel()` ya pasó.
            //
            // Y el término `hasCompletedOnboarding` no lo tapa, que es lo que lo hacía peligroso: los otros
            // borrados deliberados lo bajan de paso (`resetAllUserPreferences` se lleva la key) y por eso el
            // guard cerraba solo. El scope `.importedRows` lo CONSERVA a propósito —es lo que impide mandar
            // al Welcome a quien está a mitad de activar— así que es el único que llega aquí con el guard
            // abierto. Cinco segundos después, sobre alguien escribiendo su nombre en el onboarding, saltaba
            // un alert que dice que le borraron los datos en otro dispositivo; y al colgar de este mismo
            // anchor, **desmonta la sheet de la activación** (traza del 2026-09-03 en
            // `ShellDataAlertsModifier`). Su botón destructivo, además, lo dejaba en el Welcome.
            //
            // Mientras la activación está en pantalla, unos datos que desaparecen no son un wipe remoto: los
            // está borrando la persona que mira. Y la sesión sigue siendo solo-grupos hasta
            // `completeFullActivation`, así que tampoco es de las que obedecen esa señal (paso 9).
            if oldValue && !newValue && hasCompletedOnboarding && !showFullModeActivation {
                // Data disappeared — debounce 5s before acting (transient CloudKit gap)
                wipeGraceTask?.cancel()
                wipeGraceTask = Task {
                    do {
                        try await Task.sleep(for: .seconds(5))
                        // **El aviso afirma «TUS datos fueron eliminados de iCloud», y en una sesión que no
                        // obedece la señal del Apple ID el «tus» de esa frase señala a otra persona.** El
                        // iCloud del que habla es el del Apple ID del teléfono, y esta sesión no guarda ahí
                        // los suyos — por eso no obedece la señal, y por eso el aviso tampoco es para ella.
                        // Su botón, además, es el camino GENÉRICO de degradación (`hasCompletedOnboarding =
                        // false` más el borrado de dos centinelas de semilla): sin `isWipingData`, sin
                        // aterrizaje elegido y sin toast, expulsa al onboarding a quien no lo pidió.
                        // Decisión de Jürgen (2026-09-14): en esa celda no se enseña nada.
                        //
                        // **QUIÉN LLEGA AQUÍ DE VERDAD, medido el 2026-09-14 — y NO es el caso que da nombre
                        // al ticket.** El ticket lo atribuía al espejo de CloudKit de un teléfono prestado, y
                        // esa celda hoy no lo ejercita por los dos lados: un solo-grupos dado de alta desde el
                        // 2026-09-10 monta `.neutralNoMirror` (`SwiftDataConfiguration.shouldMountNeutralDurable`),
                        // así que no hay espejo que le baje las filas; y uno anterior a esa fecha sí tiene
                        // espejo, pero el backfill del eje le escribe `hasPrivateSession = true`
                        // (`PrivateSessionMark.backfillIfNeeded`), así que este guard NO lo calla. Lo que sí
                        // llega, en producción y hoy:
                        //
                        //  · **El aviso AUTO-INFLIGIDO tras «Vaciar datos» en una sesión solo-grupos**, que es
                        //    el caso común. `UserDataResetView.handleWipeAllData` no cancela esta gracia, y
                        //    este `onChange` no mira `isWipingData` —que además se apaga a los ~800 ms, mucho
                        //    antes de los 5 s—. En la celda privada el barrido se lleva `hasCompletedOnboarding`
                        //    y el guard de arriba cierra solo; en solo-grupos `applyWipeLanding(.groupsShell)`
                        //    lo REPONE a mano, así que la gracia arranca. Sin esta línea, a quien acaba de
                        //    vaciar sus propios datos le saltaba a los cinco segundos un aviso diciendo que se
                        //    los habían borrado desde otro dispositivo.
                        //  · La ventana entre que una sesión solo-grupos nace y su neutro entra en vigor (la
                        //    marca del mount actúa en el arranque SIGUIENTE; la del eje, ya), y la simétrica
                        //    entre desarmar ese neutro y el relanzamiento.
                        //
                        // La celda del teléfono prestado la cierra el EJE, no esta línea:
                        // `remote-wipe-axis-misses-groups-only-installs-before-the-mount-mark`.
                        //
                        // **El mismo predicado que el borrado, a propósito** (`wipeSignalObeyedByThisSession`,
                        // tercera superficie del eje). Las tres responden «¿los datos de este teléfono son
                        // los del Apple ID?» y el signo de su error coincide: hacia `true` se afirma algo
                        // falso sobre datos ajenos, hacia `false` solo se calla. Por eso la entrada es
                        // `confirmedPrivateSession()` —marca ausente ⇒ `false`— y no `hasPrivateSession()`.
                        // Un predicado propio del aviso divergiría del que gobierna el borrado en el commit
                        // siguiente, y la divergencia sería silenciosa.
                        //
                        // **Se lee AQUÍ y no al arrancar la gracia**: el aviso afirma un hecho sobre AHORA,
                        // y este es el único punto de todo `Yala/` que PIDE ese aviso. (El literal de esa
                        // línea no se cita en esta prosa a propósito: el escáner que fija que es único
                        // cuenta sobre el target de producción, y citarlo aquí haría que documentarlo lo
                        // rompiera.) No sustituye a `!showFullModeActivation`, que se evalúa en la transición
                        // e impide que la tarea NAZCA: si la activación se completa dentro de estos 5 s, el
                        // eje ya dice `true` y solo aquel término lo tapa. Los dos alcances son distintos.
                        //
                        // **Y se vuelve a leer en el DRENAJE, que es donde el aviso se enciende.** No es
                        // una duplicación por si acaso: el intent no es transitorio y puede esperar en cola
                        // a través de un background entero —bajo un cover del Welcome, bajo el sheet de la
                        // activación—, así que entre esta lectura y la pantalla puede mediar un cambio de
                        // sesión. Las dos lecturas responden a preguntas distintas: aquí, si el aviso llega
                        // a PEDIRSE; allí, si todavía es verdad cuando toca enseñarlo.
                        //
                        // **Lo que se calla de más, y está aceptado.** El aviso tiene otra causa legítima
                        // —un hueco transitorio de CloudKit—, y en esta celda también se calla. Lo que
                        // pierde esa persona es información: los datos vuelven cuando vuelven, y el botón
                        // que se va con él era el peor de los dos caminos. En solo-grupos, además, la shell
                        // es `.groupsFocused`, así que las pantallas que se vacían ni siquiera están montadas.
                        // El otro residual, éste por el término `storageMode`: una sesión privada dentro de la
                        // ventana del cutover deja de ver el aviso en la única celda donde era verdad
                        // (`storage-mode-is-a-proxy-for-the-mirror-in-the-wipe-signal`). Hoy sin población —el
                        // Modo Nube está DARK y `.cloud` solo lo escribe el cutover— pero se enciende con él.
                        let sessionObeysWipeSignal = DestructiveScopeLogic.wipeSignalObeyedByThisSession(
                            confirmedPrivateSession: PrivateSessionMark.confirmedPrivateSession(),
                            storageMode: CloudSyncFlags.storageMode)
                        guard sessionObeysWipeSignal else { return }
                        // Data still gone after 5s — ask user. **Por la COLA y no encendiendo el `@State`
                        // desde aquí** (2026-09-14, `remote-wipe-alert-skips-the-router`): quien enciende
                        // es esta tarea de fondo, y a los cinco segundos el anchor de `ContentView` puede
                        // estar presentando cualquier otra cosa. Un `.alert` encendido ahí DESMONTA lo que
                        // hubiera debajo —traza del 2026-09-03 en `ShellDataAlertsModifier`— y encima puede
                        // no llegar a montar, dejando el flag en `true` y la matriz de readiness bloqueada
                        // para el resto de la sesión. Por la cola, el aviso espera a que el anchor esté
                        // libre; es la regla (3) de Presentaciones y el molde de su vecino
                        // `.presentLateICloudMirrorNotice`.
                        RouterEntryGate.shared.submit(.presentRemoteWipeNotice)
                    } catch {
                        // Cancelled — data reappeared
                    }
                }
            } else if !oldValue && newValue {
                // Data reappeared — cancel pending wipe grace
                cancelWipeGrace()
            }
        }
    }

    /// Tramo 2: las presentaciones del anchor — covers, sheets y los seis `ViewModifier` del shell.
    private func shellPresentations(_ base: some View) -> some View {
        base
        .modifier(ShellDataAlertsModifier(
            showRemoteWipeAlert: $showRemoteWipeAlert,
            showICloudRestartAlert: $showICloudRestartAlert,
            showAppleIDChangedAlert: $showAppleIDChangedAlert,
            showFreshStartWipeAlert: $showFreshStartWipeAlert,
            showFreshStartWipeFailedAlert: $showFreshStartWipeFailedAlert,
            hasCompletedOnboarding: $hasCompletedOnboarding,
            hasExistingData: $hasExistingData,
            hasPersonalData: $hasPersonalData,
            showWelcomeFlow: $showWelcomeFlow,
            showOnboarding: $showOnboarding,
            welcomeFlowInitialStep: $welcomeFlowInitialStep,
            onCancelWipeGrace: { cancelWipeGrace() },
            onRemoteWipeStartFresh: { startFreshAfterRemoteWipeNotice() },
            onRemoteWipeDismiss: { dismissRemoteWipeNotice() }
        ))
        // Paso 4 · el aviso del espejo tardío. Sheet y no alert: lleva dos gestos, un progreso y un
        // fallo, y encadenar presentaciones desde este anchor es la carrera medida del 2026-09-03.
        .sheet(item: $lateICloudCorpus) { corpus in
            LateICloudMirrorNoticeView(
                corpus: corpus,
                onKeep: {
                    // «Déjalo así»: los dos corpus conviven, que es lo que ya pasaba — la diferencia es
                    // que ahora lo eligió la persona. Se retira el testigo: ya decidió, y volver a
                    // preguntárselo en cada arranque sería no haberla escuchado.
                    StorageModePersistence.clearPrivateChoseWithoutICloud()
                },
                performWipe: { await performICloudCorpusWipe(.handover) },
                onWiped: {
                    // La gracia del wipe remoto se cancela antes de bajar las señales: este borrado es
                    // DELIBERADO y sin esto el true→false se lee como «te borraron los datos en otro
                    // dispositivo».
                    cancelWipeGrace()
                    hasExistingData = false
                    hasPersonalData = false
                    hasCompletedOnboarding = false
                }
            )
        }
        .fullScreenCover(isPresented: $showLanguageSelection) { languageSelectionCover }
        .fullScreenCover(isPresented: $showInviteRecovery) { inviteRecoveryCover }
        .fullScreenCover(isPresented: $showWelcomeRestore) { welcomeRestoreCover }
        .fullScreenCover(isPresented: $showOnboarding) { onboardingCover }
        .modifier(WelcomeFlowModifier(
            showWelcomeFlow: $showWelcomeFlow,
            welcomeFlowInitialStep: $welcomeFlowInitialStep,
            showOnboarding: $showOnboarding,
            showWelcomeRestore: $showWelcomeRestore,
            showInviteRecovery: $showInviteRecovery,
            showWelcomeCloudSignIn: $showWelcomeCloudSignIn,
            welcomeCloudEntry: $welcomeCloudEntry,
            adoptStartsAtConsent: $adoptStartsAtConsent,
            prefilledOnboardingData: $prefilledOnboardingData,
            hasShownWelcomeChooser: $hasShownWelcomeChooser,
            hasCompletedOnboarding: $hasCompletedOnboarding,
            showFreshStartWipeAlert: $showFreshStartWipeAlert,
            groupsOrganizerFlowActive: $groupsOrganizerFlowActive,
            offersFullActivationAfterGroupsEntry: $offersFullActivationAfterGroupsEntry,
            hasExistingData: hasExistingData,
            hasLocalDataNow: { checkHasExistingData() },
            // **Las dos señales de «hay datos» bajan aquí**: son `@State` de esta vista y
            // `wipeAllUserData` no llama a `incrementDataVersion`, así que el `.onChange(of: dataVersion)`
            // que las recomputa NO dispara. Los OTROS consumidores del mismo borrado ya lo compensan
            // fuera (el `onWiped` del aviso tardío, el arm reanudado y —desde el 2026-09-14— el descarte
            // de la activación, que las RE-MIDE en vez de bajarlas porque conserva los grupos); **la
            // puerta era la única que no**, y dejaba `storeLooksEmpty` mintiendo sobre un store recién
            // vaciado.
            //
            // **Lo que este envoltorio NO es, aunque su primera versión lo dijera** (review adversarial,
            // 2026-09-14): la defensa contra el alert de fresh-start. `WelcomeFlowModifier` recibe
            // `hasExistingData` **por valor**, no por binding, así que escribir el `@State` de aquí no
            // cambia el `let` que ya capturó el `body` — y entre esta línea y la lectura no hay ningún
            // punto de suspensión que obligue a re-evaluarlo. Esa defensa es ahora el fetch VIVO de
            // `startFreshPrivateOnboarding`, que es además lo que el docblock de `hasLocalDataNow` lleva
            // pidiendo desde el review S5.
            //
            // **La gracia del wipe remoto se cancela ANTES del borrado, no después de que salga bien**, y
            // es la corrección que su hermana `performDeviceCorpusWipe` ya lleva escrita:
            // `wipeAllUserData` guarda por lotes, así que un borrado que lanza a media lista deja el
            // `hasPersonalData` cayendo igual — y cancelar solo en la rama de éxito es justo al revés de
            // donde hace falta. Sin eso, ese `true → false` se lee como «te borraron los datos en otro
            // dispositivo» y levanta un alert que DESMONTA el cover del Welcome.
            //
            // `hasCompletedOnboarding` **no** se toca: lo borra `wipeAllUserData` por su cuenta, y
            // forzarlo aquí dispararía el encaminamiento que `onboardingReset_doesNotHijackTheWelcome`
            // vigila.
            performICloudCorpusWipe: {
                cancelWipeGrace()
                let failure = await performICloudCorpusWipe(.handover)
                guard failure == nil else { return failure }
                hasExistingData = false
                hasPersonalData = false
                return nil
            },
            performDeviceCorpusWipe: { await performDeviceCorpusWipe() },
            showGroupInviteOnboarding: showGroupInviteOnboarding
        ))
        .modifier(SignOutRelaunchNetModifier(
            showRelaunchCover: $showSignOutRelaunchCover
        ))
        .modifier(ForceUpdateNetModifier(
            showCover: $showForceUpdateCover
        ))
        .modifier(GroupsBackendInviteModifier(
            showGroupsConsent: $showGroupsConsent,
            showGroupsSignIn: $showGroupsSignIn,
            showGroupsAccountIsCompleteBlock: $showGroupsAccountIsCompleteBlock,
            showGroupsEducational: $showGroupsEducational,
            pendingGroupsJoinZone: $pendingGroupsJoinZone,
            groupsOrganizerFlowActive: $groupsOrganizerFlowActive,
            onGroupsOrganizerCancelled: { returnToGroupsChooser() },
            onAdoptCompleteAccount: { adoptCompleteAccountFromGroups() }
        ))
        // G3 · paso 6 de la rama organizador. Cover propio (no sheet): el alta es terminal —cancelarla a
        // medias dejaría al usuario fuera del Welcome y sin shell— y su blocker `groupsOrganizerName` ya
        // está en la matriz. `onDismiss` de respaldo: si UIKit lo tumba sin que el alta corriera, la rama
        // se apaga en vez de quedarse colgada esperando un paso que nadie va a dar.
        .fullScreenCover(isPresented: $showGroupsOrganizerName, onDismiss: {
            // La continuación corre AQUÍ y no en el callback de éxito (contrato C7): con la dismissal ya
            // terminada, lo que el drain presente a continuación no se lo traga SwiftUI. Cancel (swipe,
            // o UIKit tumbando el cover) ⇒ la rama se apaga y el usuario vuelve al Welcome, nunca a una
            // pantalla muerta.
            guard organizerSetupCompleted else {
                groupsOrganizerFlowActive = false
                returnToGroupsChooser()
                return
            }
            organizerSetupCompleted = false
            // El trío ya está escrito ⇒ el siguiente paso que decide la máquina es el formulario.
            RouterEntryGate.shared.submit(.presentGroupsOrganizerStep)
        }) {
            GroupsOrganizerNameView {
                organizerSetupCompleted = true
                showGroupsOrganizerName = false
            }
            .environment(SessionState.shared)
        }
        .modifier(GroupInviteModifier(
            showGroupInviteOnboarding: $showGroupInviteOnboarding,
            pendingInviteMetadata: $pendingInviteMetadata,
            pendingInviteZone: $pendingInviteZone,
            hasCompletedOnboarding: $hasCompletedOnboarding,
            activeInviteError: $activeInviteError,
            activeGroupSyncError: $activeGroupSyncError
        ))
        .onChange(of: showOnboarding) { oldValue, newValue in
            // Replaces unreliable fullScreenCover onDismiss for post-onboarding flow.
            // onChange(of:) fires synchronously on @State change — always reliable.
            guard oldValue && !newValue && hasCompletedOnboarding else { return }
            if SessionState.shared.needsPostOnboardingTrial && !FeatureGateService.shared.isProUser {
                // El flag persistido se limpia en el DRAIN (presentación real),
                // no aquí: el intent es transient (drop en background) y limpiarlo
                // al emitir perdía la oferta sin re-emisión posible.
                Task {
                    // Wait for fullScreenCover dismiss animation (~0.35s, UX)
                    try? await Task.sleep(for: .seconds(0.8))
                    await waitForBootstrap()
                    RouterEntryGate.shared.submit(.presentTrialOffer)
                }
            }
        }
        .sheet(isPresented: $showSyncSettingsSheet) {
            ProfileView(initialDestination: .iCloudSync)
                .environment(SessionState.shared)
        }
        .sheet(isPresented: $showProTrialOffer, onDismiss: {
        }) {
            ProTrialOfferSheet {
                showProTrialOffer = false
            }
        }
        .sheet(isPresented: $showWhatsNew, onDismiss: {
            if let data = whatsNewData {
                lastSeenAppVersion = data.version
            }
            whatsNewData = nil
        }) {
            if let data = whatsNewData {
                WhatsNewSheet(features: data.features, version: data.version) {
                    showWhatsNew = false
                }
            }
        }
        .sheet(isPresented: $showFullModeActivation) {
            FullModeActivationView(
                // Paso 8 · la puerta privada de la activación borra SOLO la zona de iCloud. El store de una
                // sesión solo-grupos nunca espejó —lo local es suyo—, y el borrado local (`wipeAllUserData`)
                // además resetea el onboarding y el nombre: mandaría al Welcome a quien está activando.
                performICloudZoneWipe: { await performICloudCorpusWipe(.zoneOnly) },
                // **La otra puerta, la de «Restaurar → Empezar desde cero», y su borrado es OTRO.** Ahí sí
                // hay que llevarse las filas locales: para llegar a esa pantalla hubo relanzamiento, así que
                // el store ESPEJA y lo local es justo el corpus que la persona acaba de decidir no traerse
                // — borrar solo la zona lo dejaba entero y `NSPersistentCloudKitContainer` lo re-exportaba a
                // la zona recién creada. Preferencias y dominio de Grupos NO se tocan (`.importedRows`).
                performICloudZoneAndImportedRowsWipe: {
                    // **La gracia del wipe remoto se cancela ANTES de borrar, no en la rama de éxito.**
                    // `wipeAllUserData` guarda por lotes, así que un borrado que lance a media lista deja el
                    // `hasPersonalData` cayendo igual; ese `true → false` con la gracia viva se lee como «te
                    // borraron los datos en otro dispositivo» y levanta un alert que, colgando de este mismo
                    // anchor, **desmonta la sheet de la activación**. Mismo molde que `performDeviceCorpusWipe`.
                    cancelWipeGrace()
                    let failure = await performICloudCorpusWipe(.importedRows)
                    guard failure == nil else { return failure }
                    // **Se RE-MIDEN, no se bajan a `false`.** `hasExistingData` cuenta también los grupos y
                    // las bridgeadas, y aquí los grupos SIGUEN (decisión 2.2A): ponerlo a `false` sería
                    // mentirle a toda la app. El fetch vivo es además la lección del hallazgo nº1 de la
                    // review del PR hermano — escribir un `@State` no obliga a nadie a re-leerlo.
                    hasExistingData = checkHasExistingData()
                    hasPersonalData = checkHasPersonalData()
                    // **Y las filas PUENTEADAS de los grupos vuelven, porque este borrado se las lleva y
                    // nadie más las repone.** `wipeAllUserData` borra `TransactionItem` sin predicado, o sea
                    // también las que tienen `splitExpenseID`; los `SplitExpense` sobreviven (`.importedRows`
                    // no purga el dominio), pero su materialización personal no, y ningún camino la recrea:
                    // `retryPendingBridges` solo mira las que quedaron `bridgePending`, y el plan de cierre
                    // de `.freshPrivate` no converge. Sin esto, la persona conserva sus grupos y sus saldos
                    // —lo que este scope promete— con el Panel, los Registros y el Inbox vacíos de gastos de
                    // grupo, y sin que nadie se lo haya dicho.
                    //
                    // Va por la intención DURABLE y no llamando a la convergencia aquí, porque sus tres
                    // guards todavía no se cumplen: `hasPrivateSession` no se escribe hasta
                    // `completeFullActivation`, y converger antes haría que el bridge de una sesión
                    // solo-grupos BORRE las transacciones reales del gasto que re-puentea. La recoge
                    // `AppBootstrapper` en el arranque siguiente, con el gate de store listo que la espera
                    // de la sheet no tiene.
                    GroupsBridgeRestoreConvergenceStore.markPending()
                    return nil
                }
            ) {
                showFullModeActivation = false
            }
            .environment(SessionState.shared)
        }
        // Inbox alert as fullScreenCover (appears over any sheet).
        // Driven by @State set by the .contentView drain handler.
        // Setter real + onDismiss son la red contra teardowns externos (p.ej.
        // UIKit tumba la cadena al cerrar un sheet debajo): sin ellos el estado
        // queda pegado → cover fantasma invisible que bloquea toda la UI y
        // congela la readiness del router (hasActiveInboxAlert).
        .fullScreenCover(isPresented: Binding(
            get: { !activeInboxNotification.isEmpty },
            set: { if !$0 { activeInboxNotification = .init() } }
        ), onDismiss: {
            activeInboxNotification = .init()
        }) {
            InboxAlertModal(
                notification: activeInboxNotification,
                onViewInbox: {
                    RouterEntryGate.shared.submit(.presentInboxSheet)
                },
                onDismiss: {
                    activeInboxNotification = .init()
                }
            )
            .presentationBackground(.clear)
            .environment(SessionState.shared)
        }
    }

    /// Tramo 3: los observadores de ciclo de vida y de readiness.
    private func shellObservers(_ base: some View) -> some View {
        base
        .onAppear {
            themeManager.systemColorScheme = colorScheme
        }
        .onChange(of: colorScheme) { _, newScheme in
            themeManager.systemColorScheme = newScheme
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                // GC-08: Recalculate user segment on each foreground activation
                UserSegmentService.shared.recalculate()
                // Cinturón del join intent: cubre "grupo ya local pero el reconcile
                // de boot se difirió por quiescencia". El propio reconciler gatea
                // por quiescencia y hace no-op sin intents.
                Task { @MainActor in
                    await GroupJoinReconciler.reconcile(trigger: .foreground)
                }
                // Batch "salir de todos mis grupos" (D10): reanuda un batch a medio ejecutar al volver a
                // foreground. No-op sin trabajo pendiente; el orquestador gatea por quiescencia por grupo.
                Task { @MainActor in
                    await GroupBatchLeaveOrchestrator.resume(trigger: .foreground)
                }
                // Re-chequeo de actualización al volver a foreground (una app que no se mata en días
                // no veía el banner). Barato: el cache de 24h de checkForUpdate hace no-op dentro de
                // la ventana. Solo returning-users (paridad con el boot, runReturningUserPostChecks);
                // un dismiss en sesión sobrevive (checkForUpdate no resetea dismissedInSession).
                if hasCompletedOnboarding {
                    Task { await AppUpdateService.shared.checkForUpdate() }
                }
                // Forzado de actualización: re-evalúa contra el último snapshot (que un fetch de
                // foreground pudo refrescar). DARK en prod.
                ForceUpdateGate.shared.recompute()
            // El exit-on-background del relaunch terminal (decisión owner UX 2026-07-14)
            // vive en YalaApp, NO aquí: el `\.scenePhase` de ContentView es POR-ESCENA
            // (iPad multi-ventana: ocultar una ventana mataría el proceso con otra
            // visible); el de YalaApp es el AGREGADO del proceso y ya guarda tests.
            default:
                break
            }
        }
        .onChange(of: SessionState.shared.isWipingData) { _, _ in
            updateContentViewReadiness()
        }
        // El arranque asentó → se abre el gate `bootstrapPending` y la cola retenida drena
        // por prioridad (aviso de bandeja antes que paywall). Con el shell libre, `markReady`
        // bumpea revision y el `.onChange(revision)` de abajo hace el drain — NO llamarlo
        // también aquí: dos drains en el mismo tick montarían el paywall encima del aviso.
        .onChange(of: SessionState.shared.isBootstrapSettled) { _, settled in
            guard settled else { return }
            updateContentViewReadiness()
            // Si el shell sigue tapado NO hubo bump (markUnready no bumpea) y un intent que
            // supersede la cadena welcome esperaría un bump que no llega — el mismo re-peek
            // explícito que hace `dismissSplash` por el deadlock B4-04, aquí para el invite
            // que llega mientras el arranque aún corría.
            if ContentViewReadinessLogic.blocker(state: currentShellReadinessState()) != nil {
                drainContentViewIntents()
            }
        }
        // Fix carrera 2026-07-14: la fase de sign-out alimenta el blocker `signOutRelaunch`
        // como condición viva — cinturón explícito de recompute (leerla en el snapshot ya
        // registra el tracking @Observable; esto la hace grep-able junto a isWipingData).
        .onChange(of: CloudSessionSignOut.shared.phase) { _, _ in updateContentViewReadiness() }
        // Cross-node: un sheet de MainTabView visible bloquea las presentaciones
        // del shell (el cover del inbox alert no debe montarse encima y ser
        // tumbado por su dismiss — variante cross-node del bug TestFlight).
        .onChange(of: SessionState.shared.isMainTabModalVisible) { _, _ in updateContentViewReadiness() }
        // Shell-level modal flags gate readiness via pure-logic
        // ContentViewReadinessLogic. Encapsulated in a ViewModifier to keep
        // ContentView's body within the type-checker's budget.
        .readinessGateObservers(
            forceUpdateRequired: ForceUpdateGate.shared.isUpdateRequired,
            showOnboarding: showOnboarding,
            showWelcomeFlow: showWelcomeFlow,
            showLanguageSelection: showLanguageSelection,
            showWelcomeRestore: showWelcomeRestore,
            showInviteRecovery: showInviteRecovery,
            showWelcomeCloudSignIn: showWelcomeCloudSignIn,
            // Fix carrera 2026-07-14: la condición viva (la FASE) ES el blocker; el @State del
            // cover es la red visual — si la presentación tarda/falla, el router queda contenido igual.
            showSignOutRelaunch: showSignOutRelaunchCover
                || CloudSessionSignOut.shared.phase == .awaitingRelaunch,
            showFreshStartWipeAlert: showFreshStartWipeAlert,
            showFreshStartWipeFailedAlert: showFreshStartWipeFailedAlert,
            showLateICloudNotice: lateICloudCorpus != nil,
            // Condición VIVA y no el `@State` del alert: la red de presentación toggla ese flag para
            // re-presentar, y con la matriz colgada de él cada reintento la abriría un instante.
            showRemoteWipeAlert: remoteWipeNoticePending,
            showICloudRestartAlert: showICloudRestartAlert,
            showAppleIDChangedAlert: showAppleIDChangedAlert,
            // Condición VIVA del dominio, no un `@State`: el alert baja su binding en el tap y el
            // cierre sigue corriendo segundos después (regla 4 de Presentaciones).
            isSignOutWorking: CloudSessionSignOut.shared.phase == .working,
            hasActiveInviteError: activeInviteError != nil,
            hasActiveGroupSyncError: activeGroupSyncError != nil,
            activeInboxNotification: activeInboxNotification,
            showGroupInviteOnboarding: showGroupInviteOnboarding,
            showGroupsConsent: showGroupsConsent,
            showGroupsSignIn: showGroupsSignIn,
            showGroupsAccountIsCompleteBlock: showGroupsAccountIsCompleteBlock,
            showGroupsOrganizerName: showGroupsOrganizerName,
            showGroupsEducational: showGroupsEducational,
            showFullModeActivation: showFullModeActivation,
            showProTrialOffer: showProTrialOffer,
            showWhatsNew: showWhatsNew,
            showSyncSettingsSheet: showSyncSettingsSheet,
            recompute: updateContentViewReadiness
        )
        .onChange(of: AppRouter.shared.revision) { _, _ in
            drainContentViewIntents()
        }
        // .remoteOnboardingCompleted: dual-path. The intent goes through
        // RouterEntryGate too, but the readiness gate blocks .contentView
        // drain while showOnboarding=true — which is precisely when we need
        // the signal to fire (to dismiss that onboarding view from the
        // remote-completion event). Keep this observer to bypass the gate.
        .onReceive(NotificationCenter.default.publisher(for: .remoteOnboardingCompleted)) { _ in
            handleRemoteOnboardingCompleted()
        }
    }

    /// Extraído del `body` por presupuesto del type-checker (ver `ShellDataAlertsModifier`).
    @ViewBuilder
    private var languageSelectionCover: some View {
        LanguageSelectionView {
            showLanguageSelection = false
            if !hasCompletedOnboarding {
                presentNextOnboardingScreen()
            }
        }
        .environment(SessionState.shared)
    }

    /// Extraído del `body` por presupuesto del type-checker (ver `ShellDataAlertsModifier`).
    @ViewBuilder
    private var inviteRecoveryCover: some View {
        InviteRecoveryView(
            onSuccess: { url in
                showInviteRecovery = false
                AppBootstrapper.shared.handleInviteLink(url)
            },
            onBack: {
                // Vuelve al step del que SALIÓ («¿Cómo empiezas con tu grupo?»), no al chooser de nivel 1
                // («¿qué quieres hacer en Yala?»). Hasta el 2026-08-12 usaba el helper compartido con
                // `WelcomeRestoreView` —para el que `.chooser` SÍ es correcto, porque de ahí viene— y a
                // quien llegaba con un enlace le subía un nivel de más: para reintentar tenía que volver a
                // elegir «Vengo por un grupo». Es el mismo criterio que su hermano `returnToGroupsChooser`
                // explica en su comentario.
                returnToWelcomeChooser(dismissing: $showInviteRecovery, step: .groupsChooser)
            }
        )
        .environment(SessionState.shared)
    }

    /// Extraído del `body` por presupuesto del type-checker (ver `ShellDataAlertsModifier`).
    @ViewBuilder
    private var welcomeRestoreCover: some View {
        WelcomeRestoreView(
            onContinueWithSummary: { summary in
                showWelcomeRestore = false
                let destination = RestoreRouter.decide(isFullyPrefilled: summary.isFullyPrefilled)
                RestoreBreadcrumb.destination(String(describing: destination))
                MetricsService.canary(.iCloudRestoreOutcome, detail: String(describing: destination))
                switch destination {
                case .directToApp:
                    // Eje 1: el corpus personal bajó de iCloud y esta persona entra a usarlo.
                    SessionState.shared.hasPrivateSession = true
                    completeOnboardingAsRestoreSkip()
                    hasCompletedOnboarding = true
                    reEmitInviteAfterRestore()
                case .onboarding:
                    prefilledOnboardingData = summary
                    showOnboarding = true
                    // Parte F: el re-emit ocurre en el onComplete del OnboardingView
                    // (hasCompletedOnboarding=true ahí → reconnect, no re-oferta).
                }
            },
            onStartFresh: {
                // **«Empezar desde cero» va a la PUERTA del paso 4, no al onboarding.** Hasta el
                // 2026-09-14 este callback limpiaba dos preferencias y encendía `showOnboarding`:
                // **no borraba nada**, ni la zona de iCloud ni lo que el espejo ya había importado.
                // Como esta pantalla solo existe con el espejo adjunto
                // (`WelcomeMirrorRelaunchLogic.requiresMirror(.restoreICloud)`), el corpus seguía
                // bajando por debajo mientras la persona hacía su onboarding «de cero» — bajo un
                // copy que le acababa de prometer «sin tus datos previos».
                //
                // La puerta hace lo que este botón prometía y no cumplía: pregunta a CloudKit,
                // enseña las cifras y ofrece borrar (con segunda confirmación), restaurar o
                // cancelar. **Y pregunta algo que esta pantalla no puede medir**: el resumen del
                // restore cuenta FILAS DEL STORE (`ModelContext.iCloudAccountSummary`), así que un
                // import que no terminó dentro del tope sale de aquí con las cifras en cero
                // —`.notFound` sobre un corpus intacto—; la sonda de la puerta va a la zona.
                //
                // **La limpieza de residuales ya no corre aquí**, y es la regla de
                // `welcome-start-fresh-wipes-before-ask`: se limpia cuando se BORRA, no cuando se
                // pregunta. Aquel ticket exceptuó este call-site porque «el fresh-start ya estaba
                // confirmado y no hay alert que cancelar» — la puerta lo desmiente. No se pierde en
                // ninguna salida: si borra, limpia la puerta (`clearsResidualPreferencesOnWipe`); y
                // si sigue de largo, limpian el portal del relanzamiento o
                // `startFreshPrivateOnboarding`.
                prefilledOnboardingData = nil
                // **Y la persona vuelve a estar ELIGIENDO**, así que el chooser deja de constar como
                // visto. Lo cazó la review adversarial, y son DOS cosas distintas las que dependen de
                // ello — molde de `onCreateAnotherAccount`, que baja el mismo flag por el primer motivo:
                //
                //  · **Un kill aquí ya no se salta la puerta.** Con el flag en `true`,
                //    `presentNextOnboardingScreen` cae en su rama final y abre el onboarding privado
                //    DIRECTO: sin chooser y sin validar iCloud, con el espejo adjunto y el corpus
                //    intacto. O sea, este mismo bug por la puerta de atrás. Con el flag abajo vuelve al
                //    Hero, que es de donde esta persona salió.
                //  · **El neutro durable del borrado deja de ser inerte.** `armICloudCorpusWipe` arma
                //    también `armNeutralMount`, y su predicado es `armado && !hasShownWelcomeChooser`.
                //    A esta pantalla se llega con el flag YA marcado (lo pone `onSelectExistingOption`),
                //    así que el segundo término lo anulaba: un kill durante el borrado montaba espejo en
                //    el arranque siguiente y re-importaba justo lo que se estaba borrando.
                hasShownWelcomeChooser = false
                returnToWelcomeChooser(dismissing: $showWelcomeRestore, step: .privateICloudGate)
            },
            onOpenSettings: {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            },
            onBack: {
                returnToWelcomeChooser(dismissing: $showWelcomeRestore, step: .chooser)
            }
        )
        .environment(SessionState.shared)
    }

    /// El onboarding de 8 pasos. Extraído del `body` a una property porque la cadena de ese `body` está en
    /// el límite del type-checker: con este `OnboardingView` inline —medido cuando además llevaba el
    /// callback de la card «Solo grupos», retirada el 2026-09-10— la compilación muere con «unable to
    /// type-check this expression in reasonable time». Es el mismo motivo por el que la mitad de las
    /// presentaciones de esta vista viven en `ViewModifier`s separados.
    @ViewBuilder
    private var onboardingCover: some View {
        OnboardingView(
            prefilledData: prefilledOnboardingData,
            onCancelFromStep1: {
                // Resetea `hasShownWelcomeChooser` para que el Hero se vuelva
                // a presentar (no salta al Chooser automáticamente).
                showOnboarding = false
                hasShownWelcomeChooser = false
                prefilledOnboardingData = nil
                presentNextOnboardingScreen()
            }
        ) {
            // Set flag BEFORE dismiss — onChange picks it up reliably
            // El alta REAL: aquí sí van los dos efectos de primera vez (ver `EntryOnboardingEffects`).
            applyEntryOnboardingEffects(.freshInstall)
            // Eje 1: el onboarding personal terminado ES el nacimiento de la sesión privada.
            SessionState.shared.hasPrivateSession = true
            hasCompletedOnboarding = true
            showOnboarding = false
            prefilledOnboardingData = nil
            reEmitInviteAfterRestore()
        }
        .environment(SessionState.shared)
    }

    /// G3 · devuelve al organizador al step de los dos caminos. Es la salida de todo abandono de la rama
    /// (cancelar el educativo, el sign-in, el consent o el cover del nombre): el usuario ya salió del
    /// Welcome y debajo no hay shell —su alta no ha corrido—, así que dejarlo ahí sería el camino muerto
    /// que el chip prohíbe. Va al `.groupsChooser` y no al `.chooser` porque es donde estaba, y porque
    /// desde ahí puede reintentar o irse a la otra vía sin volver a recorrer el Hero.
    @MainActor
    private func returnToGroupsChooser() {
        welcomeFlowInitialStep = .groupsChooser
        showWelcomeFlow = true
    }

    /// Cierra el sub-flow del Welcome (Rama B o C) y devuelve al user al step del que salió.
    ///
    /// El `step` es EXPLÍCITO desde el 2026-08-12 y no tiene default: los dos llamadores vienen de sitios
    /// distintos —`WelcomeRestoreView` del chooser de nivel 1, `InviteRecoveryView` del sub-step de
    /// Grupos— y un default los volvería a igualar en silencio, que es el bug que este parámetro cierra.
    private func returnToWelcomeChooser(dismissing flag: Binding<Bool>, step: WelcomeFlowStep) {
        flag.wrappedValue = false
        welcomeFlowInitialStep = step
        showWelcomeFlow = true
    }

    private func dismissSplash() {
        withAnimation(.easeOut(duration: 0.4)) {
            splashOpacity = 0
        }
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            showSplash = false
            SessionState.shared.isSplashDismissed = true

            // Router drains queued intents once readiness flips.
            updateContentViewReadiness()
            // B4-04: el handoff splash→welcome no genera revision bump (markUnready
            // no bumpea), así que el .onChange(revision) no re-dispara el drain. Un
            // re-peek explícito aquí permite que un group invite encolado durante el
            // splash cierre la cadena welcome y se presente.
            drainContentViewIntents()
        }
    }

    // MARK: - Router Consumer

    /// Builds the current shell readiness snapshot from @State + SessionState.
    /// Single source for both `updateContentViewReadiness` and the welcome-chain
    /// teardown decision in `drainContentViewIntents`.
    @MainActor
    private func currentShellReadinessState() -> ShellReadinessState {
        ShellReadinessState(
            // Condición VIVA = el gate; el @State del cover (showForceUpdateCover) es la red visual.
            forceUpdateRequired: ForceUpdateGate.shared.isUpdateRequired || showForceUpdateCover,
            isSplashDismissed: SessionState.shared.isSplashDismissed,
            isBootstrapSettled: SessionState.shared.isBootstrapSettled,
            isWipingData: SessionState.shared.isWipingData,
            showOnboarding: showOnboarding,
            showWelcomeFlow: showWelcomeFlow,
            showLanguageSelection: showLanguageSelection,
            showWelcomeRestore: showWelcomeRestore,
            showInviteRecovery: showInviteRecovery,
            showWelcomeCloudSignIn: showWelcomeCloudSignIn,
            // Fix carrera 2026-07-14: la condición viva (la FASE) ES el blocker; el @State del
            // cover es la red visual — si la presentación tarda/falla, el router queda contenido igual.
            showSignOutRelaunch: showSignOutRelaunchCover
                || CloudSessionSignOut.shared.phase == .awaitingRelaunch,
            showFreshStartWipeAlert: showFreshStartWipeAlert,
            showFreshStartWipeFailedAlert: showFreshStartWipeFailedAlert,
            showLateICloudNotice: lateICloudCorpus != nil,
            // Condición VIVA y no el `@State` del alert: la red de presentación toggla ese flag para
            // re-presentar, y con la matriz colgada de él cada reintento la abriría un instante.
            showRemoteWipeAlert: remoteWipeNoticePending,
            showICloudRestartAlert: showICloudRestartAlert,
            showAppleIDChangedAlert: showAppleIDChangedAlert,
            // Condición VIVA del dominio, no un `@State`: el alert baja su binding en el tap y el
            // cierre sigue corriendo segundos después (regla 4 de Presentaciones).
            isSignOutWorking: CloudSessionSignOut.shared.phase == .working,
            hasActiveInviteError: activeInviteError != nil,
            hasActiveGroupSyncError: activeGroupSyncError != nil,
            hasActiveInboxAlert: !activeInboxNotification.isEmpty,
            showGroupInviteOnboarding: showGroupInviteOnboarding,
            showGroupsConsent: showGroupsConsent,
            showGroupsSignIn: showGroupsSignIn,
            showGroupsAccountIsCompleteBlock: showGroupsAccountIsCompleteBlock,
            showGroupsOrganizerName: showGroupsOrganizerName,
            showGroupsEducational: showGroupsEducational,
            showFullModeActivation: showFullModeActivation,
            showProTrialOffer: showProTrialOffer,
            showWhatsNew: showWhatsNew,
            showSyncSettingsSheet: showSyncSettingsSheet,
            isMainTabModalVisible: SessionState.shared.isMainTabModalVisible
        )
    }

    /// Single source of truth for `.contentView` readiness. Called from every
    /// flag that can block shell presentation. Delegates to pure-logic
    /// `ContentViewReadinessLogic.isReady(state:)` so the gating matrix is
    /// testable independently of SwiftUI state.
    @MainActor
    private func updateContentViewReadiness() {
        let state = currentShellReadinessState()
        let currentBlocker = ContentViewReadinessLogic.blocker(state: state)
        // Publica el blocker para los guards de drain de .mainTab/.panel
        // (Clase D): con el shell tapado, sus intents esperan en cola.
        // Choke point único — SessionState.shellModalBlocker no tiene otro escritor.
        if SessionState.shared.shellModalBlocker != currentBlocker {
            SessionState.shared.shellModalBlocker = currentBlocker
        }
        let ready = currentBlocker == nil
        if ready {
            AppRouter.shared.markReady(.contentView)
        } else {
            AppRouter.shared.markUnready(.contentView)
            if let blocker = currentBlocker {
                #if DEBUG
                print("ContentView readiness blocked by: \(blocker)")
                #endif
                // Throttle telemetry: only fire for non-trivial blockers (skip splash/lock
                // which are common boot states; surface user-visible modals only).
                let surfacedBlockers: Set<String> = [
                    "activeInboxAlert", "groupInviteOnboarding",
                    "fullModeActivation", "remoteWipeAlert", "iCloudRestartAlert",
                    "freshStartWipeAlert", "inviteError",
                    "groupSyncError"
                ]
                if surfacedBlockers.contains(blocker) {
                    MetricsService.routingReadinessBlocked(blocker: blocker)
                }
            }
        }
    }

    /// Drains one `.contentView` intent per revision bump. Single-intent
    /// drain — handler may enqueue new intents, they process next tick.
    @MainActor
    private func drainContentViewIntents() {
        // B4-04: un intent que supersede la cadena welcome (los sheets del invite backend)
        // está diseñado para REEMPLAZARLA, no apilarse. El cover del WelcomeFlow
        // bloquea el readiness que necesita drenar ese intent → deadlock: el welcome
        // bloquea el propio intent que lo cerraría. Si la cadena welcome es el ÚNICO
        // blocker, ciérrala para que el drain (y la presentación) procedan.
        if let next = AppRouter.shared.peekNext(for: .contentView),
           next.supersedesWelcomeChain,
           ContentViewReadinessLogic.isBlockedSolelyByWelcomeChain(state: currentShellReadinessState()) {
            dismissWelcomeChainForSupersedingIntent(for: next.id)
            updateContentViewReadiness()  // recompute síncrono → markReady(.contentView)
        }
        guard let intent = AppRouter.shared.drainNext(for: .contentView) else { return }
        switch intent {
        case .showInboxAlert(let notif):
            activeInboxNotification = notif
            // Presentación real → recién ahora se queman las firmas de los drafts
            // (consume-once persistente). Ver commitPendingInboxAlertSignatures.
            AppBootstrapper.shared.commitPendingInboxAlertSignatures()
        case .presentTrialOffer:
            showProTrialOffer = true
            // Drain == presentación real (mismo nodo que ancla el sheet, y con la
            // matriz completa solo drena con el anchor libre). Limpiar aquí — y no
            // en los productores — permite re-emitir tras un drop transient.
            SessionState.shared.needsPostOnboardingTrial = false
        case .presentWhatsNew(let features, let version):
            whatsNewData = (features: features, version: version)
            showWhatsNew = true
        case .presentLateICloudMirrorNotice(let corpus):
            lateICloudCorpus = corpus
        case .showInviteError(let detail):
            // El fallback del cuerpo vacío vivía en la vista; se mueve al productor para que la alerta
            // no tenga que saber de qué camino viene el texto.
            activeInviteError = InviteAlertContent(
                title: String(localized: "groups.invite.linkInvalidTitle"),
                message: detail.isEmpty ? String(localized: "groups.invite.linkInvalidDetail") : detail
            )
        case .showGroupArchivedNotice(_, let groupName):
            // g13_05: el enlace es bueno y el grupo existe — está archivado. Se enseña como ESTADO, con
            // el título (que lleva el nombre del grupo) y el cuerpo de `groups.reconnect.archived.*`, ya
            // traducidos a 16 idiomas y hasta hoy sin ningún consumidor. Su tercer string, `.cta`
            // («Entendido»), NO se usa: ver el aviso medido en `InviteAlertContent`.
            activeInviteError = InviteAlertContent(
                title: L10n.Groups.Reconnect.archivedTitle(groupName),
                message: L10n.Groups.Reconnect.archivedBody
            )
        case .showGroupSyncError(let message):
            activeGroupSyncError = message
        case .iCloudMismatch:
            showICloudRestartAlert = true
        case .appleIDChangedClosePrivate:
            showAppleIDChangedAlert = true
        case .remoteWipe(let skipOnboarding):
            handleRemoteWipeSignal(onboardingAlreadyDone: skipOnboarding)
        case .presentRemoteWipeNotice:
            presentRemoteWipeNoticeIfStillTrue()
        case .remoteOnboardingCompleted:
            handleRemoteOnboardingCompleted()
        case .presentFullModeActivation:
            showFullModeActivation = true
        // G4-invites (A2): flujo backend sign-in → consent → (onboarding fresco) → join.
        // DARK: con `groupsBackendEnabled` OFF los intents jamás se submitean. Las vistas
        // (GroupsBackendInviteModifier) son sheets del MISMO anchor — entran a la matriz
        // (`groupsConsent`/`groupsSignIn`) y el drain se retiene mientras un nodo superior tape.
        case .presentGroupsConsent(let zone):
            pendingGroupsJoinZone = zone
            showGroupsConsent = true
        case .presentGroupsSignIn(let zone):
            pendingGroupsJoinZone = zone
            showGroupsSignIn = true
        // G3: un solo intent para toda la rama organizador — el paso se RE-DECIDE aquí con condiciones
        // vivas en vez de viajar en el payload.
        case .presentGroupsOrganizerStep:
            advanceGroupsOrganizerFlow()
        case .presentGroupsInviteNeutralGate(let zone):
            // **La puerta del invitado.** No presenta nada propio: reabre el Welcome en su step
            // `.groupsGate` con el propósito de la invitación, que es el motor de borrado ya probado.
            //
            // **Se re-mide al llegar, y no se confía en el veredicto del productor** (regla del repo): el
            // intent pudo quedar retenido bajo un cover, y entre el submit y esta línea puede haber
            // mediado el relanzamiento entero que esta pantalla provoca. Quien llega ya neutro encuentra
            // `.proceed` y sale sin tocar nada.
            //
            // El propósito se escribe EXPLÍCITO junto al step, en la misma vuelta: son un par, y
            // separarlos es lo que haría que esta invitación entrara por la rama que informa-y-borra.
            welcomeFlowInitialStep = .groupsGate(purpose: .acceptInvite(groupID: zone))
            showWelcomeFlow = true
        case .presentGroupBackendInviteOnboarding(let zone):
            // Condición viva al drenar (regla del repo): el intent pudo quedar retenido bajo un cover; si
            // la persona YA confirmó la invitación mientras tanto, no re-presentar — continuar el flujo
            // directo (join).
            //
            // Esta es la SEGUNDA puerta con el mismo corte, y hasta 2026-09-05 preguntaba
            // `!hasCompletedOnboarding`, igual que la tabla. Corregir solo la tabla no habría arreglado
            // nada: el intent llegaba aquí y este `else` lo mandaba a `continueFlow` → join. Tiene que
            // preguntar LO MISMO que `GroupBackendInviteEntryLogic.nextStep`, y por eso lee el mismo hecho
            // del mismo sitio.
            //
            // TRES estados, no dos, y el tercero es el que un `?? false` convertía en daño: **sin entry**
            // no hay nada que confirmar. El intent puede morir entre el submit y este drenaje —el pull baja
            // el member y `.correctAndClear` lo limpia mientras un blocker retiene la cola—, y leer esa
            // ausencia como «no confirmó» le presenta la hoja a alguien que YA está dentro del grupo, con
            // el visual genérico y un CTA que no puede hacer nada (`reconcile` sale por su
            // `guard !entries.isEmpty`). Sin entry no se presenta: no se pide confirmar lo que ya no existe.
            switch PendingJoinStore.entry(zoneName: zone)?.isInviteConfirmed {
            case .some(false):
                // La marca sale del intent PERSISTIDO, no del payload: es lo que hace que también la
                // tenga el invitado que llegó desde la web con la app cerrada, que es el caso normal.
                // Antes esta línea era `= nil` con el comentario «backend: sin CKShare metadata — visual
                // genérico»: cierto entonces (el tipo exigía un `CKShare.Metadata` que el canal backend
                // no tiene) y por eso el nombre del grupo no llegaba nunca. `nil` sigue siendo el
                // fallback correcto — un enlace sin cosméticos pinta el visual genérico.
                pendingInviteMetadata = PendingJoinStore.entry(zoneName: zone)?.branded
                pendingInviteZone = zone
                showGroupInviteOnboarding = true
            case .some(true):
                Task { @MainActor in
                    await GroupBackendInviteEntryHandler.continueFlow(zoneName: zone)
                }
            case .none:
                break
            }
        default:
            break
        }
    }

    /// G3 · el avance de la rama organizador, y el ÚNICO sitio que lo decide.
    ///
    /// Los dos primeros pasos encienden los sheets que ya existen (`GroupsBackendInviteModifier` es su
    /// dueño único: un anchor propio sería la regla (4) de Presentaciones, dos anchors ante el mismo
    /// observable) con `pendingGroupsJoinZone = nil`, que es lo que los distingue del camino del invitado.
    /// El último NO presenta nada: pide el formulario en el tab Grupos, donde ya vive su anchor.
    @MainActor
    private func advanceGroupsOrganizerFlow() {
        // Condición viva al drenar: un intent retenido bajo un cover puede llegar con la rama ya abandonada
        // (cancel de un sheet), y entonces no hay nada que avanzar.
        guard groupsOrganizerFlowActive else { return }

        // C3 · **la rama entera no existe en sesión secundaria.** La puerta del Welcome
        // (`WelcomeGroupsGateView`) ya lo comprueba por su cuenta, así que esto es defensa en profundidad,
        switch GroupsOrganizerFlowLogic.nextStep(
            // C2 · el PRIMER escalón. La señal es la misma que usa el tab (`GroupsOnboardingLogic`), con su
            // término legacy incluido: quien completó su alta en modo Grupos antes de C2 ya vio el suyo.
            hasSeenEducational: GroupsOnboardingLogic.hasSeenAnyGroupsEducational(
                hasShownOnboarding: appPreferences.hasShownGroupsOnboarding,
                hasPrivateSession: SessionState.shared.hasPrivateSession,
                hasCompletedSetup: hasCompletedOnboarding),
            hasSession: CloudAuthService.shared.hasSession,
            isConsented: GroupsConsentState.isAccepted,
            // Se lee del `UserDefaults` y NO del `@AppStorage` a propósito: el espejo observable se actualiza
            // por notificación y puede ir un paso por detrás justo después de un alta; si aún dijera `false`,
            // la cadena volvería a `.presentName` — un alta repetida. El `UserDefaults` es la verdad
            // inmediata. (El caso medido era la card «Solo grupos», que escribía el trío en esta misma
            // función y re-submitía; se retiró el 2026-09-10 y la lectura se queda.)
            // Hasta el 2026-09-12 esto iba al CAJÓN de la sesión y no a `.standard` (decisión del owner
            // 2026-09-03); hoy hay un solo dominio. Aquel reparto existía porque quien escribe
            // ese trío es `GroupsOrganizerOnboarding`, que ya va por la puerta
            // (`writer.setLocal` → `PreferenceSyncService.local`). Leerlo de `.standard` preguntaba por la
            // dueña justo después de haber escrito en el cajón de la visita.
            hasCompletedSetup: UserDefaults.standard.bool(forKey: AppPreferences.Keys.hasCompletedOnboarding)
        ) {
        case .presentEducational:
            showGroupsEducational = true
        case .presentSignIn:
            pendingGroupsJoinZone = nil
            showGroupsSignIn = true
        case .presentConsent:
            pendingGroupsJoinZone = nil
            showGroupsConsent = true
        case .presentName:
            showGroupsOrganizerName = true
        case .presentGroupForm:
            // La rama termina aquí: el form lo abre `GroupsContainerView` al montar el tab (molde de
            // `pendingNewGroupExpense`). Y si el usuario lo cancela, aterriza en el empty state estándar
            // con su CTA «crear grupo» — la red ya existía, por eso el último paso puede ser el form.
            groupsOrganizerFlowActive = false
            SessionState.shared.selectedMainTab = .groups
            SessionState.shared.pendingNewGroupForm = true
        }
    }

    /// **Bloque [I]** · la cuenta que firmó en la puerta de Grupos lleva Yala completo y no hay sesión
    /// privada que respetar: se adopta y se aterriza en Grupos.
    ///
    /// **Reencamina al cover del Welcome en vez de adoptar aquí**, y no es una comodidad: la pantalla de
    /// adopt —con su progreso, su guard cross-cuenta, su auto-resume y sus seis fases terminales— vive en
    /// `WelcomeCloudSignInView`, cuyo docblock prohíbe instanciarla en paralelo (dos anchors ante el mismo
    /// flujo es la regla (4) de Presentaciones, y ya costó el bug del sign-out del 2026-07-14). Con la
    /// sesión ya viva, `runSignInFlow` salta el sign-in y sigue por `exists` → guard → adopt: es
    /// literalmente el camino que el alta born-cloud usa cuando su claim dice `existing_stable`.
    ///
    /// La pestaña se selecciona **antes**, por debajo del cover, así que al cerrarse la persona ya está en
    /// Grupos sin necesidad de un testigo durable. Si el adopt termina pidiendo relanzamiento, eso se
    /// pierde con el proceso: la invitación se retoma sola en el arranque —vive en `PendingJoinStore`, que
    /// sobrevive— y quien venía a CREAR un grupo aterriza en el Panel. Darle durabilidad a ese intent es
    /// del paso 12 y tiene ticket.
    @MainActor
    private func adoptCompleteAccountFromGroups() {
        // La rama de Grupos se apaga: quien conduce a partir de aquí es la máquina de migración, y dejarla
        // encendida haría que un cancel del cover devolviera al usuario al Welcome de grupos.
        groupsOrganizerFlowActive = false
        SessionState.shared.selectedMainTab = .groups
        // El proveedor con el que ACABA de firmar, leído del Keychain. `.apple` como último recurso: el
        // `Entry` solo elige el copy y el botón del intro, y ese intro no se muestra —`runSignInFlow` salta
        // el sign-in con la sesión viva—, así que un fallback aquí no puede mandar a nadie al proveedor
        // equivocado.
        let proveedor = CloudSignInProvider(rawValue: CloudAuthService.shared.storedProvider() ?? "")
            ?? .apple
        welcomeCloudEntry = .reentry(proveedor)
        adoptStartsAtConsent = true
        showWelcomeCloudSignIn = true
    }

    /// Cierra los 4 covers de la cadena welcome para que un intent que la
    /// supersede (group invite/reconnect) pueda presentarse sin colisión —
    /// `showWelcomeRestore`/`showInviteRecovery`/`showLanguageSelection` NO están
    /// gateados, así que dejarlos abiertos apilaría dos covers (UI invisible).
    /// `showOnboarding` se excluye a propósito (ver `welcomeChainBlockers`). El
    /// `onDismiss` del reconnect sheet reabre welcome si hace falta. Llamado solo
    /// cuando `isBlockedSolelyByWelcomeChain` es true.
    @MainActor
    private func dismissWelcomeChainForSupersedingIntent(for intentID: String) {
        showLanguageSelection = false
        showWelcomeFlow = false
        showWelcomeRestore = false
        showInviteRecovery = false
        MetricsService.routingWelcomeChainSuperseded(intentID: intentID)
    }

    /// Wait for AppBootstrapper to finish (StoreKit products, exchange rates, etc.)
    private func waitForBootstrap() async {
        for _ in 0..<20 {
            if AppBootstrapper.shared.isInitialized { break }
            do { try await Task.sleep(for: .milliseconds(500)) } catch { break }
        }
        #if DEBUG
        print("ContentView: Bootstrap wait done — products=\(StoreKitManager.shared.products.count), initialized=\(AppBootstrapper.shared.isInitialized)")
        #endif
    }

    /// Lightweight check — fetchCount doesn't materialize objects or trigger observation.
    /// Excluye entidades system (A0-Bridge crea cuenta virtual `Grupos [moneda]` y categorías
    /// `Grupos`/`Cobros de grupos` en bootstrap antes del onboarding). Contarlas reportaría
    /// "has data" en fresh installs sin data real del usuario.
    ///
    /// **Los grupos y lo bridgeado SÍ cuentan** (handover de dispositivo, hallazgo `NEW-E2-03`):
    /// excluir *todo* lo de sistema dejaba fuera exactamente lo que el bridge crea, así que un
    /// usuario anterior que venía de «Solo Grupos» (sin cuentas ni categorías propias) daba
    /// `false` ⇒ el alert de confirmación no se mostraba y «Soy nuevo» **no corría wipe alguno**:
    /// el usuario nuevo aterrizaba con las transacciones y los borradores del anterior intactos.
    /// En un fresh install de verdad los tres conteos son 0, así que el racional original se
    /// mantiene: nada de esto existe sin un grupo detrás.
    ///
    /// **Falla CERRADO** (hallazgo `E1-N4` de la auditoría, corregido con el mismo fix): el
    /// `try?` + `?? 0` anterior convertía cualquier fetch fallido en «no hay datos», que es
    /// exactamente el modo de fallo que este detector existe para impedir — «Soy nuevo» se saltaba
    /// el alert y no corría el wipe. Ante un error, asumir que SÍ hay datos solo cuesta una
    /// confirmación de más, que el usuario puede cancelar; asumir que no los hay se los lleva por
    /// delante o, peor, se los deja al usuario siguiente.
    private func checkHasExistingData() -> Bool {
        let accountDescriptor = FetchDescriptor<Account>(
            predicate: #Predicate<Account> { !$0.isSystemAccount }
        )
        let categoryDescriptor = FetchDescriptor<Category>(
            predicate: #Predicate<Category> { !$0.isSystem }
        )
        let groupDescriptor = FetchDescriptor<SplitGroup>()
        let bridgedDescriptor = FetchDescriptor<TransactionItem>(
            predicate: #Predicate<TransactionItem> { $0.splitExpenseID != nil }
        )
        do {
            let accountCount = try modelContext.fetchCount(accountDescriptor)
            let categoryCount = try modelContext.fetchCount(categoryDescriptor)
            let groupCount = try modelContext.fetchCount(groupDescriptor)
            let bridgedCount = try modelContext.fetchCount(bridgedDescriptor)
            return accountCount > 0 || categoryCount > 0 || groupCount > 0 || bridgedCount > 0
        } catch {
            #if DEBUG
            print("ContentView: checkHasExistingData failed — assuming data exists: \(error)")
            #endif
            return true
        }
    }

    /// Igual que `checkHasExistingData` pero **sin grupos ni bridgeadas**: solo lo que vive en el
    /// store personal espejado por CloudKit. Es la entrada del detector de wipe remoto (ver
    /// `hasPersonalData`). Misma exclusión de entidades de sistema y **misma falla CERRADA** por el
    /// mismo racional: un fetch fallido no debe leerse como «me borraron los datos».
    private func checkHasPersonalData() -> Bool {
        let accountDescriptor = FetchDescriptor<Account>(
            predicate: #Predicate<Account> { !$0.isSystemAccount }
        )
        let categoryDescriptor = FetchDescriptor<Category>(
            predicate: #Predicate<Category> { !$0.isSystem }
        )
        do {
            let accountCount = try modelContext.fetchCount(accountDescriptor)
            let categoryCount = try modelContext.fetchCount(categoryDescriptor)
            return accountCount > 0 || categoryCount > 0
        } catch {
            #if DEBUG
            print("ContentView: checkHasPersonalData failed — assuming data exists: \(error)")
            #endif
            return true
        }
    }

    /// Show a positive confirmation toast for ~3s. Used for remote onboarding
    /// completed and remote restore completed — the only events where a brief
    /// "your data is here" reassurance is worth interrupting the silent sync rule.
    private func showPositiveToast(_ text: String) {
        withAnimation(.easeInOut) { positiveToast = text }
        toastDismissTask?.cancel()
        toastDismissTask = Task {
            try? await Task.sleep(for: .seconds(3))
            withAnimation(.easeInOut) { positiveToast = nil }
        }
    }


    // MARK: - Cross-Device Wipe Handling

    /// Cancela la gracia de cinco segundos del vaciado remoto **y retira el aviso que ya hubiera
    /// pedido**. Las dos mitades cuentan, y la segunda es nueva (2026-09-14): desde que el aviso viaja
    /// por la cola, cancelar la tarea sólo evita los avisos que todavía no se han pedido. Uno ya
    /// encolado sobrevive al `cancel()` —el intent no es transitorio— y saldría más tarde, al liberarse
    /// el anchor, hablando de unos datos que la persona acaba de borrar ella misma.
    ///
    /// Lo llaman los borrados DELIBERADOS (el true→false de `hasPersonalData` lo provocan ellos, no un
    /// wipe remoto) y el camino en el que las filas REAPARECEN.
    @MainActor
    private func cancelWipeGrace() {
        wipeGraceTask?.cancel()
        wipeGraceTask = nil
        AppRouter.shared.drop { $0.id == RouterIntent.presentRemoteWipeNotice.id }
    }

    /// Drenaje de `.presentRemoteWipeNotice`: enciende el aviso de «tus datos fueron eliminados de
    /// iCloud», ya con el anchor de `ContentView` libre (la matriz de readiness es lo que lo garantiza).
    ///
    /// **Re-mide las tres condiciones vivas en vez de fiarse del veredicto del productor**, que es la
    /// regla del repo para todo intent que pueda haber esperado en cola. Y aquí puede esperar mucho: no
    /// es transitorio, así que sobrevive a un background entero bajo el cover que lo estuviera tapando.
    /// Las tres son las que hacen VERDADERA la frase del aviso ahora mismo:
    ///
    ///  · **Las filas siguen sin estar.** Si el espejo de CloudKit las devolvió mientras el aviso
    ///    esperaba turno, no hubo ningún vaciado que anunciar — era el hueco transitorio.
    ///  · **El onboarding sigue completo.** Si dejó de estarlo, la persona ya está en el Welcome o en el
    ///    onboarding: alguien la encaminó por otra vía y este aviso sólo puede estorbar.
    ///  · **El eje de sesión.** El «tus» del aviso señala a los datos del Apple ID de este teléfono, y
    ///    eso sólo es cierto en una sesión privada con su iCloud detrás. Misma lectura estricta que el
    ///    borrado, por el mismo motivo (ver el docblock del predicado).
    @MainActor
    private func presentRemoteWipeNoticeIfStillTrue() {
        guard !hasPersonalData else { return }
        guard hasCompletedOnboarding else { return }
        let sessionObeysWipeSignal = DestructiveScopeLogic.wipeSignalObeyedByThisSession(
            confirmedPrivateSession: PrivateSessionMark.confirmedPrivateSession(),
            storageMode: CloudSyncFlags.storageMode)
        guard sessionObeysWipeSignal else { return }
        remoteWipeNoticePending = true
        showRemoteWipeAlert = true
        armRemoteWipeNoticePresentationNet()
    }

    /// **Verificación de presentación EFECTIVA del aviso, y su desarme.** Un `.alert` que se enciende
    /// con el anchor ocupado no se presenta y tampoco avisa: SwiftUI descarta la petición y el flag se
    /// queda puesto. Cuando ese flag además retiene el router —y éste lo hace, a través de
    /// `remoteWipeNoticePending`— «no montó» se convierte en un brick de la sesión entera: ni bandeja,
    /// ni invitaciones, ni ofertas, hasta matar la app. Es la regla escrita en
    /// `.claude/rules/swiftui-ds.md`, y el motivo de que este ticket exista.
    ///
    /// La red es la misma que verifica los covers terminales del relanzamiento —decisión pura en
    /// `RelaunchNetLogic`, cadencias incluidas— con dos diferencias que impone el envoltorio. La primera:
    /// un alert no tiene contenido propio cuyo `onAppear` pruebe que apareció, así que la señal la da
    /// UIKit (`ModalPresentationProbe`). La segunda: **el bucle no termina al confirmar la presentación**,
    /// sigue vigilando hasta que el aviso se conteste, porque aquí el brick tiene dos formas —la
    /// presentación que no monta y la que se cae después— y la regla nombra las dos. Lo que se toggla es
    /// la RED VISUAL (`showRemoteWipeAlert`); la condición viva no se toca, para que la matriz siga
    /// reteniendo durante los reintentos.
    ///
    /// **Lo que la sonda cuesta si se equivocara, medido con un mutante el 2026-09-14.** Forzándola a
    /// contestar siempre «no hay nada presentado» con el aviso REALMENTE en pantalla, los nueve toggles
    /// dejan el alert pegado: el estado se apaga entero, pero UIKit no completa el desmontaje y el aviso
    /// se queda dibujado. La app no se brickea —la matriz queda libre, que es lo que importa— pero el
    /// residuo es feo, y por eso la sonda tiene una red viva en el simulador:
    /// `RemoteWipeNoticeRoutingUITests.test_notice_presentsOverTheShell_andThePresentationNetLeavesItAlone`
    /// se pone rojo el día que un runtime nuevo deje de reconocer la presentación de un `.alert`.
    ///
    /// **Y al agotarse el cap, el aviso se desarma.** Ahí `RelaunchNetLogic` deja el blocker puesto a
    /// propósito —su caso es terminal y la app se relanza—, pero éste no: nueve segundos sin conseguir
    /// presentar significan que algo tapa el anchor perpetuamente, y quedarse retenido cuesta la sesión
    /// entera. Se pierde el aviso, que vuelve en el arranque siguiente si los datos siguen sin estar, y
    /// queda el canario para saber que pasó.
    @MainActor
    private func armRemoteWipeNoticePresentationNet() {
        remoteWipeNoticeNetTask?.cancel()
        remoteWipeNoticeNetTask = Task { @MainActor in
            try? await Task.sleep(for: RelaunchNetLogic.initialVerifyDelay)
            var attempt = 0
            while !Task.isCancelled {
                switch RelaunchNetLogic.verdict(
                    armed: remoteWipeNoticePending,
                    coverDidAppear: ModalPresentationProbe.isAnythingPresented,
                    attempt: attempt
                ) {
                case .standDown:
                    return
                case .satisfied:
                    // **No se sale: se sigue vigilando mientras el aviso esté pendiente.** Terminar aquí
                    // —que es lo que hace el molde del cover— dejaba abierta la otra mitad del mismo
                    // brick: un alert que SÍ montó y que UIKit tumba después sin que corra ninguno de sus
                    // dos botones baja su binding, pero no la condición viva, y el router se queda
                    // retenido con el aviso ya invisible. La regla lo dice de las dos maneras («si UIKit
                    // descarta esa presentación»), y sin este `continue` sólo cubríamos la primera.
                    // El contador se repone: el cap cuenta fallos CONSECUTIVOS, no tiempo en pantalla.
                    attempt = 0
                    try? await Task.sleep(for: RelaunchNetLogic.retryInterval)
                case .retry:
                    attempt += 1
                    // El toggle necesita un runloop turn: en la misma transaction SwiftUI lo colapsa a
                    // un no-op y no re-presentaría nunca.
                    showRemoteWipeAlert = false
                    try? await Task.sleep(for: RelaunchNetLogic.toggleGap)
                    // **El guard mira la CONDICIÓN VIVA, no solo la cancelación**, y esa ventana de 50 ms
                    // es real: si la persona contesta el aviso justo entre las dos mitades del toggle, sus
                    // dos ramas apagan los dos flags y este `= true` volvería a encender un alert ya
                    // contestado — con la matriz libre, que es lo peor de las dos mitades: el router
                    // drenaría lo siguiente y lo montaría debajo.
                    guard !Task.isCancelled, remoteWipeNoticePending else { return }
                    showRemoteWipeAlert = true
                    try? await Task.sleep(for: RelaunchNetLogic.retryInterval)
                case .exhausted:
                    remoteWipeNoticePending = false
                    showRemoteWipeAlert = false
                    MetricsService.canary(.remoteWipeNoticeNotPresented)
                    return
                }
            }
        }
    }

    /// **«Empezar de cero» del aviso de vaciado remoto: a dónde va la persona, escrito.**
    ///
    /// Al **Hero del Welcome**, que es exactamente donde aterriza este mismo hecho cuando llega por la
    /// señal del Apple ID en vez de por la desaparición de las filas (`performLocalWipeForRemoteSync`,
    /// rama sin `skipOnboarding`). Dos caminos para un solo suceso —los datos personales de este Apple
    /// ID ya no están— y un solo desenlace: las tres ramas de entrada a la vista, con «Restaurar de
    /// iCloud» entre ellas, que es la que le sirve a quien crea que esto fue un error.
    ///
    /// **Hasta el 2026-09-14 el destino no lo elegía nadie.** El botón bajaba `hasCompletedOnboarding` y
    /// lo que pasara después dependía de lo que hubiera en las preferencias: con el chooser marcado como
    /// visto, `presentNextOnboardingScreen` metía a la persona directa al formulario del onboarding, sin
    /// ofrecerle restaurar. El aterrizaje se escribe aquí, y los dos `@AppStorage` se bajan para que
    /// nada de lo que quedara del uso anterior lo cambie.
    ///
    /// **Se monta el cover ANTES de bajar `hasCompletedOnboarding`, y ese orden es load-bearing**: el
    /// `onChange` de ese flag encamina por su cuenta a quien se queda sin onboarding, y su primer guard
    /// es «con el Welcome montado, él manda». Montándolo primero, ese camino se calla y el aterrizaje
    /// queda en un solo sitio — el de aquí. Al revés serían dos, y en esta misma vuelta.
    @MainActor
    private func startFreshAfterRemoteWipeNotice() {
        remoteWipeNoticePending = false
        showRemoteWipeAlert = false
        // Reset seed guards so onboarding can re-create data. El centinela de categorías va por
        // `CategorySeedSentinel.currentKey`: está namespaceado por store (personal vs
        // `YalaModel-UITest`) y el literal suelto apuntaría al del otro proceso.
        UserDefaults.standard.removeObject(forKey: CategorySeedSentinel.currentKey)
        UserDefaults.standard.removeObject(forKey: "notificationsSeeded")
        hasShownWelcomeChooser = false
        hasShownYalaAIOnboarding = false  // tras un vaciado vuelve a verse el onboarding del chat
        welcomeFlowInitialStep = .hero
        showWelcomeFlow = true
        hasCompletedOnboarding = false
    }

    /// **«Ahora no»: la persona se queda donde estaba, y eso ahora es verdad.**
    ///
    /// Sus dos vecinos de `ShellDataAlertsModifier` tienen que REABRIR el Welcome al cancelar, porque el
    /// suyo se enciende sobre un cover y lo desmonta al presentarse: al cerrarlos no queda nada debajo.
    /// Este aviso ya no puede estar en ese caso —viaja por la cola y sólo monta con el anchor libre, que
    /// es lo que arregla este ticket—, así que cancelar devuelve a la app tal cual estaba, con la shell
    /// montada y sin sus filas.
    ///
    /// Lo que sí hace falta es apagar la CONDICIÓN VIVA además del flag del alert: el binding lo baja
    /// SwiftUI al pulsar cualquiera de los dos botones, pero el blocker de la matriz es el otro, y sin
    /// esta línea el router se quedaría retenido con el aviso ya contestado. El aviso vuelve si las
    /// filas vuelven a desaparecer, o en el arranque siguiente por la señal.
    @MainActor
    private func dismissRemoteWipeNotice() {
        remoteWipeNoticePending = false
        showRemoteWipeAlert = false
    }

    private func handleRemoteWipeSignal(onboardingAlreadyDone: Bool) {
        let remoteWipe = NSUbiquitousKeyValueStore.default.double(forKey: "lastWipeTimestamp")
        // El eje de SESIÓN: solo una sesión privada obedece la señal del Apple ID. Una en la nube (E)
        // subiría esos borrados a SU cuenta, y una solo-grupos (F) borraría el perfil de quien está
        // usando el teléfono prestado. `confirmedPrivateSession` y NO `hasPrivateSession`: aquí el `true`
        // BORRA filas, así que la marca ausente tiene que fallar cerrado (ver el docblock del predicado).
        let sessionObeysWipeSignal = DestructiveScopeLogic.wipeSignalObeyedByThisSession(
            confirmedPrivateSession: PrivateSessionMark.confirmedPrivateSession(),
            storageMode: CloudSyncFlags.storageMode)
        let decision = RemoteWipeSignalDecider.decide(
            hasCompletedOnboarding: hasCompletedOnboarding,
            isWipingData: SessionState.shared.isWipingData,
            hasRemoteWipeTimestamp: remoteWipe > 0,
            sessionObeysWipeSignal: sessionObeysWipeSignal
        )

        if decision.shouldMarkSignalsAsProcessed {
            // A4 v3.2: fresh-install con KV-Store contaminado por install previa.
            // Marcar timestamps localmente para que checkForRemoteWipeSignal no
            // re-postee la notif en próximos launches. Bug #6 P0.
            markRemoteSignalsAsProcessed()
        }

        guard decision.shouldProcess else { return }

        // Cancel the hasExistingData-based wipe grace to avoid double-alert. `cancelWipeGrace` retira
        // además el intent del aviso si ya estaba encolado; estas dos líneas cubren el aviso que ya se
        // hubiera ENCENDIDO: la señal explícita manda sobre la sospecha, y lo que procede es el borrado
        // orquestado con su aterrizaje, no una pregunta sobre datos que la app está a punto de barrer.
        remoteWipeNoticePending = false
        showRemoteWipeAlert = false

        performLocalWipeForRemoteSync(skipOnboarding: onboardingAlreadyDone)
    }

    /// Idempotencia para el guard fresh-install: marca AMBOS timestamps remotos
    /// (wipe + onboarding) como procesados localmente para que tanto el "Caso A"
    /// (`.remoteWipeDetected`) como el "Caso B" (`.remoteOnboardingCompleted`)
    /// de `PreferenceSyncService.checkForRemoteWipeSignal` queden silenciados.
    private func markRemoteSignalsAsProcessed() {
        let iKV = NSUbiquitousKeyValueStore.default
        let local = UserDefaults.standard
        let remoteWipe = iKV.double(forKey: "lastWipeTimestamp")
        let remoteOnboarding = iKV.double(forKey: "lastOnboardingTimestamp")
        if remoteWipe > 0 {
            local.set(remoteWipe, forKey: "lastKnownWipeTimestamp")
        }
        if remoteOnboarding > 0 {
            local.set(remoteOnboarding, forKey: "lastKnownOnboardingTimestamp")
        }
    }

    private func handleRemoteOnboardingCompleted() {
        // Only act if this device is mid-onboarding — otherwise ignore
        guard showOnboarding else { return }
        // A4 v3.2: simetría con handleRemoteWipeSignal — si user está mid-onboarding
        // pero hasCompletedOnboarding=false (este device no completó setup), ignorar
        // signal del KV-Store. User debe terminar onboarding aquí. Bug #6 P0.
        guard hasCompletedOnboarding else { return }
        showOnboarding = false
        showPositiveToast(L10n.iCloud.remoteOnboardingCompleted)
    }

    private func performLocalWipeForRemoteSync(skipOnboarding: Bool) {
        remoteWipeTask?.cancel()
        remoteWipeTask = Task {
            let sessionState = SessionState.shared
            sessionState.resetToDefaults()
            sessionState.isWipingData = true

            // Wait for MainTabView to dismount (prevents @Query crash)
            try? await Task.sleep(for: .milliseconds(500))

            do {
                try DataWipeService.wipeAllUserData(
                    in: modelContext,
                    broadcastSignal: false  // Reactive wipe — don't re-signal
                )
                themeManager.resetToDefaults()
            } catch {
                #if DEBUG
                print("ContentView: Remote wipe failed: \(error)")
                #endif
            }

            // Let SwiftData settle
            try? await Task.sleep(for: .milliseconds(200))

            sessionState.isWipingData = false

            if skipOnboarding {
                hasCompletedOnboarding = true
                showPositiveToast(L10n.iCloud.remoteRestoreCompleted)
            } else {
                // Reset chooser flag: tras wipe completo, el user vuelve a ver las 3 ramas.
                hasShownWelcomeChooser = false
                hasShownYalaAIOnboarding = false  // tras wipe vuelve a verse el onboarding del chat
                hasCompletedOnboarding = false  // onChange triggers onboarding
            }
        }
    }

    /// Whether the device language needs an in-app override
    private var needsLanguageSelection: Bool {
        !LanguageManager.deviceLanguageIsSupported && LanguageManager.overrideLanguage == nil
    }

    /// Returns What's New data if version changed and features exist.
    /// Nil otherwise. Used to enqueue `.presentWhatsNew` router intent.
    private func whatsNewDataIfPending() -> (features: [WhatsNewFeature], version: String)? {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        guard !currentVersion.isEmpty, currentVersion != lastSeenAppVersion,
              let features = WhatsNewConfig.features(for: currentVersion) else { return nil }
        return (features: features, version: currentVersion)
    }

    /// Check initial state and decide whether to show language selection, hero, chooser
    /// or main app. Runs during splash so el wait es invisible.
    ///
    /// A4 v3.1: NO hace autopromote por data en iCloud. NO espera 8s con spinner.
    /// El fetch de iCloud lo hace `WelcomeHeroView` invisible mientras el user lee
    /// las cards animadas. Decisión consciente del user — no se carga data sin tap explícito.
    private func checkInitialSyncState() async {
        // **El término del corpus de la puerta del invitado, cableado desde aquí.** Contar filas pide un
        // `ModelContext` y `GroupBackendInviteEntryHandler` no tiene ninguno, así que se le instala el
        // MISMO closure que alimenta al guard cross-cuenta y a la puerta del organizador — los tres miden
        // lo mismo, incluido su fallo CERRADO ante un error de fetch.
        //
        // **Lo que este cableado NO cubre, dicho con precisión:** corre en el splash, y el trigger `.boot`
        // del reconciler corre en paralelo desde `AppBootstrapper`, así que un `drive(.boot)` muy temprano
        // puede leer todavía el default (`false`). El caso del ticket no se escapa por ahí —un store que
        // espeja iCloud lo caza el otro término, que no necesita contexto— y las vueltas siguientes
        // (`.foreground`, `.continuation`, `.userAction`) ya leen el closure real. Lo que quedaría fuera de
        // esa ventana es «corpus SIN espejo y sin onboarding completado», que en los estados donde esta
        // puerta actúa no es alcanzable: el neutro durable borra el corpus y una instalación fresca no lo
        // tiene.
        GroupBackendInviteEntryHandler.hasLocalDataProvider = { checkHasExistingData() }
        // **Y el término que distingue «sesión privada viva» de «Welcome visible».** Lo cablea aquí y el
        // handler no nombra la key: así el handler no puede elegir dominio por su cuenta.
        // (Hasta el 2026-09-12 el par vivía en un dominio por sesión y separarlos era obligatorio; hoy hay
        // un único dominio y el cableado se conserva porque la forma sigue siendo la correcta.)
        GroupBackendInviteEntryHandler.hasCompletedPersonalOnboardingProvider = {
            UserDefaults.standard.bool(forKey: AppPreferences.Keys.hasCompletedOnboarding)
        }

        // GC-08: If group invite onboarding is pending, skip normal flow entirely.
        // The CKShare was already accepted eagerly — just let the invite UI take over.
        if showGroupInviteOnboarding {
            isInitialCheckDone = true
            return
        }

        hasExistingData = checkHasExistingData()
        hasPersonalData = checkHasPersonalData()
        IntentSignalBreadcrumb.initialSyncChecked(hasExistingData: hasExistingData)

        if hasCompletedOnboarding {
            // Returning user este device — ya completó onboarding antes.
            runReturningUserPostChecks()
            isInitialCheckDone = true
            return
        }

        // First launch este device — Hero/Chooser es decisión consciente del user.
        // NO se autopromueve por data en iCloud (eso lo decide el user en el alert post-Hero).
        presentNextOnboardingScreen()
        isInitialCheckDone = true
    }

    /// **Paso 4 · la validación de iCloud que se aplazó, ejecutada cuando por fin se puede.**
    ///
    /// El hueco lo encontró Jürgen el 2026-09-09: quien elige privado sin poder validar sigue en local
    /// —correcto, no poder preguntar nunca bloquea— pero el día que el espejo sincroniza le baja el
    /// histórico viejo encima de lo que acaba de crear, sin decirle nada. Es el bug de este ticket por la
    /// puerta de atrás, y por eso se cubre aquí y no en un ticket aparte.
    ///
    /// Corre en TODO arranque de returning user, y por eso los términos baratos van delante de la sonda.
    @MainActor
    private func runLateICloudMirrorCheck() async {
        // **Paso 8 · una sesión solo-grupos también sale antes que nada.** Este aviso es para quien YA tiene una
        // vida privada en este dispositivo, y un solo-grupos no la tiene. Lo que lo hace obligatorio es el
        // borrado de abajo: la puerta privada de «Activar Yala completo» arma el mismo borrado, y reanudarlo aquí
        // pone `hasCompletedOnboarding = false` —mandaría al Welcome a quien estaba activando—. Mientras siga
        // en solo-grupos el arm queda quieto; si vuelve a elegir privado, la puerta RE-MIDE. Y no sobrevive a la
        // activación: `FullModeActivationView.completeFullActivation` lo retira, porque para entonces la persona
        // ya eligió dónde viven sus datos y reanudarlo aquí, a ciegas, se llevaría el corpus que acaba de crear.
        guard SessionState.shared.hasPrivateSession else { return }
        // **Un borrado que quedó a medias manda sobre todo lo demás: no se pregunta otra vez, se termina.**
        // Aquí sí se reanuda a ciegas —al revés que en la puerta, que vuelve a medir— y la asimetría tiene
        // motivo: para cuando esto corre, el espejo ya mezcló los dos corpus en el store local, así que
        // volver a sondear diría «hay datos» sin distinguir los viejos de los nuevos. La persona confirmó
        // dos veces y lo que falta es acabar.
        //
        // **Y el ciclo se cierra aquí, que es lo que faltaba**: `performICloudCorpusWipe` no retira los
        // testigos —los retiran las vistas al terminar su fase—, así que sin este bloque un borrado
        // reanudado con éxito dejaba el arm puesto y el arranque siguiente volvía a reanudarlo. Bucle.
        if StorageModePersistence.isICloudCorpusWipeArmed() {
            guard await performICloudCorpusWipe(.handover) == nil else { return }
            StorageModePersistence.clearPrivateChoseWithoutICloud()
            StorageModePersistence.clearICloudCorpusWipeArm()
            cancelWipeGrace()
            hasExistingData = false
            hasPersonalData = false
            hasCompletedOnboarding = false
            return
        }
        let watching = StorageModePersistence.privateChoseWithoutICloud()
        // **El pre-filtro es «¿este mount espeja?», no «¿hay iCloud?»**: sin espejo adjunto no hay nada
        // que pueda caer encima. Preguntarlo con `ubiquityIdentityToken` era el pre-filtro que tapaba al
        // criterio — mide iCloud Drive, y `.localNoMirror` adjunta el espejo igual.
        let willSync = ICloudPersonalCorpusProbe.mirrorWillSync()
        // La sonda solo se paga si los dos términos previos la justifican — `decideLateMirror` acepta
        // `nil` justamente para poder decidir sin ella.
        let outcome = (watching && willSync) ? await ICloudPersonalCorpusProbe.probe() : nil
        guard !Task.isCancelled else { return }

        switch WelcomePrivateICloudGateLogic.decideLateMirror(
            watching: watching, iCloudAvailable: willSync, outcome: outcome
        ) {
        case .idle:
            return
        case .standDown:
            StorageModePersistence.clearPrivateChoseWithoutICloud()
        case .ask(let corpus):
            // Por el ROUTER y no encendiendo el `@State`: la sonda contesta desde un `Task` async, y para
            // entonces el anchor puede estar presentando el cover de idioma o el sheet del trial. La
            // matriz de readiness retiene la cola hasta que el anchor esté libre.
            RouterEntryGate.shared.submit(.presentLateICloudMirrorNotice(corpus))
        }
    }

    /// **El borrado del corpus de iCloud, y es UNO para todos los caminos.** Lo llaman la puerta del
    /// Welcome, el aviso tardío y las dos puertas de «Activar Yala completo», y tiene que hacer lo mismo
    /// en todos: la puerta del Welcome es alcanzable con el espejo YA adjunto —el mount neutro dura un
    /// solo arranque, así que quien abre la app, ve el Welcome y la cierra sin elegir vuelve en
    /// `.iCloudMirror`— y ahí borrar solo la zona dejaría el corpus viejo entero en el dispositivo.
    ///
    /// **El dominio de Grupos solo se purga en el `.handover`** (ADR §6): vive en otro contenedor de
    /// CloudKit, y salvo en la frontera de «aquí empieza otro usuario» esto no es un handover de
    /// dispositivo sino la misma persona limpiando su propio histórico.
    ///
    /// Devuelve `nil` si fue bien, o el motivo del fallo — que la vista que lo llamó enseña.
    ///
    /// El `scope` dice **qué se lleva además de la zona**, y son tres políticas y no dos: ver
    /// `ICloudWipeScope`. Sin default a propósito — un default le devolvería a los call-sites futuros el
    /// derecho a no pronunciarse sobre un borrado, que es la forma exacta de este bug.
    @MainActor
    private func performICloudCorpusWipe(_ scope: ICloudWipeScope) async -> String? {
        // **Si el import está en vuelo, NO se borra.** Dos motivos y el segundo es duro: un `save()` de
        // SwiftData durante un import de CloudKit dispara el SIGTRAP que ese gate existe para evitar, y
        // borrar la zona con el import a medias deja al espejo re-creando filas que acabamos de quitar.
        //
        // Y **el resultado de la espera se MIRA**: la primera versión lo descartaba con `_ =` y seguía
        // igual al agotar el tope, que con un corpus grande es el caso NORMAL — o sea, crash durante el
        // import, arm superviviente, y el arranque siguiente repitiendo lo mismo. Un borrado aplazado
        // cuesta un arranque; un crash-loop cuesta la app.
        if ICloudPersonalCorpusProbe.mirrorWillSync() {
            guard await iCloudSyncService.shared.waitForImportQuiescence(timeout: 30) else {
                return "importNotQuiescent"
            }
        }
        guard !Task.isCancelled else { return "cancelled" }
        if let failure = await ICloudPersonalCorpusProbe.wipe() {
            MetricsService.canary(.freshStartWipeFailed, detail: "icloudCorpusWipe:\(failure)")
            return failure
        }
        // Las filas locales solo si las hay. **Y sí puede haberlas con el mount neutro**: hasta el
        // 2026-09-13 esta línea decía que el predicado de instalación fresca lo impedía, y el tercer
        // término del neutro (`groupsOnlySessionArmed`) rompió esa equivalencia — una sesión solo-grupos
        // monta neutro con el archivo del store lleno. La llamada siempre fue correcta; lo que era falso
        // era el motivo.
        guard scope.deletesLocalRows, checkHasExistingData() else { return nil }
        do {
            try DataWipeService.wipeAllUserData(in: modelContext, broadcastSignal: false,
                                                resetsPreferences: scope.resetsPreferences)
            // **Y el dominio de Grupos, por la misma razón que en el borrado del teléfono.** Va DENTRO del
            // guard de `scope.purgesGroupsDomain`, que es el corte que separa a los consumidores de esta
            // función: el Welcome (handover — «empiezo de cero» es la frontera de otro usuario en este
            // dispositivo) y los dos caminos de la activación de Yala completo, donde los grupos son de la
            // misma persona que está activando y purgarlos sería el daño contrario.
            //
            // Sin esto, la celda «iCloud CON datos ∧ teléfono con datos» quedaba sin sellar: el aviso
            // remoto gana al del teléfono (ofrece «traer mis datos», la salida que no destruye), su
            // borrado se llevaba lo personal y dejaba los grupos vivos y el sello sin escribir ⇒ el bridge
            // seguía abierto y el corpus de la etapa anterior subía al iCloud del Apple ID en el arranque
            // siguiente. Es el criterio de aceptación nº4 del ticket, incumplido justo en la celda que la
            // tabla cede al aviso de iCloud.
            if scope.purgesGroupsDomain {
                try DataWipeService.wipeLocalGroupsDomain(in: modelContext)
            }
        } catch {
            MetricsService.canary(.freshStartWipeFailed, detail: "icloudCorpusWipeLocal")
            return "localWipeFailed"
        }
        return nil
    }

    /// **Borrar lo que hay en ESTE TELÉFONO, sin tocar iCloud.** Es la mitad que le faltaba a la puerta
    /// privada para el camino que este ticket arregla: quien elige «Es mi primera vez → privado» desde una
    /// sesión solo-grupos tiene datos aquí y ninguno en su iCloud, así que el aviso lo levanta el corpus
    /// local y el borrado no tiene ninguna zona que quitar.
    ///
    /// **No reusa `performICloudCorpusWipe`, y la diferencia es de producto, no de fontanería:** aquélla
    /// la comparte la activación de Yala completo, donde purgar el dominio de Grupos sería el daño
    /// contrario (esos grupos son de la misma persona que está activando). Aquí «empiezo de cero» es la
    /// frontera de otro usuario en este dispositivo —el mismo criterio del alert de
    /// `ShellDataAlertsModifier`— y por eso el dominio de Grupos se purga y se SELLA: sin el sello, el
    /// bridge le mete al usuario nuevo los gastos del anterior en Panel, Inbox y presupuestos, y su corpus
    /// acaba subiendo al iCloud del Apple ID en el arranque siguiente.
    ///
    /// Devuelve `nil` si fue bien, o el motivo del fallo — mismo contrato que su hermana, porque las dos
    /// alimentan la misma pantalla de error.
    private func performDeviceCorpusWipe() async -> String? {
        // **Si el import está en vuelo, NO se borra.** Mismo gate y mismo motivo que su hermana: un
        // `save()` durante un import de CloudKit dispara el SIGTRAP. En el camino de este ticket el mount
        // es neutro y `mirrorWillSync()` es `false`, así que no cuesta nada; en el otro —la puerta
        // alcanzada con el espejo ya adjunto— es lo que evita el crash.
        if ICloudPersonalCorpusProbe.mirrorWillSync() {
            guard await iCloudSyncService.shared.waitForImportQuiescence(timeout: 30) else {
                return "importNotQuiescent"
            }
        }
        guard !Task.isCancelled else { return "cancelled" }
        // **La gracia se cancela ANTES de borrar, no después, y eso es una corrección de la review.**
        // `wipeAllUserData` hace `save()` incrementales, así que un borrado que lanza a media lista deja
        // igualmente el `hasPersonalData` en `true → false`; con la gracia viva eso se lee como wipe
        // REMOTO y enciende su alert, que al colgar del anchor de `ContentView` **desmonta el cover del
        // Welcome** (traza medida en `ShellDataAlertsModifier`) y deja la pantalla negra. La rama de éxito
        // la cancelaba y la de fallo no: justo al revés de donde hace falta.
        cancelWipeGrace()
        do {
            try DataWipeService.wipeAllUserData(in: modelContext, broadcastSignal: false)
            // El handover: los grupos de la etapa anterior se van de este teléfono y el dominio queda
            // SELLADO hasta que el usuario nuevo adopte Grupos. Va DESPUÉS del borrado personal y dentro
            // del mismo `do`, como en el alert gemelo: si el primero lanza, el segundo no debe correr.
            try DataWipeService.wipeLocalGroupsDomain(in: modelContext)
        } catch {
            MetricsService.canary(.freshStartWipeFailed, detail: "deviceCorpusWipe")
            return "deviceWipeFailed"
        }
        hasExistingData = false
        hasPersonalData = false
        return nil
    }

    /// Post-checks de returning user: trial pendiente, What's New, language, app update.
    /// Extraído para SSOT — antes vivía inline en `checkInitialSyncState`.
    private func runReturningUserPostChecks() {
        resumeFullModeActivationIfPending()
        // GC-08: Skip trial/What's New for groupInvite users — they have no context yet
        if SessionState.shared.hasPrivateSession {
            if SessionState.shared.needsPostOnboardingTrial && !FeatureGateService.shared.isProUser {
                // Flag limpiado en el drain (presentación real) — ver onChange(showOnboarding).
                Task {
                    await waitForBootstrap()
                    RouterEntryGate.shared.submit(.presentTrialOffer)
                }
            } else if let data = whatsNewDataIfPending() {
                RouterEntryGate.shared.submit(.presentWhatsNew(features: data.features, version: data.version))
            }
        }
        Task { await AppUpdateService.shared.checkForUpdate() }
        // Paso 4 · el espejo que llega tarde. Va aquí y no en `presentNextOnboardingScreen` porque su
        // población es exactamente la contraria: quien YA completó el onboarding en este device.
        Task { await runLateICloudMirrorCheck() }
        if needsLanguageSelection {
            showLanguageSelection = true
        }
    }

    /// **Paso 8 · la activación de Yala completo que tuvo que reabrir la app para adjuntar el espejo.**
    ///
    /// Un device solo-grupos es *returning user* (`hasCompletedOnboarding == true`), así que el destino durable
    /// del relanzamiento NO lo consume `presentNextOnboardingScreen`, que solo corre con el onboarding
    /// pendiente. Sin este consumidor el destino se quedaría puesto para siempre, y de él cuelga
    /// `RelaunchNetLogic.shouldExitOnBackground`: la app haría `exit(0)` cada vez que pasara a segundo plano.
    ///
    /// Al consumirlo se escribe la marca de reanudación de la activación, que no mata nada y sobrevive a un kill;
    /// y es ESA marca la que reabre la sheet en cada arranque hasta que la activación termine o se cancele. El
    /// orden —marca antes que consumir— es la kill-safety: un kill en medio deja las dos y el arranque siguiente
    /// repite lo mismo.
    private func resumeFullModeActivationIfPending() {
        // El eje de sesión lo decide `resolveAtBoot`, con tabla: una activación solo se retoma si el
        // dispositivo SIGUE en solo-grupos; si no, lo pendiente se retira sin reabrir nada.
        let resolution = FullModeActivationResumeStore.resolveAtBoot(
            pending: WelcomePendingDestinationStore.peek(),
            current: FullModeActivationResumeStore.peek(),
            isGroupsOnlySession: !SessionState.shared.hasPrivateSession)
        if let step = resolution.writesResume {
            FullModeActivationResumeStore.set(step)
        }
        if resolution.clearsResume {
            FullModeActivationResumeStore.clear()
        }
        if resolution.consumesPendingDestination {
            _ = WelcomePendingDestinationStore.consume()
        }
        if resolution.presentsActivation {
            RouterEntryGate.shared.submit(.presentFullModeActivation)
        }
    }

    /// Parte F: tras restaurar/onboarding desde la oferta de invitación se re-emitía el invite retenido en
    /// `PendingInviteStore`. **La Fase 3 se llevó ese store con el canal CKShare**, y el canal backend no lo
    /// necesita: su intención vive en `GroupBackendInviteEntryHandler.persistIntent` y la retoma
    /// `GroupJoinReconciler` en sus tres triggers. Se conserva el hook por sus call-sites y para no
    /// cambiar el flujo de la oferta de restauración en este commit.
    private func reEmitInviteAfterRestore() {
        Task { @MainActor in
            await GroupJoinReconciler.reconcile(trigger: .foreground)
        }
    }

    /// Routing único para presentar la siguiente pantalla del flow inicial.
    /// Si Chooser no se ha visto, presenta el flow Welcome (Hero+Chooser unificado).
    private func presentNextOnboardingScreen() {
        #if DEBUG
        // uitest: ir directo al OnboardingView (salta Welcome Hero/Chooser) para
        // testear el flujo de onboarding aislado.
        if UITestHooks.startAtOnboarding {
            showOnboarding = true
            return
        }
        // uitest: presentar el cover de GroupInviteOnboarding directo (CKShare no
        // funciona en sim). `-uitest-join-phase` congela la fase del tracker para
        // testear cada step determinista.
        if UITestHooks.startAtInviteOnboarding {
            if let phase = UITestHooks.joinPhaseOverride {
                GroupJoinIntentTracker.shared._uitestForcePhase(named: phase)
            }
            showGroupInviteOnboarding = true
            return
        }
        #endif
        if needsLanguageSelection {
            showLanguageSelection = true
            return
        }
        // **Paso 4 · quedó un borrado del corpus de iCloud sin terminar.** Se vuelve a la puerta, que
        // MIDE otra vez en vez de reanudar a ciegas: si la zona ya se borró, la sonda la ve vacía y sale
        // al onboarding limpio; y si no, se le vuelve a preguntar, que es lo honesto cuando no sabemos
        // qué llegó a pasar.
        //
        // **Pero el destino pendiente gana**, y eso es una corrección de la review adversarial: quien
        // abandonó la puerta y eligió «Restaurar de iCloud» expresó su voluntad DESPUÉS, y hacer ganar al
        // arm le borraría justo lo que acaba de pedir recuperar. El arm se retira con él: la petición de
        // borrado ya no está en pie.
        if StorageModePersistence.isICloudCorpusWipeArmed() {
            if WelcomePendingDestinationStore.peek() == nil {
                welcomeFlowInitialStep = .privateICloudGate
                showWelcomeFlow = true
                return
            }
            StorageModePersistence.clearICloudCorpusWipeArm()
        }
        // R2: destino retenido por el relanzamiento del mount neutro. Va ANTES del chooser y del onboarding
        // porque es más específico que los dos: el usuario YA eligió, y lo que este arranque tiene que hacer
        // es honrar esa elección en vez de volver a preguntar (chooser) o asumir la de por defecto
        // (onboarding). Se CONSUME al leerlo — un destino que no se retira secuestra la pantalla inicial de
        // todos los arranques siguientes.
        if let pending = WelcomePendingDestinationStore.consume() {
            switch pending {
            case .privateOnboarding:
                showOnboarding = true
            case .restoreICloud:
                showWelcomeRestore = true
            case .inviteRecovery:
                showInviteRecovery = true
            case .groupsOrganizer:
                // **Mitad 2 del paso 5.** El portal nunca lo persiste (`requiresMirror(.groupsOrganizer)`
                // es `false`), pero la vuelta al neutro de la puerta de Grupos SÍ: el relanzamiento no lo
                // pidió el destino sino el borrado, y este arranque es el que lo ejecutó. Se retoma en LA
                // PUERTA y no en el alta, que es la cautela que el `default` de abajo pedía —«jamás retomar
                // una rama organizador a mitad en un proceso que no ha visto su puerta»— y que aquí se
                // respeta al pie: la puerta vuelve a medir, y en este proceso ya no hay corpus ni espejo,
                // así que abre y sigue sin que la persona toque nada de más.
                welcomeFlowInitialStep = .groupsGate(purpose: .createGroup)
                showWelcomeFlow = true
            case .groupsInvite:
                // **La invitación que devolvió el teléfono al neutro.** Mismo molde que `.groupsOrganizer`
                // y por la misma razón: el relanzamiento no lo pidió el destino sino el borrado, y este
                // arranque es el que lo ejecutó. Se retoma en LA PUERTA, que vuelve a medir — y en este
                // proceso ya no hay corpus ni espejo, así que abre y el join sigue sin que la persona
                // toque nada de más.
                //
                // El `groupID` sale del intent REPUESTO, no del destino: el destino no lleva payload, y
                // quien lo repuso es el boot-hook con la key one-shot de `GroupInviteResumeStore`. Si no
                // hay intent vivo —TTL agotado, o el token nunca llegó a guardarse— no hay puerta que
                // abrir, y el recorrido normal es la respuesta segura.
                // La MÁS RECIENTE y no la primera: `all()` ordena por `createdAt` ascendente, y la que
                // este arranque acaba de reponer es por construcción la última. Con dos invitaciones vivas
                // —posible si el wipe no llegó a correr— coger la vieja retomaría la que nadie confirmó.
                if let zone = PendingJoinStore.all().last(where: { $0.isBackendJoin })?.zoneName {
                    welcomeFlowInitialStep = .groupsGate(purpose: .acceptInvite(groupID: zone))
                } else {
                    welcomeFlowInitialStep = .chooser
                }
                showWelcomeFlow = true
            case .cloudAccount, .cloudSignIn, .fullActivationPrivate, .fullActivationRestore:
                // Inalcanzables: `requiresMirror` es `false` para las dos primeras, así que el portal del
                // Welcome nunca las persiste. Si aparecen, la respuesta segura es el recorrido normal — jamás
                // saltar al cover de nube con una sesión que este proceso no ha visto.
                // Las dos de la activación (paso 8) solo las escribe un device que YA completó el onboarding
                // —solo-grupos— y las consume `resumeFullModeActivationIfPending`. Aquí solo llegarían si el
                // onboarding se vació entre medias, y entonces tampoco hay activación que retomar.
                welcomeFlowInitialStep = .chooser
                showWelcomeFlow = true
            }
            return
        }
        if !hasShownWelcomeChooser {
            welcomeFlowInitialStep = .hero
            showWelcomeFlow = true
        } else {
            showOnboarding = true
        }
    }

    /// Extracted from body so the overlay isn't recreated on every ContentView
    /// body recompute (dataVersion changes, etc.).
    private var syncStatusBannerOverlay: some View {
        SyncStatusBannerHost { showSyncSettingsSheet = true }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            // Offset below the inline nav bar so the pill doesn't cover the title.
            .padding(.top, 48)
    }

    // A4 v3.1: `iCloudSyncWaitingView` eliminada. El fetch de iCloud ahora corre
    // invisible dentro de `WelcomeHeroView` mientras el user lee las cards animadas.
}

// MARK: - Welcome Flow Modifier

/// Encapsula el flow Welcome con Hero + Chooser unificados en un solo
/// `fullScreenCover` (sin frame "azul vacío" entre ambos). El alert
/// "Detectamos tu cuenta" vive dentro del `WelcomeFlowContainer`.
private struct WelcomeFlowModifier: ViewModifier {
    @Binding var showWelcomeFlow: Bool
    @Binding var welcomeFlowInitialStep: WelcomeFlowStep
    @Binding var showOnboarding: Bool
    @Binding var showWelcomeRestore: Bool
    @Binding var showInviteRecovery: Bool
    @Binding var showWelcomeCloudSignIn: Bool
    /// Qué hace el cover de nube: re-entrada (con su provider) o alta born-cloud (A5). Cada
    /// productor lo setea EXPLÍCITO antes de presentar — jamás se hereda el del intento anterior.
    @Binding var welcomeCloudEntry: WelcomeCloudSignInView.Entry
    /// **Bloque [I]** · el cover del adopt se abrió con la sesión ya firmada en la puerta de Grupos, así
    /// que arranca en el consentimiento y no en el intro. Lo repone este modifier al cerrarse el cover.
    @Binding var adoptStartsAtConsent: Bool
    @Binding var prefilledOnboardingData: ICloudAccountSummary?
    @Binding var hasShownWelcomeChooser: Bool
    @Binding var hasCompletedOnboarding: Bool
    @Binding var showFreshStartWipeAlert: Bool
    /// G3: la rama organizador arranca aquí y la conduce `ContentView` desde su drain — este modifier solo
    /// la ENCIENDE, porque es quien tiene el callback del portal.
    @Binding var groupsOrganizerFlowActive: Bool
    /// Paso 8 · lo enciende `onEnterGroupsOnly` cuando [I] dijo «ofrécele Yala completo»; lo consume
    /// `ContentView` al quedar montada la sesión solo-grupos.
    @Binding var offersFullActivationAfterGroupsEntry: Bool
    let hasExistingData: Bool
    /// S5 del review adversarial: el guard cross-cuenta evalúa datos locales EN el
    /// momento de la decisión (fetch vivo), no el snapshot `hasExistingData` — el
    /// mirror de iCloud puede estar re-importando en background durante el Welcome.
    let hasLocalDataNow: @MainActor @Sendable () -> Bool
    /// Paso 4: el borrado del corpus de iCloud, que vive en `ContentView` porque necesita el
    /// `modelContext`. Este modifier solo lo reenvía al container, y el container a la puerta.
    let performICloudCorpusWipe: @MainActor () async -> String?
    /// Y el del corpus que ya está en el TELÉFONO, con su purga del dominio de Grupos y su sello. Mismo
    /// reenvío, y separado del de arriba porque la activación de Yala completo comparte aquél y jamás
    /// debe usar éste.
    let performDeviceCorpusWipe: @MainActor () async -> String?
    let showGroupInviteOnboarding: Bool

    func body(content: Content) -> some View {
        content
            // Cover único Hero+Chooser. Gate `!showGroupInviteOnboarding`: si
            // llega CKShare, el cover se cierra y `hasShownWelcomeChooser` queda
            // false — el flow reaparece desde el Hero en el próximo cold launch
            // si el invite onboarding se cancela.
            .fullScreenCover(isPresented: $showWelcomeFlow.gated(by: showGroupInviteOnboarding)) {
                WelcomeFlowContainer(
                    initialStep: welcomeFlowInitialStep,
                    onSelectBranch: { branch in
                        hasShownWelcomeChooser = true
                        switch branch {
                        case .new:
                            // Inalcanzable desde A4: el container desvía `.new` a su 2º nivel
                            // (`handleNewBranch`) igual que ya hacía con `.restore`. Se delega al
                            // MISMO helper que el callback nuevo — dos copias de este camino es
                            // como divergen la limpieza de residuales y el alert de wipe.
                            startFreshPrivateOnboarding()
                        case .restore:
                            showWelcomeFlow = false
                            showWelcomeRestore = true
                        case .invite:
                            showWelcomeFlow = false
                            showInviteRecovery = true
                        }
                    },
                    onSelectExistingOption: { option in
                        // H4: sub-elección de "Ya tengo una cuenta" (o su bypass — hoy en
                        // prod DARK siempre .restoreICloud = flujo restore actual intacto).
                        hasShownWelcomeChooser = true
                        switch option {
                        case .restoreICloud:
                            showWelcomeFlow = false
                            showWelcomeRestore = true
                        case .cloudSignIn:
                            welcomeCloudEntry = .reentry(.apple)  // EXPLÍCITO (jamás heredar el previo)
                            showWelcomeFlow = false
                            showWelcomeCloudSignIn = true
                        case .googleSignIn:
                            welcomeCloudEntry = .reentry(.google)
                            showWelcomeFlow = false
                            showWelcomeCloudSignIn = true
                        }
                    },
                    onSelectPrivateAccount: {
                        // A4: "Soy nuevo" → privacidad total (o su bypass, que es el recorrido de
                        // producción de hoy). Byte-idéntico al `case .new` de siempre.
                        hasShownWelcomeChooser = true
                        startFreshPrivateOnboarding()
                    },
                    onSelectCloudAccount: {
                        // A5: "Soy nuevo" → cuenta en la nube. El alta va por el MISMO cover que la
                        // re-entrada (`Entry.bornCloud`): un cover propio sería un segundo anchor
                        // presentando ante el mismo estado, y ese es el bug del sign-out de
                        // 2026-07-14 (regla (4) de Presentaciones).
                        //
                        // **NO se llama a `startFreshPrivateOnboarding()`**, y no es un olvido: aquí
                        // no se limpia nada ni se pregunta por el wipe. La limpieza de residuales y
                        // el alert de datos existentes pertenecen al camino iCloud; el alta nube
                        // decide el destino de los datos DESPUÉS del relanzamiento, con el
                        // onboarding normal, y el corpus local lo gobierna el guard cross-cuenta si
                        // el claim acaba encaminando al returning-user.
                        hasShownWelcomeChooser = true
                        welcomeCloudEntry = .bornCloud
                        showWelcomeFlow = false
                        showWelcomeCloudSignIn = true
                    },
                    onSelectGroupsOrganizer: {
                        // G3 · la puerta ya dijo que sí (canal encendido y sin datos de otro humano): el
                        // step `.groupsGate` es el único que puede llegar hasta aquí.
                        //
                        // **`hasShownWelcomeChooser` NO se marca, y es deliberado**: a diferencia de las
                        // otras cinco salidas, esta rama todavía no ha escrito NADA —el trío va cuatro
                        // pasos más allá— así que un abandono a mitad tiene que poder volver al Welcome y
                        // reintentar. Marcarlo mandaría al usuario al onboarding completo, que no es el
                        // camino que eligió. Es el mismo criterio con el que G2 dejó de marcarlo al tapear
                        // la card de nivel 1.
                        showWelcomeFlow = false
                        startGroupsOrganizerBranch()
                    },
                    onBeaconRoutesToCloudSignIn: { provider in
                        // ADR §10: el faro dice que este Apple ID YA tiene cuenta nube ⇒ lo probable es un
                        // 2º device o un reinstall, y se ENCAMINA a entrar con ella. Mismo cover que la card
                        // "Ya tengo cuenta", pero con su propio `Entry`: el intro dice de dónde viene y
                        // ofrece «Crear otra cuenta» (paso 6). El método viene del faro y se setea EXPLÍCITO
                        // (jamás heredar el del intento anterior). Aquí NO se limpian prefs residuales: no
                        // es un fresh start.
                        hasShownWelcomeChooser = true
                        welcomeCloudEntry = .beaconRouted(accountProvider: provider)
                        showWelcomeFlow = false
                        showWelcomeCloudSignIn = true
                    },
                    onNeedsMirrorRelaunch: { destination in
                        // R2: el destino necesita el mirror y este proceso montó neutro. Se cierra la
                        // elección (el chooser no vuelve a salir) y se GUARDA a dónde iba, porque el
                        // relanzamiento mata el proceso: sin esto, quien pidió restaurar reabriría la app
                        // y aterrizaría en el onboarding normal con su elección perdida.
                        //
                        // La limpieza de residuales del camino privado corre AQUÍ y no tras el
                        // relanzamiento: es la misma que hace `startFreshPrivateOnboarding` y tiene que
                        // ocurrir antes de que el onboarding lea nada.
                        //
                        // **Lo que aquí NO se hace es preguntar por los datos, y hasta el 2026-09-13 este
                        // comentario decía que no hacía falta.** Decía: «el mount neutro exige que no haya
                        // archivo de store, así que en este camino no puede haber datos que confirmar».
                        // Eso valía con los dos términos viejos del neutro; el tercero
                        // (`groupsOnlySessionArmed`) rompió la equivalencia — una sesión solo-grupos tiene
                        // archivo de store CON datos dentro (categorías sembradas, grupos, bridgeadas) y
                        // monta neutro igual. El aviso se perdía entero: `proceed()` no corre en este
                        // camino, así que no corría `startFreshPrivateOnboarding` ni con él el alert.
                        //
                        // El aviso vive ahora DELANTE, en la puerta privada
                        // (`WelcomePrivateICloudGateView`, término `deviceCorpus`), que es un step del
                        // mismo cover y puede pedir confirmación sin desmontar nada. Para cuando este
                        // callback corre, la pregunta ya se hizo.
                        hasShownWelcomeChooser = true
                        // **El anti-bucle del neutro solo-grupos** (paso 5 del rediseño), y va JUNTO a la
                        // línea de arriba porque hace exactamente su mismo trabajo sobre el otro
                        // predicado de mount. Este callback es el punto ÚNICO donde se decide que un
                        // destino necesita el espejo (`WelcomeMirrorRelaunchLogic.shouldRelaunch`), y un
                        // device solo-grupos que pide restaurar giraría para siempre sin esto: marca
                        // puesta ⇒ mount neutro ⇒ «reabre Yala» ⇒ mount neutro otra vez. Es el bucle que
                        // la caducidad por `hasShownWelcomeChooser` cierra para la marca hermana y que
                        // ésta, al no caducar, tiene que cerrar aquí.
                        StorageModePersistence.clearGroupsOnlyNeutralMount()
                        if destination == .privateOnboarding {
                            OnboardingResetHelper.clearResidualPreferencesForFreshStart()
                        }
                        WelcomePendingDestinationStore.set(destination)
                    },
                    onGroupsGateNeutralReturnArmed: { purpose in
                        // **Mitad 2 del paso 5 · el borrado está ARMADO y solo falta reabrir la app.**
                        //
                        // El destino se persiste AQUÍ y no antes de empezar, y el orden es lo que evita un
                        // daño concreto: `RelaunchNetLogic.shouldExitOnBackground` lee «hay destino
                        // pendiente» como «este proceso tiene que morir al pasar a segundo plano»
                        // (`YalaApp.swift`, `welcomeMirrorRelaunchArmed`). Escribirlo antes del arm haría
                        // que la app se cerrara sola aunque la vuelta al neutro se hubiera bloqueado o
                        // abortado. La ventana que queda —un kill entre el arm y esta línea— cuesta una
                        // pantalla, no datos: el borrado corre igual y la persona aterriza en el Welcome.
                        //
                        // Y se persiste a donde iba. Sobrevive al borrado:
                        // `welcome.pendingMirrorRelaunchDestination` no está en el barrido de
                        // `DataWipeService.removeUserPreferenceKeys` (medido) y nadie la limpia en
                        // producción.
                        //
                        // **Y qué destino se persiste lo decide el PROPÓSITO que VIENE CON el aviso**, no
                        // un estado de esta vista: los dos caminos llegan a este mismo callback desde la
                        // misma pantalla, y escribir siempre `.groupsOrganizer` mandaría al invitado al
                        // alta de un grupo que no quiso crear.
                        //
                        // El sobre `{groupID, token}` ya lo escribió la PANTALLA al recibir el gesto —aquí
                        // solo se comprueba—: entre el arm del borrado y este callback hay una entrega de
                        // SwiftUI, y en el camino del swap in-process la jerarquía se desmonta en la misma
                        // vuelta del arm, así que escribirlo aquí lo dejaba fuera de la ventana.
                        if let groupID = purpose.invitedGroupID {
                            // Sin sobre no hay join que retomar, así que tampoco se persiste un destino que
                            // llevaría a una puerta sin nada detrás: el arranque siguiente cae en el
                            // recorrido normal, que es lo honesto cuando la invitación ya no está.
                            if GroupInviteResumeStore.peek()?.groupID == groupID {
                                WelcomePendingDestinationStore.set(.groupsInvite)
                            } else {
                                #if DEBUG
                                print("ContentView: invite neutral return armed without a live envelope — nothing to resume")
                                #endif
                            }
                        } else {
                            WelcomePendingDestinationStore.set(.groupsOrganizer)
                        }
                        // El cover del Welcome y el terminal del cierre de sesión cuelgan del MISMO body,
                        // así que UIKit presenta uno solo. Cerrar éste es lo que deja presentarse al otro,
                        // que es el que tiene verify loop, blocker de readiness y salida en background.
                        showWelcomeFlow = false
                    },
                    onGroupsGateInviteProceed: { zone in
                        // La puerta del invitado abrió: este dispositivo ya no cruza datos de nadie. Se
                        // cierra el Welcome y se RETOMA el join donde estaba — `continueFlow` re-lee el
                        // intent persistido y re-evalúa el paso con condiciones vivas, así que no hace
                        // falta recordar en cuál se quedó.
                        //
                        // **El cover NO se cierra si no hay nada que continuar**, y esa comprobación es la
                        // misma que `continueFlow` hace por dentro antes de volverse sin hacer nada. El
                        // intent puede haber muerto entre el submit y este tap (el pull baja el member y el
                        // reconciler lo limpia), y con el onboarding sin completar debajo de este cover no
                        // hay shell ninguna: cerrarlo dejaba a la persona ante un fondo vacío, sin un solo
                        // control, hasta matar la app.
                        guard PendingJoinStore.entry(zoneName: zone) != nil else {
                            welcomeFlowInitialStep = .groupsChooser
                            return
                        }
                        showWelcomeFlow = false
                        Task { @MainActor in
                            await GroupBackendInviteEntryHandler.continueFlow(zoneName: zone)
                        }
                    },
                    hasLocalDataNow: hasLocalDataNow,
                    // Paso 4: el borrado vive aquí porque necesita el `modelContext`. La puerta solo
                    // decide y enseña.
                    //
                    // **Sin scope a propósito: esto es un REENVÍO, no una llamada al borrador.** El
                    // `performICloudCorpusWipe` que se lee aquí es el closure que `WelcomeFlowModifier`
                    // recibió, y quien eligió `.handover` fue el envoltorio que se lo pasó. Ponerle un
                    // scope aquí sería darle a este reenvío el derecho a contradecir al de arriba.
                    performICloudCorpusWipe: { await performICloudCorpusWipe() },
                    performDeviceCorpusWipe: { await performDeviceCorpusWipe() }
                )
                .environment(SessionState.shared)
            }
            // H4: re-entrada a una cuenta del Modo Nube (SIWA → exists → adopt).
            // Gate group-invite (mismo patrón que el cover del flow) + onDismiss de
            // respaldo (C2): si UIKit tumba el cover sin terminal, reabrir el chooser
            // — jamás dejar al usuario en pantalla vacía con onboarding incompleto.
            .fullScreenCover(
                isPresented: $showWelcomeCloudSignIn.gated(by: showGroupInviteOnboarding),
                onDismiss: {
                    // El arranque-en-consent es de UNA entrada: la siguiente por el chooser es un
                    // recorrido normal y debe ver su intro.
                    adoptStartsAtConsent = false
                    // R2: `!showOnboarding` es el término nuevo. El alta born-cloud que NO relanza cierra
                    // este cover y enciende el onboarding en la misma vuelta; sin este término, el respaldo
                    // devolvería al usuario al chooser encima del onboarding que acaba de abrirse — dos
                    // presentaciones ante el mismo anchor, que es la regla (4) de Presentaciones.
                    // `!showWelcomeFlow` es el término del bloque [I], hermano del `!showOnboarding` de
                    // arriba: `onEnterGroupsOnly` cierra este cover y enciende el Welcome en el step de
                    // Grupos, y sin este término el respaldo lo pisaba con `.chooser` — devolviendo a la
                    // persona a «¿qué quieres hacer en Yala?» justo después de haberlo elegido.
                    if !hasCompletedOnboarding && !showGroupInviteOnboarding && !showOnboarding
                        && !showWelcomeFlow {
                        welcomeFlowInitialStep = .chooser
                        showWelcomeFlow = true
                    }
                }
            ) {
                WelcomeCloudSignInView(
                    entry: welcomeCloudEntry,
                    startsAtConsent: adoptStartsAtConsent,
                    deviceStateNow: {
                        // Se compone AQUÍ y se evalúa en el momento de la decisión: el mirror puede
                        // asentar entre que se monta la pantalla y que la persona firma, y esta vista es
                        // alcanzable desde la puerta de Grupos con el onboarding ya completado.
                        CloudIdentityRoutingLogic.deviceState(
                            hasCompletedOnboarding: hasCompletedOnboarding,
                            storageMode: StorageModePersistence.read(),
                            hasPrivateSession: PrivateSessionMark.hasPrivateSession())
                    },
                    hasLocalDataNow: hasLocalDataNow,
                    onAdoptStarted: {
                        // TEMPRANO (antes de conducir la máquina): cierra el hazard
                        // kill-mid-adopt → el seed del onboarding jamás corre sobre una
                        // cuenta existente; un kill aterriza en MainTab con la card de
                        // Almacenamiento reflejando el estado real del adopt.
                        // Eje 1: adoptar una cuenta existente trae su vida personal a este dispositivo.
                        SessionState.shared.hasPrivateSession = true
                        completeOnboardingAsRestoreSkip()
                        hasCompletedOnboarding = true
                    },
                    onFinishedToApp: {
                        showWelcomeCloudSignIn = false
                    },
                    onBornCloudCompleted: {
                        // R2: el alta terminó sin relanzamiento (mount neutro). Se cierra el cover y se
                        // presenta el onboarding NORMAL — que es exactamente lo que el usuario habría visto
                        // tras reabrir la app. `hasShownWelcomeChooser` ya quedó `true` al elegir la card
                        // nube, así que no hay chooser al que volver.
                        //
                        // **Sigue siendo SOLO del alta, y conviene saber por qué** (2026-09-07): la
                        // re-entrada terminó teniendo su propia fase (`.reentryReady`) y sale por
                        // `onFinishedToApp`. Mandarla aquí habría deshecho el `onAdoptStarted` de cuatro
                        // líneas más arriba —que marca `hasCompletedOnboarding` para que el seed no corra
                        // sobre una cuenta existente— y con el motor ya arrancado en sesión, la cuenta
                        // duplicada y las categorías sembradas habrían SUBIDO al backend.
                        //
                        // `hasCompletedOnboarding` NO se marca aquí: el onboarding es real y lo marca él.
                        // Por eso `showOnboarding` se enciende EXPLÍCITAMENTE en vez de dejar que el
                        // `onDismiss` decida — su rama de respaldo devuelve al chooser.
                        showWelcomeCloudSignIn = false
                        showOnboarding = true
                    },
                    onEnterGroupsOnly: { offersFullActivation in
                        // Paso 8 · la oferta viaja hasta que la sesión solo-grupos quede montada.
                        offersFullActivationAfterGroupsEntry = offersFullActivation
                        // **Bloque [I]** · el backend dijo que esta cuenta solo lleva grupos, así que no
                        // se adopta nada: el recorrido pasa a la mini-app de Grupos con la sesión VIVA.
                        //
                        // **Va a la PUERTA de Grupos del Welcome, no a la cadena directamente**, y esa es
                        // la corrección de dos defectos que las lentes adversariales cazaron:
                        //
                        // 1. `startGroupsOrganizerBranch()` se salta `GroupsOrganizerGateLogic`, que es
                        //    quien comprueba el canal, el espejo del mount y —lo que más pesa— los DATOS
                        //    AJENOS. Por ahí un device con el corpus de otra persona llegaba al alta, y
                        //    su final da de alta una sesión solo-grupos encima del corpus del dueño.
                        // 2. El `onDismiss` de respaldo de este cover se dispara igual —en el Welcome
                        //    `hasCompletedOnboarding` es `false` por construcción, así que el término que
                        //    salva a sus hermanos no puede salvar a este— y reabría el chooser encima,
                        //    dejando la cadena de Grupos retenida por el blocker `welcomeFlow`. Encender
                        //    aquí el flujo del Welcome en su step lo hace explícito, y el respaldo ya no
                        //    actúa (su guard mira `showWelcomeFlow`).
                        //
                        // Lo que NO se hace aquí, y no por olvido: escribir el trío de solo-grupos. Lo
                        // escribe `GroupsOrganizerNameView` al final de su cadena, que es quien tiene
                        // permiso.
                        // **El desarme del boot-wipe de grupos, que este camino se saltaba.** Lo medido:
                        // «Salir de Yala en este dispositivo» arma `groupsOnlyWipeArmed` y reabre el
                        // Welcome SIN relanzar, así que la persona puede volver a entrar por aquí y
                        // recuperar sus grupos… hasta el siguiente arranque en frío, que los borra. El
                        // único desarme de re-entrada vivía en el closure del sheet de `GroupsSignInView`,
                        // y por este camino ese sheet no se presenta (con la sesión viva, `GroupsGateLogic`
                        // no pide sign-in). Los otros efectos de ese closure sí se auto-curan: el latch de
                        // historial y el arranque del canal los repone el `onAppear` del tab, y el consent
                        // baja en el boot siguiente.
                        StorageModePersistence.clearGroupsOnlyWipeArm()
                        GroupsSignOutBannerMarker.clear()
                        welcomeFlowInitialStep = .groupsGate(purpose: .createGroup)
                        showWelcomeFlow = true
                        showWelcomeCloudSignIn = false
                    },
                    onCreateAnotherAccount: {
                        // **Paso 6 · el faro solo encamina.** Desde la entrada a la que llevó el faro, la
                        // persona pide crear otra cuenta: vuelve a «Elige dónde quieres guardar tus datos»
                        // ENTERO —las cards que diga `visibleNewOptions`, privado incluido— y NO al chooser
                        // de nivel 1, donde «Soy nuevo» la volvería a encaminar. Decisión de Jürgen del
                        // 2026-09-09: ni se preselecciona ni se recorta nada.
                        //
                        // Mismo trío que `onBack`, en el mismo orden: el `onDismiss` de este cover mira
                        // `showWelcomeFlow` y, ya encendido, no pisa el step con `.chooser`.
                        //
                        // **Y la persona vuelve a estar ELIGIENDO**, así que `hasShownWelcomeChooser` vuelve a
                        // `false`: es el estado de quien llega a esa pantalla por el recorrido normal. Con el
                        // `true` que dejó el faro al encaminar, un cierre de la app aquí abriría el onboarding
                        // privado directo —sin elegir y sin la comprobación de iCloud del paso 4— y el arranque
                        // siguiente ya no montaría neutro. Mismo gesto que `onCancelFromStep1`.
                        hasShownWelcomeChooser = false
                        showWelcomeCloudSignIn = false
                        welcomeFlowInitialStep = .newChooser
                        showWelcomeFlow = true
                    },
                    onBack: {
                        showWelcomeCloudSignIn = false
                        welcomeFlowInitialStep = .chooser
                        showWelcomeFlow = true
                    }
                )
            }
    }

    /// G3 · arranca la rama organizador. **No presenta nada directamente**: submitea el avance al router
    /// para que el primer sheet espere a que el cover del Welcome termine de irse (el gate ve
    /// `showWelcomeFlow` y no drena hasta que baja). Presentarlo a pelo en esta misma vuelta es la carrera
    /// clásica de dos presentaciones sobre el mismo anchor.
    private func startGroupsOrganizerBranch() {
        groupsOrganizerFlowActive = true
        RouterEntryGate.shared.submit(.presentGroupsOrganizerStep)
    }

    /// "Soy nuevo → privacidad total": el camino de siempre, extraído a un helper para que el
    /// callback de A4 y la rama `.new` histórica no puedan divergir.
    private func startFreshPrivateOnboarding() {
        // Segunda barrera vs data residual: el alert "Detectamos tu cuenta" del Hero cubre
        // el caso iCloud-con-data, pero falla en (1) sim sin iCloud, (2) timeout del fetch,
        // (3) CloudKit mirror sync que llega post-Hero. Si hay data al momento del tap,
        // pedir confirmation explícito antes de wipe.
        //
        // **El fetch VIVO y no el snapshot `hasExistingData`** (review adversarial, 2026-09-14). Es el
        // mismo motivo que el docblock de `hasLocalDataNow` lleva escrito desde el review S5 —«el mirror
        // de iCloud puede estar re-importando en background durante el Welcome»— y ahora además hay un
        // camino donde el snapshot está garantizado stale: la puerta de iCloud borra el corpus y sale sin
        // relanzar (el mount ya espeja), así que este modifier sigue con el `let` que capturó el `body`
        // ANTES del borrado. Con él, a quien acababa de confirmar el borrado dos veces le salía un tercer
        // alert pidiéndole borrar lo que ya no existía — y su «Cancelar» lo dejaba plantado en el Welcome.
        if hasLocalDataNow() {
            showFreshStartWipeAlert = true
            // welcomeFlow sigue visible hasta resolver el alert
        } else {
            // La limpieza de prefs residuales del KV-Store del Apple ID (userName, currency —
            // sobreviven al uninstall) va DENTRO de las ramas que de verdad proceden: aquí, y en
            // el botón destructivo del alert. Corrió durante meses ANTES de este `if`, así que
            // «Cancelar» no la deshacía y el usuario perdía su nombre y su divisa por preguntar.
            // Y el efecto era DIFERIDO —`AppPreferences.loadFromDefaults()` solo corre en el
            // `init` y descarta los vacíos— así que lo percibía un arranque en frío después.
            // Se limpia cuando se BORRA, no cuando se pregunta.
            OnboardingResetHelper.clearResidualPreferencesForFreshStart()
            showWelcomeFlow = false
            showOnboarding = true
        }
    }
}

// MARK: - Sign-out relaunch net (H4, C1 del review adversarial + fix carrera 2026-07-14)

/// DUEÑO ÚNICO del cover terminal del cierre de sesión `.cloud`/secundario (`awaitingRelaunch`
/// = wipe de boot ARMADO). ProfileView ya NO presenta (ante la fase solo cierra su sheet):
/// dos anchors ante el mismo observable eran una carrera de reconciliación — UIKit no
/// presenta dos veces y tumbaba AMBAS cadenas dejando el flag en `true` sin onDismiss
/// (red muerta, app usable con el wipe armado; bug device 2026-07-14).
///
/// Verificación de presentación EFECTIVA: el flag NO prueba nada — solo el `onAppear` del
/// contenido real (`coverDidAppear`) confirma que UIKit presentó. El primer intento puede
/// caer con la sheet de Profile aún cerrándose → el verify loop reintenta (toggle
/// false→true, cadencias en `RelaunchNetLogic`) hasta `satisfied` o el cap del ciclo.
/// `signOutRelaunch` es además blocker de la matriz por CONDICIÓN VIVA (la fase, no este
/// flag) — el router queda contenido desde la transición aunque el cover tarde en llegar.
private struct SignOutRelaunchNetModifier: ViewModifier {
    @Binding var showRelaunchCover: Bool

    /// true SOLO cuando el onAppear del contenido real disparó (única prueba de presentación).
    @State private var coverDidAppear = false
    @State private var verifyTask: Task<Void, Never>?
    @Environment(\.scenePhase) private var scenePhase

    private var phase: CloudSessionSignOut.Phase { CloudSessionSignOut.shared.phase }

    func body(content: Content) -> some View {
        content
            .onAppear {
                if phase == .awaitingRelaunch { arm() }
            }
            .onChange(of: phase) { _, newPhase in
                if newPhase == .awaitingRelaunch { arm() }
            }
            // Ciclo FRESCO al volver a foreground con la condición armada y sin cover
            // (el cap de intentos es por-ciclo, no de por vida).
            .onChange(of: scenePhase) { _, newScene in
                if newScene == .active && phase == .awaitingRelaunch && !coverDidAppear { arm() }
            }
            .fullScreenCover(
                isPresented: $showRelaunchCover,
                onDismiss: {
                    // Terminal: si UIKit lo tumbara, re-presentar (regla toolbar-muerta).
                    coverDidAppear = false
                    if CloudSessionSignOut.shared.phase == .awaitingRelaunch { arm() }
                }
            ) {
                SignOutRelaunchView()
                    .onAppear {
                        // Presentación REAL confirmada (dispara al inicio de la animación;
                        // idempotente ante doble onAppear). Jamás se toggla un cover vivo.
                        coverDidAppear = true
                        verifyTask?.cancel()
                        verifyTask = nil
                    }
            }
    }

    private func arm() {
        showRelaunchCover = true
        // Cancel-before-start: un solo verify loop vivo — dos loops togglando el mismo
        // binding reproducirían la carrera que este fix mata.
        verifyTask?.cancel()
        verifyTask = runRelaunchNetVerifyLoop(
            net: "signout",
            armed: { CloudSessionSignOut.shared.phase == .awaitingRelaunch },
            coverDidAppear: { coverDidAppear },
            setCover: { showRelaunchCover = $0 }
        )
    }
}

// MARK: - Force-update net (min-version, molde SignOutRelaunchNetModifier)

/// DUEÑO ÚNICO del cover TERMINAL del forzado de actualización (min-version). Presenta
/// `ForceUpdateView` mientras `ForceUpdateGate.shared.isUpdateRequired`; si UIKit lo tumbara con el
/// forzado aún vigente, re-presenta (regla toolbar-muerta) vía el verify loop compartido.
/// `forceUpdate` es además el blocker de MÁXIMA severidad de la matriz por CONDICIÓN VIVA (el gate,
/// no este @State).
///
/// Coexistencia con los otros 2 net-modifiers terminales (signout/secondary): son PRÁCTICAMENTE
/// DISJUNTOS — el forzado se determina en boot/foreground ANTES de que exista flujo de sign-out (la
/// UI ya está bloqueada) y es el blocker más alto. No se añade guard cruzado (mismo precedente que
/// signout+secondary, que ya coexisten sin él porque no co-arman). DARK en prod (el gate es false).
private struct ForceUpdateNetModifier: ViewModifier {
    @Binding var showCover: Bool

    @State private var coverDidAppear = false
    @State private var verifyTask: Task<Void, Never>?
    @Environment(\.scenePhase) private var scenePhase

    private var isRequired: Bool { ForceUpdateGate.shared.isUpdateRequired }

    func body(content: Content) -> some View {
        content
            .onAppear {
                if isRequired { arm() }
            }
            .onChange(of: isRequired) { _, required in
                if required { arm() }
            }
            // Ciclo FRESCO al volver a foreground con el forzado vigente y sin cover (cap por-ciclo).
            .onChange(of: scenePhase) { _, newScene in
                if newScene == .active && isRequired && !coverDidAppear { arm() }
            }
            .fullScreenCover(
                isPresented: $showCover,
                onDismiss: {
                    // Terminal: si UIKit lo tumbara con el forzado aún vigente, re-presentar.
                    coverDidAppear = false
                    if ForceUpdateGate.shared.isUpdateRequired { arm() }
                }
            ) {
                ForceUpdateView()
                    .onAppear {
                        // Presentación REAL confirmada (idempotente). Jamás togglar un cover vivo.
                        coverDidAppear = true
                        verifyTask?.cancel()
                        verifyTask = nil
                    }
            }
    }

    private func arm() {
        showCover = true
        // Cancel-before-start: un solo verify loop vivo.
        verifyTask?.cancel()
        verifyTask = runRelaunchNetVerifyLoop(
            net: "forceUpdate",
            armed: { ForceUpdateGate.shared.isUpdateRequired },
            coverDidAppear: { coverDidAppear },
            setCover: { showCover = $0 }
        )
    }
}

/// Verify loop COMPARTIDO de las redes de relaunch/forzado terminal (un solo punto de verdad
/// del reintento — la decisión pura vive en `RelaunchNetLogic`, los triggers en cada
/// modifier). El closure `coverDidAppear` lee el `@State` del modifier en el momento de
/// cada chequeo; `setCover` escribe su binding.
@MainActor
fileprivate func runRelaunchNetVerifyLoop(
    net: String,
    armed: @escaping @MainActor () -> Bool,
    coverDidAppear: @escaping @MainActor () -> Bool,
    setCover: @escaping @MainActor (Bool) -> Void
) -> Task<Void, Never> {
    Task { @MainActor in
        try? await Task.sleep(for: RelaunchNetLogic.initialVerifyDelay)
        var attempt = 0
        while !Task.isCancelled {
            switch RelaunchNetLogic.verdict(
                armed: armed(),
                coverDidAppear: coverDidAppear(),
                attempt: attempt
            ) {
            case .standDown, .satisfied:
                return
            case .exhausted:
                CloudSyncBreadcrumb.relaunchNetExhausted(net: net)
                MetricsService.canary(.relaunchNetExhausted, detail: net)
                return
            case .retry:
                // Cede un runloop y re-chequea antes de togglar: el onAppear del cover
                // pudo encolarse justo antes del verdict (presentación aceptada a ~ms del
                // deadline) — jamás tumbar un cover recién vivo.
                await Task.yield()
                guard !Task.isCancelled, !coverDidAppear() else { return }
                attempt += 1
                CloudSyncBreadcrumb.relaunchNetRetried(net: net, attempt: attempt)
                setCover(false)
                try? await Task.sleep(for: RelaunchNetLogic.toggleGap)
                guard !Task.isCancelled else { return }
                setCover(true)
                try? await Task.sleep(for: RelaunchNetLogic.retryInterval)
            }
        }
    }
}

// MARK: - Helpers (file-private SSOT)

/// Los dos efectos de "primera vez" —oferta de prueba y marcador del checklist— aplicados según
/// CÓMO se entró (`EntryOnboardingEffects`, que es donde vive el criterio y sus tests).
fileprivate func applyEntryOnboardingEffects(_ kind: AppEntryKind) {
    if EntryOnboardingEffects.armsTrialOffer(kind, isProUser: FeatureGateService.shared.isProUser) {
        SessionState.shared.needsPostOnboardingTrial = true
    }
    if EntryOnboardingEffects.marksNewInstall(kind) {
        SetupChecklistManager.shared.markAsNewInstall()
    }
}

/// Side-effect de `WelcomeRestoreView.onCompleteSkipAll` (rama fullyPrefilled) y del arranque del
/// adopt: marca el onboarding como completado.
///
/// **Es una RE-ENTRADA**, así que NO arma la oferta de prueba ni el marcador de instalación nueva
/// (`EntryOnboardingEffects`): sus tres callsites son gente que ya tenía cuenta —restauró de iCloud,
/// era "solo grupos", o está adoptando su cuenta del Modo Nube— y los dos efectos aterrizaban justo
/// en la ventana en la que la app se ve vacía porque sus datos todavía están bajando.
fileprivate func completeOnboardingAsRestoreSkip() {
    applyEntryOnboardingEffects(.reentry)
    // Hasta el 2026-09-12, el CAJÓN de la sesión, por el mismo motivo que su gemelo de `OnboardingView.completeOnboarding`
    // (decisión del owner 2026-09-03): es el MISMO hecho —«esta persona ya no tiene onboarding
    // pendiente»— escrito por el otro camino, el de la restauración. Fuera de sesión secundaria la
    // puerta devuelve `.standard` y esto es byte-idéntico a lo de antes.
    UserDefaults.standard.set(true, forKey: AppPreferences.Keys.hasCompletedOnboarding)
}

/// Binding gate: el flag solo se refleja `true` si `inhibitor == false`.
/// Setear el binding a `false` siempre llega al storage. Centraliza el patrón
/// "auto-cerrar Hero/alert/chooser cuando llega un CKShare" en el flow de
/// onboarding A4 v3.1.
fileprivate extension Binding where Value == Bool {
    func gated(by inhibitor: Bool) -> Binding<Bool> {
        Binding(
            get: { wrappedValue && !inhibitor },
            set: { wrappedValue = $0 }
        )
    }
}

// MARK: - Group Invite Modifier (GC-08)

/// Contenido de la alerta que cierra un tap de enlace de grupo. Nació como un `String?` con el título
/// FIJADO a «Enlace no válido» en la vista, y eso dejaba de valer en cuanto apareció un segundo productor:
/// g13_05 rechaza la entrada a un grupo ARCHIVADO, y ahí el enlace es perfecto —lo que pasa es que el
/// grupo ya no admite gente—. Con el título en la vista, ese caso solo podía mentir o irse a la alerta de
/// «Hubo un problema con el grupo», que también miente: no ha habido ningún problema.
///
/// Por eso título y cuerpo viajan juntos desde el productor. Reusa el MISMO anchor
/// (`activeInviteError`), que es lo que mantiene el aviso dentro de los gates de readiness ya existentes
/// (`hasActiveInviteError`) sin abrir una segunda superficie de presentación que habría que enseñarle al
/// router.
///
/// ⚠️ **NO añadas aquí el texto del BOTÓN.** El copy de archivado trae el suyo
/// (`groups.reconnect.archived.cta`, «Entendido») y el primer intento fue pasarlo por este struct para
/// pintarlo con `Button(activeInviteError?.cta ?? …)`. **Eso rompe la app entera, no solo esta alerta**:
/// con el label del `Button` dependiendo del `@State`, el `actions` builder de `.alert` deja la vista sin
/// alcanzar `idle`, y lo que se rompió al medirlo fue **guardar una transacción** —
/// `TransactionSuccessView` no llegaba a montarse y `QuickActionsFavoritesUITests` se caía a 10 s de
/// espera. Aislado por bisección el 2026-09-06 con control en las dos direcciones: CTA literal pasa (×2),
/// CTA dinámico falla (×4); el TÍTULO dinámico, en cambio, pasa sin problema. El botón se queda en
/// `common.ok`, y lo que se pierde es el matiz «Entendido» vs «Aceptar».
struct InviteAlertContent: Equatable {
    let title: String
    let message: String
}

/// Extracted to a ViewModifier to avoid type-checker complexity in ContentView body.
private struct GroupInviteModifier: ViewModifier {

    @Binding var showGroupInviteOnboarding: Bool
    @Binding var pendingInviteMetadata: InviteLinkService.BrandedMetadata?
    @Binding var pendingInviteZone: String?
    @Binding var hasCompletedOnboarding: Bool
    @Binding var activeInviteError: InviteAlertContent?
    @Binding var activeGroupSyncError: String?

    func body(content: Content) -> some View {
        content
            .alert(
                activeInviteError?.title ?? String(localized: "groups.invite.linkInvalidTitle"),
                isPresented: Binding(
                    get: { activeInviteError != nil },
                    set: { if !$0 { activeInviteError = nil } }
                )
            ) {
                // Literal a propósito — ver el aviso en `InviteAlertContent`. Un label dinámico aquí
                // deja la app sin llegar a `idle` y rompe el guardado de transacciones.
                Button(String(localized: "common.ok"), role: .cancel) {}
            } message: {
                Text(activeInviteError?.message ?? "")
            }
            .alert(
                String(localized: "groups.bridge.alertTitle"),
                isPresented: Binding(
                    get: { activeGroupSyncError != nil },
                    set: { if !$0 { activeGroupSyncError = nil } }
                )
            ) {
                Button(String(localized: "common.ok"), role: .cancel) {}
            } message: {
                Text(activeGroupSyncError ?? "")
            }
            .fullScreenCover(isPresented: $showGroupInviteOnboarding) {
                GroupInviteOnboardingView(
                    inviteMetadata: pendingInviteMetadata,
                    pendingJoinZone: pendingInviteZone
                ) { outcome in
                    // El consumo del invite pendiente según el outcome vivía aquí y su cuerpo llevaba
                    // vacío desde que `PendingInviteStore` —lo único que limpiaba— dejó de existir con el
                    // transporte CloudKit. Un `if` sin cuerpo no es una decisión: es un residuo que se lee
                    // como si algo pasara.
                    //
                    // 2026-09-05 · ahora SÍ hay una decisión que tomar, porque hay un outcome que no
                    // termina en alta: `.declined` es «ahora no», y a quien lo elige no se le marca ningún
                    // onboarding —no ha completado nada— ni se le toca el intent desde aquí (lo retira la
                    // propia vista, que es quien sabe de qué grupo habla). En los demás, el setup ya corrió
                    // (nombre/moneda): no re-onboardear, y el join intent sigue trabajando en background.
                    if outcome != .declined {
                        hasCompletedOnboarding = true
                    }
                    showGroupInviteOnboarding = false
                    pendingInviteMetadata = nil
                    pendingInviteZone = nil
                }
                .environment(SessionState.shared)
            }
    }
}

// MARK: - TabView Principal con Search Role (iOS 18+)

struct MainTabView: View {
    @Bindable private var sessionState: SessionState
    @Environment(\.requestReview) private var requestReview
    @Environment(\.yalaTheme) private var theme
    @Environment(\.modelContext) private var modelContext
    /// D1: leído reactivamente para reducir la tab bar cuando el usuario elige «Solo mis grupos».
    @Environment(AppPreferences.self) private var appPreferences
    @State private var searchText: String = ""
    @AppStorage(TabBarConfiguration.storageKey) private var tabConfigJSON: String = TabBarConfiguration.default.toJSON()
    /// Gate "Grupos necesita iCloud" (§i.8(c)2): singleton observado — leer `status`
    /// (stored) en el branch `.groups` registra la dependencia; `isAccountAvailable`
    /// es computed y @Observable no la trackea. Patrón iCloudSyncSettingsView.
    @State private var syncService = iCloudSyncService.shared

    // On-demand data for downgrade resolution (replaces @Query to prevent 0x8BADF00D)
    @State private var downgradeAccounts: [Account] = []
    @State private var downgradeBudgets: [Budget] = []
    @State private var showDowngradeResolution = false
    @State private var showTrialExpired = false
    /// Milestone number for the upgrade sheet — also drives sheet
    /// presentation (non-nil → shown). Carried by .presentMilestoneUpgrade.
    @State private var activeMilestone: Int?

    private var tabConfig: TabBarConfiguration {
        TabBarConfiguration.fromJSON(tabConfigJSON)
    }

    /// Tabs to show: mode-aware config + temporary tab (if set and not already active)
    private var visibleTabs: [ConfigurableTab] {
        // El eje 1 se lee del espejo OBSERVABLE de `SessionState` y no de la marca persistida: esta
        // propiedad se recalcula cuando SwiftUI observa un cambio, y un point-read no lo provocaría.
        let reduceToGroupsOnly = ShellModeLogic.effective(
            hasPrivateSession: sessionState.hasPrivateSession) == .groupsFocused
        let modeConfig = TabBarConfiguration.forMode(
            stored: tabConfig,
            reduceToGroupsOnly: reduceToGroupsOnly)
        var tabs = modeConfig.activeTabs
        if let temp = sessionState.temporaryTab, !tabs.contains(temp) {
            tabs.append(temp)
        }
        return tabs
    }

    /// iPhone's tab bar shows at most 5 items; anything beyond collapses into
    /// iOS's native "More" controller (stray back chevron + ugly system list).
    /// configurables + More + Search reaches 6 once a temporary tab pushes the
    /// configurable count to 4, so we drop Search there.
    ///
    /// Edge case: navigating *from* Search to a hidden tab sets `temporaryTab`
    /// synchronously while `selectMainTab` defers `selectedMainTab` ~50ms, so the
    /// selection can briefly point at an unmounted Search tab; it self-heals once
    /// `selectedMainTab` lands on the destination. Keeping Search mounted during
    /// that window would push the bar back to 6 items, so the transient is
    /// accepted over re-triggering iOS's native More.
    private var showsSearchTab: Bool {
        visibleTabs.count <= 3
    }

    /// «La app se ve vacía», medido por el shell con el MISMO detector que decide el alert del Welcome
    /// (`checkHasExistingData`). Solo lo consume el banner de hidratación; viaja por el init en vez de
    /// re-contarse aquí porque dos detectores distintos de «hay datos» es como divergen.
    private let storeLooksEmpty: Bool

    init(storeLooksEmpty: Bool = false) {
        self.storeLooksEmpty = storeLooksEmpty
        // Get SessionState from the environment wrapper
        // This is initialized here to work with @Bindable
        _sessionState = Bindable(wrappedValue: SessionState.shared)
    }

    var body: some View {
        // IMPORTANT: When wiping data, completely unmount the TabView to deactivate all @Query observers
        // This prevents crashes from SwiftUI trying to access invalidated model instances
        if sessionState.isWipingData {
            wipingDataView
        } else {
            TabView(selection: $sessionState.selectedMainTab) {
                // Dynamic tabs based on configuration + temporary tab
                ForEach(visibleTabs) { tab in
                    Tab(tab.displayName, systemImage: tab.iconName, value: tab.appTab) {
                        viewForTab(tab)
                    }
                }

                Tab(L10n.Tab.more, systemImage: "ellipsis", value: .more) {
                    MoreView()
                }

                // Search tab with .search role - pinned to trailing edge.
                // Hidden past the 5-item limit while a temporary tab is active.
                if showsSearchTab {
                    Tab(value: .search, role: .search) {
                        GlobalSearchView()
                    }
                }
            }
            .tint(theme.accent)
            .tabBarMinimizeBehavior(.onScrollDown)
            .transaction { $0.animation = nil }
            // Fase real de la hidratación: la invitada (M1) y, desde 2026-08-12, también el dueño que
            // vuelve — tras el relanzamiento del adopt su store nace igual de vacío. `hasExistingData`
            // es el MISMO detector que decide el alert del Welcome; pasárselo evita un segundo contador
            // de «hay datos», que es como divergen.
            .overlay(alignment: .top) {
                CloudHydrationBanner(storeLooksEmpty: storeLooksEmpty)
            }
            .sheet(isPresented: $showDowngradeResolution) {
                DowngradeResolutionSheet(
                    accounts: downgradeAccounts,
                    budgets: downgradeBudgets
                ) {
                    showDowngradeResolution = false
                }
            }
            .sheet(isPresented: $showTrialExpired) {
                UpgradePromptSheet(feature: .voiceInput, context: .trialExpired, source: "trialExpired")
                    // One-shot quemado al PRESENTARSE de verdad (no en el drain):
                    // si el sheet queda tapado por un cover superior, el flag sigue
                    // false y el productor re-emite en el próximo foreground.
                    // En el callsite (no dentro de UpgradePromptSheet: multi-contexto).
                    .onAppear { ProUpsellService.shared.markTrialExpiredSheetShown() }
            }
            .sheet(item: Binding(
                get: { activeMilestone.map(MilestoneIdentifier.init) },
                set: { activeMilestone = $0?.value }
            )) { wrapper in
                MilestoneUpgradeSheet(milestone: wrapper.value)
            }
            .routerConsumer(.mainTab) {
                drainMainTabIntents()
            }
            // Re-drain al liberarse el shell (cerrar un cover superior no bumpea
            // revision — mismo racional que el gate del ChatSheet en PanelShell).
            .onChange(of: sessionState.shellModalBlocker) { _, newBlocker in
                if newBlocker == nil { drainMainTabIntents() }
            }
            .onChange(of: showDowngradeResolution) { _, _ in publishMainTabModalVisibilityAndRedrain() }
            .onChange(of: showTrialExpired) { _, _ in publishMainTabModalVisibilityAndRedrain() }
            .onChange(of: activeMilestone) { _, _ in publishMainTabModalVisibilityAndRedrain() }
        }
    }

    /// True mientras un sheet propio de MainTabView está presentado.
    private var ownModalVisible: Bool {
        showDowngradeResolution || showTrialExpired || activeMilestone != nil
    }

    /// Publica la visibilidad para el guard de `.panel` y la matriz del shell,
    /// y re-drena al cerrar un sheet propio (el siguiente intent retenido entra).
    private func publishMainTabModalVisibilityAndRedrain() {
        if sessionState.isMainTabModalVisible != ownModalVisible {
            sessionState.isMainTabModalVisible = ownModalVisible
        }
        if !ownModalVisible { drainMainTabIntents() }
    }

    /// Drain peek-first de `.mainTab` (Clase D): un intent que presenta un sheet
    /// propio se RETIENE en cola mientras el shell esté tapado o ya haya un
    /// sheet propio arriba — antes se consumía a ciegas y el sheet se seteaba
    /// tapado (one-shots quemados sin verse, presentaciones "que saltan").
    private func drainMainTabIntents() {
        guard let next = AppRouter.shared.peekNext(for: .mainTab) else { return }
        let decision = RouterConsumerGateLogic.mainTabDecision(
            intent: next,
            shellBlocker: sessionState.shellModalBlocker,
            ownModalVisible: ownModalVisible
        )
        guard decision == .drain else {
            // Canario D4: solo los flags PUBLICADOS pueden quedar pegados
            // (shellModalBlocker); ownModalVisible es @State local atado a
            // sheets reales que SwiftUI resetea en el dismiss.
            if let blocker = sessionState.shellModalBlocker {
                RouterHoldCanary.shared.noteHold(intentID: next.id, blocker: blocker, consumer: "mainTab")
            }
            #if DEBUG
            print("MainTabView drain hold: \(next.id) por \(sessionState.shellModalBlocker ?? "ownModal")")
            #endif
            return
        }
        guard let intent = AppRouter.shared.drainNext(for: .mainTab) else { return }
        RouterHoldCanary.shared.noteDrained(intentID: intent.id)
        handleMainTabIntent(intent)
    }

    private func handleMainTabIntent(_ intent: RouterIntent) {
        switch intent {
        case .navigate(let dest):
            // GC-08 guard centralizado en SessionState.selectMainTab — los
            // intents no-groups en modo groupInvite se descartan ahí.
            switch dest {
            case .panel:
                sessionState.selectMainTab(.panel)
            case .statistics:
                sessionState.selectMainTab(.statistics)
            case .records:
                sessionState.selectedDetailTab = .records
                sessionState.selectMainTab(.statistics)
            case .categories:
                sessionState.selectedDetailTab = .categories
                sessionState.selectMainTab(.statistics)
            case .planning:
                sessionState.selectMainTab(.planning)
            case .budgets:
                sessionState.selectedPlanningTab = .budgets
                sessionState.selectMainTab(.planning)
            case .inbox:
                sessionState.selectMainTab(.panel)
                RouterEntryGate.shared.submit(.presentInboxSheet)
            case .scheduledPayments:
                sessionState.selectedPlanningTab = .scheduledPayments
                sessionState.selectMainTab(.planning)
            case .recordsStandalone:
                sessionState.selectMainTab(.records)
            case .groups, .groupDetail:
                sessionState.enteredViaGroupNotification = true
                if case .groupDetail(let groupID) = dest {
                    sessionState.pendingGroupID = groupID
                }
                sessionState.selectMainTab(.groups)
            }
        case .presentDowngradeResolution:
            do {
                let accounts = try modelContext.fetch(FetchDescriptor<Account>())
                let budgets = try modelContext.fetch(
                    FetchDescriptor<Budget>(predicate: #Predicate { $0.isActive })
                )
                let billableAccounts = accounts.billableUserAccounts
                if billableAccounts.count > (ProFeature.accounts.freeLimit ?? Int.max)
                    || budgets.count > (ProFeature.budgets.freeLimit ?? Int.max) {
                    downgradeAccounts = accounts
                    downgradeBudgets = budgets
                    showDowngradeResolution = true
                }
            } catch {
                // No presentar con datos parciales: el productor re-encola en el
                // siguiente cold launch mientras la condición de downgrade persista.
                #if DEBUG
                print("ContentView: fetch downgrade falló: \(error)")
                #endif
            }
        case .presentTrialExpired:
            // El one-shot se quema en el onAppear del sheet, no aquí: .mainTab
            // drena aunque un cover superior lo tape y quemarlo drenado-tapado
            // perdía el aviso de expiración PARA SIEMPRE.
            showTrialExpired = true
        case .presentMilestoneUpgrade(let milestone):
            activeMilestone = milestone
        case .requestAppStoreReview:
            let action = requestReview
            Task {
                try? await Task.sleep(for: .seconds(1))  // UX delay, not sync
                action()
                ReviewPromptService.recordPromptShown()
            }
        default:
            break
        }
    }

    @ViewBuilder
    private func viewForTab(_ tab: ConfigurableTab) -> some View {
        switch tab {
        case .panel:
            PanelShell()
        case .statistics:
            StatisticsView()
        case .planning:
            PlanningView()
        case .records:
            RecordsStandaloneView()
        case .reports:
            FinancialReportView()
        case .groups:
            // `isAccountAvailable` es COMPUTED (@Observable no la trackea); `status` es
            // stored y transiciona vía NSUbiquityIdentityDidChange → leerlo registra la
            // dependencia que re-evalúa este branch cuando la cuenta iCloud cambia.
            let _ = syncService.status
            // El muro «Grupos necesita iCloud» (gate CloudKit-era + `GroupsICloudUnavailableView`) se
            // RETIRÓ aquí, que es el retiro real que su propio comentario prometía «post-G6»: el canal
            // superviviente no exige la cuenta iCloud del OS. La lectura de `syncService.status` de
            // arriba se conserva a propósito — sigue siendo lo que registra la dependencia @Observable
            // de este branch. El gate del código beta «1050» también se retiró (2.1: Grupos abierto
            // para todos), y por eso el tab monta su contenido SIN condición.
            GroupsContainerView()
                // Entrar al tab ES el acto de adopción del dominio: ocupa el hueco que dejó el
                // código beta. Sin este escritor, un dispositivo SELLADO por «empiezo de cero» se
                // queda sin nadie que escriba la key y el bridge le queda cerrado en silencio
                // («mis gastos de grupo no aparecen»). Es idempotente — ver el guard del marker.
                .onAppear { GroupsDomainAdoptionMarker.recordEntry() }
        }
    }

    private var wipingDataView: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: DS.Spacing.xl) {
                ProgressView()
                    .scaleEffect(1.5)

                Text(L10n.Settings.deletingData)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// `.sheet(item:)` requires Identifiable — this wraps Int so milestone
/// presentation binds to `activeMilestone: Int?` directly.
private struct MilestoneIdentifier: Identifiable {
    let value: Int
    var id: Int { value }
}

// MARK: - App Tab Enum

enum AppTab: Hashable {
    case panel
    case statistics
    case planning
    case more
    case search
    case records
    case reports
    case groups
}


#Preview {
    ContentView()
        .modelContainer(
            for: [
                Account.self,
                TransactionItem.self,
                Category.self,
                Subcategory.self,
                Tag.self,
                Budget.self,
                ExchangeRate.self,
            ], inMemory: true)
}
