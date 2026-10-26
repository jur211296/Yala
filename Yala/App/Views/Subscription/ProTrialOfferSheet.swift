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

    private let store = StoreKitManager.shared

    init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }

    @State private var selectedPlan: String = StoreKitManager.proYearlyID
    @State private var showError = false
    @State private var showSuccess = false
    @State private var productLoadFailed = false

    // MARK: - Body

    /// El mismo cuerpo que el paywall (UX 2.2 · L17-2 variante 2: «vale para el paywall y para la oferta») con la salida
    /// a la vista (L17-5): la X arriba y «Quizás después» justo bajo el botón, sin tener que bajar. Antes la única salida
    /// quedaba bajo el pliegue, entre el botón y «Restaurar compras».
    var body: some View {
        NavigationStack {
            ScrollView {
                ProPaywallBody(
                    offers: store.planOffers,
                    pricesFailed: productLoadFailed,
                    selectedID: $selectedPlan,
                    isPurchasing: store.isPurchasing,
                    ctaIdentifier: "trial_offer_cta",
                    dismissTitle: L10n.TrialOffer.maybeLater,
                    dismissIdentifier: "trial_offer_dismiss",
                    onDismiss: { if !store.isPurchasing { onDismiss() } },
                    onRetryPrices: {
                        productLoadFailed = false
                        Task { await loadProductsWithTimeout() }
                    },
                    onPurchase: { Task { await purchaseSelected() } },
                    onRestore: { Task { await store.restorePurchases() } }
                )
            }
            .scrollBounceBehavior(.basedOnSize)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        if !store.isPurchasing { onDismiss() }
                    }
                    .accessibilityIdentifier("trial_offer_close")
                }
            }
            .yalaScreenBackground(.subtle)
        }
        // Mientras Apple procesa la compra no se sale (review del lote decidido 06).
        .interactiveDismissDisabled(store.isPurchasing)
        .task {
            await loadProductsWithTimeout()
        }
        .alert(store.alertTitle ?? L10n.Subscription.errorTitle, isPresented: $showError) {
            // Vaciar el aviso al cerrarlo: con el mismo error otra vez, el `onChange` no volvía a saltar,
            // y un título viejo titulaba el error siguiente (molde de `UpgradePromptSheet`).
            Button(L10n.Common.ok, role: .cancel) { clearStoreAlert() }
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
                showSuccess = true
            }
            store.didJustSubscribe = false
        }
        .fullScreenCover(isPresented: $showSuccess, onDismiss: {
            ProTourManager.shared.triggerIfEligible()
            onDismiss()
        }) {
            SubscriptionSuccessView()
        }
    }

    // MARK: - Helpers

    private func clearStoreAlert() {
        store.errorMessage = nil
        store.alertTitle = nil
    }

    private func loadProductsWithTimeout() async {
        await store.loadProducts()
        // If products are still empty after loading, mark as failed
        if store.planOffers.isEmpty {
            productLoadFailed = true
        }
    }

    private func purchaseSelected() async {
        let offerID = store.planOffers.first { $0.id == selectedPlan }?.id ?? store.planOffers.first?.id
        guard let offerID else { return }
        _ = await store.purchase(offerID: offerID)
    }
}

// MARK: - Preview

#Preview {
    ProTrialOfferSheet(onDismiss: {})
}
