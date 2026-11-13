//
//  SetupCompleteTrialOfferSheet.swift
//  Yala
//
//  Y23-18 · La oferta del final de Primeros pasos (docs/onboarding-2-3/SPEC.md, prototipo oficial v35, pestaña 8): la
//  prueba de Yala Pro de la App Store, con el plan anual preseleccionado («El más elegido»), los precios reales, la línea
//  de tiempo (hoy · el aviso · el primer cobro) y la salida «Seguir con la versión gratis», que no regala nada. La prueba
//  solo empieza si la persona confirma en la hoja de pago de Apple (norma 3.1.2); entonces, «¡Listo! Tienes Pro» y un
//  aviso local antes del cobro.
//
//  La duración se dice como la da la App Store: «1 mes» si la oferta es de un mes (decisión D21 de Jürgen), con las
//  fechas reales. La otra oferta de la app (tras guardar un registro) sigue en `ProTrialOfferSheet`.
//

import StoreKit
import SwiftUI

struct SetupCompleteTrialOfferSheet: View {
    private typealias T = L10n.PrimerosPasos23.Final

    let onDismiss: () -> Void

    private let store = StoreKitManager.shared

    @State private var selectedPlan: String = StoreKitManager.proYearlyID
    @State private var showError = false
    @State private var productLoadFailed = false
    /// Apple confirmó la compra: la hoja pasa a «¡Listo! Tienes Pro».
    @State private var purchased = false
    /// La compra salió de «Empezar mi mes gratis» (no de «Restaurar compras»): solo ella promete la prueba y el aviso.
    @State private var purchaseInFlight = false
    /// El aviso antes del cobro quedó agendado: solo entonces se dice «El … te avisamos».
    @State private var reminderScheduled = false
    /// Hay permiso de avisos: sin él, la línea de tiempo no promete el aviso (no se pide, Y23-17).
    @State private var canRemind = false

    @Environment(\.yalaTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var selectedOffer: ProPlanOffer? {
        store.planOffers.first { $0.id == selectedPlan } ?? store.planOffers.first
    }

    /// Con Pro ya activo la hoja enseña el final aunque iOS haya rehecho su contenido (y su `@State`) tras la hoja de pago.
    private var showsSuccess: Bool { purchased || store.isProUser }

    var body: some View {
        NavigationStack {
            ScrollView {
                Group {
                    if showsSuccess {
                        success.transition(.opacity)
                    } else {
                        offer.transition(.opacity)
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.xxl)
            }
            .scrollBounceBehavior(.basedOnSize)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !showsSuccess {
                    ToolbarItem(placement: .topBarTrailing) {
                        YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                            if !store.isPurchasing { onDismiss() }
                        }
                        .accessibilityIdentifier("setup_offer_close")
                    }
                }
            }
            .yalaScreenBackground(.subtle)
            .overlay {
                if showsSuccess && !reduceMotion { ConfettiView().allowsHitTesting(false) }
            }
        }
        .animation(reduceMotion ? nil : DS.Animation.appear, value: showsSuccess)
        // Mientras Apple procesa la compra no se sale, y con Pro ya activo se sale por «Empezar a usarlo».
        .interactiveDismissDisabled(store.isPurchasing || showsSuccess)
        .task {
            MetricsService.usedProOffer()
            canRemind = SetupCompleteTrialOfferLogic.canScheduleReminder(
                await NotificationService.shared.checkPermissionStatus())
            await loadProducts()
        }
        .alert(store.alertTitle ?? L10n.Subscription.errorTitle, isPresented: $showError) {
            Button(L10n.Common.ok, role: .cancel) { clearStoreAlert() }
        } message: {
            Text(store.errorMessage ?? "")
        }
        .onChange(of: store.errorMessage) { _, newValue in
            if newValue != nil { showError = true }
        }
        .onChange(of: store.didJustSubscribe) { _, didSubscribe in
            if didSubscribe && store.isProUser { purchaseConfirmed() }
            store.didJustSubscribe = false
        }
    }

    // MARK: - La oferta

