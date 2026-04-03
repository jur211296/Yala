//
//  ProTrialOfferSheet.swift
//  Yala
//
//  Sheet shown after onboarding to offer the free trial with plan selection.
//

import StoreKit
import SwiftUI

struct ProTrialOfferSheet: View {

    // MARK: - Properties

    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.yalaTheme) private var theme

    private let store = StoreKitManager.shared

    init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }

    @State private var selectedPlan: String = StoreKitManager.proYearlyID
    @State private var animateHero = false
    @State private var contentOpacity: Double = 0
    @State private var showError = false
    @State private var showSuccess = false
    @State private var productLoadFailed = false

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.md) {
                // Hero spark
                ZStack {
                    YalaSpark(size: .large, animated: false)
                        .scaleEffect(4.0)
                        .blur(radius: 25)
                        .opacity(animateHero ? 0.5 : 0.2)

                    YalaSpark(size: .large, animated: true)
                        .scaleEffect(3.5)
                        .shadow(color: Color.orange.opacity(0.5), radius: 8, y: 4)
                }
                .scaleEffect(animateHero ? 1.0 : 0.8)
                .frame(height: 100)
                .padding(.top, DS.Spacing.lg)

                // Title & subtitle
                VStack(spacing: DS.Spacing.sm) {
                    Text(L10n.TrialOffer.title)
                        .font(DS.Typography.largeTitle)
                        .foregroundStyle(.thPrimaryText)
                        .multilineTextAlignment(.center)

                    Text(L10n.TrialOffer.subtitle)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.thSecondaryText)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, DS.Spacing.xl)

                // Features list
                featuresList
                    .opacity(contentOpacity)

                // Plan selector
                if !store.products.isEmpty {
                    planSelector
                        .opacity(contentOpacity)
                } else if productLoadFailed {
                    VStack(spacing: DS.Spacing.sm) {
                        Text(L10n.Subscription.errorTitle)
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(.secondary)
                        Button(L10n.Action.retry) {
                            productLoadFailed = false
                            Task { await loadProductsWithTimeout() }
                        }
                        .font(DS.Typography.label)
                    }
                    .padding(.vertical, DS.Spacing.lg)
                } else {
                    ProgressView()
                        .padding(.vertical, DS.Spacing.lg)
                }

                // CTA + dismiss + legal (scrolls with content)
                VStack(spacing: DS.Spacing.md) {
                    YalaPrimaryButton(
                        store.isPurchasing
                            ? L10n.Subscription.processing
                            : L10n.Subscription.startFreeTrial,
                        isDisabled: store.isPurchasing || store.products.isEmpty
                    ) {
                        Task { await purchaseSelected() }
                    }

                    Button {
                        onDismiss()
                    } label: {
                        Text(L10n.TrialOffer.maybeLater)
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: DS.Spacing.xs) {
                        Text(L10n.Subscription.legalFooter)
                            .font(DS.Typography.caption)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                        HStack(spacing: DS.Spacing.xs) {
                            Link(L10n.Subscription.termsOfUseLink, destination: AppConstants.termsURL)
                            Text("·").foregroundStyle(.tertiary)
                            Link(L10n.Subscription.privacyPolicyLink, destination: AppConstants.privacyURL)
                        }
                        .font(DS.Typography.caption)
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.sm)
                .padding(.bottom, DS.Spacing.xl)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(theme.background.ignoresSafeArea())
        .task {
            await loadProductsWithTimeout()
        }
        .onAppear {
            dsWithAnimation(reduceMotion) {
                animateHero = true
            }
            dsWithAnimation(reduceMotion) {
                contentOpacity = 1.0
            }
        }
        .alert(L10n.Subscription.errorTitle, isPresented: $showError) {
            Button(L10n.Common.ok, role: .cancel) {}
        } message: {
            Text(store.errorMessage ?? "")
        }
        .onChange(of: store.errorMessage) { _, newValue in
            if newValue != nil {
                showError = true
            }
        }
        .onChange(of: store.didJustSubscribe) { _, didSubscribe in
            if didSubscribe {
                store.didJustSubscribe = false
                showSuccess = true
            }
        }
        .fullScreenCover(isPresented: $showSuccess, onDismiss: {
            ProTourManager.shared.triggerIfEligible()
            onDismiss()
        }) {
            SubscriptionSuccessView()
        }
    }

    // MARK: - Features List

    private var featuresList: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.none) {
            featureRow(icon: "building.columns.fill", text: L10n.Subscription.featureUnlimitedAccounts, color: .blue)
            featureRow(icon: "chart.pie.fill", text: L10n.Subscription.featureUnlimitedBudgets, color: .purple)
            featureRow(icon: "sparkles", text: L10n.Subscription.featureAIAssistant, color: .electricIndigo)
            featureRow(icon: "waveform.badge.mic", text: L10n.Subscription.featureVoice, color: .hotPink)
            featureRow(icon: "photo.on.rectangle", text: L10n.Subscription.featureImage, color: .teal)
            featureRow(icon: "paintpalette.fill", text: L10n.Subscription.featureThemes, color: .orange)
            featureRow(icon: "app.fill", text: L10n.Subscription.featurePremiumIcons, color: .pink)
        }
        .padding(.vertical, DS.Spacing.sm)
        .background(.thCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
        .padding(.horizontal, DS.Spacing.lg)
    }

    private func featureRow(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: icon)
                .font(DS.Typography.caption.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(color)
                )
                .accessibilityHidden(true)

            Text(text)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.thPrimaryText)

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(DS.Typography.subheadline)
                .foregroundStyle(.thAccent)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
    }

    // MARK: - Plan Selector

    private var planSelector: some View {
        VStack(spacing: DS.Spacing.md) {
            if let yearly = store.yearlyProduct {
                planCard(
                    product: yearly,
                    badge: savingsBadge,
                    isSelected: selectedPlan == yearly.id
                )
            }

            if let monthly = store.monthlyProduct {
                planCard(
                    product: monthly,
                    badge: nil,
                    isSelected: selectedPlan == monthly.id
                )
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
    }

    private var savingsBadge: String? {
        guard let percent = store.yearlySavingsPercent, percent > 0 else { return nil }
        return L10n.Subscription.saveBadge(percent)
    }

    private func planCard(product: Product, badge: String?, isSelected: Bool) -> some View {
        Button {
            dsWithAnimation(reduceMotion) {
                selectedPlan = product.id
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    HStack(spacing: DS.Spacing.sm) {
                        Text(planDisplayName(for: product))
                            .font(DS.Typography.headline)
                            .foregroundStyle(.thPrimaryText)

                        if let badge {
                            Text(badge)
                                .font(DS.Typography.labelSmall)
                                .foregroundStyle(.white)
                                .padding(.horizontal, DS.Spacing.sm)
                                .padding(.vertical, DS.Spacing.xxs)
                                .background(
                                    Capsule().fill(
                                        LinearGradient(
                                            colors: DS.Gradients.subscription,
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                )
                        }
                    }

                    if let trialText = trialDaysText(for: product) {
                        Text(trialText)
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(.thAccent)
                    } else {
                        Text(product.displayPrice + " " + planPeriodLabel(for: product))
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(.thSecondaryText)
                    }

                    if let monthlyEquiv = store.monthlyEquivalent(for: product) {
                        Text(L10n.Subscription.perMonth(monthlyEquiv))
                            .font(DS.Typography.caption)
                            .foregroundStyle(.thSecondaryText)
                    }
                }

                Spacer()

                ZStack {
                    Circle()
                        .stroke(
                            isSelected ? Color.brandPrimary : theme.secondaryText.opacity(0.3),
                            lineWidth: 2
                        )
                        .frame(width: 24, height: 24)

                    if isSelected {
                        Circle()
                            .fill(Color.brandPrimary)
                            .frame(width: 16, height: 16)
                    }
                }
            }
            .padding(DS.Spacing.lg)
            .background(.thCard)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .stroke(
                        isSelected ? Color.brandPrimary : Color.primary.opacity(0.05),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func planDisplayName(for product: Product) -> String {
        product.id == StoreKitManager.proYearlyID
            ? L10n.Subscription.planYearly
            : L10n.Subscription.planMonthly
    }

    private func planPeriodLabel(for product: Product) -> String {
        product.id == StoreKitManager.proYearlyID
            ? L10n.Subscription.perYear
            : L10n.Subscription.perMonth("")
    }

    private func trialDaysText(for product: Product) -> String? {
        guard let intro = product.subscription?.introductoryOffer,
              intro.paymentMode == .freeTrial else { return nil }
        let period = intro.period
        let days: Int
        switch period.unit {
        case .day:
            days = period.value
        case .week:
            days = period.value * 7
        case .month:
            days = period.value * 30
        case .year:
            days = period.value * 365
        @unknown default:
            days = period.value
        }
        return L10n.Subscription.trialThenPrice(
            "\(days)",
            product.displayPrice + " " + planPeriodLabel(for: product)
        )
    }

    private func loadProductsWithTimeout() async {
        await store.loadProducts()
        // If products are still empty after loading, mark as failed
        if store.products.isEmpty {
            productLoadFailed = true
        }
    }

    private func purchaseSelected() async {
        let product = store.products.first { $0.id == selectedPlan }
        guard let product else { return }
        _ = await store.purchase(product)
    }
}

// MARK: - Preview

#Preview {
    ProTrialOfferSheet(onDismiss: {})
}
