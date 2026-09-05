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
    /// M1: red DURABLE de la VENTANA DE ENTRADA secundaria (descriptor persistido, store del
    /// DUEÑO montado, relaunch pendiente). El cover primario es la fase `.relaunchSecondary`
    /// del welcome; si ese cover muere, este re-presenta (regla toolbar-muerta).
    @State private var showSecondaryEntryRelaunchCover: Bool = false
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
    @State private var showRemoteWipeAlert: Bool = false
    @State private var showICloudRestartAlert: Bool = false
    @State private var showFreshStartWipeAlert: Bool = false
    /// El wipe de «empiezo de cero» LANZÓ (cualquiera de los dos caminos que borran). Blocker de la
    /// matriz de readiness como sus hermanos: mientras esté puesto, nada del router presenta debajo.
    @State private var showFreshStartWipeFailedAlert: Bool = false
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
    /// G4-invites (A2): sheets del flujo backend sign-in → consent → join, drenados de
    /// `.presentGroupsConsent` / `.presentGroupsSignIn`. DARK: con `groupsBackendEnabled`
    /// OFF los intents jamás se submitean.
    @State private var showGroupsConsent: Bool = false
    @State private var showGroupsSignIn: Bool = false
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
    /// C2 · el educativo como PRIMER escalón de las puertas A y B. Blocker propio de la matriz de
    /// readiness, igual que su hermana de arriba y por la misma regla.
    @State private var showGroupsEducational: Bool = false
    /// C2 · lo que la card «Solo grupos» del onboarding ya preguntó (nombre y divisa), **en memoria y sin
    /// persistir**. Esa es la invariante entera del chip: hasta que haya identidad y consent no se escribe
    /// nada, y cuando se escribe va todo junto en `GroupsOrganizerOnboarding.completeSetup`. Que viaje en
    /// un `@State` y no en `UserDefaults` es lo que hace la afirmación comprobable.
    @State private var pendingGroupsOnlyPayload: GroupsOnlyOnboardingPayload?
    @State private var showFullModeActivation: Bool = false
    /// D1: acción elegida en la pantalla de retención; se EJECUTA en el `onDismiss` del cover
    /// (con el cover YA fuera — anti-carrera toolbar-muerta). `nil` = ninguna elegida aún.
    @State private var pendingRetentionAction: RetentionAction?
    /// D1: red visual del cover de retención. Sincronizada desde la condición viva
    /// (`groupsRetentionPending && !isWipingData`) por `syncGroupsRetentionCover()`.
    @State private var showGroupsRetentionCover: Bool = false
    /// Inbox alert payload, driven by .contentView drain of .showInboxAlert.
    @State private var activeInboxNotification: PendingInboxNotification = .init()
    /// Invite error detail, carried by .showInviteError intent.
    @State private var activeInviteError: String?
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
            // Data wipe path: invalida summary stale + respeta el flag del chooser.
            // `performLocalWipeForRemoteSync` resetea `hasShownWelcomeChooser=false` cuando
            // el wipe requiere re-onboarding completo, así que el chooser vuelve a presentarse.
            if !newValue {
                // D1: con retención pendiente (vaciado CON grupos vivos), NO rutear a Welcome —
                // la pantalla de retención decide. Si el usuario elige «Empezar de cero», su
                // onDismiss llama a `presentNextOnboardingScreen()` (mismo cuerpo).
                guard !SessionState.shared.groupsRetentionPending else { return }
                prefilledOnboardingData = nil
                presentNextOnboardingScreen()
            }
        }
        .onChange(of: hasPersonalData) { oldValue, newValue in
            if oldValue && !newValue && hasCompletedOnboarding {
                // Data disappeared — debounce 5s before acting (transient CloudKit gap)
                wipeGraceTask?.cancel()
                wipeGraceTask = Task {
                    do {
                        try await Task.sleep(for: .seconds(5))
                        // Data still gone after 5s — ask user
                        showRemoteWipeAlert = true
                    } catch {
                        // Cancelled — data reappeared
                    }
                }
            } else if !oldValue && newValue {
                // Data reappeared — cancel pending wipe grace
                wipeGraceTask?.cancel()
                wipeGraceTask = nil
            }
        }
    }

    /// Tramo 2: las presentaciones del anchor — covers, sheets y los seis `ViewModifier` del shell.
    private func shellPresentations(_ base: some View) -> some View {
        base
        .modifier(ShellDataAlertsModifier(
            showRemoteWipeAlert: $showRemoteWipeAlert,
            showICloudRestartAlert: $showICloudRestartAlert,
            showFreshStartWipeAlert: $showFreshStartWipeAlert,
            showFreshStartWipeFailedAlert: $showFreshStartWipeFailedAlert,
            hasCompletedOnboarding: $hasCompletedOnboarding,
            hasExistingData: $hasExistingData,
            hasPersonalData: $hasPersonalData,
            showWelcomeFlow: $showWelcomeFlow,
            showOnboarding: $showOnboarding,
            welcomeFlowInitialStep: $welcomeFlowInitialStep,
            onCancelWipeGrace: { wipeGraceTask?.cancel(); wipeGraceTask = nil }
        ))
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
            prefilledOnboardingData: $prefilledOnboardingData,
            hasShownWelcomeChooser: $hasShownWelcomeChooser,
            hasCompletedOnboarding: $hasCompletedOnboarding,
            showFreshStartWipeAlert: $showFreshStartWipeAlert,
            groupsOrganizerFlowActive: $groupsOrganizerFlowActive,
            hasExistingData: hasExistingData,
            hasLocalDataNow: { checkHasExistingData() },
            showGroupInviteOnboarding: showGroupInviteOnboarding
        ))
        .modifier(SignOutRelaunchNetModifier(
            showRelaunchCover: $showSignOutRelaunchCover
        ))
        .modifier(SecondaryEntryRelaunchNetModifier(
            showRelaunchCover: $showSecondaryEntryRelaunchCover,
            welcomeCloudCoverVisible: showWelcomeCloudSignIn
        ))
        .modifier(ForceUpdateNetModifier(
            showCover: $showForceUpdateCover
        ))
        .modifier(GroupsBackendInviteModifier(
            showGroupsConsent: $showGroupsConsent,
            showGroupsSignIn: $showGroupsSignIn,
            showGroupsEducational: $showGroupsEducational,
            pendingGroupsJoinZone: $pendingGroupsJoinZone,
            groupsOrganizerFlowActive: $groupsOrganizerFlowActive,
            pendingGroupsOnlyPayload: $pendingGroupsOnlyPayload,
            onGroupsOrganizerCancelled: { returnToGroupsChooser() }
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
            FullModeActivationView {
                showFullModeActivation = false
            }
            .environment(SessionState.shared)
        }
        // D1: pantalla de retención tras «Vaciar mis datos» CON grupos vivos. DUEÑO ÚNICO = ContentView.
        // @State `showGroupsRetentionCover` = red visual (patrón showSignOutRelaunchCover); la CONDICIÓN VIVA
        // es `groupsRetentionPending && !isWipingData`, sincronizada por `syncGroupsRetentionCover()` desde los
        // onChange de ambos flags (un Binding(get:) computado sobre el singleton NO re-evalúa la presentación).
        // La acción de cada botón se difiere al `onDismiss` (cover YA fuera — anti-carrera toolbar-muerta).
        .fullScreenCover(isPresented: $showGroupsRetentionCover, onDismiss: {
            // capture-all → reset-all → act (molde UserDataResetView:122-144).
            let action = pendingRetentionAction
            pendingRetentionAction = nil
            switch action {
            case .groupsOnly:
                // `usageFocus` ya es `.groupsOnly` (escrito en el botón). Navega a Grupos y monta
                // MainTabView (reducida). selectMainTab primero (usa effectiveShellMode), luego montar.
                SessionState.shared.selectMainTab(.groups)
                hasCompletedOnboarding = true
            case .startFresh:
                // `usageFocus` ya es `.full`. Rutea a Welcome/onboarding = comportamiento actual exacto
                // (mismo cuerpo que el onChange(hasCompletedOnboarding) gateado durante la retención).
                prefilledOnboardingData = nil
                presentNextOnboardingScreen()
            case nil:
                // Teardown EXTERNO (UIKit tumbó el cover sin elección del usuario). Re-arma desde la
                // condición viva: si la retención sigue pendiente, re-presenta en el próximo runloop
                // (molde RelaunchNet) — evita el blocker `groupsRetention` colgado sin cover visible.
                syncGroupsRetentionCover()
            }
        }) {
            GroupsRetentionView(
                hasDebt: SessionState.shared.groupsRetentionHasDebt,
                onGroupsOnly: {
                    pendingRetentionAction = .groupsOnly
                    SessionState.shared.groupsRetentionPending = false
                },
                onStartFresh: {
                    pendingRetentionAction = .startFresh
                    SessionState.shared.groupsRetentionPending = false
                })
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
            // D1: recoge un `groupsRetentionPending` armado ANTES de que ContentView observara
            // (p.ej. el seam de uitest o un re-arranque); los onChange cubren el cambio in-sesión.
            syncGroupsRetentionCover()
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
                // D1: recuperación warm-foreground del cover de retención (si un teardown externo lo
                // tumbó con la retención aún pendiente). Idempotente; no-op sin retención pendiente.
                syncGroupsRetentionCover()
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
            syncGroupsRetentionCover()  // el cover se presenta cuando el wipe termina (!isWipingData)
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
        // D1: la retención es blocker de la matriz + condición viva de la red visual del cover.
        .onChange(of: SessionState.shared.groupsRetentionPending) { _, _ in
            updateContentViewReadiness()
            syncGroupsRetentionCover()
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
            // M1: la condición viva (statics) ES el blocker; el @State del cover es la red visual.
            secondaryEntryRelaunch: showSecondaryEntryRelaunchCover
                || (SecondarySessionStore.isActive() && !SwiftDataConfiguration.secondaryStoreMounted),
            showFreshStartWipeAlert: showFreshStartWipeAlert,
            showFreshStartWipeFailedAlert: showFreshStartWipeFailedAlert,
            showRemoteWipeAlert: showRemoteWipeAlert,
            showICloudRestartAlert: showICloudRestartAlert,
            hasActiveInviteError: activeInviteError != nil,
            hasActiveGroupSyncError: activeGroupSyncError != nil,
            activeInboxNotification: activeInboxNotification,
            showGroupInviteOnboarding: showGroupInviteOnboarding,
            showGroupsConsent: showGroupsConsent,
            showGroupsSignIn: showGroupsSignIn,
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
                // Destino por onboardingMode restaurado (synced) — RestoreRouter.
                let destination = RestoreRouter.decide(
                    onboardingMode: OnboardingMode.current(),
                    isFullyPrefilled: summary.isFullyPrefilled
                )
                RestoreBreadcrumb.destination(String(describing: destination))
                MetricsService.canary(.iCloudRestoreOutcome, detail: String(describing: destination))
                switch destination {
                case .groupsOnly:
                    // El usuario era "solo grupos": no forzar onboarding personal.
                    OnboardingMode.setCurrent(.groupInvite)
                    SessionState.shared.onboardingMode = .groupInvite
                    completeOnboardingAsRestoreSkip()
                    hasCompletedOnboarding = true
                    reEmitInviteAfterRestore()
                case .directToApp:
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
                // A4 v3.2 (#9b): clean slate también desde WelcomeRestoreView.
                // Cubre paths .notFound/.error/.iCloudDisabled → "Empezar
                // configuración" + confirmation dialog desde state .found.
                OnboardingResetHelper.clearResidualPreferencesForFreshStart()
                prefilledOnboardingData = nil
                showWelcomeRestore = false
                showOnboarding = true
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
    /// el límite del type-checker: con este `OnboardingView` inline —y su callback de C2— la compilación
    /// muere con «unable to type-check this expression in reasonable time». Es el mismo motivo por el que
    /// la mitad de las presentaciones de esta vista viven en `ViewModifier`s separados.
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
            },
            // C2 · la card «Solo grupos» no completa aquí: cede a la cadena sin escribir nada.
            onGroupsOnlyComplete: { startGroupsOnlyBranch(payload: $0) }
        ) {
            // Set flag BEFORE dismiss — onChange picks it up reliably
            if !FeatureGateService.shared.isProUser {
                SessionState.shared.needsPostOnboardingTrial = true
            }
            hasCompletedOnboarding = true
            SetupChecklistManager.shared.markAsNewInstall()
            showOnboarding = false
            prefilledOnboardingData = nil
            reEmitInviteAfterRestore()
        }
        .environment(SessionState.shared)
    }

    /// C2 · la card «Solo grupos» del onboarding entra en la MISMA cadena que la rama organizador del
    /// Welcome, con el nombre y la divisa que ya preguntó viajando **en memoria**.
    ///
    /// **Lo que este método NO hace es la mitad del chip:** no escribe `hasCompletedOnboarding`, ni
    /// `onboardingMode`, ni `groupsBetaUnlocked`, ni la divisa. Todo eso lo escribía
    /// `OnboardingView.completeGroupsOnlyOnboarding` —ya eliminado— aquí mismo y sin cuenta; ahora se
    /// escribe junto y al final, en `GroupsOrganizerOnboarding.completeSetup`.
    ///
    /// `hasShownWelcomeChooser` tampoco se marca, igual que en `onSelectGroupsOrganizer` y por lo mismo:
    /// esta rama todavía no ha escrito nada, así que un abandono a mitad tiene que poder reintentarlo en
    /// vez de caer al onboarding completo.
    @MainActor
    private func startGroupsOnlyBranch(payload: GroupsOnlyOnboardingPayload) {
        pendingGroupsOnlyPayload = payload
        showOnboarding = false
        prefilledOnboardingData = nil
        // Mismo par que `WelcomeFlowModifier.startGroupsOrganizerBranch` (que vive allí porque su productor
        // es el chooser): encender el discriminador y SUBMITEAR, sin presentar nada a pelo — el gate ve el
        // cover del onboarding todavía bajando y no drena hasta que se vaya. Presentar en esta misma vuelta
        // es la carrera clásica de dos presentaciones sobre el mismo anchor.
        groupsOrganizerFlowActive = true
        RouterEntryGate.shared.submit(.presentGroupsOrganizerStep)
    }

    /// G3 · devuelve al organizador al step de los dos caminos. Es la salida de todo abandono de la rama
    /// (cancelar el educativo, el sign-in, el consent o el cover del nombre): el usuario ya salió del
    /// Welcome y debajo no hay shell —su alta no ha corrido—, así que dejarlo ahí sería el camino muerto
    /// que el chip prohíbe. Va al `.groupsChooser` y no al `.chooser` porque es donde estaba, y porque
    /// desde ahí puede reintentar o irse a la otra vía sin volver a recorrer el Hero.
    @MainActor
    private func returnToGroupsChooser() {
        // C2 · choke-point de TODA cancelación de la cadena (educativo, sign-in, consent y el cover del
        // nombre pasan por aquí), así que es el sitio donde el payload de la card «Solo grupos» se descarta
        // — un payload superviviente haría que el siguiente intento saltara la pantalla del nombre con
        // datos de una sesión abandonada. Y para la card B esta salida es además la que evita la pantalla
        // muerta: el onboarding de 8 pasos ya se cerró, así que el chooser de Grupos es el sitio vivo más
        // cercano desde el que reintentar o irse por la otra vía.
        pendingGroupsOnlyPayload = nil
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
            groupsRetentionPending: SessionState.shared.groupsRetentionPending,
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
            // M1: la condición viva (statics) ES el blocker; el @State del cover es la red visual.
            secondaryEntryRelaunch: showSecondaryEntryRelaunchCover
                || (SecondarySessionStore.isActive() && !SwiftDataConfiguration.secondaryStoreMounted),
            showFreshStartWipeAlert: showFreshStartWipeAlert,
            showFreshStartWipeFailedAlert: showFreshStartWipeFailedAlert,
            showRemoteWipeAlert: showRemoteWipeAlert,
            showICloudRestartAlert: showICloudRestartAlert,
            hasActiveInviteError: activeInviteError != nil,
            hasActiveGroupSyncError: activeGroupSyncError != nil,
            hasActiveInboxAlert: !activeInboxNotification.isEmpty,
            showGroupInviteOnboarding: showGroupInviteOnboarding,
            showGroupsConsent: showGroupsConsent,
            showGroupsSignIn: showGroupsSignIn,
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
        case .showInviteError(let detail):
            activeInviteError = detail
        case .showGroupSyncError(let message):
            activeGroupSyncError = message
        case .iCloudMismatch:
            showICloudRestartAlert = true
        case .remoteWipe(let skipOnboarding):
            handleRemoteWipeSignal(onboardingAlreadyDone: skipOnboarding)
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
        case .presentGroupBackendInviteOnboarding(let zone):
            // Condición viva al drenar (regla del repo): el intent pudo quedar retenido bajo
            // un cover; si el onboarding YA se completó mientras tanto, no re-presentar —
            // continuar el flujo directo (join).
            if !hasCompletedOnboarding {
                // La marca sale del intent PERSISTIDO, no del payload: es lo que hace que también la
                // tenga el invitado que llegó desde la web con la app cerrada, que es el caso normal.
                // Antes esta línea era `= nil` con el comentario «backend: sin CKShare metadata — visual
                // genérico»: cierto entonces (el tipo exigía un `CKShare.Metadata` que el canal backend
                // no tiene) y por eso el nombre del grupo no llegaba nunca. `nil` sigue siendo el
                // fallback correcto — un enlace sin cosméticos pinta el visual genérico.
                pendingInviteMetadata = PendingJoinStore.entry(zoneName: zone)?.branded
                showGroupInviteOnboarding = true
            } else {
                Task { @MainActor in
                    await GroupBackendInviteEntryHandler.continueFlow(zoneName: zone)
                }
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

        // C3 · **la rama entera no existe en sesión secundaria, y este es el único sitio por el que pasan
        // sus DOS puertas.** La del Welcome (`WelcomeGroupsGateView`) ya lo comprueba por su cuenta; la de
        // la card «Solo grupos» del onboarding NO pasa por esa puerta —`startGroupsOnlyBranch` enciende el
        // discriminador y submitea directo— y su camino SÍ existe con un descriptor vivo: la invitada entra
        // con el onboarding ya marcado, pero un borrado de datos en sesión lo reabre. Sin esto, el alta
        // escribiría sus seis preferencias en el `UserDefaults.standard` del DUEÑO.
        //
        // Se manda a la PUERTA en vez de inventar aquí una superficie de bloqueo: es la que ya sabe pintar
        // este veredicto, y así el usuario recibe la misma respuesta honesta viniendo por donde venga —un
        // `return` mudo le dejaría un botón que no hace nada, que es el «camino muerto» que el spec prohíbe.
        if SecondarySessionStore.isActive() {
            groupsOrganizerFlowActive = false
            pendingGroupsOnlyPayload = nil
            showOnboarding = false
            welcomeFlowInitialStep = .groupsGate
            showWelcomeFlow = true
            return
        }
        switch GroupsOrganizerFlowLogic.nextStep(
            // C2 · el PRIMER escalón. La señal es la misma que usa el tab (`GroupsOnboardingLogic`), con su
            // término legacy incluido: quien completó su alta en modo Grupos antes de C2 ya vio el suyo.
            hasSeenEducational: GroupsOnboardingLogic.hasSeenAnyGroupsEducational(
                hasShownOnboarding: appPreferences.hasShownGroupsOnboarding,
                onboardingMode: SessionState.shared.onboardingMode,
                hasCompletedSetup: hasCompletedOnboarding),
            hasSession: CloudAuthService.shared.hasSession,
            isConsented: GroupsConsentState.isAccepted,
            // Se lee del `UserDefaults` y NO del `@AppStorage` a propósito: cuando la card B escribe el trío
            // unas líneas más abajo y re-submitea para que la máquina re-decida, el espejo observable puede
            // no haberse refrescado todavía (se actualiza por notificación) y la cadena volvería a
            // `.presentName` — un alta repetida. El `UserDefaults` es la verdad inmediata.
            // Y es el CAJÓN de esta sesión (decisión del owner 2026-09-03), no `.standard`: quien escribe
            // ese trío unas líneas más abajo es `GroupsOrganizerOnboarding`, que ya va por la puerta
            // (`writer.setLocal` → `PreferenceSyncService.local`). Leerlo de `.standard` preguntaba por la
            // dueña justo después de haber escrito en el cajón de la visita.
            hasCompletedSetup: SessionDefaults.current.bool(forKey: AppPreferences.Keys.hasCompletedOnboarding),
            entry: pendingGroupsOnlyPayload == nil ? .organizer : .onboardingCard
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
            // C2 · la card «Solo grupos» ya preguntó nombre y divisa en sus steps 1 y 5, así que aquí no se
            // vuelve a preguntar: se ESCRIBE, que es lo que la invariante pedía —con la identidad y el
            // consent ya en mano, y todo junto—. La rama del Welcome, que no preguntó nada, sí pasa por la
            // pantalla del nombre.
            guard let payload = pendingGroupsOnlyPayload else {
                showGroupsOrganizerName = true
                return
            }
            pendingGroupsOnlyPayload = nil
            GroupsOrganizerOnboarding.completeSetup(
                displayName: payload.displayName,
                context: modelContext,
                explicitCurrencyCode: payload.currencyCode)
            // Re-decidir en vez de encadenar a mano el terminal: es la regla del repo («cada llamada
            // re-evalúa condiciones VIVAS») y evita duplicar aquí lo que ya hace `.presentGroupForm`.
            RouterEntryGate.shared.submit(.presentGroupsOrganizerStep)
        case .presentGroupForm:
            // La rama termina aquí: el form lo abre `GroupsContainerView` al montar el tab (molde de
            // `pendingNewGroupExpense`). Y si el usuario lo cancela, aterriza en el empty state estándar
            // con su CTA «crear grupo» — la red ya existía, por eso el último paso puede ser el form.
            groupsOrganizerFlowActive = false
            SessionState.shared.selectedMainTab = .groups
            SessionState.shared.pendingNewGroupForm = true
        }
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

    private func handleRemoteWipeSignal(onboardingAlreadyDone: Bool) {
        let remoteWipe = NSUbiquitousKeyValueStore.default.double(forKey: "lastWipeTimestamp")
        let decision = RemoteWipeSignalDecider.decide(
            hasCompletedOnboarding: hasCompletedOnboarding,
            isWipingData: SessionState.shared.isWipingData,
            hasRemoteWipeTimestamp: remoteWipe > 0
        )

        if decision.shouldMarkSignalsAsProcessed {
            // A4 v3.2: fresh-install con KV-Store contaminado por install previa.
            // Marcar timestamps localmente para que checkForRemoteWipeSignal no
            // re-postee la notif en próximos launches. Bug #6 P0.
            markRemoteSignalsAsProcessed()
        }

        guard decision.shouldProcess else { return }

        // Cancel the hasExistingData-based wipe grace to avoid double-alert
        wipeGraceTask?.cancel()
        wipeGraceTask = nil
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

    /// Post-checks de returning user: trial pendiente, What's New, language, app update.
    /// Extraído para SSOT — antes vivía inline en `checkInitialSyncState`.
    private func runReturningUserPostChecks() {
        // GC-08: Skip trial/What's New for groupInvite users — they have no context yet
        if !SessionState.shared.isGroupInviteMode {
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
        if needsLanguageSelection {
            showLanguageSelection = true
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
    /// D1: sincroniza la red visual del cover de retención con la condición viva. Presenta cuando la
    /// retención está pendiente Y el wipe terminó (durante el wipe `wipingData` tapa todo). Idempotente.
    @MainActor
    private func syncGroupsRetentionCover() {
        let shouldShow = SessionState.shared.groupsRetentionPending && !SessionState.shared.isWipingData
        if showGroupsRetentionCover != shouldShow {
            showGroupsRetentionCover = shouldShow
        }
    }

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
            case .cloudAccount, .cloudSignIn, .groupsOrganizer:
                // Inalcanzables: `requiresMirror` es `false` para las tres, así que el portal del Welcome
                // nunca las persiste. Si aparecen, la respuesta segura es el recorrido normal — jamás
                // saltar al cover de nube con una sesión que este proceso no ha visto, ni retomar una rama
                // organizador a mitad en un proceso que no ha visto su puerta.
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
    @Binding var prefilledOnboardingData: ICloudAccountSummary?
    @Binding var hasShownWelcomeChooser: Bool
    @Binding var hasCompletedOnboarding: Bool
    @Binding var showFreshStartWipeAlert: Bool
    /// G3: la rama organizador arranca aquí y la conduce `ContentView` desde su drain — este modifier solo
    /// la ENCIENDE, porque es quien tiene el callback del portal.
    @Binding var groupsOrganizerFlowActive: Bool
    let hasExistingData: Bool
    /// S5 del review adversarial: el guard cross-cuenta evalúa datos locales EN el
    /// momento de la decisión (fetch vivo), no el snapshot `hasExistingData` — el
    /// mirror de iCloud puede estar re-importando en background durante el Welcome.
    let hasLocalDataNow: @MainActor @Sendable () -> Bool
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
                        // A26 (§k.2): el faro dice que este Apple ID YA tiene cuenta nube ⇒ este
                        // device es un 2º device (o un reinstall), no un usuario nuevo. Se reusa el
                        // MISMO cover de re-entrada que la card "Ya tengo cuenta"; el provider viene
                        // del faro y se setea EXPLÍCITO (jamás heredar el del intento anterior).
                        // Aquí NO se limpian prefs residuales: no es un fresh start.
                        hasShownWelcomeChooser = true
                        welcomeCloudEntry = .reentry(provider)
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
                        // ocurrir antes de que el onboarding lea nada. El alert de datos existentes que
                        // esa función también monta NO hace falta — el mount neutro exige que no haya
                        // archivo de store, así que en este camino no puede haber datos que confirmar.
                        hasShownWelcomeChooser = true
                        if destination == .privateOnboarding {
                            OnboardingResetHelper.clearResidualPreferencesForFreshStart()
                        }
                        WelcomePendingDestinationStore.set(destination)
                    },
                    hasLocalDataNow: hasLocalDataNow
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
                    // R2: `!showOnboarding` es el término nuevo. El alta born-cloud que NO relanza cierra
                    // este cover y enciende el onboarding en la misma vuelta; sin este término, el respaldo
                    // devolvería al usuario al chooser encima del onboarding que acaba de abrirse — dos
                    // presentaciones ante el mismo anchor, que es la regla (4) de Presentaciones.
                    if !hasCompletedOnboarding && !showGroupInviteOnboarding && !showOnboarding {
                        welcomeFlowInitialStep = .chooser
                        showWelcomeFlow = true
                    }
                }
            ) {
                WelcomeCloudSignInView(
                    entry: welcomeCloudEntry,
                    hasLocalDataNow: hasLocalDataNow,
                    onAdoptStarted: {
                        // TEMPRANO (antes de conducir la máquina): cierra el hazard
                        // kill-mid-adopt → el seed del onboarding jamás corre sobre una
                        // cuenta existente; un kill aterriza en MainTab con la card de
                        // Almacenamiento reflejando el estado real del adopt.
                        completeOnboardingAsRestoreSkip()
                        hasCompletedOnboarding = true
                    },
                    onSecondaryEntryFlagsMarked: {
                        // M1 (D1, decisión owner): flags SÍ, trial NO (la invitada no recibe
                        // la oferta del device del dueño) ni markAsNewInstall (el checklist
                        // es estado device-global del dueño).
                        //
                        // **Y ÉSTA se queda en `.standard` cuando sus vecinas bajaron al cajón**
                        // (2026-09-05), porque es la única que corre en la ventana de ENTRADA: el
                        // descriptor acaba de activarse y el cajón todavía no existe — lo crea y lo
                        // siembra `performSecondaryEntryTasksIfNeeded` en el arranque siguiente,
                        // COPIANDO de aquí (`SessionDefaults.seededDeviceKeys`). Escribirlo en el
                        // cajón lo dejaría fuera de esa herencia y la visita arrancaría en el Welcome
                        // sobre un store secundario vacío, que es el brick que el mount prohíbe.
                        //
                        // Eso vale para la entrada PRIMERA, que es la que importa. En una RE-entrada
                        // in-session —el Welcome se le reabre a la visita tras un «vaciar mis datos»,
                        // y `SecondarySlotOccupancyLogic` deja pasar a la MISMA cuenta— la raíz ya se
                        // montó con descriptor, así que la línea de abajo va al cajón y ésta al dueño.
                        // Ahí ya no hereda nadie (el sentinel de la siembra está puesto) y el `true`
                        // que queda en `.standard` se lo lleva el reset de la salida. Inocuo, pero no
                        // es el caso que este comentario justifica.
                        UserDefaults.standard.set(true, forKey: AppPreferences.Keys.hasCompletedOnboarding)
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
                        // `hasCompletedOnboarding` NO se marca aquí: el onboarding es real y lo marca él.
                        // Por eso `showOnboarding` se enciende EXPLÍCITAMENTE en vez de dejar que el
                        // `onDismiss` decida — su rama de respaldo devuelve al chooser.
                        showWelcomeCloudSignIn = false
                        showOnboarding = true
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
        if hasExistingData {
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

// MARK: - Secondary entry relaunch net (M1, molde C1)

/// Red DURABLE de la VENTANA DE ENTRADA secundaria (descriptor persistido, store del DUEÑO
/// montado): el cover primario es la fase `.relaunchSecondary` DENTRO del welcome cloud cover;
/// si ese cover muere por cualquier vía (con los flags de onboarding ya puestos, el onDismiss
/// del container no reabre nada → la app quedaría usable sobre el store del dueño), este anchor
/// re-presenta el cover terminal. `secondaryEntryRelaunch` es además blocker de la matriz.
/// Mismo hardening de presentación efectiva que `SignOutRelaunchNetModifier` (la ENTRADA M1
/// comparte la suposición refutada en device: "SwiftUI materializa la presentación pendiente
/// al despejarse el anchor" — falso). Triggers propios (statics + señal del welcome cover);
/// lo compartido es la decisión pura (`RelaunchNetLogic`) y el loop (`runRelaunchNetVerifyLoop`).
private struct SecondaryEntryRelaunchNetModifier: ViewModifier {
    @Binding var showRelaunchCover: Bool
    /// El flag del welcome cloud cover — su caída con la ventana armada dispara la red.
    let welcomeCloudCoverVisible: Bool

    /// true SOLO cuando el onAppear del contenido real disparó (única prueba de presentación).
    @State private var coverDidAppear = false
    @State private var verifyTask: Task<Void, Never>?
    @Environment(\.scenePhase) private var scenePhase

    private var isArmedUnmounted: Bool {
        SecondarySessionStore.isActive() && !SwiftDataConfiguration.secondaryStoreMounted
    }

    func body(content: Content) -> some View {
        content
            .onAppear {
                if isArmedUnmounted { arm() }
            }
            .onChange(of: welcomeCloudCoverVisible) { _, visible in
                if !visible && isArmedUnmounted { arm() }
            }
            // Ciclo FRESCO al volver a foreground (cap por-ciclo, no de por vida).
            .onChange(of: scenePhase) { _, newScene in
                if newScene == .active && isArmedUnmounted && !coverDidAppear
                    && !welcomeCloudCoverVisible { arm() }
            }
            // M3 · CUARTO trigger, DEV-only: el descriptor cambió desde el panel DEBUG. Los otros tres
            // esperan a un evento del ciclo de vida, y activar el descriptor no es ninguno — esa ventana
            // (app navegable sobre el store del DUEÑO con la sesión ya armada) es el residual de M1-1.
            .modifier(DevSecondaryDescriptorReevaluation(onSignal: reevaluate))
            .fullScreenCover(
                isPresented: $showRelaunchCover,
                onDismiss: {
                    // Terminal: si UIKit lo tumbara, re-presentar (regla toolbar-muerta).
                    coverDidAppear = false
                    if isArmedUnmounted { arm() }
                }
            ) {
                SignOutRelaunchView()
                    .onAppear {
                        // Presentación REAL confirmada (idempotente). Jamás togglar un cover vivo.
                        coverDidAppear = true
                        verifyTask?.cancel()
                        verifyTask = nil
                    }
            }
    }

    private func arm() {
        showRelaunchCover = true
        // Cancel-before-start: un solo verify loop vivo.
        verifyTask?.cancel()
        verifyTask = runRelaunchNetVerifyLoop(
            net: "secondaryEntry",
            armed: {
                SecondarySessionStore.isActive()
                    && !SwiftDataConfiguration.secondaryStoreMounted
            },
            coverDidAppear: { coverDidAppear },
            setCover: { showRelaunchCover = $0 }
        )
    }

    /// M3 · re-evaluación en los DOS sentidos, que es lo que la hace útil como herramienta de QA: los tres
    /// triggers de arriba solo saben ARMAR, así que limpiar el descriptor desde el panel dejaría el cover
    /// terminal puesto sobre una condición que ya no existe — y el panel que acaba de limpiarlo, detrás.
    /// La condición que decide es la VIVA (statics), nunca un payload de la notificación.
    private func reevaluate() {
        if isArmedUnmounted {
            arm()
        } else {
            verifyTask?.cancel()
            verifyTask = nil
            coverDidAppear = false
            showRelaunchCover = false
        }
    }
}

/// M3 · el cuarto trigger del net secundario, aislado en su propio modifier para que el `#if` no viva en
/// medio del `body` del net —donde una rama `#else` que se comiera un modifier real sería invisible en
/// review— y para que un source-scan pueda afirmar el cableado. En producción esto es `content` y nada más.
private struct DevSecondaryDescriptorReevaluation: ViewModifier {
    let onSignal: () -> Void

    func body(content: Content) -> some View {
        #if DEV_BUILD
        content.onReceive(
            NotificationCenter.default.publisher(for: DevSecondaryDescriptorSignal.didChange)
        ) { _ in
            onSignal()
        }
        #else
        content
        #endif
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

/// Side-effect de `WelcomeRestoreView.onCompleteSkipAll` (rama fullyPrefilled):
/// setea trial pendiente, completion flag y new-install marker.
fileprivate func completeOnboardingAsRestoreSkip() {
    if !FeatureGateService.shared.isProUser {
        SessionState.shared.needsPostOnboardingTrial = true
    }
    // El CAJÓN de esta sesión, por el mismo motivo que su gemelo de `OnboardingView.completeOnboarding`
    // (decisión del owner 2026-09-03): es el MISMO hecho —«esta persona ya no tiene onboarding
    // pendiente»— escrito por el otro camino, el de la restauración. Fuera de sesión secundaria la
    // puerta devuelve `.standard` y esto es byte-idéntico a lo de antes.
    SessionDefaults.current.set(true, forKey: AppPreferences.Keys.hasCompletedOnboarding)
    SetupChecklistManager.shared.markAsNewInstall()
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

/// Extracted to a ViewModifier to avoid type-checker complexity in ContentView body.
private struct GroupInviteModifier: ViewModifier {

    @Binding var showGroupInviteOnboarding: Bool
    @Binding var pendingInviteMetadata: InviteLinkService.BrandedMetadata?
    @Binding var hasCompletedOnboarding: Bool
    @Binding var activeInviteError: String?
    @Binding var activeGroupSyncError: String?

    func body(content: Content) -> some View {
        content
            .alert(
                String(localized: "groups.invite.linkInvalidTitle"),
                isPresented: Binding(
                    get: { activeInviteError != nil },
                    set: { if !$0 { activeInviteError = nil } }
                )
            ) {
                Button(String(localized: "common.ok"), role: .cancel) {}
            } message: {
                Text((activeInviteError?.isEmpty ?? true)
                     ? String(localized: "groups.invite.linkInvalidDetail")
                     : (activeInviteError ?? ""))
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
                GroupInviteOnboardingView(inviteMetadata: pendingInviteMetadata) { outcome in
                    // El consumo del invite pendiente según el outcome vivía aquí y su cuerpo llevaba
                    // vacío desde que `PendingInviteStore` —lo único que limpiaba— dejó de existir con el
                    // transporte CloudKit. Un `if` sin cuerpo no es una decisión: es un residuo que se lee
                    // como si algo pasara.
                    // El setup silencioso ya corrió (nombre/moneda): no re-onboardear
                    // en ningún outcome; el join intent sigue trabajando en background.
                    hasCompletedOnboarding = true
                    showGroupInviteOnboarding = false
                    pendingInviteMetadata = nil
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
        let secondary = SecondarySessionStore.isActive()
        // D1: reduce a solo-Grupos cuando el usuario eligió «Solo mis grupos» (usageFocus).
        // Se lee `appPreferences.usageFocus` (reactivo) — NO `SessionState.effectiveShellMode`
        // (point-read, no reaccionaría). Byte-idéntico con usageFocus=.full.
        let reduceToGroupsOnly = ShellModeLogic.effective(
            onboardingMode: sessionState.onboardingMode,
            usageFocus: appPreferences.usageFocus) == .groupsFocused
        let modeConfig = TabBarConfiguration.forMode(
            sessionState.onboardingMode, stored: tabConfig, secondarySessionActive: secondary,
            groupsBackendEnabled: CloudSyncFlags.groupsBackendEnabled,
            reduceToGroupsOnly: reduceToGroupsOnly)
        var tabs = modeConfig.activeTabs
        // M1 / D8: el temporaryTab tampoco puede colar `.groups` en secundaria con el canal backend
        // APAGADO (grupos = iCloud del dueño); con el flag ON la invitada ve sus propios grupos ⇒ se permite.
        if let temp = sessionState.temporaryTab, !tabs.contains(temp),
           !(secondary && temp == .groups && !CloudSyncFlags.groupsBackendEnabled) {
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
                SecondaryHydrationBanner(storeLooksEmpty: storeLooksEmpty)
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

/// D1: elección de la pantalla de retención tras vaciar con grupos vivos. La acción se difiere
/// al `onDismiss` del cover (con la pantalla YA fuera — anti-carrera toolbar-muerta).
private enum RetentionAction {
    /// «Solo mis grupos»: navega al tab Grupos y mantiene la app montada (shell reducida).
    case groupsOnly
    /// «Empezar de cero»: ruta a Welcome/onboarding (comportamiento actual exacto).
    case startFresh
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
