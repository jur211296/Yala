//
//  Bienvenida23FinalTests.swift
//  YalaTests
//
//  Lote 05 de la bienvenida 2.3 (docs/onboarding-2-3/SPEC.md): el paso 6 (Y23-14, «Omitir» pasa el mazo al 7), el paso 7
//  (Y23-16, cuatro maneras de anotar sin abrir Yala) y el final (Y23-18, la oferta de la prueba de Pro y su aviso antes
//  del cobro). Lógica pura, sin contexto.
//

import Foundation
import Testing
import UserNotifications

@testable import Yala

@MainActor
@Suite("Bienvenida 2.3 · pasos 6 y 7 y el final (Y23-14, Y23-16, Y23-18)", .serialized)
struct Bienvenida23FinalTests {

    // MARK: - Y23-14 · Paso 6

    /// «Omitir» en la guía del paso 6 la da por omitida (el mazo pasa al 7); terminarla, por hecha.
    @Test func chartsStep_skip_runsOnSkip_andFinish_runsOnFinish() {
        let center = PlaceGuideCenter()
        var finished = 0
        var skipped = 0
        center.start(.chartsStep, onFinish: { finished += 1 }, onSkip: { skipped += 1 })
        center.skip()
        #expect(!center.isActive)
        #expect(skipped == 1)
        #expect(finished == 0)

        center.start(.chartsStep, onFinish: { finished += 1 }, onSkip: { skipped += 1 })
        center.tabDidChange(to: .more)
        center.advance()
        #expect(finished == 1)
        #expect(skipped == 1, "terminarla no la omite")
    }

    /// Irse a otra pestaña la cierra sin resolver el paso: ni hecho ni omitido.
    @Test func chartsStep_leavingToAnotherTab_resolvesNothing() {
        let center = PlaceGuideCenter()
        var resolved = 0
        center.start(.chartsStep, onFinish: { resolved += 1 }, onSkip: { resolved += 1 })
        center.tabDidChange(to: .records)
        #expect(!center.isActive)
        #expect(resolved == 0)
    }

    /// Tocar fuera de la tarjeta la cierra sin omitir el paso: un toque perdido no lo resuelve.
    @Test func chartsStep_tapOutside_resolvesNothing() {
        let center = PlaceGuideCenter()
        var resolved = 0
        center.start(.chartsStep, onFinish: { resolved += 1 }, onSkip: { resolved += 1 })
        center.dismiss()
        #expect(!center.isActive)
        #expect(resolved == 0)
    }

    /// Un cierre colgante sigue siendo «al terminarla», no «al omitirla» (los moldes de antes lo usan así).
    @Test func trailingClosure_isStillOnFinish() {
        let center = PlaceGuideCenter()
        var finished = 0
        center.start(.chartsStep) { finished += 1 }
        center.skip()
        #expect(finished == 0)
        center.start(.chartsStep) { finished += 1 }
        center.tabDidChange(to: .more)
        center.advance()
        #expect(finished == 1)
    }

    /// Lo que arrancó una guía no se le pega a la siguiente: «Omitir» en la de «días después» no toca el paso 6.
    @Test func skipCallback_doesNotLeakToTheNextGuide() {
        let center = PlaceGuideCenter()
        var skipped = 0
        center.start(.chartsStep, onFinish: nil, onSkip: { skipped += 1 })
        center.tabDidChange(to: .records)
        center.start(.chartsLater)
        center.skip()
        #expect(skipped == 0)
    }

    // MARK: - Y23-16 · Paso 7

    /// Cuatro maneras, en el orden de la ficha; sin el correo mientras su servidor no esté desplegado (Y23-19).
    @Test func homeScreen_teachesFourWays_withoutTheEmail() {
        #expect(HomeScreenTutorialLogic.methods == [.widget, .applePay, .share, .siri])
        #expect(HomeScreenTutorialLogic.methods.filter(\.isPro) == [.share])
        #expect(HomeScreenTutorialLogic.position(of: .applePay) == 2)
    }

    @Test func homeScreen_next_isTheFirstUnresolved_inOrder() {
        typealias L = HomeScreenTutorialLogic
        #expect(L.next(after: [:]) == .widget)
        #expect(L.next(after: [.widget: .done]) == .applePay)
        #expect(L.next(after: [.widget: .done, .applePay: .skipped]) == .share)
        #expect(L.next(after: [.widget: .done, .applePay: .skipped, .share: .done, .siri: .skipped]) == nil)
    }

