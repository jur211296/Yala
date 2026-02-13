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

    private var store = StoreKitManager.shared

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
                YalaToolbarButton(systemName: "chevron.left", label: "Atrás") {
                    dismiss()
                }
            }
        }
        .task {
            await store.loadProducts()
            await store.updateSubscriptionStatus()
        }
        .alert(L10n.Subscription.errorTitle, isPresented: $showError) {
            Button("OK", role: .cancel) {}
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
        .fullScreenCover(isPresented: $showSuccessView) {
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
                                .foregroundStyle(Color.brandPrimary)
                        }
                    }
                    .padding(.horizontal, DS.Spacing.lg)

                    // Legal footer
                    VStack(spacing: DS.Spacing.xs) {
                        Text(L10n.Subscription.legalFooter)
                            .font(DS.Typography.caption)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                        if let url = URL(string: "https://yala-app.pe/terms") {
                            Link(L10n.Subscription.termsLink, destination: url)
                                .font(DS.Typography.caption)
                        }
                    }
                    .padding(.horizontal, DS.Spacing.xl)
                    .padding(.bottom, DS.Spacing.xxl)
                }
                .padding(.top, DS.Spacing.xxl)
            }
        }
        .background(Color.yalaBackground)
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
                        .shadow(color: Color.orange.opacity(0.5), radius: 8, y: 4)
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
                            .fill(Color.orange.opacity(0.1))
                            .frame(width: 100, height: 100)

                        YalaSpark(size: .large, animated: true)
                            .scaleEffect(2.0)
                    }
                    .padding(.bottom, DS.Spacing.sm)

                    Text(L10n.Subscription.activeTitle)
                        .font(.title2.bold())
                        .foregroundStyle(Color.yalaPrimaryText)

                    Text(L10n.Subscription.activeSubtitle)
                        .font(DS.Typography.body)
                        .foregroundStyle(Color.yalaSecondaryText)
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
                        .foregroundStyle(Color.brandPrimary)
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
            featureRow(icon: "waveform.badge.mic", text: L10n.Subscription.featureVoice, color: .hotPink)
            featureRow(icon: "photo.on.rectangle", text: L10n.Subscription.featureImage, color: .teal)
            featureRow(icon: "app.fill", text: L10n.Subscription.featurePremiumIcons, color: .pink)
        }
        .padding(.vertical, DS.Spacing.sm)
        .background(Color.yalaCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
        .padding(.horizontal, DS.Spacing.lg)
    }

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
                .foregroundStyle(Color.yalaPrimaryText)

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(DS.Typography.body)
                .foregroundStyle(Color.brandPrimary)
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
                            .foregroundStyle(Color.yalaPrimaryText)

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

                    Text(product.displayPrice + " " + planPeriodLabel(for: product))
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(Color.yalaSecondaryText)

                    if let monthlyEquiv = store.monthlyEquivalent(for: product) {
                        Text(L10n.Subscription.perMonth(monthlyEquiv))
                            .font(DS.Typography.caption)
                            .foregroundStyle(Color.yalaSecondaryText)
                    }
                }

                Spacer()

                ZStack {
                    Circle()
                        .stroke(
                            isSelected ? Color.brandPrimary : Color.yalaSecondaryText.opacity(0.3),
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
            .background(Color.yalaCard)
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

    // MARK: - Current Plan Card (active subscriber)

    private func currentPlanCard(transaction: StoreKit.Transaction) -> some View {
        VStack(spacing: DS.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(L10n.Subscription.currentPlan)
                        .font(DS.Typography.caption)
                        .foregroundStyle(Color.yalaSecondaryText)

                    Text(transaction.productID == StoreKitManager.proYearlyID
                        ? L10n.Subscription.planYearly
                        : L10n.Subscription.planMonthly)
                        .font(DS.Typography.headline)
                        .foregroundStyle(Color.yalaPrimaryText)
                }

                Spacer()

                YalaSpark(size: .medium, animated: false)
            }

            if let expirationDate = transaction.expirationDate {
                Divider()

                HStack {
                    Text(L10n.Subscription.renewsOn)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(Color.yalaSecondaryText)
                    Spacer()
                    Text(expirationDate.formatted(date: .abbreviated, time: .omitted))
                        .font(DS.Typography.label)
                        .foregroundStyle(Color.yalaPrimaryText)
                }
            }
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
}
