//
//  CloudSignOutFlowLogic.swift
//  Yala
//
//  Pure-logic del "Cerrar sesión" universal (gap H4 de I14, decisión owner 2026-07-12):
//  camino por modo de almacenamiento, visibilidad de la fila en Ajustes y veredicto
//  del push-all previo al cierre en `.cloud`.
//
//  Invariante de seguridad (F0): en `.cloud` NUNCA se borran datos EN SESIÓN — el
//  cleanup destructivo (archivos de YalaModel + YalaSyncMeta) corre en el BOOT
//  pre-mount, gated por `signOutWipeArmed`. Borrar FILAS propagaría los deletes a
//  iCloud vía el replay de History al remontar el mirror (qa/cloud/README HALLAZGO 3).
//

import Foundation

nonisolated enum CloudSignOutFlowLogic {

    /// Camino del sign-out según el modo de almacenamiento del device.
    enum Path: Equatable {
        /// `.icloud` (privado): NO se tocan datos — signOut backend si hay sesión,
        /// teardown si el runtime existe, reset de onboarding → Welcome EN SESIÓN.
        /// Re-entrada: "Ya tengo cuenta → Restaurar iCloud" (datos intactos).
        case privateReset
        /// `.cloud`: push-all (bloquear si falla, jamás descartar) → signOut +
        /// teardown → armar `signOutWipeArmed` → relaunch asistido (NUNCA auto-kill).
        case cloudSecureSignOut
    }

    static func path(for storageMode: StorageMode) -> Path {
        switch storageMode {
        case .icloud: .privateReset
        case .cloud: .cloudSecureSignOut
        }
    }

    /// Fila "Cerrar sesión" en Seguridad y cuenta: SIEMPRE visible (decisión owner —
    /// aplica a privado y nube), excepto en modo group-invite (onboarding especial de
    /// invitados, coherente con el resto de filas personales de ProfileView).
    static func shouldShowRow(isGroupInviteMode: Bool) -> Bool {
        !isGroupInviteMode
    }

    /// Veredicto de una iteración del loop de push-all previo al cierre en `.cloud`.
    /// `nil` = seguir iterando.
    enum PushAllVerdict: Equatable {
        /// Outbox vivo == 0 verificado por fetch → seguro proceder al cierre.
        case drained
        /// Quedan filas vivas y el ciclo falló o se alcanzó el tope → ABORTAR el
        /// cierre mostrando el error. Los pendientes JAMÁS se descartan.
        case blocked(pendingCount: Int)
    }

    static func pushAllVerdict(
        livePendingCount: Int,
        cycleSucceeded: Bool,
        iteration: Int,
        maxIterations: Int
    ) -> PushAllVerdict? {
        if livePendingCount == 0 { return .drained }
        if !cycleSucceeded || iteration >= maxIterations {
            return .blocked(pendingCount: livePendingCount)
        }
        return nil
    }
}
