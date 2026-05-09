//
//  OnboardingFlowScreen.swift
//  Yala
//
//  Wrapper visual del OnboardingView — bifurca el background entre el flow
//  inicial post-Welcome (`.heroFlow`, gradient indigo→negro continuo del
//  WelcomeFlowContainer) y la activación full desde mode `groupsOnly`
//  (`.themedPanel`, PanelBackgroundView que adapta al tema del user).
//
//  Coexiste con `WelcomeFlowScreen` (Hero/Chooser siguen usando su propio
//  wrapper). El logo NO lo dibuja este wrapper — solo expone el `logoTopSpacing`
//  proporcional para que el content (Step 1) lo consuma.
//

import SwiftUI

// MARK: - Background Style

enum OnboardingBackgroundStyle {
    /// Continuidad visual con WelcomeFlowContainer: gradient indigo→negro fijo,
    /// texto blanco rígido. Default para flow inicial fresh-install.
    case heroFlow
    /// Adapta al tema del user (PanelBackgroundView). Usado por
    /// FullModeActivationView donde el user ya tiene tema configurado.
    case themedPanel
}

/// Modo del flow para telemetría. NO afecta layout — eso lo hace `backgroundStyle`.
enum OnboardingFlowMode: String {
    case initial
    case fullActivation
}

// MARK: - Flow Screen Wrapper

struct OnboardingFlowScreen<Content: View>: View {
    let style: OnboardingBackgroundStyle
    @ViewBuilder let content: (_ logoTopSpacing: CGFloat) -> Content

    var body: some View {
        // Gradient/PanelBackgroundView fuera del GeometryReader para que no
        // re-renderice en cada keystroke del TextField interior.
        ZStack {
            background
            GeometryReader { geo in
                content(WelcomeFlowLayout.logoTopSpacing(in: geo))
                    .frame(width: geo.size.width, height: geo.size.height)
            }
        }
    }

    @ViewBuilder
    private var background: some View {
        switch style {
        case .heroFlow:
            LinearGradient(
                colors: DS.Gradients.heroIndigoBlack,
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        case .themedPanel:
            PanelBackgroundView()
        }
    }
}