    /// Resolver la última termina el paso; antes, la pantalla de entre medias. «¡Van N de 4!» cuenta solo las vistas.
    @Test func homeScreen_lastResolution_finishes_andCountsOnlyTheDoneOnes() {
        typealias L = HomeScreenTutorialLogic
        #expect(L.exitAfterResolving([.widget: .done]) == nil)
        #expect(L.doneCount([.widget: .done, .applePay: .skipped, .share: .done]) == 2)
        #expect(L.exitAfterResolving([.widget: .done, .applePay: .skipped, .share: .skipped, .siri: .skipped])
            == .finished(anyDone: true))
        #expect(L.exitAfterResolving([.widget: .skipped, .applePay: .skipped, .share: .skipped, .siri: .skipped])
            == .finished(anyDone: false))
    }

    /// Hecho con al menos una manera vista; omitido si las omitió todas o se saltó el paso; «Atrás» no toca el mazo.
    @Test func homeScreen_resolution_ofEachExit() {
        typealias L = HomeScreenTutorialLogic
        #expect(L.resolution(of: .finished(anyDone: true)) == .completed)
        #expect(L.resolution(of: .finished(anyDone: false)) == .skipped)
        #expect(L.resolution(of: .skippedStep) == .skipped)
        #expect(L.resolution(of: .closed) == nil)
    }

    // MARK: - Y23-18 · Final y oferta de Pro

    /// 1,6 s tras la tarjeta del final; 0,2 s con Reducir movimiento (el prototipo).
    @Test func offer_risesAfterTheCard() {
        #expect(SetupCompleteTrialOfferLogic.offerDelay(reduceMotion: false) == .milliseconds(1600))
        #expect(SetupCompleteTrialOfferLogic.offerDelay(reduceMotion: true) == .milliseconds(200))
    }

    /// El aviso cae dos días de calendario antes del cobro, a las 10:00, también al cruzar de mes.
    @Test func reminder_isTwoCalendarDaysBeforeTheCharge_atTen() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Lima"))
        let charge = try #require(calendar.date(from: DateComponents(year: 2026, month: 12, day: 12, hour: 19, minute: 4)))
        let reminder = try #require(SetupCompleteTrialOfferLogic.reminderDate(chargeDate: charge, calendar: calendar))
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminder)
        #expect(parts == DateComponents(year: 2026, month: 12, day: 10, hour: 10, minute: 0))

        let earlyMonth = try #require(calendar.date(from: DateComponents(year: 2027, month: 3, day: 1, hour: 8)))
        let crossing = try #require(SetupCompleteTrialOfferLogic.reminderDate(chargeDate: earlyMonth, calendar: calendar))
        #expect(calendar.dateComponents([.month, .day], from: crossing) == DateComponents(month: 2, day: 27))
    }

    /// Solo se agenda con fecha futura.
    @Test func reminder_onlyInTheFuture() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(SetupCompleteTrialOfferLogic.schedulesReminder(at: now.addingTimeInterval(60), now: now))
        #expect(!SetupCompleteTrialOfferLogic.schedulesReminder(at: now, now: now))
        #expect(!SetupCompleteTrialOfferLogic.schedulesReminder(at: nil, now: now))
    }

    /// Nunca se pide permiso: solo se agenda con el que ya hay (ni diálogo de iOS ni provisional).
    @Test func reminder_onlyWithPermissionAlreadyGiven() {
        typealias L = SetupCompleteTrialOfferLogic
        #expect(L.canScheduleReminder(.authorized))
        #expect(L.canScheduleReminder(.provisional))
        #expect(L.canScheduleReminder(.ephemeral))
        #expect(!L.canScheduleReminder(.notDetermined))
        #expect(!L.canScheduleReminder(.denied))
    }

    /// «El … te avisamos» solo con el aviso agendado y su fecha futura (en Sandbox un mes dura minutos).
    @Test func reminder_isAnnouncedOnlyWhenScheduledAndInTheFuture() {
        typealias L = SetupCompleteTrialOfferLogic
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(L.announcesReminder(now.addingTimeInterval(3600), scheduled: true, now: now))
        #expect(!L.announcesReminder(now.addingTimeInterval(3600), scheduled: false, now: now))
        #expect(!L.announcesReminder(now.addingTimeInterval(-60), scheduled: true, now: now))
        #expect(!L.announcesReminder(nil, scheduled: true, now: now))
    }

    /// El aviso prometido se repone mientras la prueba siga y renueve; cancelada o terminada, se retira y se olvida.
    @Test func reminder_reconcile_followsTheSubscription() {
        typealias L = SetupCompleteTrialOfferLogic
        let charge = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(L.reconcile(owed: false, isTrial: true, willAutoRenew: true, chargeDate: charge) == .nothing)
        #expect(L.reconcile(owed: true, isTrial: true, willAutoRenew: true, chargeDate: charge) == .ensure(chargeDate: charge))
        #expect(L.reconcile(owed: true, isTrial: true, willAutoRenew: nil, chargeDate: charge) == .ensure(chargeDate: charge))
        #expect(L.reconcile(owed: true, isTrial: true, willAutoRenew: false, chargeDate: charge) == .removeAndForget)
        #expect(L.reconcile(owed: true, isTrial: false, willAutoRenew: true, chargeDate: nil) == .removeAndForget)
    }

    /// Lo que se apunta en el acto (las marcas de la red del arranque) no espera al envío retrasado de la oferta.
    @Test func setupCompletedMoment_armsRightAway_evenWithADelayedSubmit() {
        let session = SessionState.shared
        let armed = session.needsPostOnboardingTrial
        let reached = session.trialOfferMomentReached
        defer {
            session.needsPostOnboardingTrial = armed
            session.trialOfferMomentReached = reached
        }
        session.needsPostOnboardingTrial = false
        session.trialOfferMomentReached = false
        TrialOfferMoments.note(.setupChecklistCompleted, submitDelay: .seconds(3600))
        if !FeatureGateService.shared.isProUser {
            #expect(session.needsPostOnboardingTrial)
            #expect(session.trialOfferMomentReached)
        }
    }
}
