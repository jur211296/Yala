//
//  ProPurchaseComponents.swift
//  Yala
//
//  Las piezas de las hojas de compra de Yala Pro (auditoría UX 2.2 · lote decidido 06): el paywall, la oferta de prueba
//  y «Función Pro» las comparten para que digan lo mismo del precio y de la prueba (L17-2 variante 2, L17-3 variante 2).
//  Sin degradados ni brillos: el plan elegido va relleno del color de acento y lo demás, en tarjeta o en cristal.
//

import StoreKit
import SwiftUI

// MARK: - Textos derivados

/// Lo que Yala dice del plan Pro, ya en palabras. Lee `StoreKitManager` (observable): quien lo use desde un `body` se
/// repinta cuando cargan los precios o cambia el plan.
@MainActor
enum ProPresentation {

    /// «15 de noviembre»
    static func longDate(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.wide).locale(AppLocale.current))
    }

    /// «15 nov»
    static func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).locale(AppLocale.current))
    }

    /// «$29.99 al año»
    static func priceWithPeriod(_ price: String, yearly: Bool) -> String {
        yearly ? L10n.UXPro.priceYearly(price) : L10n.UXPro.priceMonthly(price)
    }

    /// El texto de los botones que llevan a Pro (L17-4): «Probar Pro gratis» o «Pasarme a Pro».
    static var upgradeButtonTitle: String {
        let store = StoreKitManager.shared
        switch ProPlanStatusLogic.upgradeLabel(
            eligibilityKnown: store.isIntroOfferEligibilityKnown,
            isEligible: store.offeredTrialDays != nil
        ) {
        case .tryFree: return L10n.UXPro.tryProFree
        case .switchToPro: return L10n.UXPro.switchToPro
        }
    }

    /// Si lo que se acabó era la prueba o una suscripción pagada (L17-6): lo dicen la hoja de fin de Pro y
    /// «Prueba terminada».
    static var endedWasTrial: Bool {
        #if DEBUG
        if UITestHooks.isActive { return !UITestHooks.proEndedPaid }
        #endif
        return ProPlanStatusLogic.endedWasTrial(
            lastActiveWasTrial: StoreKitManager.shared.lastActivePlanWasTrial,
            everWasInTrial: ProUpsellService.shared.everWasInTrial)
    }

    /// La línea de la fila «Yala Pro» de Ajustes (L17-1).
    static var settingsStatusLine: String {
        let store = StoreKitManager.shared
        switch ProPlanStatusLogic.settingsStatus(
            isPro: store.isProUser,
            plan: store.activePlan,
            offeredTrialDays: store.offeredTrialDays
        ) {
        case .freeWithTrial(let days):
            return store.offeredTrialIsOneMonth ? L10n.UXL15.settingsFreeWithTrialOneMonth : L10n.UXPro.settingsFreeWithTrial(days)
        case .free: return L10n.UXPro.settingsFree
        case .trialEnds(let date): return L10n.UXPro.settingsTrialEnds(shortDate(date))
        case .renews(let yearly, let date):
            return yearly ? L10n.UXPro.settingsRenewsYearly(shortDate(date)) : L10n.UXPro.settingsRenewsMonthly(shortDate(date))
        case .ends(let yearly, let date):
            return yearly ? L10n.UXPro.settingsEndsYearly(shortDate(date)) : L10n.UXPro.settingsEndsMonthly(shortDate(date))
        case .proActive: return L10n.UXPro.settingsProActive
        }
    }

    /// La segunda línea de la tarjeta del plan con Pro activo (L17-8).
    static func activeCardLine(for plan: ProActivePlan) -> String? {
        let price = StoreKitManager.shared.displayPrice(yearly: plan.nextChargeIsYearly)
        switch ProPlanStatusLogic.activeCardLine(plan: plan, price: price) {
        case .trialThenPrice(let until, let price, let yearly):
            return L10n.UXPro.activeTrialThen(shortDate(until), priceWithPeriod(price, yearly: yearly))
        case .trialUntil(let until): return L10n.UXPro.activeTrialUntil(shortDate(until))
        case .renews(let on, let price, let yearly):
            return L10n.UXPro.activeRenews(shortDate(on), priceWithPeriod(price, yearly: yearly))
        case .renewsNoPrice(let on): return L10n.UXPro.activeRenewsNoPrice(shortDate(on))
        case .ends(let on): return L10n.UXPro.activeEnds(shortDate(on))
        case nil: return nil
        }
    }
}

