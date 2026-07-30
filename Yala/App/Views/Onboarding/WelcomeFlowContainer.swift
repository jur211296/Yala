//
//  WelcomeFlowContainer.swift
//  Yala
//
//  Contenedor unificado del flow Welcome (Hero + Chooser) bajo un solo
//  `fullScreenCover`. Resuelve el "azul vacío" entre dismiss del Hero y
//  present del Chooser que aparecía con dos covers separados — el background
//  gradient persiste y la transición entre steps es un cross-fade smooth.
//
//  El alert "Detectamos tu cuenta" vive dentro del container (no en el
//  ContentView) para mantener todo el flow Hero+Chooser+alert encapsulado.
//

import SwiftUI

enum WelcomeFlowStep {
    case hero
    case chooser
    /// 2º nivel de "Ya tengo una cuenta" (H4): Restaurar iCloud | Sign in with Apple.
    /// Solo alcanzable con >1 opción visible (bypass en `handleExistingBranch`).
    case existingChooser
}

struct WelcomeFlowContainer: View {
    /// Step inicial. Para flujo normal `.hero`; para casos como "back" desde
    /// InviteRecovery (rama C → vuelve al Chooser) se pasa `.chooser`.
    let initialStep: WelcomeFlowStep

    var onSelectBranch: (WelcomeChooserView.Branch) -> Void
    var onLoadMyData: () -> Void
    /// Sub-elección de "Ya tengo una cuenta" (también el resultado del bypass).
    var onSelectExistingOption: (WelcomeAccountChoiceLogic.ExistingOption) -> Void

    @State private var step: WelcomeFlowStep = .hero
    @State private var showDetectedDataAlert: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        initialStep: WelcomeFlowStep = .hero,
        onSelectBranch: @escaping (WelcomeChooserView.Branch) -> Void,
        onLoadMyData: @escaping () -> Void,
        onSelectExistingOption: @escaping (WelcomeAccountChoiceLogic.ExistingOption) -> Void
    ) {
        self.initialStep = initialStep
        self.onSelectBranch = onSelectBranch
        self.onLoadMyData = onLoadMyData
        self.onSelectExistingOption = onSelectExistingOption
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

    var body: some View {
        ZStack {
            switch step {
            case .hero:
                WelcomeHeroView { decision in
                    handleHeroDecision(decision)
                }
                .transition(.opacity)
            case .chooser:
                WelcomeChooserView(
                    onSelect: { branch in
                        // "Ya tengo una cuenta" abre el 2º nivel (o bypass con 1 opción —
                        // hoy en prod DARK equivale exactamente al flujo restore actual).
                        if branch == .restore {
                            handleExistingBranch()
                        } else {
                            onSelectBranch(branch)
                        }
                    },
                    onBack: { goTo(.hero) }
                )
                .transition(.opacity)
            case .existingChooser:
                WelcomeExistingChooserView(
                    options: visibleExistingOptions,
                    onSelect: { option in onSelectExistingOption(option) },
                    onBack: { goTo(.chooser) }
                )
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
        .alert(
            L10n.Welcome.DetectedData.title,
            isPresented: $showDetectedDataAlert
        ) {
            Button(L10n.Welcome.DetectedData.loadMyData) {
                onLoadMyData()
            }
            Button(L10n.Welcome.DetectedData.startFresh) {
                goTo(.chooser)
            }
            // B-11: Cancel explícito captura el dismiss implícito de iOS (swipe-down,
            // gesture, Escape) que antes dejaba el Hero en estado consumido (`hasTappedEmpezar=true`)
            // sin posibilidad de re-tap. Si el user ignora el aviso, lo llevamos al Chooser
            // donde decidirá entre "Soy nuevo" / "Tengo cuenta".
            Button(L10n.Action.cancel, role: .cancel) {
                goTo(.chooser)
            }
        } message: {
            Text(L10n.Welcome.DetectedData.message)
        }
    }

    private func handleHeroDecision(_ decision: HeroDecision) {
        switch decision {
        case .proceedNoData:
            goTo(.chooser)
        case .proceedWithData:
            showDetectedDataAlert = true
        }
    }

    /// "Ya tengo una cuenta": con una sola opción visible (prod DARK / uitest) hace
    /// bypass directo — comportamiento idéntico al flujo restore de hoy; con ambas,
    /// muestra el 2º nivel.
    private func handleExistingBranch() {
        if let single = WelcomeAccountChoiceLogic.bypass(visibleExistingOptions) {
            onSelectExistingOption(single)
        } else {
            goTo(.existingChooser)
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
