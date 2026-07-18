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

    /// Naturaleza del bloqueo del push-all (H-2026-07-18-6): distingue lo que se sana
    /// SOLO esperando (red intermitente, ciclo coalescido, quiescencia del import aún no
    /// asentada) de lo que NO se cura sin acción del usuario (sesión caída / cuenta no
    /// disponible). El sign-out solo-grupos reintenta internamente los transitorios y solo
    /// muestra un error cuando agota su presupuesto o el bloqueo es permanente.
    enum BlockReason: Equatable {
        /// Curable esperando: red/HTTP/decode/save intermitente, ciclo coalescido, o el
        /// tope de iteraciones/quiescencia (aún drenando). Reintentable.
        case transient
        /// NO curable sin acción del usuario: 401 sesión caída, 403 cuenta no disponible.
        case permanent
    }

    /// Clasifica el outcome crudo de un ciclo de cadencia como transitorio o permanente
    /// (H-2026-07-18-6). Base del retry interno del sign-out solo-grupos.
    static func classify(_ outcome: SyncCadencePolicy.CadenceOutcome) -> BlockReason {
        switch outcome {
        case .sessionExpired, .accountUnavailable: return .permanent
        case .transient, .completed, .coalesced: return .transient
        }
    }

    /// Veredicto de una iteración del loop de push-all previo al cierre en `.cloud`.
    /// `nil` = seguir iterando.
    enum PushAllVerdict: Equatable {
        /// Outbox vivo == 0 verificado por fetch → seguro proceder al cierre.
        case drained
        /// Quedan filas vivas y el ciclo falló o se alcanzó el tope → ABORTAR el
        /// cierre. Los pendientes JAMÁS se descartan. `reason` distingue transitorio
        /// (reintentable) de permanente (H-2026-07-18-6).
        case blocked(pendingCount: Int, reason: BlockReason)
    }

    /// `cycleOutcome` (H-2026-07-18-6): el outcome CRUDO del ciclo — no el Bool colapsado —
    /// para que `.blocked` porte la naturaleza del bloqueo. "Éxito de ciclo" sigue siendo
    /// `.completed`/`.coalesced` (sin señal de fallo); el resto no drena. El tope de iteraciones
    /// con ciclo sano pero pendientes es un bloqueo TRANSITORIO (aún drenando, se agotó el margen).
    static func pushAllVerdict(
        livePendingCount: Int,
        cycleOutcome: SyncCadencePolicy.CadenceOutcome,
        iteration: Int,
        maxIterations: Int
    ) -> PushAllVerdict? {
        if livePendingCount == 0 { return .drained }
        let cycleSucceeded = cycleOutcome == .completed || cycleOutcome == .coalesced
        if !cycleSucceeded || iteration >= maxIterations {
            return .blocked(pendingCount: livePendingCount, reason: classify(cycleOutcome))
        }
        return nil
    }
}

/// Decisión PURA del retry interno del sign-out solo-grupos (H-2026-07-18-6): el device-QA
/// mostró que el bloqueo típico es TRANSITORIO (writes internos del boot aún asentándose) y el
/// usuario tenía que tocar "Cerrar sesión" 2-3 veces. Aquí decidimos, ante un bloqueo, si
/// reintentar (dentro de un PRESUPUESTO GLOBAL de tiempo tras el primer bloqueo) o rendirse y
/// mostrar el error. `elapsedSeconds` es el tiempo transcurrido desde el PRIMER bloqueo (el
/// orquestador de servicio lo mide con `Date()`; la decisión lo recibe como número — regla del
/// repo: nunca `Date()`/sleep crudos en lógica testeada).
nonisolated enum GroupsSignOutRetryDecision {

    /// Presupuesto de reintentos (segundos ADICIONALES tras el primer bloqueo transitorio).
    static let budgetSeconds: Double = 45

    /// Intervalo entre reintentos (segundos).
    static let retryIntervalSeconds: Double = 2

    enum Decision: Equatable {
        /// Reintentar tras `seconds` (bloqueo transitorio, presupuesto NO agotado).
        case retryAfter(seconds: Double)
        /// Rendirse y mostrar el error transitorio ("un momento más") — presupuesto agotado.
        case surfaceTransient
        /// Rendirse y mostrar el error permanente (sesión/cuenta) — inmediato, sin reintentar.
        case surfacePermanent
    }

    static func decide(
        elapsedSeconds: Double,
        budgetSeconds: Double,
        reason: CloudSignOutFlowLogic.BlockReason
    ) -> Decision {
        if reason == .permanent { return .surfacePermanent }
        if elapsedSeconds < budgetSeconds { return .retryAfter(seconds: retryIntervalSeconds) }
        return .surfaceTransient
    }
}
