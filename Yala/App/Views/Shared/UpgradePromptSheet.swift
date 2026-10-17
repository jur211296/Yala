//
//  UpgradePromptSheet.swift
//  Yala
//
//  Sheet prompting user to upgrade to Pro when a feature is blocked.
//

import StoreKit
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

                // La estrella, sólida y sin halo (UX 2.2 · L4-12: nada de brillos). Conserva su leve movimiento.
                YalaSpark(size: .large, animated: true, solid: true)
                    .scaleEffect(2.5)
                    .frame(width: 120, height: 120)

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

                // Un ejemplo de qué hace la función y cuánto cuesta (UX 2.2 · L4-12): «exclusiva de Yala Pro» no
                // decía qué se gana.
                if context == .proFeature, let example = featureExample {
                    Text(example)
                        .font(DS.Typography.subheadline.italic())
                        .foregroundStyle(.thPrimaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DS.Spacing.xl)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("upgrade_prompt_example")
                }

                // Feature highlight. Al acabarse la prueba no hay UNA función que destacar: la fila decía
                // «Registro por voz · PRO» a todo el mundo, la usara o no (lote 17 · B6).
                if context.showsFeatureHighlight {
                    featureHighlight
                }

                Spacer()

                // Buttons
                VStack(spacing: DS.Spacing.md) {
                    if context == .proFeature, featureExample != nil, let offerLine {
                        Text(offerLine)
                            .font(DS.Typography.caption)
                            .foregroundStyle(.thSecondaryText)
                            .multilineTextAlignment(.center)
                            .accessibilityIdentifier("upgrade_prompt_offer")
                    }

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

    /// Solo voz y foto llevan ejemplo: son las que el lote 4 auditó; el resto de la oferta es del lote de Yala Pro.
    private var featureExample: String? {
        switch feature {
        case .voiceInput: return L10n.FeatureGate.voiceExample
        case .imageInput: return L10n.FeatureGate.imageExample
        default: return nil
        }
    }

    /// «Gratis 7 días, luego S/ 9.90 / mes», o el precio al mes si ya no hay prueba. `nil` hasta que cargan los
    /// productos de la tienda: mejor nada que un precio inventado.
    private var offerLine: String? {
        let store = StoreKitManager.shared
        guard let product = store.monthlyProduct ?? store.yearlyProduct else { return nil }
        let periodLabel = product.id == StoreKitManager.proYearlyID ? L10n.Subscription.perYear : L10n.Subscription.perMonthUnit
        let intro = product.subscription?.introductoryOffer
        if let days = PaywallPricingLogic.promisedTrialDays(
            hasFreeTrialOffer: intro?.paymentMode == .freeTrial,
            periodUnit: intro?.period.unit,
            periodValue: intro?.period.value ?? 0,
            isEligible: store.isIntroOfferEligible
        ) {
            return L10n.Subscription.trialThenPrice("\(days)", product.displayPrice + " " + periodLabel)
        }
        return product.displayPrice + " " + periodLabel
    }

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
