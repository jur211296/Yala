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
        /// Sesión SECUNDARIA (M1): push-all verificado idéntico al camino `.cloud`, pero
        /// arma `SecondarySessionStore.armWipe` (borra SOLO los archivos `-Secondary` en el
        /// boot; los del dueño intactos) y JAMÁS `armSignOutWipe` ni el reset masivo de prefs.
        case secondaryCloudSignOut
    }

    /// M1 — ATOMICIDAD con el getter efectivo: `secondarySessionActive` gana PRIMERO. Sin esta
    /// rama, el `.cloud` EFECTIVO derivado del descriptor enrutaría el sign-out de la invitada a
    /// `.cloudSecureSignOut` → `armSignOutWipe` → el boot borraría el `YalaModel` del DUEÑO.
    static func path(for storageMode: StorageMode, secondarySessionActive: Bool) -> Path {
        if secondarySessionActive { return .secondaryCloudSignOut }
        switch storageMode {
        case .icloud: return .privateReset
        case .cloud: return .cloudSecureSignOut
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
