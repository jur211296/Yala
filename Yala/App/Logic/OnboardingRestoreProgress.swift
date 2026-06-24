//
//  OnboardingRestoreProgress.swift
//  Yala
//
//  Pure-logic de las fases de la pantalla de progreso del restore de iCloud.
//  CloudKit no expone un % real del import (es opaco), así que la barra avanza
//  por fases observables (estado del primer import + quiescencia) y los conteos
//  en vivo —que la vista hace por polling— son la "verdad" mostrada al usuario.
//

import Foundation

enum OnboardingRestorePhase: Equatable {
    /// Aún no llegó el primer importEvent de CloudKit.
    case connecting
    /// Primer import recibido; siguen llegando lotes (no quiescente).
    case importing
    /// Import asentado (quiescente): datos completos.
    case completed
    /// Se agotó el timeout con datos parciales — "listo lo esencial, seguimos en background".
    case partial
}

enum OnboardingRestoreProgress {

    /// Fase observable a partir del estado del import. `timedOut` gana solo si
    /// el import no llegó a asentarse (si ya está completo, no es parcial).
    static func phase(
        hasCompletedFirstImport: Bool,
        isQuiescent: Bool,
        timedOut: Bool
    ) -> OnboardingRestorePhase {
        let settled = hasCompletedFirstImport && isQuiescent
        if settled { return .completed }
        if timedOut { return .partial }
        if !hasCompletedFirstImport { return .connecting }
        return .importing
    }

    /// Fracción de la barra (0...1) para cada fase. `partial` llena la barra
    /// (terminamos, aunque con datos incompletos).
    static func fraction(for phase: OnboardingRestorePhase) -> Double {
        switch phase {
        case .connecting: return 0.25
        case .importing:  return 0.66
        case .completed:  return 1.0
        case .partial:    return 1.0
        }
    }

    /// `true` cuando el flujo debe continuar (entrar a la app / decidir destino).
    static func isTerminal(_ phase: OnboardingRestorePhase) -> Bool {
        phase == .completed || phase == .partial
    }
}
