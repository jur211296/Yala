//
//  ProPlanStatusLogicTests.swift
//  YalaTests
//
//  Auditoría UX 2.2 · lote decidido 06 (Yala Pro). Lo que Yala dice del plan y qué aviso sale cuando Pro se acaba:
//  cada rama de `ProPlanStatusLogic`, con el caso vecino que NO debe dar lo mismo.
//

import Foundation
import StoreKit
import Testing

@testable import Yala

@MainActor
@Suite("ProPlanStatusLogic · plan Pro, prueba y fin de Pro")
struct ProPlanStatusLogicTests {

    typealias L = ProPlanStatusLogic

    private static let date = Date(timeIntervalSince1970: 1_800_000_000)

    private static func plan(yearly: Bool = true, trial: Bool = false, renews: Bool? = true, date: Date? = date)
        -> ProActivePlan {
        ProActivePlan(isYearly: yearly, expirationDate: date, isTrial: trial, willAutoRenew: renews)
    }

    // MARK: L17-4 · el botón que lleva a Pro

    @Test("«Probar Pro gratis» solo si se midió que la cuenta tiene la prueba")
    func upgradeLabel() {
        #expect(L.upgradeLabel(eligibilityKnown: true, isEligible: true) == .tryFree)
        #expect(L.upgradeLabel(eligibilityKnown: true, isEligible: false) == .switchToPro)
        // Sin precios no se sabe: no se promete (el `true` inicial de StoreKitManager no es una medida).
        #expect(L.upgradeLabel(eligibilityKnown: false, isEligible: true) == .switchToPro)
    }

    // MARK: L17-1 · la fila de Ajustes

    @Test("Gratis: con la prueba disponible la ofrece; sin ella, «Gratis» a secas")
    func settingsStatus_free() {
        #expect(L.settingsStatus(isPro: false, plan: nil, offeredTrialDays: 30) == .freeWithTrial(days: 30))
        #expect(L.settingsStatus(isPro: false, plan: nil, offeredTrialDays: nil) == .free)
        #expect(L.settingsStatus(isPro: false, plan: nil, offeredTrialDays: 0) == .free)
        // Un plan local que aún figura no cuenta si ya no es Pro.
        #expect(L.settingsStatus(isPro: false, plan: Self.plan(), offeredTrialDays: nil) == .free)
    }

