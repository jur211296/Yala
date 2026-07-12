//
//  GroupInviteOnboardingLogic.swift
//  Yala
//
//  Pure-logic del onboarding de invitación a grupos (patrón
//  GroupsOnboardingLogic). Decide qué step muestra la vista a partir de la fase
//  REAL del join intent — nunca un fallback optimista.
//
//  Contexto (bug 2026-07-11): `detectFinalStep` devolvía la pantalla de ÉXITO
//  ("¡Todo listo!") como fallback defensivo cuando el grupo no había sincronizado
//  o el ensure lanzaba — el invitado creía haberse unido sin member real.
//  Invariante central de esta lógica: JAMÁS `.active` sin `phase == .active`.
//

import Foundation

/// Fase del join intent, publicada por `GroupJoinIntentTracker` (la alimentan
/// `acceptShare` y `GroupJoinReconciler`).
enum JoinIntentPhase: Equatable {
    /// Sin intent registrado.
    case idle
    /// `container.accept` en vuelo (o re-accept en retry).
    case accepting
    /// Share aceptado; el SplitGroup aún no materializó localmente.
    case waitingForZone
    /// Grupo presente; el SplitMember se está asegurando/exportando.
    case creatingMember
    /// Member existe con `.pendingApproval` — esperando al admin.
    case pendingApproval
    /// Member existe `.active` (confirmado).
    case active
    /// Terminal reintentanble (salvo `.expired`).
    case failed(JoinFailureReason)
}

enum JoinFailureReason: Equatable {
    /// `container.accept` lanzó. `recoverable` según la taxonomía de
    /// `AppBootstrapper.isRecoverableInviteFetchError`.
    case acceptFailed(recoverable: Bool)
    /// `ensureCurrentUserMemberExists` lanzó (save del member).
    case memberSaveFailed
    /// TTL del intent/invite vencido sin lograr member.
    case expired
}

/// Cómo terminó la sesión del onboarding — gobierna la limpieza del
/// `PendingInviteStore` y la navegación post-cierre.
enum GroupInviteOnboardingOutcome: Equatable {
    case joined
    case pendingApproval
    /// Salió desde "está tardando" — el intent persistente sigue trabajando.
    case closedWhileSyncing
    case abandonedAfterFailure(recoverable: Bool)
}

enum GroupInviteOnboardingLogic {

    /// Step visible del onboarding.
    enum Step: Equatable {
        /// Nombre + botón "Unirme al grupo".
        case welcome
        /// Spinner con copy honesto ("Conectando con tu grupo…").
        case joining
        /// Soft-timeout vencido: copy tranquilo + salida digna. NO es error.
        case takingLong
        /// Member `.pendingApproval` — esperando aprobación del admin.
        case pendingApproval
        /// Member confirmado activo → "¡Todo listo!". SOLO con phase == .active.
        case active
        /// Error real con retry visible.
        case failed(JoinFailureReason)
    }

    /// Soft-timeout del spinner antes de pasar a `takingLong`. Con la gracia
    /// export-only de 60s, muchos invitados legítimos lo alcanzarán — por eso
    /// `takingLong` es un estado de primera clase, no un error.
    static let softTimeout: TimeInterval = 20

    /// Pure function del step. Las fases TERMINALES dominan siempre sobre el
    /// timeout (monotónica): si el grupo llega tarde estando en `takingLong`,
    /// la vista salta sola a pending/active.
    static func step(
        hasTappedJoin: Bool,
        phase: JoinIntentPhase,
        hitSoftTimeout: Bool
    ) -> Step {
        guard hasTappedJoin else { return .welcome }
        switch phase {
        case .pendingApproval:
            return .pendingApproval
        case .active:
            return .active
        case .failed(let reason):
            return .failed(reason)
        case .idle, .accepting, .waitingForZone, .creatingMember:
            return hitSoftTimeout ? .takingLong : .joining
        }
    }

    /// `PendingInviteStore.clear()` al cerrar el onboarding: true salvo abandono
    /// con error RECUPERABLE — ahí el re-emit de cold-launch/foreground debe
    /// poder reintentar el accept (acotado por el TTL 24h del invite).
    static func shouldClearPendingInvite(outcome: GroupInviteOnboardingOutcome) -> Bool {
        if case .abandonedAfterFailure(recoverable: true) = outcome { return false }
        return true
    }
}
