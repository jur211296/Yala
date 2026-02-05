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

    var iconColor: Color {
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

    // MARK: - Properties

    let feature: ProFeature
    let context: UpgradeContext

    // MARK: - State

    @State private var showSubscription = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: DS.Spacing.xxl) {
                Spacer()

                // Icon
                ZStack {
                    // Glow effect
                    Circle()
                        .fill(context.iconColor.opacity(0.2))
                        .frame(width: 120, height: 120)
                        .blur(radius: 20)

                    Image(systemName: context.icon)
                        .font(.system(size: 56))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.yellow, Color.orange],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }

                // Title
                Text(context.title)
                    .font(.title2.bold())
                    .foregroundStyle(Color.yalaPrimaryText)
                    .multilineTextAlignment(.center)

                // Contextual message
                Text(messageForFeature)
                    .font(.body)
                    .foregroundStyle(Color.yalaSecondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Spacing.xl)

                // Feature highlight
                featureHighlight

                Spacer()

                // Buttons
                VStack(spacing: DS.Spacing.md) {
                    YalaPrimaryButton(L10n.FeatureGate.upgradeToPro) {
                        showSubscription = true
                    }

                    Button(L10n.Common.cancel) {
                        dismiss()
                    }
                    .font(.body)
                    .foregroundStyle(Color.yalaSecondaryText)
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.xxl)
            }
            .background(Color.yalaBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    YalaToolbarButton(systemName: "xmark") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showSubscription) {
            NavigationStack {
                SubscriptionView()
            }
        }
    }

    // MARK: - Subviews

    private var featureHighlight: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: feature.icon)
                .font(.system(size: DS.Icon.sizeMedium, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: DS.Icon.badgeMedium, height: DS.Icon.badgeMedium)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.sm)
                        .fill(Color.brandPrimary)
                )

            Text(feature.localizedName)
                .font(.body.weight(.medium))
                .foregroundStyle(Color.yalaPrimaryText)

            Spacer()

            ProBadge(size: .medium)
        }
        .padding(DS.Spacing.lg)
        .background(Color.yalaCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
        .padding(.horizontal, DS.Spacing.lg)
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
