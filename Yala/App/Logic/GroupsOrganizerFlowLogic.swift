//
//  GroupsOrganizerFlowLogic.swift
//  Yala
//
//  G3 de Grupos-first · el paso encadenado de la rama organizador, una vez la puerta
//  (`GroupsOrganizerGateLogic`) ya la dejó pasar.
//
//  **Espeja `GroupBackendInviteEntryLogic.nextStep` a propósito, y respeta su orden**: sign-in ANTES
//  que consent, que es el del invitado (al revés que el Welcome, donde el consent va antes y en la
//  misma pantalla). Es una lógica hermana y no un reuso porque el invitado tiene una zona a la que
//  unirse y el organizador no tiene todavía ningún grupo: su último paso es el formulario de creación,
//  no un join.
//
//  **Cada llamada re-evalúa condiciones VIVAS** (regla del repo): el drenaje del router vuelve aquí
//  después de cada sheet en vez de recordar en qué paso iba, así que un sign-in que ya estaba hecho, un
//  consent aceptado en otra pantalla o un kill-and-relaunch a mitad no dejan la máquina desalineada.
//

import Foundation

nonisolated enum GroupsOrganizerFlowLogic {

    enum Step: Equatable {
        /// Sin sesión de nube → `GroupsSignInView` (el de GRUPOS, jamás una hermana de
        /// `WelcomeCloudSignInView`: su docblock prohíbe instanciarla en paralelo).
        case presentSignIn
        /// Con sesión y sin consent → `GroupsConsentView`, reusada LITERAL (un solo parámetro, sin ramas:
        /// epoch y `textVersion` intactos, append-only).
        case presentConsent
        /// Falta el alta: la pantalla mínima de nombre a mostrar, que es donde se escribe el trío.
        case presentName
        /// Todo listo → el formulario de grupo, directo.
        case presentGroupForm
    }

    /// - Parameters:
    ///   - hasSession: `CloudAuthService.shared.hasSession`.
    ///   - isConsented: `GroupsConsentState.isAccepted`.
    ///   - hasCompletedSetup: `hasCompletedOnboarding` — lo marca el propio alta (paso 7), así que es el
    ///     testigo de que el trío ya está escrito y de que este proceso no debe volver a pedir el nombre.
    static func nextStep(hasSession: Bool, isConsented: Bool, hasCompletedSetup: Bool) -> Step {
        if !hasSession { return .presentSignIn }
        if !isConsented { return .presentConsent }
        if !hasCompletedSetup { return .presentName }
        return .presentGroupForm
    }
}
