//
//  SubscriptionView.swift
//  Yala
//
//  Paywall / subscription management view.
//

import StoreKit
import SwiftUI

struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.yalaTheme) private var theme

    var source: String = "direct"

    @State private var store = StoreKitManager.shared

    @State private var selectedPlan: String = StoreKitManager.proYearlyID
    @State private var showManageSubscription = false
    @State private var showError = false
    @State private var animateHero = false
    @State private var showSuccessView = false

    var body: some View {
        ZStack {
            if store.isProUser {
                PanelBackgroundView()
                activeSubscriptionContent
            } else {
                paywallContent
            }
        }
        .navigationTitle(L10n.Subscription.title)
        .navigationBarTitleDisplayMode(.inline)
        .swipeBack()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                YalaToolbarButton(systemName: "chevron.left", label: L10n.Action.back) {
                    dismiss()
                }
            }
        }
        .task {
            await store.loadProducts()
            await store.updateSubscriptionStatus()
            TelemetryService.trackOnce(.paywallViewed, key: "paywall", parameters: TelemetryService.upsellParameters(source: source))
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
                showSuccessView = true
                store.didJustSubscribe = false
            }
        }
        .fullScreenCover(isPresented: $showSuccessView, onDismiss: {
            ProTourManager.shared.triggerIfEligible()
        }) {
            SubscriptionSuccessView()
        }
    }

    // MARK: - Paywall (non-subscriber)

    private var paywallContent: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.none) {
                // Hero gradient header
                heroSection

                // Content below hero
                VStack(spacing: DS.Spacing.xxl) {
                    // Features list
                    featuresSection

                    // Plan selector
                    planSelector

                    // Purchase button
                    VStack(spacing: DS.Spacing.md) {
                        YalaPrimaryButton(
                            store.isPurchasing
                                ? L10n.Subscription.processing
                                : selectedProductHasFreeTrial
                                    ? L10n.Subscription.startFreeTrial
                                    : L10n.Subscription.subscribe,
                            isDisabled: store.isPurchasing || store.products.isEmpty
                        ) {
                            Task { await purchaseSelected() }
                        }

                        Button {
                            Task { await store.restorePurchases() }
                        } label: {
                            Text(L10n.Subscription.restore)
                                .font(DS.Typography.subheadline)
                                .foregroundStyle(.thPrimaryText)
                        }
                    }
                    .padding(.horizontal, DS.Spacing.lg)

                    // Legal footer
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
                        .tint(theme.accent)
                    }
                    .padding(.horizontal, DS.Spacing.xl)
                    .padding(.bottom, DS.Spacing.xxl)
                }
                .padding(.top, DS.Spacing.xxl)
            }
        }
        .background(.thBackground)
        .ignoresSafeArea(edges: .top)
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [
                    Color.electricIndigo,
                    Color.electricIndigo.opacity(0.85),
                    Color.electricIndigo.opacity(0.6),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Subtle pattern overlay
            Circle()
                .fill(DS.Colors.backgroundFaint)
                .frame(width: 300, height: 300)
                .offset(x: 120, y: -60)

            Circle()
                .fill(Color.white.opacity(0.03))  // Even fainter than DS.Opacity.faint
                .frame(width: 200, height: 200)
                .offset(x: -100, y: 40)

            // Content
            VStack(spacing: DS.Spacing.lg) {
                Spacer()
                    .frame(height: 60) // Safe area compensation

                // Spark icon with glow
                ZStack {
                    // Glow
                    YalaSpark(size: .large, animated: false)
                        .scaleEffect(3.5)
                        .blur(radius: 20)
                        .opacity(animateHero ? 0.6 : 0.3)

                    YalaSpark(size: .large, animated: true)
                        .scaleEffect(3.0)
                        .shadow(color: Color.orange.opacity(0.5), radius: 8, y: 4) // DS-OK: brand decorative
                }
                .scaleEffect(animateHero ? 1.0 : 0.8)
                .onAppear {
                    dsWithAnimation(reduceMotion) {
                        animateHero = true
                    }
                }

                // Title
                Text(L10n.Subscription.paywallTitle)
                    .font(DS.Typography.largeTitle)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .shadow(color: Color.black.opacity(0.2), radius: 4, y: 2)

                // Subtitle
                Text(L10n.Subscription.paywallSubtitle)
                    .font(DS.Typography.body)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)

                Spacer()
                    .frame(height: DS.Spacing.lg)
            }
            .padding(.horizontal, DS.Spacing.xxl)
        }
        .frame(height: 320)
    }

    // MARK: - Active Subscription Content

    private var activeSubscriptionContent: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.xxl) {
                // Header
                VStack(spacing: DS.Spacing.md) {
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.1)) // DS-OK: brand decorative
                            .frame(width: 100, height: 100)

                        YalaSpark(size: .large, animated: true)
                            .scaleEffect(2.0)
                    }
                    .padding(.bottom, DS.Spacing.sm)

                    Text(L10n.Subscription.activeTitle)
                        .font(.title2.bold())
                        .foregroundStyle(.thPrimaryText)

                    Text(L10n.Subscription.activeSubtitle)
                        .font(DS.Typography.body)
                        .foregroundStyle(.thSecondaryText)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, DS.Spacing.xxxl)

                // Current plan info
                if let transaction = store.activeSubscription {
                    currentPlanCard(transaction: transaction)
                }

                // Manage subscription
                Button {
                    showManageSubscription = true
                } label: {
                    Text(L10n.Subscription.manageInAppStore)
                        .font(DS.Typography.bodyBold)
                        .foregroundStyle(.thPrimaryText)
                }
                .manageSubscriptionsSheet(isPresented: $showManageSubscription)
            }
        }
    }

    // MARK: - Features

    private var featuresSection: some View {
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
        .solidCard(radius: DS.Radius.xl)
        .padding(.horizontal, DS.Spacing.lg)
    }

    private func featureRow(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(DS.Typography.labelSmall.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
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
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
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
                            isSelected ? theme.accent : theme.secondaryText.opacity(0.3),
                            lineWidth: 2
                        )
                        .frame(width: 24, height: 24)

                    if isSelected {
                        Circle()
                            .fill(theme.accent)
                            .frame(width: 16, height: 16)
                    }
                }
            }
            .padding(DS.Spacing.lg)
            .selectableCard(isSelected: isSelected, radius: DS.Radius.lg)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Current Plan Card (active subscriber)

    private func currentPlanCard(transaction: StoreKit.Transaction) -> some View {
        VStack(spacing: DS.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(L10n.Subscription.currentPlan)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.thSecondaryText)

                    Text(transaction.productID == StoreKitManager.proYearlyID
                        ? L10n.Subscription.planYearly
                        : L10n.Subscription.planMonthly)
                        .font(DS.Typography.headline)
                        .foregroundStyle(.thPrimaryText)
                }

                Spacer()

                YalaSpark(size: .medium, animated: false)
            }

            if let expirationDate = transaction.expirationDate {
                Divider()

                HStack {
                    Text(L10n.Subscription.renewsOn)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.thSecondaryText)
                    Spacer()
                    Text(expirationDate.formatted(date: .abbreviated, time: .omitted))
                        .font(DS.Typography.label)
                        .foregroundStyle(.thPrimaryText)
                }
            }
        }
        .solidCard(padding: DS.Spacing.lg, radius: DS.Radius.lg)
        .padding(.horizontal, DS.Spacing.lg)
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

    private func purchaseSelected() async {
        let product = store.products.first { $0.id == selectedPlan }
        guard let product else { return }
        _ = await store.purchase(product)
    }

    /// Whether the selected product has a free trial introductory offer
    private var selectedProductHasFreeTrial: Bool {
        guard let product = store.products.first(where: { $0.id == selectedPlan }),
              let intro = product.subscription?.introductoryOffer,
              intro.paymentMode == .freeTrial else { return false }
        return true
    }

    /// Extract readable trial duration from a product's introductory offer
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
}
