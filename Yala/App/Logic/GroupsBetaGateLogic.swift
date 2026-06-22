//
//  GroupsBetaGateLogic.swift
//  Yala
//
//  Pure decision logic para el gate de código beta del tab Grupos. Grupos se
//  libera en producción de forma controlada (validación de la v2.0.1): nadie
//  entra sin el código beta, salvo quien llega por enlace de invitación.
//
//  Gate TEMPORAL — se removerá al estabilizar la 2.0.1.
//
//  Extraído como pure-logic para tests sin SwiftData ni UI (sin flake R8 conocido
//  por `makeTestContext()`). Patrón análogo a `GroupsOnboardingLogic`.
//

import Foundation

enum GroupsBetaGateLogic {

    /// Código beta numérico que desbloquea el acceso a Grupos.
    static let betaCode = "1050"

    /// `true` si el texto ingresado coincide con el código beta. Trim defensivo:
    /// `.numberPad` no garantiza solo-dígitos (teclados de terceros, pegado).
    static func isValidCode(_ input: String) -> Bool {
        input.trimmingCharacters(in: .whitespacesAndNewlines) == betaCode
    }

    /// Decide si mostrar el gate de bloqueo en lugar del contenido de Grupos.
    /// - Parameters:
    ///   - isUnlocked: `AppPreferences.Keys.groupsBetaUnlocked` (per-device). Una vez
    ///     `true` (código correcto o invitación aceptada), el gate no se muestra más.
    ///   - isGroupInviteMode: `SessionState.isGroupInviteMode`. Los invitados por enlace
    ///     entran sin código (exentos del gate).
    static func shouldShowGate(isUnlocked: Bool, isGroupInviteMode: Bool) -> Bool {
        !isUnlocked && !isGroupInviteMode
    }
}
