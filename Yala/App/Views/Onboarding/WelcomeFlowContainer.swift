//
//  WelcomeFlowContainer.swift
//  Yala
//
//  Contenedor unificado del flow Welcome (Hero + Chooser) bajo un solo
//  `fullScreenCover`. Resuelve el "azul vacío" entre dismiss del Hero y
//  present del Chooser que aparecía con dos covers separados — el background
//  gradient persiste y la transición entre steps es un cross-fade smooth.
//
//  **El Hero desemboca SIEMPRE en el chooser** (decisión del owner 2026-08-11,
//  punto 2 de MODO-NUBE-REVISION-FLUJOS-NOTAS): aquí vivía el alert "Detectamos
//  tu cuenta", que empujaba hacia la cuenta iCloud del container a quien podía
//  tener su cuenta en la nube. La reentrada la elige el usuario en
//  "Ya tengo una cuenta", que ofrece las tres vías.
//

import SwiftUI

enum WelcomeFlowStep {
    case hero
    case chooser
    /// 2º nivel de "Ya tengo una cuenta" (H4): Restaurar iCloud | Sign in with Apple.
    /// Solo alcanzable con >1 opción visible (bypass en `handleExistingBranch`).
    case existingChooser
    /// 2º nivel de "Soy nuevo" (A4 de D-A7, §k.2): privacidad total (iCloud) | cuenta en la nube.
    /// Solo alcanzable con >1 opción visible (bypass en `handleNewBranch`).
    case newChooser
    /// G2 · 2º nivel de «Vengo por un grupo»: los dos caminos con los que se empieza un grupo —crearlo o
    /// entrar con la invitación—. La rama `.invite` del chooser deja de salir por el portal para venir
    /// aquí; el que ya tiene enlace sale por el MISMO `Destination .inviteRecovery` desde la card.
    case groupsChooser
    /// G3 · la PUERTA de la rama organizador: re-mide el canal de Grupos con `force` y comprueba que el
    /// device no tenga datos de otro humano. Es un step y no un alert porque el source-scan de W1 prohíbe
    /// `.alert(` en este fichero, y porque una pantalla de bloqueo con salida no es un camino muerto.
    /// **Nada se escribe hasta que esta puerta dice que sí.**
    case groupsGate
    /// R2 · TERMINAL: este proceso montó el store NEUTRO y el destino elegido necesita el mirror de
    /// CloudKit ⇒ hay que reabrir la app. Vive DENTRO de este cover a propósito: un cover propio sería una
    /// presentación nueva colgando del anchor de `ContentView` (matriz de readiness, regla (3) de
    /// Presentaciones) para enseñar dos párrafos; aquí es un step más del contenedor que ya está montado.
    case mirrorRelaunch
}

struct WelcomeFlowContainer: View {
    /// Step inicial. Para flujo normal `.hero`; para casos como "back" desde
    /// InviteRecovery (rama C → vuelve al Chooser) se pasa `.chooser`.
    let initialStep: WelcomeFlowStep

    var onSelectBranch: (WelcomeChooserView.Branch) -> Void
    /// Sub-elección de "Ya tengo una cuenta" (también el resultado del bypass).
    var onSelectExistingOption: (WelcomeAccountChoiceLogic.ExistingOption) -> Void
    /// "Soy nuevo" con la opción PRIVADA elegida (también el resultado del bypass, que es el
    /// recorrido de producción de hoy).
    var onSelectPrivateAccount: () -> Void
    /// A5: "Soy nuevo" con la opción NUBE elegida ⇒ alta born-cloud (consent → sign-in → claim →
    /// par → relanzamiento). El destino es el MISMO cover que la re-entrada, con `Entry.bornCloud`.
    var onSelectCloudAccount: () -> Void
    /// A26 (§k.2): el faro de iCloud-KV dice que este Apple ID YA tiene cuenta nube ⇒ el Welcome
    /// NO ofrece la elección y encamina al returning-user con el provider del propio faro.
    var onBeaconRoutesToCloudSignIn: (CloudSignInProvider) -> Void
    /// G3: «Crear mi primer grupo» con la puerta ya CONFIRMADA abierta (canal encendido y sin datos de
    /// otro humano en el device). El container no comprueba nada aquí: eso es del step `.groupsGate`, que
    /// es el único que puede llamarlo.
    var onSelectGroupsOrganizer: () -> Void
    /// R2: el destino elegido necesita el mirror y este proceso montó neutro ⇒ el container va a su step
    /// terminal y ContentView PERSISTE el destino para retomarlo tras el relanzamiento. Se separa en dos
    /// responsabilidades porque el container no debe tocar `UserDefaults` ni los flags de onboarding.
    var onNeedsMirrorRelaunch: (WelcomeMirrorRelaunchLogic.Destination) -> Void
    /// G3: fetch VIVO del corpus local para la puerta (mismo closure que alimenta el guard cross-cuenta
    /// del sign-in de nube — un snapshot no vale, el mirror puede estar re-importando).
    var hasLocalDataNow: @MainActor @Sendable () -> Bool

