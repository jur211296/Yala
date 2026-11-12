//
//  GroupsEmptyStepsLogic.swift
//  Yala
//
//  Auditoría UX 2.2 · L12-2 (decisión de Jürgen del 15-oct: variante 2, con el botón morado). Los cinco estados vacíos de
//  la pestaña Grupos comparten una tarjeta; los que están en el camino hacia el primer grupo enseñan sus tres pasos
//  (cuenta, aceptar, crear e invitar) y marcan el que toca.
//
//  Pura: decide QUÉ tarjeta corresponde a cada `GroupsEmptyStateLogic.Kind`, sin textos ni vistas. El orden de los pasos
//  espeja el de `GroupsGateLogic`: lo que la tarjeta anuncia es lo que el toque va a pedir.
//

import Foundation

nonisolated enum GroupsEmptyStepsLogic {

    /// Los tres pasos hacia el primer grupo, en el orden en que los pide la puerta.
    enum Step: Int, CaseIterable, Equatable {
        case account = 1
        case consent = 2
        case create = 3
    }

    enum StepState: Equatable {
        case done
        case current
        case upcoming
    }

    /// Qué hace el botón de la tarjeta. El destino lo pone la vista con el callback de siempre de cada estado.
    enum Action: Equatable {
        /// «Toca aquí y te lo contamos»: el educativo o el consentimiento, que explican antes de pedir nada.
        case tellMe
        case createAccount
        case createGroup
        case signIn
    }

    struct Card: Equatable {
        /// `nil` = tarjeta sin pasos (no es el camino hacia un primer grupo).
        let currentStep: Step?
        let action: Action

        var showsSteps: Bool { currentStep != nil }
        /// «Te lleva un minuto…» solo mientras falta algo antes de crear: con la cuenta y el consentimiento hechos, crear
        /// es el último toque y la nota sobra.
        var showsFootnote: Bool { currentStep == .account || currentStep == .consent }
    }

    /// - Parameters:
    ///   - kind: el estado que ya decidió `GroupsEmptyStateLogic.decide`.
    ///   - flagOn: `CloudSyncFlags.groupsBackendEnabled`. Apagado no hay cuenta ni consentimiento que contar.
    ///   - hasArchivedGroups: la lista está vacía porque todo está archivado. Esa persona ya creó grupos: «tu primer
    ///     grupo» le mentiría.
    ///   - hasSession / isConsented: el educativo va antes que todo, también para quien ya tiene cuenta o ya aceptó; el
    ///     paso que se marca es el primero que de verdad falta.
    static func card(
        for kind: GroupsEmptyStateLogic.Kind,
        flagOn: Bool,
        hasArchivedGroups: Bool,
        hasSession: Bool = false,
        isConsented: Bool = false
    ) -> Card {
        switch kind {
        case .needsEducational:
            let first: Step = !hasSession ? .account : (!isConsented ? .consent : .create)
            return Card(currentStep: first, action: .tellMe)
        case .createAccount:
            return Card(currentStep: .account, action: .createAccount)
        case .needsConsent:
            return Card(currentStep: .consent, action: .tellMe)
        case .standard:
            return Card(currentStep: (flagOn && !hasArchivedGroups) ? .create : nil, action: .createGroup)
        case .signInToView:
            // Sus grupos ya existen en una cuenta: no hay primer grupo que contar, hay que volver a entrar.
            return Card(currentStep: nil, action: .signIn)
        }
    }

    static func state(of step: Step, current: Step) -> StepState {
        if step.rawValue < current.rawValue { return .done }
        if step == current { return .current }
        return .upcoming
    }
}