// MARK: - Tarjeta de plan

/// Un plan para elegir: el elegido, relleno del color de acento con el texto en blanco; el otro, en tarjeta.
struct ProPlanCard: View {
    @Environment(\.yalaTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let offer: ProPlanOffer
    let isSelected: Bool
    /// «Sale a $2.50 al mes» bajo el anual (el paywall sí; «Función Pro», no: la captura elegida no lo lleva).
    var showsMonthlyEquivalent: Bool = true
    let onSelect: () -> Void

    private var savingsBadge: String? {
        guard offer.isYearly, let percent = StoreKitManager.shared.yearlySavingsPercent ?? fakeSavings else { return nil }
        return percent > 0 ? L10n.Subscription.saveBadge(percent) : nil
    }

    /// Con precios de mentira (`-uitest-fake-prices`) no hay `Product` del que sacar el ahorro.
    private var fakeSavings: Int? {
        #if DEBUG
        return UITestHooks.fakePrices != nil ? PaywallPricingLogic.yearlySavingsPercent(monthly: 4.99, yearly: 29.99) : nil
        #else
        return nil
        #endif
    }

    private var priceLine: String {
        if offer.trialDays != nil, offer.trialIsOneMonth {
            return offer.isYearly
                ? L10n.UXL15.oneMonthThenYearly(offer.displayPrice)
                : L10n.UXL15.oneMonthThenMonthly(offer.displayPrice)
        }
        if let days = offer.trialDays {
            return offer.isYearly
                ? L10n.UXPro.trialThenYearly(days, offer.displayPrice)
                : L10n.UXPro.trialThenMonthly(days, offer.displayPrice)
        }
        return ProPresentation.priceWithPeriod(offer.displayPrice, yearly: offer.isYearly)
    }

    var body: some View {
        Button {
            dsWithAnimation(reduceMotion) { onSelect() }
        } label: {
            HStack(spacing: DS.Spacing.md) {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    HStack(spacing: DS.Spacing.sm) {
                        Text(offer.isYearly ? L10n.Subscription.planYearly : L10n.Subscription.planMonthly)
                            .font(DS.Typography.headline)
                        if let savingsBadge {
                            Text(savingsBadge)
                                .font(DS.Typography.labelSmall)
                                .foregroundStyle(theme.onFill(isSelected ? Color.hotPink : theme.accent))
                                .padding(.horizontal, DS.Spacing.sm)
                                .padding(.vertical, DS.Spacing.xxs)
                                .background(Capsule().fill(isSelected ? Color.hotPink : theme.accent))
                                .accessibilityIdentifier("subscription_save_badge")
                        }
                    }
                    Text(priceLine)
                        .font(DS.Typography.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                    if showsMonthlyEquivalent, let equivalent = offer.monthlyEquivalent {
                        Text(L10n.UXPro.monthlyEquivalent(equivalent))
                            .font(DS.Typography.caption)
                            .opacity(isSelected ? 0.9 : 0.75)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(DS.Typography.title)
                    .symbolRenderingMode(isSelected ? .palette : .monochrome)
                    .foregroundStyle(isSelected ? AnyShapeStyle(theme.accent) : AnyShapeStyle(Color.primary.opacity(0.6)),
                                     theme.onAccent)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(isSelected ? theme.onAccent : Color.primary)
            .padding(DS.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .fill(isSelected ? AnyShapeStyle(theme.accent) : AnyShapeStyle(.thCard))
            )
            .contentShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(offer.isYearly ? "pro_plan_yearly" : "pro_plan_monthly")
    }
}

/// Los dos planes, el anual primero.
struct ProPlanPicker: View {
    let offers: [ProPlanOffer]
    @Binding var selectedID: String
    var showsMonthlyEquivalent: Bool = true

    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            ForEach(offers) { offer in
                ProPlanCard(
                    offer: offer,
                    isSelected: selectedID == offer.id,
                    showsMonthlyEquivalent: showsMonthlyEquivalent
                ) { selectedID = offer.id }
            }
        }
    }
}

// MARK: - Sin precios

/// La App Store no devolvió precios: se dice y se deja reintentar (lote 17 · B1). Sin precios no hay planes.
struct ProPricesUnavailable: View {
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            Text(L10n.TrialOffer.pricesUnavailable)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.thSecondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("subscription_prices_unavailable")
            Button(L10n.Action.retry, action: onRetry)
                .font(DS.Typography.label)
                .accessibilityIdentifier("subscription_prices_retry")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.md)
    }
}

// MARK: - Así funciona la prueba

/// Hoy no pagas · tal día se cobra si sigues · cancela antes y no se cobra (L17-2 variante 2). Solo con prueba.
struct ProTrialTimeline: View {
    @Environment(\.yalaTheme) private var theme