    @State private var step: WelcomeFlowStep = .hero

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        initialStep: WelcomeFlowStep = .hero,
        onSelectBranch: @escaping (WelcomeChooserView.Branch) -> Void,
        onSelectExistingOption: @escaping (WelcomeAccountChoiceLogic.ExistingOption) -> Void,
        onSelectPrivateAccount: @escaping () -> Void,
        onSelectCloudAccount: @escaping () -> Void,
        onSelectGroupsOrganizer: @escaping () -> Void,
        onBeaconRoutesToCloudSignIn: @escaping (CloudSignInProvider) -> Void,
        onNeedsMirrorRelaunch: @escaping (WelcomeMirrorRelaunchLogic.Destination) -> Void,
        hasLocalDataNow: @escaping @MainActor @Sendable () -> Bool
    ) {
        self.initialStep = initialStep
        self.onSelectBranch = onSelectBranch
        self.onSelectExistingOption = onSelectExistingOption
        self.onSelectPrivateAccount = onSelectPrivateAccount
        self.onSelectCloudAccount = onSelectCloudAccount
        self.onBeaconRoutesToCloudSignIn = onBeaconRoutesToCloudSignIn
        self.onSelectGroupsOrganizer = onSelectGroupsOrganizer
        self.onNeedsMirrorRelaunch = onNeedsMirrorRelaunch
        self.hasLocalDataNow = hasLocalDataNow
        self._step = State(initialValue: initialStep)
    }

    private var visibleExistingOptions: [WelcomeAccountChoiceLogic.ExistingOption] {
        // `-uitest-cloud-chooser` (opt-in EXPLÍCITO, sesión 2): destapa las cards cloud bajo
        // uitest SOLO para el XCUITest del chooser — el resto de uitest queda byte-idéntico
        // (bypass a restore intacto). `remoteCloudEnabled` (DIFERIDOS #34): kill-switch de la
        // ENTRADA; bajo uitest/DEV sin fetch el default es ON (byte-idéntico), y si el fetch
        // aterriza con la vista abierta se lee en el siguiente render (sin live-update — asumido).
        WelcomeAccountChoiceLogic.visibleExistingOptions(
            isConfigured: CloudBackendConfig.isConfigured,
            isUITest: SwiftDataConfiguration.isUITesting && !UITestHooks.forceCloudChooser,
            remoteCloudEnabled: CloudRemoteFlags.cloudModeEnabled)
    }

    /// A4: espejo EXACTO de los argumentos del existing (mismo opt-in de uitest, mismo kill-switch)
    /// más los dos términos propios del born-cloud: la constante COMPILADA (hoy `true`) y el
    /// sub-flag remoto de la elección, que es el que sirve `"0"` en producción.
    private var visibleNewOptions: [WelcomeAccountChoiceLogic.NewOption] {
        WelcomeAccountChoiceLogic.visibleNewOptions(
            isConfigured: CloudBackendConfig.isConfigured,
            isUITest: SwiftDataConfiguration.isUITesting && !UITestHooks.forceCloudChooser,
            bornCloudEnabled: CloudSyncFlags.bornCloudChoiceEnabled,
            remoteCloudEnabled: CloudRemoteFlags.cloudModeEnabled,
            remoteOnboardingChoiceEnabled: CloudRemoteFlags.cloudOnboardingChoiceEnabled)
    }

    /// El encaminamiento por faro (A26) va a la MISMA pantalla que la card `.cloudSignIn` del
    /// sub-chooser de "Ya tengo cuenta" ⇒ su disponibilidad se DERIVA de ahí en vez de re-escribir
    /// los tres términos, que es como dos gates que deberían coincidir empiezan a divergir.
    private var cloudEntryAvailable: Bool {
        visibleExistingOptions.contains(.cloudSignIn)
    }

    var body: some View {
        ZStack {
            switch step {
            case .hero:
                WelcomeHeroView {
                    goTo(.chooser)
                }
                .transition(.opacity)
            case .chooser:
                WelcomeChooserView(
                    onSelect: { branch in
                        // "Ya tengo una cuenta" y "Soy nuevo" abren su 2º nivel (o bypass con 1
                        // opción — en producción hoy equivale exactamente al flujo actual).
                        switch branch {
                        case .restore: handleExistingBranch()
                        case .new: handleNewBranch()
                        // G2: la card ya no es «me invitaron» sino «vengo por un grupo», así que no
                        // puede salir directa a la recuperación de invitación — abre el step de los
                        // dos caminos y es ahí donde el invitado elige el suyo.
                        case .invite: goTo(.groupsChooser)
                        }
                    },
                    onBack: { goTo(.hero) }
                )
                .transition(.opacity)
            case .groupsChooser:
                WelcomeGroupsChooserView(
                    // G3: la card de crear ya está cableada y por tanto se pinta. Su handler NO sale del
                    // cover: abre la puerta, que es el step siguiente. El portal se cruza más tarde, y
                    // solo si la puerta abre.
                    onCreate: { goTo(.groupsGate) },
                    onJoin: {
                        leaveWelcome(to: .inviteRecovery) { onSelectBranch(.invite) }
                    },
                    onBack: { goTo(.chooser) }
                )
                .transition(.opacity)
            case .groupsGate:
                WelcomeGroupsGateView(
                    // Re-envuelto en vez de reenviado: pasar la property directa convierte un valor de
                    // función no-Sendable y avisa (`may introduce data races`). El closure nuevo nace ya en
                    // este contexto y no cruza ninguna frontera.
                    hasLocalDataNow: { hasLocalDataNow() },
                    onProceed: {
                        leaveWelcome(to: .groupsOrganizer) { onSelectGroupsOrganizer() }
                    },
                    onBack: { goTo(.groupsChooser) }
                )
                .transition(.opacity)
            case .existingChooser:
                WelcomeExistingChooserView(
                    options: visibleExistingOptions,
                    onSelect: { option in handleExistingOption(option) },
                    onBack: { goTo(.chooser) }
                )
                .transition(.opacity)
            case .newChooser:
                WelcomeNewChooserView(
                    options: visibleNewOptions,
                    onSelect: { option in handleNewOption(option) },
                    onBack: { goTo(.chooser) }
                )
                .transition(.opacity)
            case .mirrorRelaunch:
                WelcomeMirrorRelaunchView()
                    .transition(.opacity)
            }
        }
        .task {
            // DIFERIDOS #34: refresh del remote-config en la ENTRADA (fresh install pre-onboarding
            // puede no tener cache del boot todavía). Min-interval 6 h.
            // Bajo uitest NO se toca red (hermeticidad — los getters ya devuelven el default).
            guard !SwiftDataConfiguration.isUITesting else { return }
            await RemoteConfigClient.shared.refreshIfDue()
        }
    }

    /// **R2 · el único portal de salida del Welcome.** Toda elección que abandona este cover pasa por aquí,
    /// y aquí se decide si antes hay que reabrir la app.
    ///
    /// Está en el CONTAINER y no en los callbacks de `ContentView` por una razón concreta: los destinos se
    /// producen en SEIS sitios (las dos cards del sub-chooser de grupos —«Tengo una invitación» directa y
    /// «Crear mi primer grupo» a través de su puerta—, el sub-chooser existente, el encaminamiento por faro
    /// y las dos cards del sub-chooser nuevo), varios de ellos con bypass, y repartir la comprobación por
    /// los seis es exactamente cómo divergen. Con un portal único, añadir una salida nueva obliga a nombrar
    /// su `Destination`.
    ///
    /// G2 (2026-08-11) movió el primero de nivel: lo producía la card `.invite` del chooser y ahora lo
    /// produce la card de unirse DENTRO del step de grupos. El `Destination` es el MISMO —`.inviteRecovery`,
    /// con su misma fila `requiresMirror`— así que el invitado no pierde nada; lo que cambia es que
    /// `hasShownWelcomeChooser` deja de marcarse al tapear la card de nivel 1, igual que ya pasaba con las
    /// otras dos ramas cuando muestran su 2º nivel.
    ///
    /// G3 (2026-08-11) añadió el sexto, `.groupsOrganizer`, y es el único que pasa por una PUERTA: la card
    /// de crear no llama aquí, va al step `.groupsGate` y es él quien cruza el portal si —y solo si— el
    /// canal está encendido y el device no tiene datos de otro humano.
    ///
    /// Eran SEIS hasta el 2026-08-11 por otra razón: el alert «Detectamos tu cuenta» tenía el suyo
    /// (`.restoreICloud`), y se fue entero con el alert cuando la reentrada pasó a ser decisión del usuario.
    private func leaveWelcome(to destination: WelcomeMirrorRelaunchLogic.Destination,
                              proceed: () -> Void) {
        guard WelcomeMirrorRelaunchLogic.shouldRelaunch(
            destination: destination,
            mountedDecision: SwiftDataConfiguration.personalStoreMountedDecision) else {
            proceed()
            return
        }
        onNeedsMirrorRelaunch(destination)
        goTo(.mirrorRelaunch)
    }

    /// "Ya tengo una cuenta": con una sola opción visible (prod DARK / uitest) hace
    /// bypass directo — comportamiento idéntico al flujo restore de hoy; con ambas,
    /// muestra el 2º nivel.
    private func handleExistingBranch() {
        if let single = WelcomeAccountChoiceLogic.bypass(visibleExistingOptions) {
            handleExistingOption(single)
        } else {
            goTo(.existingChooser)
        }
    }

    /// R2: el sub-chooser de "Ya tengo una cuenta" y su bypass comparten portal. Solo `restoreICloud`
    /// necesita el mirror; las dos entradas a la cuenta nube montan el mismo store que el neutro ya es.
    private func handleExistingOption(_ option: WelcomeAccountChoiceLogic.ExistingOption) {
        let destination: WelcomeMirrorRelaunchLogic.Destination
        switch option {
        case .restoreICloud: destination = .restoreICloud
        case .cloudSignIn, .googleSignIn: destination = .cloudSignIn
        }
        leaveWelcome(to: destination) { onSelectExistingOption(option) }
    }

    /// "Soy nuevo" (A4). **El faro se consulta ANTES de ofrecer nada** (§k.2 / A26) y, por tanto,
    /// antes de que `ContentView` limpie las prefs residuales del fresh-start: ese orden es el
    /// contrato. Medido el 2026-08-09: `OnboardingResetHelper.safeKeysToClear` son SOLO `userName`
    /// y `defaultCurrencyCode`, así que la limpieza no toca las `yala.cloud.*` del faro — no hay
    /// bug ahí, y el orden se respeta igual para que siga sin haberlo.
    ///
    /// Con una sola opción visible NO se muestra pantalla intermedia: en producción (percent
    /// remoto en 0) y bajo uitest el recorrido es byte-idéntico al de hoy.
    private func handleNewBranch() {
        switch WelcomeNewBranchRouter.route(
            beacon: CloudBeacon(),
            cloudEntryAvailable: cloudEntryAvailable,
            options: visibleNewOptions
        ) {
        case .cloudSignIn(let provider):
            leaveWelcome(to: .cloudSignIn) { onBeaconRoutesToCloudSignIn(provider) }
        case .single(let option):
            handleNewOption(option)
        case .chooser:
            goTo(.newChooser)
        }
    }

    private func handleNewOption(_ option: WelcomeAccountChoiceLogic.NewOption) {
        switch option {
        case .privateAccount:
            // R2: **es el bypass de producción** (percent remoto de la elección nube en 0 ⇒ el sub-chooser
            // ni se muestra), así que este es el camino por el que pasa hoy todo usuario nuevo — y el que
            // paga el relanzamiento que el alta nube deja de pagar. Es el reparto que la Opción C aprueba.
            leaveWelcome(to: .privateOnboarding) { onSelectPrivateAccount() }
        case .cloudAccount:
            // A5: el alta born-cloud. El stub explícito de A4 (`showBornCloudPendingAlert`) queda
            // BORRADO en este mismo commit, no silenciado — era una promesa con fecha.
            // R2: pasa por el portal igual que los demás, y sale sin relanzar — que es el chip entero.
            leaveWelcome(to: .cloudAccount) { onSelectCloudAccount() }
        }
    }

    private func goTo(_ next: WelcomeFlowStep) {
        guard step != next else { return }
        let animation: Animation? = reduceMotion ? nil : .smooth(duration: 0.5, extraBounce: 0.1)
        withAnimation(animation) {
            step = next
        }
    }
}
