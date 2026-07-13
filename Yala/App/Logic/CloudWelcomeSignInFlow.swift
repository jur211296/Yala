//
//  CloudWelcomeSignInFlow.swift
//  Yala
//
//  Pure-logic de la pantalla "Sign in with Apple" del Welcome (re-entrada a una
//  cuenta del Modo Nube existente). Rutea el resultado de GET /account/exists
//  (read-only — el claim con `created` CREA cuenta server-side, por eso JAMÁS se
//  claimea sin `exists == true` previo) y mapea el uiState del controller a la
//  fase de pantalla durante el adopt.
//

import Foundation

/// Fase de pantalla del sign-in de nube en el Welcome.
nonisolated enum CloudWelcomeSignInPhase: Equatable {
    /// Pantalla inicial con el botón SIWA.
    case intro
    /// `exists` en vuelo tras SIWA exitoso.
    case checking
    /// Cross-cuenta con datos locales (F0-C degradado) — mensaje + volver.
    case blockedForeignData
    /// Adopt en curso (progreso de la máquina de migración).
    case adopting(fraction: Double)
    /// Claim devolvió `claiming_in_progress` — otro device lidera.
    case waitingLeader
    /// Adopt completo — TERMINAL: "Cierra y reabre Yala" (NUNCA auto-kill).
    case relaunch
    /// M1: confirmación explícita ANTES de escribir nada de la sesión secundaria
    /// ("entrarás con tu cuenta; los datos del dueño no se tocan").
    case secondaryConfirm
    /// M1: descriptor + claim armados — TERMINAL: "Cierra y reabre Yala" (el boot
    /// monta el store secundario). Sin auto-kill, igual que `.relaunch`.
    case relaunchSecondary
    /// El Apple ID firmado no tiene cuenta Yala en la nube.
    case notFound
    /// Fallo de red/sesión del `exists` o de la máquina.
    case error(retryable: Bool)
}

nonisolated enum CloudWelcomeSignInFlow {

    /// Ruteo del resultado de GET /account/exists. `accountFound` NO arranca nada:
    /// el caller debe pasar por `CrossAccountEntryGuardLogic` antes de adoptar.
    enum ExistsRoute: Equatable {
        case accountFound
        case accountMissing
        case failed(retryable: Bool)
    }

    static func route(_ outcome: ExistsOutcome) -> ExistsRoute {
        switch outcome {
        case .exists(true): .accountFound
        case .exists(false): .accountMissing
        case .sessionExpired: .failed(retryable: true)
        case .transient: .failed(retryable: true)
        }
    }

    /// Mapea el `uiState` del CloudMigrationController a la fase de pantalla
    /// mientras el adopt corre. Estados que "no deberían ocurrir aquí" degradan
    /// a `.error` (defensivo, nunca trap).
    static func phase(for uiState: CloudMigrationUIState) -> CloudWelcomeSignInPhase {
        switch uiState {
        case .idle:
            // Pre-arranque de la máquina (fases consent/authenticating no-durables).
            return .adopting(fraction: 0)
        case .migrating(let step):
            return .adopting(fraction: step.fraction)
        case .needsRelaunch(.toCloud):
            return .relaunch
        case .cloudActive:
            // El relaunch ya se resolvió en otro proceso — terminal equivalente.
            return .relaunch
        case .waitingForLeader:
            return .waitingLeader
        case .failed:
            return .error(retryable: true)
        case .reverting, .needsRelaunch(.toICloud):
            // Imposibles en un adopt desde Welcome; jamás presentar UI de reversa.
            return .error(retryable: false)
        }
    }
}
