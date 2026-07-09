//
//  BGTaskMigrationGate.swift
//  Yala
//
//  Pure-logic nonisolated del gate §i.9: decide qué hace cada uno de los 3 BGTasks del sistema
//  (widget-refresh / report-notification / report-backup) según la `MigrationPhase` actual, la
//  quiescencia del import y el ROL (lector vs escritor) del task.
//
//  Cierre C1 de [[MODO-NUBE-GAPS]]: los 3 BGTasks son un read/write-path OUT-OF-BAND que puede tocar
//  el `mainContext` a medio hidratar durante una migración/reversa EN CURSO → reabre el
//  `_assertionFailure`/SIGTRAP no-atrapable de la saga de Grupos, disparado por un evento del SISTEMA
//  fuera del control del usuario. El gate lo evita SIN regresar la feature de reports en estado estable.
//
//  Invariante crítico (§i.9 v9, corrección del marco INVERTIDO de v7/v8): en TODOS los estados ESTABLES
//  los 3 tasks corren NORMAL, sin gate. Solo se gatean MIENTRAS la migración/reversa está en un estado
//  TRANSITORIO. Leerlo al revés gatearía PERMANENTEMENTE los reports para el 100% de usuarios (`notStarted`
//  = todo usuario iCloud que nunca tocó la nube; `done` = ya migrado y estable) = regresión de producción.
//
//  Taxonomía REAL (v8, verificada contra `BackgroundTaskManager.swift`): DOS ESCRITORES + UN lector.
//  `report-notification` y `report-backup` comparten `handleReportNotificationTask` (escriben
//  `lastNotifiedDate` + `save()`); `widget-refresh` es el único solo-lectura.
//
//  SWITCH EXHAUSTIVO SIN default (decisión del plan, guard del bug invertido): un case futuro de
//  `MigrationPhase` DEBE romper la compilación y OBLIGAR a clasificarlo estable/transitorio — jamás caer
//  a un default silencioso (un default hacia "transitorio" mataría los reports si el case futuro fuera
//  estable; un default hacia "estable" abriría el crash si fuera transitorio). Romper compila > silencio.
//

import Foundation

nonisolated enum BGTaskMigrationGate {

    // MARK: - Rol del task

    /// El rol del BGTask según su acceso al store. `.reader` = widget-refresh (solo lectura);
    /// `.writer` = report-notification / report-backup (leen + escriben `lastNotifiedDate` + `save()`).
    enum Role: Equatable {
        case reader
        case writer
    }

    // MARK: - Decisión

    enum Decision: Equatable {
        /// Corre el flujo normal del task (estable, o escritor con quiescencia).
        case run
        /// Lector en fase transitoria: early-return + `setTaskCompleted(false)` (iOS lo re-programa;
        /// el widget muestra el último cache — no crítico en la ventana de una migración).
        case suspendAndReschedule
        /// Escritor en fase transitoria SIN quiescencia: difiere (re-programa) el `save()` — nunca sobre
        /// grafo a medio hidratar. Un lector NO usa esta disciplina; un escritor NO usa `suspend`.
        case deferAndReschedule
    }

    // MARK: - Gate

    /// - Parameters:
    ///   - phase: la `MigrationPhase` actual (de `MigrationPhaseStore`; hoy SIEMPRE `.notStarted`).
    ///   - isImportQuiescent: quiescencia del import personal (`iCloudSyncService.isImportQuiescent`).
    ///   - role: `.reader` (widget-refresh) o `.writer` (report-notification / report-backup).
    static func decide(phase: MigrationPhase, isImportQuiescent: Bool, role: Role) -> Decision {
        // EXHAUSTIVO SIN default: clasifica CADA case de `MigrationPhase`. Un case nuevo → error de
        // compilación → clasificación obligatoria (ver doc-comment del archivo).
        switch phase {

        // ESTABLES → `.run` INCONDICIONAL (ignora quiescencia y rol). §i.9: en todo estado estable los
        // 3 corren NORMAL, sin gate. `failedRollback` es ESTABLE: la transición TERMINÓ y el device
        // quedó idéntico a como empezó (el mirror nunca se apagó).
        case .notStarted, .done, .failedRollback:
            return .run

        // TRANSITORIOS (migración EN CURSO) → gate por rol. `.cutover` cubre TODOS sus sub-estados
        // (pending/serverConfirmed/localModeSet/markerWritten/mirrorOff) sin bindear el associated value.
        case .dryRun, .consent, .authenticating, .waitingForLeader,
             .claimingMigration, .assigningIdentity, .uploadingSnapshot,
             .verifying, .cutover:
            switch role {
            case .reader:
                // Solo-lectura → suspende siempre (el cache viejo es aceptable en la ventana transitoria).
                return .suspendAndReschedule
            case .writer:
                // Escritor → exige quiescencia antes de tocar/escribir el `mainContext`; si no, difiere.
                return isImportQuiescent ? .run : .deferAndReschedule
            }
        }
    }
}
