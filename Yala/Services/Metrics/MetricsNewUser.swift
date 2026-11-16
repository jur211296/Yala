//
//  MetricsNewUser.swift
//  Yala
//
//  Telemetría del usuario nuevo DESPUÉS del alta (card 4b7h, 2026-11-13; revisión del usuario nuevo, §5 y §7.1). El
//  embudo del alta acaba en `alta.termina`; esto mide lo de después: el primer registro, presupuesto, pago y la segunda
//  cuenta, y cómo recorre Primeros pasos. Todo son eventos `use` de UNA VEZ POR INSTALACIÓN (`MetricsOnceLogic`).
//
//  **Lo que se borra como «Era de prueba» no cuenta** (criterio de activación de la revisión): el primer registro,
//  presupuesto o pago no sale al guardarse, sino cuando se sabe que se queda:
//   · si su paso del mazo ya estaba hecho, no habrá pregunta y sale en el acto;
//   · si no, espera a que el paso se cierre (`SetupChecklistManager.markCompleted`): sin «¿Era de prueba?», sale ahí; con
//     ella, espera la respuesta. «Guardarlo» lo emite; «Borrarlo» lo descarta y el siguiente vuelve a ser el primero;
//   · el tutorial de «Aprender a registrar» retiene el paso hasta su hoja final («¿Borramos los de prueba?»);
//   · lo que sigue esperando al ARRANCAR se emite: borrar solo pasa contestando, así que si la respuesta no llegó (iOS
//     cerró Yala con la pregunta en pantalla), el registro se quedó. Salvo el registro con el tutorial aún en marcha y
//     menos de 24 h de espera: cerrar el tutorial con la X después de probar una manera lo deja en marcha hasta que se
//     retome, y sin ese plazo el primer registro de quien lo abandona no saldría nunca (review adversarial).
//
//  Privacidad: viaja el slug y nada más. Bajo `-uitest` y en tests no se apunta nada (`MetricsService.eventDefaults`).
//

import Foundation
import SwiftData

/// Decisiones puras del usuario nuevo. Sin estado ni efectos: lo prueban los tests sin servicio.
@MainActor
enum NewUserMilestoneLogic {

    /// El hito que cierra un «crea tu primer X» del mazo. Las prácticas de voz y foto crean BORRADORES, no registros.
    static func milestone(for step: SetupStepID) -> MetricsUseFeature? {
        switch step {
        case .firstExpense: return .primerosRegistro
        case .firstBudget: return .primerosPresupuesto
        case .scheduledPayment: return .primerosPago
        case .firstAccount, .groups, .whereMoneyGoes, .homeScreen, .tryVoiceInput, .tryImageInput: return nil
        }
    }

    /// El paso del mazo hecho. Sin `default`: un paso nuevo del mazo tiene que decidir su slug.
    static func deckStepDone(_ step: SetupStepID) -> MetricsUseFeature? {
        switch step {
        case .firstAccount: return .primerosPasosCuenta
        case .firstExpense: return .primerosPasosRegistrar
        case .firstBudget: return .primerosPasosPresupuesto
        case .scheduledPayment: return .primerosPasosPagos
        case .groups: return .primerosPasosGrupo
        case .whereMoneyGoes: return .primerosPasosDinero
        case .homeScreen: return .primerosPasosInicio
        case .tryVoiceInput, .tryImageInput: return nil
        }
    }

    /// Al crear: con el paso ya hecho no habrá «¿Era de prueba?» y sale en el acto; si no, espera a que el paso se cierre.
    static func emitsOnCreation(stepAlreadyCompleted: Bool) -> Bool {
        stepAlreadyCompleted
    }

    /// Lo que espera el registro a la hoja final de un tutorial que sigue en marcha. Pasado esto, se da por abandonado.
    static let recordTutorialWaitCeiling: TimeInterval = 24 * 3600

    /// Al arrancar, lo que esperaba sale, salvo el registro con el tutorial en marcha y menos de 24 h de espera: su hoja
    /// final aún puede preguntar. `waitingSince` = cuándo empezó a esperar (`nil`: no se sabe, y se da por vencido).
    static func emitsAtLaunch(
        _ milestone: MetricsUseFeature, recordTutorialRunning: Bool, waitingSince: Date?, now: Date
    ) -> Bool {
        guard milestone == .primerosRegistro, recordTutorialRunning, let waitingSince else { return true }
        return now.timeIntervalSince(waitingSince) >= recordTutorialWaitCeiling
    }

    /// La segunda cuenta: tras crear una, la persona tiene al menos dos propias.
    static func reachesSecondAccount(billableAccounts: Int) -> Bool {
        billableAccounts >= 2
    }
}

/// El lado con efectos: guarda lo que espera en el `UserDefaults` del servicio y emite por `MetricsService.used`, que pone el
/// «una vez por instalación» y el «solo instalaciones nuevas».
@MainActor
enum NewUserMetrics {

    // MARK: Primer registro, presupuesto y pago

    /// Se guardó algo NUEVO del tipo de `step` (registro, presupuesto, pago). Se llama antes de que la pantalla marque el
    /// paso: el orden es el del guardado de siempre (guardar → `markFirstCreation`).
    static func created(_ step: SetupStepID) {
        created(step, stepAlreadyCompleted: SetupChecklistManager.shared.stepCompleted[step] == true)
    }