    let offer: ProPlanOffer

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(L10n.UXPro.howTrialWorks)
                .font(DS.Typography.headline)
                .foregroundStyle(.thPrimaryText)
                .accessibilityAddTraits(.isHeader)
            step(icon: "lock.open.fill", color: .hotPink,
                 when: L10n.UXPro.trialTodayTitle, what: L10n.UXPro.trialTodayBody)
            if let chargeDate = offer.firstChargeDate {
                step(icon: "calendar", color: theme.accent,
                     when: ProPresentation.longDate(chargeDate),
                     what: offer.isYearly
                        ? L10n.UXPro.trialChargeYearly(offer.displayPrice)
                        : L10n.UXPro.trialChargeMonthly(offer.displayPrice))
            }
            step(icon: "xmark", color: Color(.systemGray), // A11Y-DM: gris de sistema, adapta a Dark Mode
                 when: L10n.UXPro.trialCancelTitle, what: L10n.UXPro.trialCancelBody)
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        .accessibilityIdentifier("pro_trial_timeline")
    }

    private func step(icon: String, color: Color, when: String, what: String) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(DS.Typography.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(Circle().fill(color))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(when)
                    .font(DS.Typography.bodyBold)
                    .foregroundStyle(.thPrimaryText)
                Text(what)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.thSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Qué incluye Pro

/// Lo que incluye Pro, en fichas de cristal de dos en dos (L17-2). También en la pantalla de Pro activo (L17-8).
struct ProIncludedGrid: View {
    private let columns = [GridItem(.flexible(), spacing: DS.Spacing.sm), GridItem(.flexible(), spacing: DS.Spacing.sm)]

    // A11Y-DM: paleta decorativa por función (colores de sistema y de marca, rellenos, sin texto encima)
    private var items: [(icon: String, text: String, color: Color)] {
        [
            ("waveform", L10n.UXPro.featureVoice, .hotPink),
            ("camera.fill", L10n.UXPro.featurePhoto, .teal),
            ("sparkles", L10n.UXPro.featureAI, .electricIndigo),
            ("building.columns.fill", L10n.UXPro.featureAccounts, .blue),
            ("chart.pie.fill", L10n.UXPro.featureBudgets, .purple),
            ("paintpalette.fill", L10n.UXPro.featureLooks, .orange),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(L10n.UXPro.includedTitle)
                .font(DS.Typography.headline)
                .foregroundStyle(.thPrimaryText)
                .accessibilityAddTraits(.isHeader)
            LazyVGrid(columns: columns, spacing: DS.Spacing.sm) {
                ForEach(items, id: \.text) { item in
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: item.icon)
                            .font(DS.Typography.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous).fill(item.color))
                            .accessibilityHidden(true)
                        Text(item.text)
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(.thPrimaryText)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(DS.Spacing.md)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                }
            }
        }
        .accessibilityIdentifier("pro_included_grid")
    }
}

