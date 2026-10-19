//
//  ProPlanStatusLogic.swift
//  Yala
//
//  Lógica pura de lo que Yala dice del plan Pro (auditoría UX 2.2 · lote decidido 06): la fila de Ajustes, la tarjeta
//  del plan, el banner de la prueba, el botón que lleva a Pro y qué aviso sale cuando Pro se acaba. Vive aquí, sin
//  StoreKit ni vistas, para poder afirmar cada rama con un test.
//

import Foundation

/// El plan que StoreKit da por activo en este Apple ID. `nil` en `StoreKitManager.activePlan` = no hay transacción
/// local (gratis, o Pro que viene de la cuenta de Yala).
nonisolated struct ProActivePlan: Equatable, Sendable {
    let isYearly: Bool
    let expirationDate: Date?
    let isTrial: Bool
    /// `nil` = Apple no lo contó (sin estado de renovación verificado).
    let willAutoRenew: Bool?
    /// A qué plan renueva: quien pasó del anual al mensual sigue en el anual hasta la fecha y renueva al mensual. `nil`
    /// = Apple no lo contó, y se toma el plan de ahora.
    var renewsYearly: Bool?

    /// El plan del PRÓXIMO cobro, el que dicen «luego $X» y «se renueva · $X».
    var nextChargeIsYearly: Bool { renewsYearly ?? isYearly }
}

/// Un plan que se puede comprar, ya traducido a lo que la pantalla enseña. Se arma desde `Product` en
/// `StoreKitManager.planOffers`; existe para que las tres hojas de compra no dependan de StoreKit directamente.
nonisolated struct ProPlanOffer: Equatable, Identifiable, Sendable {
    let id: String
    let isYearly: Bool
    let displayPrice: String
    /// «$2.50»: lo que sale al mes el anual. `nil` en el mensual.
    let monthlyEquivalent: String?
    /// Días de prueba que se pueden PROMETER (`nil` sin prueba o sin derecho a ella).
    let trialDays: Int?
    /// Cuándo se cobraría por primera vez si la prueba empieza hoy. `nil` sin prueba.
    let firstChargeDate: Date?
}

enum ProPlanStatusLogic {

    // MARK: - L17-4 · El botón que lleva a Pro

    enum UpgradeLabel: Equatable { case tryFree, switchToPro }

    /// «Probar Pro gratis» solo si se MIDIÓ que la cuenta aún tiene la prueba; sin medir, «Pasarme a Pro»: no se
    /// promete lo que no se sabe (la elegibilidad solo existe tras cargar los precios).
    static func upgradeLabel(eligibilityKnown: Bool, isEligible: Bool) -> UpgradeLabel {
        eligibilityKnown && isEligible ? .tryFree : .switchToPro
    }

    // MARK: - L17-1 · La fila «Yala Pro» de Ajustes

    enum SettingsStatus: Equatable {
        case freeWithTrial(days: Int)
        case free
        case trialEnds(Date)
        case renews(yearly: Bool, on: Date)
        case ends(yearly: Bool, on: Date)
        /// Pro sin transacción local que lo describa (Pro de la cuenta, o el de pruebas).
        case proActive
    }

    static func settingsStatus(isPro: Bool, plan: ProActivePlan?, offeredTrialDays: Int?) -> SettingsStatus {
        guard isPro else {
            if let days = offeredTrialDays, days > 0 { return .freeWithTrial(days: days) }
            return .free
        }
        guard let plan, let date = plan.expirationDate else { return .proActive }
        if plan.isTrial { return .trialEnds(date) }
        if plan.willAutoRenew == false { return .ends(yearly: plan.isYearly, on: date) }
        return .renews(yearly: plan.isYearly, on: date)
    }

    // MARK: - L17-8 · La tarjeta del plan con Pro activo

