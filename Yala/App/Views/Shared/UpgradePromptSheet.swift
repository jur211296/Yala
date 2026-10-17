//
//  UpgradePromptSheet.swift
//  Yala
//
//  Sheet prompting user to upgrade to Pro when a feature is blocked.
//

import SwiftUI

// MARK: - Upgrade Context

/// Context in which the upgrade prompt is shown
enum UpgradeContext {
    /// User reached free tier limit (accounts/budgets)
    case limitReached
    /// User tried to use a Pro-only feature (voice, image, icons)
    case proFeature
    /// User's trial has expired
    case trialExpired

    var title: String {
        switch self {
        case .limitReached: return L10n.FeatureGate.limitReachedTitle
        case .proFeature: return L10n.FeatureGate.proFeatureTitle
        case .trialExpired: return L10n.FeatureGate.trialExpiredTitle
        }
    }

    var icon: String {
        switch self {
        case .limitReached: return "exclamationmark.circle.fill"
        case .proFeature: return "lock.fill"
        case .trialExpired: return "clock.badge.exclamationmark.fill"
        }
    }

    /// Si la hoja destaca la función que la abrió. `.trialExpired` no la abre ninguna función.
    var showsFeatureHighlight: Bool {
        switch self {
        case .limitReached, .proFeature: return true
        case .trialExpired: return false
        }
    }

    var iconColor: Color {
        // A11Y-DM: colores decorativos por caso del prompt (sistema, adaptan a Dark Mode)
        switch self {
        case .limitReached: return .orange
        case .proFeature: return .purple
        case .trialExpired: return .red
        }
    }
}

// MARK: - Upgrade Prompt Sheet

struct UpgradePromptSheet: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @Environment(\.yalaTheme) private var theme

    // MARK: - Properties

    let feature: ProFeature
    let context: UpgradeContext
    var source: String = "featureGate"

    // MARK: - State

    @State private var showSubscription = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: DS.Spacing.xxl) {
                Spacer()

                // Hero spark icon
                ZStack {
                    // Glow effect
                    Circle()
                        .fill(Color.orange.opacity(0.2))
                        .frame(width: 120, height: 120)
                        .blur(radius: 20)

                    // Large animated spark
                    YalaSpark(size: .large, animated: true)
                        .scaleEffect(2.5)
                }

                // Title
                Text(context.title)
                    .font(.title2.bold())
                    .foregroundStyle(.thPrimaryText)
                    .multilineTextAlignment(.center)

                // Contextual message
                Text(messageForFeature)
                    .font(DS.Typography.body)
                    .foregroundStyle(.thSecondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Spacing.xl)

                // Feature highlight. Al acabarse la prueba no hay UNA función que destacar: la fila decía
                // «Registro por voz · PRO» a todo el mundo, la usara o no (lote 17 · B6).
                if context.showsFeatureHighlight {
                    featureHighlight
                }

                Spacer()

                // Buttons
                VStack(spacing: DS.Spacing.md) {
                    YalaPrimaryButton(L10n.FeatureGate.upgradeToPro) {
                        showSubscription = true
                    }
                    .accessibilityIdentifier("upgrade_prompt_cta")

                    Button(L10n.Common.cancel) {
                        dismiss()
                    }
                    .font(DS.Typography.body)
                    .foregroundStyle(.thSecondaryText)
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.xxl)
            }
            .yalaScreenBackground(.subtle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showSubscription) {
            NavigationStack {
                SubscriptionView(source: source)
            }
        }
    }

    // MARK: - Subviews

    private var featureHighlight: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: feature.icon)
                .font(DS.Typography.iconMedium)
                .foregroundStyle(.white)
                .frame(width: DS.Icon.badgeMedium, height: DS.Icon.badgeMedium)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.sm)
                        .fill(theme.accent)
                )
                .accessibilityHidden(true)

            Text(feature.localizedName)
                .font(DS.Typography.bodyBold)
                .foregroundStyle(.thPrimaryText)

            Spacer()

            ProBadge(size: .medium)
        }
        .padding(DS.Spacing.lg)
        .background(.thCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
        .padding(.horizontal, DS.Spacing.lg)
        .accessibilityIdentifier("upgrade_prompt_feature_row")
    }

    // MARK: - Helpers

    private var messageForFeature: String {
        switch context {
        case .limitReached:
            return L10n.FeatureGate.limitReachedMessage(feature.localizedName)
        case .proFeature:
            return L10n.FeatureGate.proFeatureMessage(feature.localizedName)
        case .trialExpired:
            return L10n.FeatureGate.trialExpiredMessage
        }
    }
}

// MARK: - Preview

#Preview {
    UpgradePromptSheet(feature: .voiceInput, context: .proFeature)
}