    @Test("Pro: la prueba dice cuándo termina; lo pagado, cuándo se renueva o termina")
    func settingsStatus_pro() {
        #expect(L.settingsStatus(isPro: true, plan: Self.plan(trial: true), offeredTrialDays: nil) == .trialEnds(Self.date))
        #expect(L.settingsStatus(isPro: true, plan: Self.plan(), offeredTrialDays: nil) == .renews(yearly: true, on: Self.date))
        #expect(L.settingsStatus(isPro: true, plan: Self.plan(yearly: false), offeredTrialDays: nil)
                == .renews(yearly: false, on: Self.date))
        #expect(L.settingsStatus(isPro: true, plan: Self.plan(renews: false), offeredTrialDays: nil)
                == .ends(yearly: true, on: Self.date))
        // Sin dato de renovación se asume la renovación (lo normal), no el final.
        #expect(L.settingsStatus(isPro: true, plan: Self.plan(renews: nil), offeredTrialDays: nil)
                == .renews(yearly: true, on: Self.date))
        #expect(L.settingsStatus(isPro: true, plan: nil, offeredTrialDays: 30) == .proActive)
        #expect(L.settingsStatus(isPro: true, plan: Self.plan(date: nil), offeredTrialDays: nil) == .proActive)
    }

    // MARK: L17-8 · la tarjeta del plan

    @Test("La prueba dice hasta cuándo y qué se cobra después; sin renovación, solo hasta cuándo")
    func activeCardLine_trial() {
        #expect(L.activeCardLine(plan: Self.plan(trial: true), price: "$29.99")
                == .trialThenPrice(until: Self.date, price: "$29.99", yearly: true))
        #expect(L.activeCardLine(plan: Self.plan(trial: true, renews: false), price: "$29.99") == .trialUntil(Self.date))
        #expect(L.activeCardLine(plan: Self.plan(trial: true), price: nil) == .trialUntil(Self.date))
    }

    @Test("Lo pagado: se renueva con precio, sin precio, o termina")
    func activeCardLine_paid() {
        #expect(L.activeCardLine(plan: Self.plan(yearly: false), price: "$4.99")
                == .renews(on: Self.date, price: "$4.99", yearly: false))
        #expect(L.activeCardLine(plan: Self.plan(), price: nil) == .renewsNoPrice(on: Self.date))
        #expect(L.activeCardLine(plan: Self.plan(renews: false), price: "$29.99") == .ends(on: Self.date))
        #expect(L.activeCardLine(plan: Self.plan(date: nil), price: "$29.99") == nil)
    }

    // MARK: L17-7 · el banner

    @Test("El banner de la prueba, solo los últimos 5 días y también el último")
    func trialBanner() {
        #expect(!L.showsTrialBanner(isInTrial: true, daysRemaining: 6))
        #expect(L.showsTrialBanner(isInTrial: true, daysRemaining: 5))
        #expect(L.showsTrialBanner(isInTrial: true, daysRemaining: 1))
        // `isTrialExpiringSoon` exigía > 0 y el banner desaparecía justo el último día.
        #expect(L.showsTrialBanner(isInTrial: true, daysRemaining: 0))
        #expect(!L.showsTrialBanner(isInTrial: false, daysRemaining: 3))
    }

    @Test("Los días de la prueba se cuentan por calendario: la víspera es «mañana», no «hoy»")
    func calendarDaysRemaining() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Lima") ?? .gmt
        let end = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 15, hour: 10)))
        let eveAfternoon = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 14, hour: 12)))
        let sameDayMorning = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 15, hour: 8)))
        let threeBefore = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 12, hour: 23)))
        #expect(L.calendarDaysRemaining(until: end, now: eveAfternoon, calendar: calendar) == 1)
        // Control: contar bloques de 24 h daba 0 («termina hoy») la víspera.
        #expect(calendar.dateComponents([.day], from: eveAfternoon, to: end).day == 0)
        #expect(L.calendarDaysRemaining(until: end, now: sameDayMorning, calendar: calendar) == 0)
        #expect(L.calendarDaysRemaining(until: end, now: threeBefore, calendar: calendar) == 3)
        #expect(L.calendarDaysRemaining(until: eveAfternoon, now: end, calendar: calendar) == 0)
    }

    @Test("El precio del próximo cobro es el del plan al que se renueva")
    func nextChargeFollowsTheRenewalPlan() {
        var switched = Self.plan(yearly: true)
        switched.renewsYearly = false
        #expect(L.activeCardLine(plan: switched, price: "$4.99") == .renews(on: Self.date, price: "$4.99", yearly: false))
        var trial = Self.plan(yearly: true, trial: true)
        trial.renewsYearly = false
        #expect(L.activeCardLine(plan: trial, price: "$4.99")
                == .trialThenPrice(until: Self.date, price: "$4.99", yearly: false))
        // Sin dato de Apple, el plan de ahora.
        #expect(Self.plan(yearly: true).nextChargeIsYearly)
        // La fila de Ajustes sigue nombrando el plan de AHORA.
        #expect(L.settingsStatus(isPro: true, plan: switched, offeredTrialDays: nil) == .renews(yearly: true, on: Self.date))
    }

    // MARK: L17-6 · fin de Pro

    @Test("El título de la hoja: la marca precisa manda; sin ella, si alguna vez estuvo en prueba")
    func endedWasTrial() {
        #expect(L.endedWasTrial(lastActiveWasTrial: true, everWasInTrial: false))
        #expect(!L.endedWasTrial(lastActiveWasTrial: false, everWasInTrial: true))
        #expect(L.endedWasTrial(lastActiveWasTrial: nil, everWasInTrial: true))
        #expect(!L.endedWasTrial(lastActiveWasTrial: nil, everWasInTrial: false))
    }

    @Test("La hoja sale si hay algo que elegir o un icono que devolver")
    func endedSheetIsNeeded() {
        #expect(L.endedSheetIsNeeded(hasExcess: true, iconWillReset: false))
        #expect(L.endedSheetIsNeeded(hasExcess: false, iconWillReset: true))
        #expect(!L.endedSheetIsNeeded(hasExcess: false, iconWillReset: false))
    }

    @Test("«Prueba terminada» no sale tras la hoja de fin de Pro ni con ella pendiente")
    func trialExpiredPresents() {
        #expect(L.trialExpiredPresents(alreadyShown: false, endedSheetPending: false))
        #expect(!L.trialExpiredPresents(alreadyShown: true, endedSheetPending: false))
        #expect(!L.trialExpiredPresents(alreadyShown: false, endedSheetPending: true))
    }

    // MARK: L17-5 · la oferta

    @Test("La oferta: con derecho sale; sin derecho, nunca; sin saberlo, espera")
    func trialOfferDecision() {
        #expect(L.trialOfferDecision(eligibilityKnown: true, isEligible: true) == .present)
        #expect(L.trialOfferDecision(eligibilityKnown: true, isEligible: false) == .dropForever)
        #expect(L.trialOfferDecision(eligibilityKnown: false, isEligible: true) == .holdForLater)
        #expect(L.trialOfferDecision(eligibilityKnown: false, isEligible: false) == .holdForLater)
    }

    // MARK: L17-6 · elegir qué se conserva

    @Test("Tocar uno de más con el cupo lleno no elige: avisa")
    func toggle() {
        #expect(L.toggle(isSelected: false, selectedCount: 2, limit: 3) == .selected)
        #expect(L.toggle(isSelected: false, selectedCount: 3, limit: 3) == .full)
        #expect(L.toggle(isSelected: true, selectedCount: 3, limit: 3) == .deselected)
        #expect(L.toggle(isSelected: true, selectedCount: 1, limit: 3) == .deselected)
    }
}

