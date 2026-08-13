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

    /// ¿Debe un canal de sync RE-PUBLICAR la fase del join intent al haber aplicado el `SplitMember` PROPIO
    /// de una zona? Es la mitad SIMÉTRICA del invariante de arriba: si «¡Todo listo!» exige member
    /// confirmado, la fase PENDIENTE tiene que retirarse en cuanto ese member deja de estar pendiente.
    ///
    /// Bug device 2026-07-31 (canal BACKEND): el owner aprobaba —`approve_member - Ok` y el cursor del pull
    /// avanzando—, el `SplitMember` propio quedaba `active` en el store (el banner de DENTRO del grupo se
    /// iba, porque lo pinta el status local) y el banner de tab `groups.invite.waitingApproval.banner`
    /// seguía puesto para siempre. Al canal backend le faltaban LAS DOS observaciones que el de CloudKit
    /// sí tiene tras un fetch (`SplitSyncManager.processPendingRemoteChanges`): ni llama al reconciliador
    /// (`GroupJoinReconciler.reconcile` no tiene call-site en `GroupsSyncClient` — sus triggers vivos son
    /// boot / foreground / acceptShare) ni mira el member. Y el reconciliador tampoco lo habría salvado:
    /// `reconcileBackendEntry` dispara `.correctAndClear` con el member presente AUNQUE esté `pendingApproval`
    /// ⇒ el intent ya está limpio cuando llega la aprobación ⇒ los cuatro triggers salen por su
    /// `guard !entries.isEmpty`. La fase se quedaba sin nadie que la moviera.
    ///
    /// **Precondición del caller**: el status que va a publicar es el del member del USUARIO ACTUAL,
    /// resuelto por `sub` (`GroupJoinReconcileLogic.backendMemberMatchesCurrentUser`) y JAMÁS por
    /// `isCurrentUser` —`GroupsSyncClient.applyMember` nunca lo setea (regla de área)—. Publicar el de otro
    /// retiraría el banner del invitado el día que aprobasen a un compañero.
    ///
    /// Solo con un join EN VUELO (zona trackeada + fase no terminal):
    /// - `.idle` NO: crearía un banner que nadie está mostrando (el tracker vive en memoria y arranca
    ///   `.idle` tras un relanzamiento, con el intent ya limpio).
    /// - `.active` / `.failed` NO: son terminales y sus superficies tienen salida propia (la vista consume
    ///   `.active`; el banner de error trae Retry y el de expirado una X). `.pendingApproval` es la única
    ///   fase SIN salida para el usuario, y de ahí que sea la que atrapa.
    static func shouldRepublishPhase(
        trackedPhase: JoinIntentPhase,
        trackedZone: String?,
        appliedZone: String
    ) -> Bool {
        guard let trackedZone, trackedZone == appliedZone else { return false }
        switch trackedPhase {
        case .accepting, .waitingForZone, .creatingMember, .pendingApproval:
            return true
        case .idle, .active, .failed:
            return false
        }
    }
}
