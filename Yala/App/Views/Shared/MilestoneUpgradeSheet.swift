//
//  MilestoneUpgradeSheet.swift
//  Yala
//
//  Celebratory sheet shown at transaction count milestones for Free users.
//

import SwiftUI

struct MilestoneUpgradeSheet: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @Environment(\.yalaTheme) private var theme

    // MARK: - Properties

    let milestone: Int

    // MARK: - State

    @State private var showSubscription = false
    @State private var animateNumber = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: DS.Spacing.xxl) {
                Spacer()

                // Hero milestone number
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 140, height: 140)
                        .blur(radius: 10)

                    Text("\(milestone)")
                        .font(.system(size: 64, weight: .bold, design: .rounded)) // A11Y-DT: decorative milestone number, fixed layout
                        .foregroundStyle(
                            LinearGradient(
                                colors: DS.Gradients.proBadge,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(animateNumber ? 1.0 : 0.5)
                        .opacity(animateNumber ? 1.0 : 0)
                }
                .onAppear {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                        animateNumber = true
                    }
                }

                // Title
                Text(L10n.Milestone.title(milestone))
                    .font(.title2.bold())
                    .foregroundStyle(.thPrimaryText)
                    .multilineTextAlignment(.center)

                // Contextual message
                Text(milestoneMessage)
                    .font(DS.Typography.body)
                    .foregroundStyle(.thSecondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Spacing.xl)

                // Features highlight
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    featureRow(icon: "waveform.badge.mic", text: L10n.Subscription.featureVoice, color: .hotPink)
                    featureRow(icon: "sparkles", text: L10n.FeatureGate.smartInsightsAI, color: .purple)
                    featureRow(icon: "building.columns.fill", text: L10n.Milestone.unlimitedAccounts, color: .blue)
                }
                .padding(DS.Spacing.lg)
                .background(.thCard)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                        .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                )
                .padding(.horizontal, DS.Spacing.lg)

                Spacer()

                // Buttons
                VStack(spacing: DS.Spacing.md) {
                    YalaPrimaryButton(L10n.FeatureGate.upgradeToPro) {
                        TelemetryService.track(.proUpsellTapped, parameters: TelemetryService.upsellParameters(source: "milestone"))
                        showSubscription = true
                    }

                    Button(L10n.Milestone.notNow) {
                        TelemetryService.track(.proUpsellDismissed, parameters: TelemetryService.upsellParameters(source: "milestone"))
                        dismiss()
                    }
                    .font(DS.Typography.body)
                    .foregroundStyle(.thSecondaryText)
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.xxl)
            }
            .yalaScreenBackground(.panel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        TelemetryService.track(.proUpsellDismissed, parameters: TelemetryService.upsellParameters(source: "milestone"))
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            TelemetryService.track(.proUpsellShown, parameters: TelemetryService.upsellParameters(source: "milestone"))
        }
        .sheet(isPresented: $showSubscription) {
            NavigationStack {
                SubscriptionView(source: "milestone")
            }
        }
    }

    // MARK: - Subviews

    private func featureRow(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(DS.Typography.labelSmall.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(color)
                )

            Text(text)
                .font(DS.Typography.body)
                .foregroundStyle(.thPrimaryText)

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(DS.Typography.body)
                .foregroundStyle(.thAccent)
        }
    }

    // MARK: - Helpers

    private var milestoneMessage: String {
        switch milestone {
        case 10:
            return L10n.Milestone.message10
        case 50:
            return L10n.Milestone.message50
        default:
            return L10n.Milestone.message100
        }
    }
}

// MARK: - L10n Extension

extension L10n {
    enum Milestone {
        static func title(_ count: Int) -> String {
            String(
                format: NSLocalizedString("milestone.title", comment: ""),
                count
            )
        }
        static var message10: String {
            NSLocalizedString("milestone.message10", comment: "Milestone 10 message")
        }
        static var message50: String {
            NSLocalizedString("milestone.message50", comment: "Milestone 50 message")
        }
        static var message100: String {
            NSLocalizedString("milestone.message100", comment: "Milestone 100 message")
        }
        static var notNow: String {
            NSLocalizedString("milestone.notNow", comment: "Not now button")
        }
        static var unlimitedAccounts: String {
            NSLocalizedString("milestone.unlimitedAccounts", comment: "Unlimited accounts feature")
        }
    }
}

// MARK: - Preview

#Preview {
    MilestoneUpgradeSheet(milestone: 50)
}