    private var offer: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            VStack(spacing: DS.Spacing.md) {
                YalaSpark(size: .large, animated: false, solid: true)
                    .accessibilityHidden(true)
                Text(title)
                    .font(DS.Typography.welcomeHeadline)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("setup_offer_title")
                Text(T.offerSubtitle)
                    .font(DS.Typography.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, DS.Spacing.md)

            SetupOfferFeatures()

            if !store.planOffers.isEmpty {
                VStack(spacing: DS.Spacing.sm) {
                    ForEach(store.planOffers) { plan in
                        ProPlanCard(
                            offer: plan,
                            isSelected: plan.id == selectedOffer?.id,
                            badgeOverride: plan.isYearly ? T.mostChosen : nil,
                            secondaryLineOverride: plan.isYearly ? T.cheaperPerMonth : nil,
                            onSelect: {
                                DS.Haptic.selection()
                                selectedPlan = plan.id
                            })
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("setup_offer_plans")
                if let selectedOffer, let charge = selectedOffer.firstChargeDate {
                    SetupOfferTimeline(chargeDate: charge, showsReminder: canRemind)
                }
            } else if productLoadFailed {
                ProPricesUnavailable {
                    productLoadFailed = false
                    Task { await loadProducts() }
                }
            } else {
                ProgressView().frame(maxWidth: .infinity)
            }

            VStack(spacing: DS.Spacing.md) {
                YalaPrimaryButton(ctaTitle, isDisabled: store.isPurchasing || store.planOffers.isEmpty) {
                    Task { await purchaseSelected() }
                }
                .accessibilityIdentifier("setup_offer_cta")
                .primerosPasosButtonText()
                Button(T.keepFree) { if !store.isPurchasing { onDismiss() } }
                    .font(DS.Typography.body.weight(.semibold))
                    .foregroundStyle(.thAccentText)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .accessibilityIdentifier("setup_offer_keep_free")
                Button(L10n.Subscription.restore) {
                    purchaseInFlight = false
                    Task { await store.restorePurchases() }
                }
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.thSecondaryText)
                    .accessibilityIdentifier("subscription_restore")
            }

            ProLegalFooter()
                .padding(.top, DS.Spacing.sm)
        }
    }

    /// La duración que da la App Store; sin prueba en el plan elegido, no se promete ninguna.
    private var title: String {
        guard let offer = selectedOffer, let days = offer.trialDays else { return L10n.Subscription.title }
        return offer.trialIsOneMonth ? T.offerTitleOneMonth : T.offerTitleDays(days)
    }

    private var ctaTitle: String {
        if store.isPurchasing { return L10n.Subscription.processing }
        guard let offer = selectedOffer, let days = offer.trialDays else { return L10n.Subscription.subscribe }
        return offer.trialIsOneMonth ? T.ctaOneMonth : T.ctaDays(days)
    }

    // MARK: - ¡Listo! Tienes Pro

    private var success: some View {
        VStack(spacing: DS.Spacing.lg) {
            Image(systemName: "checkmark")
                .font(DS.Typography.title.weight(.bold))
                .foregroundStyle(theme.onAccent)
                .frame(width: 64, height: 64)
                .background(Circle().fill(theme.accent))
                .accessibilityHidden(true)
                .padding(.top, DS.Spacing.xl)
            Text(T.successTitle)
                .font(DS.Typography.welcomeHeadline)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("setup_offer_success_title")
            if let line = successLine {
                Text(line)
                    .font(DS.Typography.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("setup_offer_success_line")
            }
            SetupOfferFeatures()
            YalaPrimaryButton(T.startUsing) {
                ProTourManager.shared.triggerIfEligible()
                onDismiss()
            }
            .accessibilityIdentifier("setup_offer_start_using")
            .primerosPasosButtonText()
        }
        .frame(maxWidth: .infinity)
    }

    /// Hasta cuándo va la prueba (la fecha de Apple, solo si la transacción es la prueba) y, si quedó agendado y es
    /// futuro, cuándo avisamos. Tras «Restaurar compras» o sin prueba, nada que contar.
    private var successLine: String? {
        guard store.isInTrial, let trialEnd = store.trialEndDate else { return nil }
        let until = ProPresentation.longDate(trialEnd)
        let reminder = SetupCompleteTrialOfferLogic.reminderDate(chargeDate: trialEnd, calendar: .current)
        let oneMonth = selectedOffer?.trialIsOneMonth ?? true
        let days = selectedOffer?.trialDays
        if SetupCompleteTrialOfferLogic.announcesReminder(reminder, scheduled: reminderScheduled, now: .now),
           let reminder {
            let remind = ProPresentation.longDate(reminder)
            if let days, !oneMonth { return T.successDays(days, until, remind) }
            return T.successOneMonth(until, remind)
        }
        if let days, !oneMonth { return T.successDaysUntil(days, until) }
        return T.successOneMonthUntil(until)
    }

    // MARK: - Compra

    private func loadProducts() async {
        await store.loadProducts()
        if store.planOffers.isEmpty { productLoadFailed = true }
    }

    private func purchaseSelected() async {
        guard let offerID = selectedOffer?.id else { return }
        // Se baja al confirmar (`purchaseConfirmed`) o si la compra no salió: el aviso de Apple llega por `onChange`, en
        // una vuelta posterior, y un `defer` aquí lo bajaría antes de que se lea.
        purchaseInFlight = true
        if await store.purchase(offerID: offerID) == false { purchaseInFlight = false }
    }

    /// Apple confirmó. Solo una compra de esta hoja que sea la prueba (no «Restaurar compras») agenda el aviso antes
    /// del cobro, con la fecha real de Apple; se apunta como prometido solo si quedó agendado.
    private func purchaseConfirmed() {
        let startsTrial = purchaseInFlight && store.isInTrial
        purchaseInFlight = false
        purchased = true
        DS.Haptic.success()
        guard startsTrial, let end = store.trialEndDate else { return }
        Task {
            let scheduled = await NotificationService.shared.scheduleProTrialChargeReminder(chargeDate: end)
            if scheduled { UserDefaults.standard.set(true, forKey: SetupCompleteTrialOfferLogic.reminderOwedKey) }
            reminderScheduled = scheduled
        }
    }

    private func clearStoreAlert() {
        store.errorMessage = nil
        store.alertTitle = nil
    }
}

// MARK: - Piezas

/// Los seis beneficios de Pro: los títulos de la app (`uxpro.feature.*`) con su línea del prototipo.
private struct SetupOfferFeatures: View {
    private typealias T = L10n.PrimerosPasos23.Final