@MainActor
@Suite("PaywallPricingLogic · cuándo se cobra la prueba")
struct PaywallFirstChargeDateTests {

    private static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Lima") ?? .gmt
        return c
    }

    private static func day(_ y: Int, _ m: Int, _ d: Int) throws -> Date {
        try #require(calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 10)))
    }

    @Test("Un mes de prueba que empieza el 15 de octubre se cobra el 15 de noviembre, no a los 30 días")
    func month_isCalendarMonth() throws {
        let start = try Self.day(2026, 10, 15)
        let charge = PaywallPricingLogic.firstChargeDate(from: start, unit: .month, value: 1, calendar: Self.calendar)
        #expect(charge == (try Self.day(2026, 11, 15)))
        // Control: `días × 30` habría dado el 14.
        #expect(charge != Self.calendar.date(byAdding: .day, value: 30, to: start))
    }

    @Test("Días, semanas y años con su unidad")
    func otherUnits() throws {
        let start = try Self.day(2026, 10, 15)
        #expect(PaywallPricingLogic.firstChargeDate(from: start, unit: .day, value: 7, calendar: Self.calendar)
                == (try Self.day(2026, 10, 22)))
        #expect(PaywallPricingLogic.firstChargeDate(from: start, unit: .week, value: 2, calendar: Self.calendar)
                == (try Self.day(2026, 10, 29)))
        #expect(PaywallPricingLogic.firstChargeDate(from: start, unit: .year, value: 1, calendar: Self.calendar)
                == (try Self.day(2027, 10, 15)))
    }
}
