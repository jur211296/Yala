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
//  Opción B de Jürgen (20-nov-2026, tema 4 de las maquetas): sale al terminar «Aprender a registrar» y vende lo que la
//  persona acaba de probar. Tres funciones en vez de seis, la línea de tiempo en una línea, el botón de empezar fijo
//  abajo y solo, y «Ahora no» en la barra (nunca un botón debajo de otro). «¡Listo! Tienes Pro» enseña «Pruébalo ahora»
//  en lugar del tour Pro (tema 3).
//
//  Opción A de Jürgen (20-nov-2026, «Oferta Pro: más beneficios»): la cabecera más corta y una tarjeta con cuatro
//  bloques que nombran las ocho puertas Pro (`OfertaProBeneficiosCard`), y «Ver todos los beneficios ›», que empuja
//  «Qué incluye Yala Pro» dentro de la misma hoja con el mismo botón de empezar abajo.
//

import StoreKit
import SwiftUI

struct SetupCompleteTrialOfferSheet: View {
    private typealias T = L10n.PrimerosPasos23.Final
    private typealias P = PrimerosPasosPaso7Text.Offer

    /// Lo que la persona probó gratis en el paso 2 (voz, foto, Yala IA): el título y la línea lo nombran.
    let triedMethods: [RecordTutorialLogic.Method]
    /// Un acceso de «Pruébalo ahora»: quien presenta la hoja abre la función cuando termina de cerrarse.
    let onTryNow: (ProTryNowAction) -> Void
    let onDismiss: () -> Void

    init(triedMethods: [RecordTutorialLogic.Method] = [],
         onTryNow: @escaping (ProTryNowAction) -> Void = { _ in },
         onDismiss: @escaping () -> Void) {
        self.triedMethods = triedMethods
        self.onTryNow = onTryNow
        self.onDismiss = onDismiss
    }

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
    /// «Qué incluye Yala Pro» empujada encima de la oferta. No guarda plan: compra el que se eligió aquí.
    @State private var showsAllBenefits = false

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
            .navigationDestination(isPresented: $showsAllBenefits) {
                OfertaProTodosLosBeneficiosPage { bottomButton }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !showsSuccess {
                    ToolbarItem(placement: .topBarLeading) {
                        YalaToolbarTextButton(P.notNow) { if !store.isPurchasing { onDismiss() } }
                            .accessibilityIdentifier("setup_offer_close")
                    }
                }
            }
            // El botón de empezar, solo y fijo abajo (la maqueta: antes quedaba debajo de seis funciones y dos planes).
            .safeAreaBar(edge: .bottom, spacing: DS.Spacing.sm) {
                bottomButton
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.bottom, DS.Spacing.md)
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
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // Cabecera corta (opción A): 4 pt entre piezas, para que en el SE quepan la tarjeta y los dos planes.
            VStack(spacing: DS.Spacing.xs) {
                YalaSpark(size: .large, animated: false, solid: true)
                    .accessibilityHidden(true)
                Text(title)
                    .font(DS.Typography.title)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("setup_offer_title")
                Text(subtitle)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("setup_offer_subtitle")
            }
            .frame(maxWidth: .infinity)
            .padding(.top, DS.Spacing.xs)

            OfertaProBeneficiosCard { showsAllBenefits = true }

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

            // «Restaurar compras» y lo legal, al final del contenido: el botón de empezar va solo, abajo.
            Button(L10n.Subscription.restore) {
                purchaseInFlight = false
                Task { await store.restorePurchases() }
            }
            .font(DS.Typography.subheadline)
            .foregroundStyle(.thSecondaryText)
            .frame(maxWidth: .infinity, minHeight: 44)
            .accessibilityIdentifier("subscription_restore")

            ProLegalFooter()
        }
    }

    /// Abajo, fijo: «Empezar mi mes gratis» en la oferta y «Empezar a usarlo» en «¡Listo! Tienes Pro».
    @ViewBuilder
    private var bottomButton: some View {
        if showsSuccess {
            YalaPrimaryButton(T.startUsing) { onDismiss() }
                .accessibilityIdentifier("setup_offer_start_using")
                .primerosPasosButtonText()
        } else {
            YalaPrimaryButton(ctaTitle, isDisabled: store.isPurchasing || store.planOffers.isEmpty) {
                Task { await purchaseSelected() }
            }
            .accessibilityIdentifier("setup_offer_cta")
            .primerosPasosButtonText()
        }
    }

    /// Lo que probó en el paso 2, o la línea general si no probó ninguna manera de Pro.
    private var subtitle: String {
        switch SetupCompleteTrialOfferLogic.headlineMethod(triedMethods) {
        case .voice: P.triedVoice
        case .photo: P.triedPhoto
        case .ai: P.triedAI
        case .manual, nil: OfertaProBeneficiosText.subtitle
        }
    }

    /// La duración que da la App Store; sin prueba en el plan elegido, no se promete ninguna.
    private var title: String {
        guard let offer = selectedOffer, let days = offer.trialDays else { return L10n.Subscription.title }
        if SetupCompleteTrialOfferLogic.headlineMethod(triedMethods) != nil {
            return offer.trialIsOneMonth ? P.triedTitleOneMonth : P.triedTitleDays(days)
        }
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
            // Lo que mostraba el tour Pro, aquí y con un toque para probarlo (opción B de Jürgen, 20-nov-2026).
            ProTryNowSection { action in
                onTryNow(action)
                onDismiss()
            }
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
        showsAllBenefits = false
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

/// «Hoy no pagas · te avisamos el … · cobro el …» en una sola línea, con las fechas reales (la maqueta del tema 4: antes
/// era una lista de tres pasos). Sin permiso de avisos, sin el aviso: no se promete lo que no puede salir (decisión de
/// Jürgen, 12-nov, opción A).
private struct SetupOfferTimeline: View {
    let chargeDate: Date
    let showsReminder: Bool

    private var reminderDate: Date? {
        SetupCompleteTrialOfferLogic.reminderDate(chargeDate: chargeDate, calendar: .current)
    }

    private var text: String {
        let charge = ProPresentation.longDate(chargeDate)
        if showsReminder, let reminderDate {
            return PrimerosPasosPaso7Text.Offer.timelineWithReminder(ProPresentation.longDate(reminderDate), charge)
        }
        return PrimerosPasosPaso7Text.Offer.timelineCharge(charge)
    }

    var body: some View {
        Text(text)
            .font(DS.Typography.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("setup_offer_timeline")
    }
}
