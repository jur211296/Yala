//
//  TrialOfferMomentLogic.swift
//  Yala
//
//  CUÁNDO se ofrece la prueba gratis de Yala Pro a quien acaba de darse de alta (UX 2.2 · L1-12, decisión
//  de Jürgen del 2026-10-13: opción B, y además al terminar «Primeros pasos»).
//
//  Hasta 2.2 salía 0,8 s después de cerrar el onboarding, encima del Panel y de su primer tip: quien nunca
//  usó una app financiera recibía un muro de pago antes de apuntar nada. Ahora hay dos momentos, los dos de
//  éxito:
//
//   1. **Tras guardar un registro.** El one-shot `needsPostOnboardingTrial` se sigue armando al terminar el
//      alta (`EntryOnboardingEffects.armsTrialOffer`), pero ya no se presenta al cerrar el onboarding: se
//      pide al aparecer la pantalla de «guardado» (registro, borrador de la Bandeja, aprobación en bloque), y
//      el router lo retiene hasta que esa hoja se cierre (`waitsForForeignPresentation`). **Si el registro
//      es el primero de verdad**, detrás viene el aviso «¿Era de prueba?» del Panel; la oferta espera a que
//      se conteste, porque dos presentaciones de dos anchors distintos que se liberan a la vez pueden pisarse
//      (la regla de «Presentaciones» de `swiftui-ds.md`).
//   2. **Al completar «Primeros pasos».** Se vuelve a armar y a pedir, si no es Pro. Su último paso
//      («Descubre qué más puede hacer Yala») abría el paywall general; cuando ese paso es el que completa la
//      lista, la oferta lo sustituye para no enseñar dos muros seguidos (`PanelView.handleSetupStep`).
//
//  LA RED DEL ARRANQUE. El intent es transitorio (un paso a segundo plano lo tira), y por eso un momento ya
//  alcanzado se apunta en `trialOfferMomentReached`: si al arrancar la oferta sigue armada y su momento ya
//  llegó, se vuelve a pedir. Sin momento alcanzado, el arranque NO la presenta — eso era el comportamiento
//  de antes y es justo lo que L1-12 retira. Las dos marcas se apagan en el drenaje (presentación real).
//

import Foundation

enum TrialOfferMoment: Equatable {
    /// Apareció una pantalla de «guardado». `firstRecordPracticePending` = detrás viene «¿Era de prueba?».
    case recordSaved(firstRecordPracticePending: Bool)
    /// Se contestó «¿Era de prueba?» del primer registro (conservar o borrar).
    case firstRecordPracticeAnswered
    /// Se completó el último paso de «Primeros pasos».
    case setupChecklistCompleted
    /// Arranque de alguien que ya completó el onboarding.
    case launch
}

enum TrialOfferMomentLogic {

    /// Si este momento ARMA la oferta, aunque no estuviera armada. Solo «Primeros pasos»: el primer momento
    /// se arma al terminar el alta.
    static func arms(_ moment: TrialOfferMoment, isProUser: Bool) -> Bool {
        moment == .setupChecklistCompleted && !isProUser
    }

    /// Si este momento cuenta como «ya llegó el momento» para la red del arranque.
    static func reachesTheMoment(_ moment: TrialOfferMoment) -> Bool {
        switch moment {
        case .recordSaved, .firstRecordPracticeAnswered, .setupChecklistCompleted: return true
        case .launch: return false
        }
    }

    /// Si hay que pedir la oferta ahora.
    ///
    /// - Parameters:
    ///   - armed: `needsPostOnboardingTrial` DESPUÉS de aplicar `arms`.
    ///   - momentReached: `trialOfferMomentReached` tal como estaba antes de este momento.
    static func shouldSubmit(_ moment: TrialOfferMoment, armed: Bool, momentReached: Bool, isProUser: Bool) -> Bool {
        guard armed, !isProUser else { return false }
        switch moment {
        case .recordSaved(let practicePending):
            return !practicePending
        case .firstRecordPracticeAnswered, .setupChecklistCompleted:
            return true
        case .launch:
            return momentReached
        }
    }
}

/// El lado con efectos: lee y escribe las dos marcas de `SessionState` y pide la oferta al router.
@MainActor
enum TrialOfferMoments {

    /// Apareció una pantalla de «guardado». Si detrás viene «¿Era de prueba?» del primer registro, la oferta
    /// espera a esa respuesta (`notePracticeAnswered`).
    static func noteRecordSaved() {
        let practice = SetupChecklistManager.shared.pendingPracticeCleanup
        note(.recordSaved(firstRecordPracticePending: practice?.stepID == .firstExpense))
    }

    /// Se contestó un «¿Era de prueba?». Solo cuenta el del primer REGISTRO: el de un presupuesto o un pago
    /// planificado no es el momento que eligió Jürgen.
    static func notePracticeAnswered(_ item: PracticeCleanupItem?) {
        guard item?.stepID == .firstExpense else { return }
        note(.firstRecordPracticeAnswered)
    }

    static func note(_ moment: TrialOfferMoment) {
        let session = SessionState.shared
        let isPro = FeatureGateService.shared.isProUser
        if TrialOfferMomentLogic.arms(moment, isProUser: isPro) {
            session.needsPostOnboardingTrial = true
        }
        let wasReached = session.trialOfferMomentReached
        guard session.needsPostOnboardingTrial else { return }
        if TrialOfferMomentLogic.reachesTheMoment(moment), !wasReached {
            session.trialOfferMomentReached = true
        }
        if TrialOfferMomentLogic.shouldSubmit(
            moment, armed: session.needsPostOnboardingTrial, momentReached: wasReached, isProUser: isPro) {
            RouterEntryGate.shared.submit(.presentTrialOffer)
        }
    }
}
