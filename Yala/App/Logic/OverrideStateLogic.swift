//
//  OverrideStateLogic.swift
//  Yala
//
//  Pure-logic: resuelve el estado visible del toggle "Integración personal" per-grupo
//  según `(global, override, memberIsActive)`. Testeable sin SwiftData ni SwiftUI.
//

import Foundation

enum OverrideStateLogic {

    /// Estado visual del toggle + hint a mostrar debajo.
    enum UIState: Equatable {
        /// Member NO está `.isActive` (pending/rejected/removed) — sección oculta entera.
        case hiddenSection
        /// Global OFF — toggle disabled y forzado OFF visual. Hint explica activar global.
        case disabledOff
        /// Global ON + override nil — toggle ON heredando. Hint "heredas tu ajuste general".
        case enabledOnInheriting
        /// Global ON + override true — toggle ON explícito (redundante pero válido).
        /// El UX simplificado lo trata igual que inheriting; mantenido por completitud.
        case enabledOnLocal
        /// Global ON + override false — toggle OFF explícito. Hint "solo en este grupo".
        case enabledOffLocal
    }

    /// Resuelve el estado del toggle del grupo.
    /// - Parameters:
    ///   - global: `AppPreferences.bridgeGroupExpensesToPersonalAccounts`.
    ///   - override: `GroupBridgePreference.bridgeOverride` para este grupo.
    ///   - memberIsActive: `currentMember.status == .active`.
    static func compute(global: Bool, override: Bool?, memberIsActive: Bool) -> UIState {
        guard memberIsActive else { return .hiddenSection }
        guard global else { return .disabledOff }
        switch override {
        case nil: return .enabledOnInheriting
        case .some(true): return .enabledOnLocal
        case .some(false): return .enabledOffLocal
        }
    }
}
