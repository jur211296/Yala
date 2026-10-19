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

    var source: String = "direct"

    @State private var store = StoreKitManager.shared

    @State private var selectedPlan: String = StoreKitManager.proYearlyID
    @State private var showManageSubscription = false
    @State private var showError = false
    @State private var showSuccessView = false
    /// La App Store no devolvió precios. Sin esto el paywall dejaba «Suscribirse» en gris sin decir por qué
    /// ni dejar reintentar (lote 17 · B1); mismo aviso que la oferta de prueba.
    @State private var productLoadFailed = false

    var body: some View {
        Group {
            if store.isProUser {
                activeSubscriptionContent
            } else {
                paywallContent
            }
        }
        // Sin el degradado premium que tenía (UX 2.2 · L17-2): fondo plano, como toda hoja.
        .yalaScreenBackground(.subtle)
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
            await loadProducts()
            await store.updateSubscriptionStatus()
        }
        .alert(store.alertTitle ?? L10n.Subscription.errorTitle, isPresented: $showError) {
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
            if didSubscribe && store.isProUser {
                showSuccessView = true
            }
            store.didJustSubscribe = false
        }
        // «Comenzar» cierra la bienvenida y también esta pantalla: tras comprar no queda nada de Pro por cerrar
        // (UX 2.2 · L17-9). Desde una hoja, `dismiss` la cierra; desde Ajustes, vuelve a la lista.
        .fullScreenCover(isPresented: $showSuccessView, onDismiss: {
            ProTourManager.shared.triggerIfEligible()
            dismiss()
        }) {
            SubscriptionSuccessView()
        }
    }

    // MARK: - Paywall (non-subscriber)

    /// El molde L17-2 variante 2: cabecera corta sin degradado, planes arriba, «Así funciona la prueba», fichas debajo.
    private var paywallContent: some View {
        ScrollView {
            ProPaywallBody(
                offers: store.planOffers,
                pricesFailed: productLoadFailed,
                selectedID: $selectedPlan,
                isPurchasing: store.isPurchasing,
                ctaIdentifier: "subscription_cta",
                onRetryPrices: {
                    productLoadFailed = false
                    Task { await loadProducts() }
                },
                onPurchase: { Task { await purchaseSelected() } },
                onRestore: { Task { await store.restorePurchases() } }
            )
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    // MARK: - Active Subscription Content

    /// Pro activo (L17-8): la tarjeta del plan con la fecha y el precio, lo que incluye, «Gestionar o cancelar» como
    /// botón de verdad y qué pasa si se cancela. Antes, «Eres Yala Pro» y un texto que no parecía un botón.
    private var activeSubscriptionContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                HStack(alignment: .center, spacing: DS.Spacing.md) {
                    YalaSpark(size: .large, animated: false, solid: true)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        Text(L10n.Subscription.activeTitle)
                            .font(DS.Typography.title)
                            .foregroundStyle(.thPrimaryText)
                            .accessibilityAddTraits(.isHeader)
                        Text(L10n.Subscription.activeSubtitle)
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(.thSecondaryText)
                    }
                }
                .padding(.top, DS.Spacing.md)

                currentPlanCard

                ProIncludedGrid()

                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    YalaSecondaryButton(L10n.UXPro.activeManage) {
                        showManageSubscription = true
                    }
                    .accessibilityIdentifier("subscription_manage")
                    .manageSubscriptionsSheet(isPresented: $showManageSubscription)

                    Text(L10n.UXPro.activeIfCancel(ProFeature.accounts.freeLimit ?? 0, ProFeature.budgets.freeLimit ?? 0))
                        .font(DS.Typography.caption)
                        .foregroundStyle(.thSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("subscription_if_cancel")
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.xxl)
        }
    }

    /// «Plan actual · Anual · Se renueva el 15 nov · $29.99 al año» (o «Prueba gratis hasta el 15 nov · luego…»).
    /// Sin transacción local que lo describa (Pro de la cuenta) queda «Yala Pro» sin fecha.
    private var currentPlanCard: some View {
        let plan = store.activePlan
        return VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(L10n.Subscription.currentPlan)
                .font(DS.Typography.caption)
                .foregroundStyle(.thSecondaryText)
            Text(plan.map { $0.isYearly ? L10n.Subscription.planYearly : L10n.Subscription.planMonthly }
                 ?? L10n.Subscription.title)
                .font(DS.Typography.headline)
                .foregroundStyle(.thPrimaryText)
            if let plan, let line = ProPresentation.activeCardLine(for: plan) {
                Text(line)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.thPrimaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("subscription_plan_line")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .solidCard(padding: DS.Spacing.lg, radius: DS.Radius.lg)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("subscription_plan_card")
    }

    // MARK: - Helpers

    private func loadProducts() async {
        await store.loadProducts()
        productLoadFailed = store.planOffers.isEmpty
    }

    private func purchaseSelected() async {
        let offerID = store.planOffers.first { $0.id == selectedPlan }?.id ?? store.planOffers.first?.id
        guard let offerID else { return }
        _ = await store.purchase(offerID: offerID)
    }
}
