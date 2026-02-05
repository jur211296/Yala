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

    // MARK: - State

    @State private var showConfetti = false
    @State private var crownScale: CGFloat = 0
    @State private var featuresOpacity: Double = 0

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background
            Color.yalaBackground
                .ignoresSafeArea()

            // Confetti overlay
            if showConfetti {
                ConfettiView()
                    .ignoresSafeArea()
            }

            // Content
            VStack(spacing: DS.Spacing.xxl) {
                Spacer()

                // Animated spark
                ZStack {
                    // Glow
                    YalaSpark(size: .large, animated: false)
                        .scaleEffect(5.0)
                        .blur(radius: 30)
                        .opacity(0.5)

                    YalaSpark(size: .large, animated: true)
                        .scaleEffect(4.0)
                        .shadow(color: Color.orange.opacity(0.5), radius: 10, y: 5)
                }
                .scaleEffect(crownScale)

                // Title
                VStack(spacing: DS.Spacing.md) {
                    Text(L10n.Subscription.Success.title)
                        .font(.title.bold())
                        .foregroundStyle(Color.yalaPrimaryText)
                        .multilineTextAlignment(.center)

                    Text(L10n.Subscription.Success.subtitle)
                        .font(.body)
                        .foregroundStyle(Color.yalaSecondaryText)
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
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.xxl)
            }
        }
        .onAppear {
            playEntranceAnimation()
        }
    }

    // MARK: - Subviews

    private var unlockedFeaturesList: some View {
        VStack(spacing: DS.Spacing.md) {
            unlockedFeatureRow(icon: "infinity", text: L10n.Subscription.featureUnlimitedAccounts, color: .blue)
            unlockedFeatureRow(icon: "chart.pie.fill", text: L10n.Subscription.featureUnlimitedBudgets, color: .purple)
            unlockedFeatureRow(icon: "waveform", text: L10n.Subscription.featureVoice, color: .cyan)
            unlockedFeatureRow(icon: "photo.on.rectangle", text: L10n.Subscription.featureImage, color: .orange)
            unlockedFeatureRow(icon: "app.fill", text: L10n.Subscription.featurePremiumIcons, color: .pink)
        }
        .padding(.horizontal, DS.Spacing.xl)
    }

    private func unlockedFeatureRow(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: DS.Icon.sizeMedium, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: DS.Icon.badgeMedium, height: DS.Icon.badgeMedium)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.sm)
                        .fill(color)
                )

            Text(text)
                .font(.body)
                .foregroundStyle(Color.yalaPrimaryText)

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.green)
        }
    }

    // MARK: - Animation

    private func playEntranceAnimation() {
        // Haptic feedback
        DS.Haptic.success()

        // Show confetti
        showConfetti = true

        // Animate crown
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
            crownScale = 1.0
        }

        // Fade in features
        withAnimation(.easeOut(duration: 0.5).delay(0.4)) {
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