    enum ActiveCardLine: Equatable {
        /// «Prueba gratis hasta el 15 nov · luego $29.99 al año»
        case trialThenPrice(until: Date, price: String, yearly: Bool)
        /// «Prueba gratis hasta el 15 nov» (renovación apagada o sin precio)
        case trialUntil(Date)
        /// «Se renueva el 15 nov · $29.99 al año»
        case renews(on: Date, price: String, yearly: Bool)
        /// «Se renueva el 15 nov» (sin precio cargado)
        case renewsNoPrice(on: Date)
        /// «Termina el 15 nov»
        case ends(on: Date)
    }

    static func activeCardLine(plan: ProActivePlan, price: String?) -> ActiveCardLine? {
        guard let date = plan.expirationDate else { return nil }
        if plan.isTrial {
            if plan.willAutoRenew != false, let price {
                return .trialThenPrice(until: date, price: price, yearly: plan.nextChargeIsYearly)
            }
            return .trialUntil(date)
        }
        if plan.willAutoRenew == false { return .ends(on: date) }
        if let price { return .renews(on: date, price: price, yearly: plan.nextChargeIsYearly) }
        return .renewsNoPrice(on: date)
    }

    // MARK: - L17-7 · El banner de la prueba en el Panel

    /// Días de CALENDARIO entre hoy y el final: 0 = termina hoy, 1 = mañana. Contar bloques de 24 h y truncar decía
    /// «termina hoy» la víspera por la tarde.
    static func calendarDaysRemaining(until end: Date, now: Date, calendar: Calendar) -> Int {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: end)).day ?? 0
        return max(0, days)
    }

    /// Solo los últimos 5 días, el último incluido. Antes salía los 30 y desaparecía justo el último día
    /// (`isTrialExpiringSoon` exige > 0).
    static func showsTrialBanner(isInTrial: Bool, daysRemaining: Int) -> Bool {
        isInTrial && daysRemaining <= 5 && daysRemaining >= 0
    }

    // MARK: - L17-6 · Cuando Pro se acaba

    /// Lo que se le dice a quien se le acabó Pro: la prueba, si lo último activo era la prueba; la suscripción, si
    /// pagó. Sin la marca nueva (se acabó antes de esta versión) decide lo que ya se sabía: si estuvo en prueba.
    static func endedWasTrial(lastActiveWasTrial: Bool?, everWasInTrial: Bool) -> Bool {
        lastActiveWasTrial ?? everWasInTrial
    }

    /// La hoja de fin de Pro sale si hay algo que elegir o un icono que devolver; si no, no hay nada que decir.
    static func endedSheetIsNeeded(hasExcess: Bool, iconWillReset: Bool) -> Bool {
        hasExcess || iconWillReset
    }

    /// «Prueba terminada» no sale si ya salió (la hoja de fin de Pro también lo marca al aparecer) ni si la hoja de fin
    /// de Pro está por salir: una sola hoja (L17-6).
    static func trialExpiredPresents(alreadyShown: Bool, endedSheetPending: Bool) -> Bool {
        !alreadyShown && !endedSheetPending
    }

    // MARK: - L17-5 · La oferta de prueba

    enum TrialOfferDecision: Equatable {
        case present
        /// Ya usó la prueba: la oferta no es para esta persona y se desarma.
        case dropForever
        /// Sin precios no se sabe: no se enseña y se queda armada para el arranque siguiente.
        case holdForLater
    }

    static func trialOfferDecision(eligibilityKnown: Bool, isEligible: Bool) -> TrialOfferDecision {
        guard eligibilityKnown else { return .holdForLater }
        return isEligible ? .present : .dropForever
    }

    // MARK: - L17-6 · Elegir qué se conserva

    enum ToggleResult: Equatable {
        case selected
        case deselected
        /// Ya están todos los del plan gratis: hay que quitar uno antes (se avisa con el nombre del tocado).
        case full
    }

    static func toggle(isSelected: Bool, selectedCount: Int, limit: Int) -> ToggleResult {
        if isSelected { return .deselected }
        return selectedCount < limit ? .selected : .full
    }
}
