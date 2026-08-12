//
//  GroupsOrganizerFlowLogic.swift
//  Yala
//
//  G3 de Grupos-first · el paso encadenado de la rama organizador, una vez la puerta
//  (`GroupsOrganizerGateLogic`) ya la dejó pasar.
//
//  **C2 (2026-08-12): ya NO espeja a `GroupBackendInviteEntryLogic` — las dos DERIVAN de
//  `GroupsGateLogic`.** Lo que hasta hoy eran tres funciones prometiéndose paridad por docblock («espeja
//  … a propósito, y respeta su orden») es una sola tabla con un parámetro `entry`. Este tipo se conserva
//  como fachada nombrada de la rama organizador: su Step es el vocabulario que habla `ContentView`, y
//  colapsarlo obligaría a que el router tradujera casos que en esta rama son inalcanzables (`join`,
//  `presentInviteOnboarding`).
//
//  Sigue siendo cierto lo que aquel docblock explicaba: sign-in ANTES que consent (al revés que el
//  Welcome, donde el consent va antes y en la misma pantalla), y el terminal es el formulario de creación
//  y no un join, porque el organizador todavía no tiene ningún grupo al que unirse. Lo que C2 añade
//  delante es el EDUCATIVO.
//
//  **Cada llamada re-evalúa condiciones VIVAS** (regla del repo): el drenaje del router vuelve aquí
//  después de cada sheet en vez de recordar en qué paso iba, así que un sign-in que ya estaba hecho, un
//  consent aceptado en otra pantalla o un kill-and-relaunch a mitad no dejan la máquina desalineada.
//

import Foundation

nonisolated enum GroupsOrganizerFlowLogic {

    enum Step: Equatable {
        /// C2 · el educativo de Grupos, PRIMER escalón. Antes de C2 esta rama pedía identidad sin haber
        /// contado nunca qué es un grupo ni dónde viven sus gastos.
        case presentEducational
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

    /// Deriva de `GroupsGateLogic.nextStep`. **La rama organizador y la card «Solo grupos» comparten la
    /// cadena entera** (`entry` solo las separa para la telemetría y para el payload que la card arrastra),
    /// así que las dos entran por aquí.
    ///
    /// - Parameters:
    ///   - hasSeenEducational: `AppPreferences.hasShownGroupsOnboarding`.
    ///   - hasSession: `CloudAuthService.shared.hasSession`.
    ///   - isConsented: `GroupsConsentState.isAccepted`.
    ///   - hasCompletedSetup: `hasCompletedOnboarding` — lo marca el propio alta (paso 7), así que es el
    ///     testigo de que el trío ya está escrito y de que este proceso no debe volver a pedir el nombre.
    ///   - entry: `.organizer` (Welcome) o `.onboardingCard` (card «Solo grupos»). Cualquier otro valor es
    ///     un error del llamador y cae al mismo camino: los dos terminales de esta fachada son los suyos.
    static func nextStep(hasSeenEducational: Bool,
                         hasSession: Bool,
                         isConsented: Bool,
                         hasCompletedSetup: Bool,
                         entry: GroupsGateLogic.Entry = .organizer) -> Step {
        switch GroupsGateLogic.nextStep(
            entry: entry,
            hasSeenEducational: hasSeenEducational,
            hasSession: hasSession,
            isConsented: isConsented,
            hasCompletedSetup: hasCompletedSetup
        ) {
        case .presentEducational: return .presentEducational
        case .presentSignIn:      return .presentSignIn
        case .presentConsent:     return .presentConsent
        case .presentName:        return .presentName
        // Inalcanzables para `.organizer`/`.onboardingCard` — la tabla única solo los produce con
        // `entry: .invite`. Se mapean al formulario en vez de a un `fatalError` porque un llamador que
        // pasara la entry equivocada merece aterrizar en la pantalla que la rama sabe usar, no un crash.
        case .presentGroupForm, .presentInviteOnboarding, .join:
            return .presentGroupForm
        }
    }
}
