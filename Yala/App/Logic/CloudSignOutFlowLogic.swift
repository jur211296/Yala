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
        /// SESIÓN SOLO-GRUPOS (G5-B): sesión backend viva + personal aún en `.icloud`. NO es
        /// `.cloud` (el store personal no se sincroniza por el motor) ni secundaria. Cierra la
        /// sesión backend limpiamente: push-all VERIFICADO del outbox de GRUPOS → teardown del
        /// canal → purga in-session del outbox/cursor de grupos → limpieza del consent → wipe
        /// ARMADO SOLO del store de grupos al boot (jamás del personal). Datos personales intactos.
        case groupsOnlySignOut
    }

    /// Precedencia CONGELADA (G5-B):
    ///  1. `secondarySessionActive` — M1 gana SIEMPRE (ATOMICIDAD con el getter efectivo: en
    ///     secundaria el modo EFECTIVO es `.cloud`; sin esta rama primero el sign-out de la
    ///     invitada iría a `.cloudSecureSignOut` → `armSignOutWipe` → el boot borraría el
    ///     `YalaModel` del DUEÑO).
    ///  2. `.cloud` — el store personal lo sincroniza el motor; el wipe seguro es por archivos.
    ///  3. `groupsBackendEnabled && hasLiveSession` — sesión solo-grupos (personal `.icloud`).
    ///  4. else — `.privateReset` (datos intactos, reset a Welcome).
    ///
    /// Con el flag OFF o sin sesión backend (TODO device prod hoy) las filas 1/2/4 son la matriz
    /// EXACTA de antes: la fila 3 solo se alcanza con `groupsBackendEnabled == true`.
    static func path(for storageMode: StorageMode,
                     secondarySessionActive: Bool,
                     hasLiveSession: Bool,
                     groupsBackendEnabled: Bool) -> Path {
        if secondarySessionActive { return .secondaryCloudSignOut }
        if storageMode == .cloud { return .cloudSecureSignOut }
        if groupsBackendEnabled && hasLiveSession { return .groupsOnlySignOut }
        return .privateReset
    }

    /// Copy honesto del confirmationDialog por camino (G5-B). Extraído para testear la precedencia
    /// (idéntica a `path`); el mapeo enum → string localizado vive en `ProfileView`.
    enum ConfirmMessage: Equatable {
        case icloud
        case cloud
        case secondary
        case groupsOnly
    }

    static func confirmMessage(for path: Path) -> ConfirmMessage {
        switch path {
        case .privateReset: return .icloud
        case .cloudSecureSignOut: return .cloud
        case .secondaryCloudSignOut: return .secondary
        case .groupsOnlySignOut: return .groupsOnly
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