// MARK: - Pie legal

/// Lo que App Review exige en toda hoja de compra (3.1.2): cómo se cobra y se renueva, Términos y Privacidad.
struct ProLegalFooter: View {
    @Environment(\.yalaTheme) private var theme

    var body: some View {
        VStack(spacing: DS.Spacing.xs) {
            Text(L10n.Subscription.legalFooter)
                .font(DS.Typography.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: DS.Spacing.xs) {
                Link(L10n.Subscription.termsOfUseLink, destination: AppConstants.termsURL)
                Text("·").foregroundStyle(.tertiary)
                Link(L10n.Subscription.privacyPolicyLink, destination: AppConstants.privacyURL)
            }
            .font(DS.Typography.caption)
            .tint(theme.accentText)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Cuerpo del paywall y de la oferta

/// Paywall y oferta de prueba con el molde L17-2-B: cabecera corta, planes arriba, «Así funciona la prueba», el botón,
/// la salida, «Restaurar compras», lo que incluye y el pie legal. La oferta añade su X arriba (L17-5) por fuera.
struct ProPaywallBody: View {
    let offers: [ProPlanOffer]
    let pricesFailed: Bool
    @Binding var selectedID: String
    let isPurchasing: Bool
    let ctaIdentifier: String
    /// La salida bajo el botón («Quizás después» en la oferta). `nil` en el paywall, que sale por la barra.
    var dismissTitle: String?
    var dismissIdentifier: String = ""
    var onDismiss: () -> Void = {}
    let onRetryPrices: () -> Void
    let onPurchase: () -> Void
    let onRestore: () -> Void

    private var selectedOffer: ProPlanOffer? {
        offers.first { $0.id == selectedID } ?? offers.first
    }

    private var ctaTitle: String {
        if isPurchasing { return L10n.Subscription.processing }
        if selectedOffer?.trialDays != nil, selectedOffer?.trialIsOneMonth == true { return L10n.UXL15.startTrialOneMonth }
        if let days = selectedOffer?.trialDays { return L10n.UXPro.startTrialDays(days) }
        return L10n.Subscription.subscribe
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            ProPaywallHeader()

            if !offers.isEmpty {
                ProPlanPicker(offers: offers, selectedID: $selectedID)
                if let offer = selectedOffer, offer.trialDays != nil {
                    ProTrialTimeline(offer: offer)
                }
            } else if pricesFailed {
                ProPricesUnavailable(onRetry: onRetryPrices)
            } else {
                ProgressView().frame(maxWidth: .infinity)
            }

            VStack(spacing: DS.Spacing.md) {
                YalaPrimaryButton(ctaTitle, isDisabled: isPurchasing || offers.isEmpty) { onPurchase() }
                    .accessibilityIdentifier(ctaIdentifier)
                if let dismissTitle {
                    Button(dismissTitle, action: onDismiss)
                        .font(DS.Typography.body)
                        .foregroundStyle(.thSecondaryText)
                        .accessibilityIdentifier(dismissIdentifier)
                }
                Button(L10n.Subscription.restore, action: onRestore)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.thSecondaryText)
                    .accessibilityIdentifier("subscription_restore")
            }

            ProIncludedGrid()
                .padding(.top, DS.Spacing.sm)

            ProLegalFooter()
                .padding(.top, DS.Spacing.sm)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.bottom, DS.Spacing.xxl)
    }
}

/// «Yala Pro · Apunta en segundos, sin límites», con la estrella pequeña y sin halo (L17-2: sin degradado).
struct ProPaywallHeader: View {
    var body: some View {
        HStack(alignment: .center, spacing: DS.Spacing.md) {
            YalaSpark(size: .large, animated: false, solid: true)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(L10n.Subscription.title)
                    .font(DS.Typography.title)
                    .foregroundStyle(.thPrimaryText)
                    .accessibilityAddTraits(.isHeader)
                Text(L10n.UXPro.paywallSubtitle)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.thSecondaryText)
            }
        }
        .padding(.top, DS.Spacing.md)
    }
}