    @Environment(\.yalaTheme) private var theme

    private var items: [(icon: String, color: Color, title: String, detail: String)] {
        [
            ("waveform", .hotPink, L10n.UXPro.featureVoice, T.voiceDetail),
            ("camera.fill", .teal, L10n.UXPro.featurePhoto, T.photoDetail),
            ("sparkles", .electricIndigo, L10n.UXPro.featureAI, T.aiDetail),
            ("building.columns.fill", .blue, L10n.UXPro.featureAccounts, T.accountsDetail),
            ("chart.pie.fill", .purple, L10n.UXPro.featureBudgets, T.budgetsDetail),
            ("paintpalette.fill", .orange, L10n.UXPro.featureLooks, T.looksDetail),
        ]
    }

    var body: some View {
        PairedFeatureGrid(items: items.map { item in
            HStack(alignment: .top, spacing: DS.Spacing.sm) {
                Image(systemName: item.icon)
                    .font(DS.Typography.body.weight(.semibold))
                    .foregroundStyle(item.color)
                    .frame(width: 28)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(item.title).font(DS.Typography.subheadline.weight(.semibold))
                    Text(item.detail)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(DS.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: DS.Radius.md).fill(theme.card))
            .accessibilityElement(children: .combine)
        })
    }
}

/// Dos columnas a tamaño normal; una sola con texto de accesibilidad (el texto grande no corta).
private struct PairedFeatureGrid<Item: View>: View {
    let items: [Item]

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let columns = dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.flexible(), alignment: .top), GridItem(.flexible(), alignment: .top)]
        LazyVGrid(columns: columns, spacing: DS.Spacing.sm) {
            ForEach(items.indices, id: \.self) { index in items[index] }
        }
    }
}

/// «Hoy · <aviso> · <cobro>» con las fechas reales (el prototipo decía «Día 28 · Día 30»). Sin permiso de avisos, sin el
/// paso del aviso: no se promete lo que no puede salir (decisión de Jürgen, 12-nov, opción A).
private struct SetupOfferTimeline: View {
    let chargeDate: Date
    let showsReminder: Bool

    @Environment(\.yalaTheme) private var theme

    private var reminderDate: Date? {
        SetupCompleteTrialOfferLogic.reminderDate(chargeDate: chargeDate, calendar: .current)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            row(1, when: L10n.UXPro.trialTodayTitle, what: L10n.UXPro.trialTodayBody)
            if showsReminder, let reminderDate {
                row(2, when: ProPresentation.longDate(reminderDate), what: L10n.PrimerosPasos23.Final.reminderBody)
            }
            row(showsReminder && reminderDate != nil ? 3 : 2, when: ProPresentation.longDate(chargeDate),
                what: L10n.PrimerosPasos23.Final.chargeBody)
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: DS.Radius.lg).fill(theme.card))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("setup_offer_timeline")
    }

    private func row(_ number: Int, when: String, what: String) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            Text(verbatim: "\(number)")
                .font(DS.Typography.subheadline.weight(.bold))
                .foregroundStyle(theme.onAccent)
                .frame(width: 28, height: 28)
                .background(Circle().fill(theme.accent))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(when).font(DS.Typography.subheadline.weight(.semibold))
                Text(what)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
