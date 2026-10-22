//
//  SubscriptionSuccessView.swift
//  Yala
//
//  Celebration view shown after successful Pro subscription.
//

import SwiftUI

struct SubscriptionSuccessView: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.yalaTheme) private var theme

    /// La función de la que venía la compra (UX 2.2 · L17-9): el subtítulo dice «Ya puedes…» con ella, y al tocar
    /// «Comenzar» quien abrió la compra la abre. `nil` desde el paywall.
    var feature: ProFeature?

    // MARK: - State

    @State private var showConfetti = false
    @State private var crownScale: CGFloat = 0
    @State private var featuresOpacity: Double = 0

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background
            theme.background
                .ignoresSafeArea()

            // Confetti overlay
            if showConfetti {
                ConfettiView()
                    .ignoresSafeArea()
            }

            // Content
            VStack(spacing: DS.Spacing.xxl) {
                Spacer()

                // La estrella, sólida y sin halo ni sombra (UX 2.2 · L17-9: la bienvenida pierde el brillo).
                YalaSpark(size: .large, animated: true, solid: true)
                    .scaleEffect(3.0)
                    .frame(height: 100)
                    .scaleEffect(crownScale)
                    .accessibilityHidden(true)

                // Title
                VStack(spacing: DS.Spacing.md) {
                    Text(L10n.Subscription.Success.title)
                        .font(DS.Typography.largeTitle)
                        .foregroundStyle(.thPrimaryText)
                        .multilineTextAlignment(.center)

                    Text(subtitle)
                        .font(DS.Typography.body)
                        .foregroundStyle(.thSecondaryText)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, DS.Spacing.xl)

                // Features unlocked
                unlockedFeaturesList
                    .opacity(featuresOpacity)
                    .padding(.top, DS.Spacing.lg)

                Spacer()

                // Continue button
                YalaPrimaryButton(L10n.Subscription.Success.continueButton) {
                    dismiss()
                }
                .accessibilityIdentifier("subscription_success_continue")
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.xxl)
            }
        }
        .onAppear {
            playEntranceAnimation()
        }
    }

    // MARK: - Subviews

    private var subtitle: String {
        switch feature {
        case .voiceInput: return L10n.UXPro.welcomeVoice
        case .imageInput: return L10n.UXPro.welcomePhoto
        case .smartInsightsAI: return L10n.UXPro.welcomeInsights
        case .chatAssistant: return L10n.UXPro.welcomeChat
        case .accounts: return L10n.UXPro.welcomeAccounts
        case .budgets: return L10n.UXPro.welcomeBudgets
        case .proThemes: return L10n.UXPro.welcomeTheme
        case .premiumIcons: return L10n.UXPro.welcomeIcon
        case .cashFlowAdvanced: return L10n.UXPro.welcomeCashFlow
        case nil: return L10n.Subscription.Success.subtitle
        }
    }

    /// Decisión B de Jürgen (2026-10-21): las mismas fichas de «Qué incluye Pro» que el paywall (`ProIncludedGrid`). La
    /// lista de antes tenía los nombres viejos («Registro por voz ilimitado»…) y decía lo mismo con otras palabras.
    private var unlockedFeaturesList: some View {
        ProIncludedGrid()
            .padding(.horizontal, DS.Spacing.lg)
    }

    // MARK: - Animation

    private func playEntranceAnimation() {
        // Haptic feedback
        DS.Haptic.success()

        // Show confetti
        showConfetti = true

        // Animate crown
        dsWithAnimation(reduceMotion) {
            crownScale = 1.0
        }

        // Fade in features
        dsWithAnimation(reduceMotion) {
            featuresOpacity = 1.0
        }
    }
}

// MARK: - L10n Extension

extension L10n.Subscription {
    enum Success {
        static var title: String {
            NSLocalizedString("subscription.success.title", comment: "Success view title")
        }
        static var subtitle: String {
            NSLocalizedString("subscription.success.subtitle", comment: "Success view subtitle")
        }
        static var continueButton: String {
            NSLocalizedString("subscription.success.continue", comment: "Continue button")
        }
    }

    // Additional feature strings for success view
    static var featureUnlimitedAccounts: String {
        NSLocalizedString("subscription.feature.unlimitedAccounts", comment: "Unlimited accounts feature")
    }
    static var featureUnlimitedBudgets: String {
        NSLocalizedString("subscription.feature.unlimitedBudgets", comment: "Unlimited budgets feature")
    }
    static var featurePremiumIcons: String {
        NSLocalizedString("subscription.feature.premiumIcons", comment: "Premium icons feature")
    }
}

// MARK: - Preview

#Preview {
    SubscriptionSuccessView()
}
