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
}

struct WelcomeFlowContainer: View {
    /// Step inicial. Para flujo normal `.hero`; para casos como "back" desde
    /// InviteRecovery (rama C → vuelve al Chooser) se pasa `.chooser`.
    let initialStep: WelcomeFlowStep

    var onSelectBranch: (WelcomeChooserView.Branch) -> Void
    var onLoadMyData: () -> Void

    @State private var step: WelcomeFlowStep = .hero
    @State private var showDetectedDataAlert: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        initialStep: WelcomeFlowStep = .hero,
        onSelectBranch: @escaping (WelcomeChooserView.Branch) -> Void,
        onLoadMyData: @escaping () -> Void
    ) {
        self.initialStep = initialStep
        self.onSelectBranch = onSelectBranch
        self.onLoadMyData = onLoadMyData
        self._step = State(initialValue: initialStep)
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
                    onSelect: { branch in onSelectBranch(branch) },
                    onBack: { goTo(.hero) }
                )
                .transition(.opacity)
            }
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

    private func goTo(_ next: WelcomeFlowStep) {
        guard step != next else { return }
        let animation: Animation? = reduceMotion ? nil : .smooth(duration: 0.5, extraBounce: 0.1)
        withAnimation(animation) {
            step = next
        }
    }
}