    static func created(_ step: SetupStepID, stepAlreadyCompleted: Bool) {
        guard let milestone = NewUserMilestoneLogic.milestone(for: step), isNewUser() else { return }
        if NewUserMilestoneLogic.emitsOnCreation(stepAlreadyCompleted: stepAlreadyCompleted) {
            MetricsService.used(milestone)
        } else {
            setWaiting(milestone, true)
        }
    }

    /// El paso del mazo quedó hecho (`SetupChecklistManager.markCompleted`, después de su guarda). Emite el paso y, si no
    /// viene «¿Era de prueba?», el hito que esperaba.
    static func stepCompleted(_ step: SetupStepID, practicePending: Bool) {
        if let done = NewUserMilestoneLogic.deckStepDone(step) { MetricsService.used(done) }
        guard !practicePending, let milestone = NewUserMilestoneLogic.milestone(for: step) else { return }
        releaseWaiting(milestone)
    }

    /// Se contestó «¿Era de prueba?». Guardarlo emite lo que esperaba; borrarlo lo descarta.
    static func practiceAnswered(step: SetupStepID?, kept: Bool) {
        guard let step, let milestone = NewUserMilestoneLogic.milestone(for: step) else { return }
        if kept {
            releaseWaiting(milestone)
        } else {
            setWaiting(milestone, false)
        }
    }

    /// La hoja final del tutorial de registro: si no se quedó ningún REGISTRO (los borradores de voz y foto no lo son), el
    /// primer registro no ha pasado todavía. Va antes de cerrar el paso (`RecordTutorialSession.finish`).
    static func recordTutorialFinished(keptARecord: Bool) {
        guard !keptARecord else { return }
        setWaiting(.primerosRegistro, false)
    }

    /// En el arranque, tras `MetricsService.start()`: lo que se quedó esperando una respuesta que no llegó.
    static func releaseWaitingAtLaunch(recordTutorialRunning: Bool, now: Date = .now) {
        for (milestone, since) in waitingSince() where NewUserMilestoneLogic.emitsAtLaunch(
            milestone, recordTutorialRunning: recordTutorialRunning, waitingSince: since, now: now) {
            releaseWaiting(milestone)
        }
    }

    /// Una RE-ENTRADA (restaurar con todo, retomar «solo grupos», adoptar una cuenta de la nube): sus datos ya existían, así
    /// que lo que haga a partir de aquí no es un «primero». Retira la marca que pudo dejar un alta anterior en este
    /// teléfono (p. ej. un alta solo de grupos) y lo que esperaba.
    static func reentered() {
        guard let target = MetricsService.eventDefaults() else { return }
        target.removeObject(forKey: MetricsService.newUserKey)
        target.removeObject(forKey: MetricsService.waitingMilestonesKey)
    }

    // MARK: Segunda cuenta

    /// Se creó una cuenta (formulario o paso 1 del mazo). Cuenta las propias, como Primeros pasos (`isBillableUserAccount`).
    static func accountCreated(in context: ModelContext) {
        guard isNewUser() else { return }
        do {
            let billable = try context.fetch(FetchDescriptor<Account>()).count(where: \.isBillableUserAccount)
            if NewUserMilestoneLogic.reachesSecondAccount(billableAccounts: billable) {
                MetricsService.used(.primerosCuenta2)
            }
        } catch {
            #if DEBUG
            print("NewUserMetrics: Error: counting accounts: \(error)")
            #endif
        }
    }

    // MARK: Estado

    private static func isNewUser() -> Bool {
        MetricsService.eventDefaults()?.bool(forKey: MetricsService.newUserKey) == true
    }

    /// `[slug: segundos desde 1970]`: lo que espera y desde cuándo.
    private static func waitingStore() -> [String: Double] {
        MetricsService.eventDefaults()?.dictionary(forKey: MetricsService.waitingMilestonesKey) as? [String: Double] ?? [:]
    }

    private static func waitingSince() -> [(MetricsUseFeature, Date)] {
        waitingStore().compactMap { slug, since in
            MetricsUseFeature(rawValue: slug).map { ($0, Date(timeIntervalSince1970: since)) }
        }
    }

    /// Esperar otra vez no mueve el «desde cuándo»: el plazo del tutorial cuenta desde el primero.
    private static func setWaiting(_ milestone: MetricsUseFeature, _ isWaiting: Bool, now: Date = .now) {
        guard let target = MetricsService.eventDefaults() else { return }
        var store = waitingStore()
        if isWaiting {
            if store[milestone.rawValue] == nil { store[milestone.rawValue] = now.timeIntervalSince1970 }
        } else {
            store[milestone.rawValue] = nil
        }
        if store.isEmpty {
            target.removeObject(forKey: MetricsService.waitingMilestonesKey)
        } else {
            target.set(store, forKey: MetricsService.waitingMilestonesKey)
        }
    }

    /// Emite lo que esperaba, si esperaba.
    private static func releaseWaiting(_ milestone: MetricsUseFeature) {
        guard waitingStore()[milestone.rawValue] != nil else { return }
        setWaiting(milestone, false)
        MetricsService.used(milestone)
    }
}
