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
//   3. **Con el mazo de 2.3, al terminar «Aprender a registrar»** (opción B de Jürgen, 20-nov-2026): la persona acaba
//      de probar voz, foto o Yala IA gratis una vez. Mientras el mazo está a medias, el momento 1 se calla
//      (`isHeldByPrimerosPasos`), y si esta oferta ya salió el final de Primeros pasos no la repite.
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
    /// Se terminó «Aprender a registrar» (paso 2) por su tutorial, ya contestado «¿Borramos los de prueba?». Es el
    /// momento de la oferta en una instalación con el mazo (opción B de Jürgen, 20-nov-2026).
    case recordStepFinished
    /// Arranque de alguien que ya completó el onboarding.
    case launch
}

enum TrialOfferMomentLogic {

    /// Si este momento ARMA la oferta, aunque no estuviera armada. Solo los de «Primeros pasos»: el primer momento
    /// se arma al terminar el alta.
    static func arms(_ moment: TrialOfferMoment, isProUser: Bool) -> Bool {
        (moment == .setupChecklistCompleted || moment == .recordStepFinished) && !isProUser
    }

    /// Con Primeros pasos a la vista y a medias, guardar un registro (o contestar «¿Era de prueba?») no pide la oferta:
    /// su momento es el final del paso 2 (opción B de Jürgen, 20-nov-2026). Sin esto la oferta de 2.2 salía dentro del
    /// tutorial, al guardar el primer registro del formulario. No marca el momento como alcanzado: la red del arranque
    /// tampoco la saca.
    static func isHeldByPrimerosPasos(_ moment: TrialOfferMoment, primerosPasosShown: Bool) -> Bool {
        guard primerosPasosShown else { return false }
        switch moment {
        case .recordSaved, .firstRecordPracticeAnswered: return true
        case .setupChecklistCompleted, .recordStepFinished, .launch: return false
        }
    }

    /// Si este momento cuenta como «ya llegó el momento» para la red del arranque.
    static func reachesTheMoment(_ moment: TrialOfferMoment) -> Bool {
        switch moment {
        case .recordSaved, .firstRecordPracticeAnswered, .setupChecklistCompleted, .recordStepFinished: return true
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
        case .firstRecordPracticeAnswered, .setupChecklistCompleted, .recordStepFinished:
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

    /// Terminó «Aprender a registrar» por su tutorial (opción B de Jürgen, 20-nov-2026): en una instalación con el mazo,
    /// la oferta del mes de Pro sale aquí y nombra lo que la persona probó gratis. Se apunta que ya se pidió: el final
    /// de Primeros pasos no la repite.
    /// - Parameter submitDelay: con el aviso «Borramos N registros de prueba» a la vista, la oferta espera a que se vaya:
    ///   presentarla lo retira en el acto (`SavedRecordNotice`) y nadie llegaba a leerlo.
    static func noteRecordStepFinished(triedMethods: [RecordTutorialLogic.Method], submitDelay: Duration? = nil) {
        guard SetupChecklistManager.shared.showsDeck else { return }
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: SetupCompleteTrialOfferLogic.pendingOfferKey)
        defaults.set(true, forKey: SetupCompleteTrialOfferLogic.offeredAfterRecordStepKey)
        defaults.set(SetupCompleteTrialOfferLogic.storedTriedMethods(triedMethods),
                     forKey: SetupCompleteTrialOfferLogic.triedMethodsKey)
        note(.recordStepFinished, submitDelay: submitDelay)
    }

    /// - Parameter submitDelay: las marcas se escriben en el acto (la red del arranque las necesita si la app muere) y
    ///   solo el envío al router espera (Y23-18: la oferta del final sube tras la tarjeta «¡Primeros pasos completos!»).
    static func note(_ moment: TrialOfferMoment, submitDelay: Duration? = nil) {
        if TrialOfferMomentLogic.isHeldByPrimerosPasos(
            moment, primerosPasosShown: SetupChecklistManager.shared.isPrimerosPasosShown) {
            #if DEBUG
            print("TrialOfferMoments: \(moment) ignorado: su momento es el final del paso 2 de Primeros pasos")
            #endif
            return
        }
        let session = SessionState.shared
        let isPro = FeatureGateService.shared.isProUser
        #if DEBUG
        if isPro { print("TrialOfferMoments: \(moment) sin oferta: ya es Pro") }
        #endif
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
            guard let submitDelay else {
                RouterEntryGate.shared.submit(.presentTrialOffer)
                return
            }
            Task { @MainActor in
                do { try await Task.sleep(for: submitDelay) } catch { return }
                RouterEntryGate.shared.submit(.presentTrialOffer)
            }
        }
    }
}
