//
//  GroupsLoopRestartLogic.swift
//  Yala
//
//  Pure-logic gate for (re)starting the OWN cadence loop of the Groups→backend sync channel
//  (`GroupsSyncClient.startIfEligible`). Extracted so the restart decision is a single testable table instead of
//  scattered guards (molde: `SplitSyncStartGate`, pure, nonisolated, exhaustive table).
//
//  **Las llamadas a MITAD de sesión (primer plano, tras un sign-in: H-2026-07-18-4) son seguras por otro motivo
//  que el que esta cabecera daba hasta el 2026-11-06.** El guard «D8» de mount-mismatch (`secondaryActive &&
//  !secondaryMounted`) salió de esta tabla el 2026-09-13 con la sesión de visita (783a4ec9b): sin ella hay UN solo
//  store personal montado por proceso, así que la ventana que cerraba ya no existe. Lo que impide subir cambios de
//  otra persona desde este teléfono es el dueño por fila del outbox (`GroupSyncOutbox.ownerUserID`, la subida solo
//  manda las filas de la sesión). Medido leyendo el código el 2026-11-06, no en un aparato.
//
//  Scope: this decides ONLY whether the channel's OWN loop should (re)start now — y, desde el 2026-09-16, si
//  el loop que YA vive hay que DESPERTARLO (`shouldWake`), porque estar vivo no es estar trabajando: puede
//  estar durmiendo hasta 5 min de backoff. The piggyback mode (when
//  the PERSONAL runtime cadences, the group cycle rides as step 5.6 of `CloudSyncRuntime.performCycle`) is
//  NOT modeled here — its early-return lives in `startIfEligible` after this returns `true` with
//  `loopAlive == false`. The boot-net rehydrate of the App Group mirror also runs behind a `true` here.
//

import Foundation

nonisolated enum GroupsLoopRestartLogic {

    /// Cómo corre el canal de Grupos una vez decidido arrancarlo (ticket
    /// `can-run-domain-reads-the-filler-phase-before-the-journal-connects`).
    enum LoopMode: Equatable {
        /// El runtime personal cadencia y Grupos va de paso 5.6 (piggyback): sin loop propio.
        case piggyback
        /// Loop propio de Grupos.
        case ownLoop
        /// Todavía no se puede saber: modo `.cloud` y el journal sin conectar. Antes del paso 11 del arranque
        /// `MigrationPhaseStore.currentPhaseRead` es el RELLENO `.notStarted`, que el candado del motor lee como fase
        /// estable: con una fase transitoria de verdad, Grupos se iba de piggyback y el motor personal —ya con el journal—
        /// no arrancaba. Se vuelve a decidir cuando el journal se conecta.
        case decideAfterJournal
    }

    /// `personalCanRun` es `CloudSyncRuntime.canRunDomain()` y solo se consulta con el journal conectado: con el relleno su
    /// respuesta no vale nada. Fuera de `.cloud` el candado no abre con ninguna fase, así que no hay nada que esperar.
    static func loopMode(
        runtimeEnabled: Bool, storageModeIsCloud: Bool, journalConnected: Bool, personalCanRun: () -> Bool
    ) -> LoopMode {
        guard runtimeEnabled, storageModeIsCloud else { return .ownLoop }
        guard journalConnected else { return .decideAfterJournal }
        return personalCanRun() ? .piggyback : .ownLoop
    }


    /// ¿Debe `startIfEligible` (re)arrancar el loop propio del canal AHORA?
    ///
    /// - `flagOn` — `CloudSyncFlags.groupsBackendEnabled`. Con el flag OFF SIEMPRE `false`: el re-arranque en
    ///   foreground / post-sign-in es un no-op. OFF hoy solo con el kill-switch remoto puesto: el default compilado es
    ///   ON desde D-R1 paso 2 (2026-07-30) y el flag remoto solo puede apagarlo.
    /// - `hasSession` — hay sesión viva (`sessionCheck()`). Sin sesión no hay a quién sincronizar.
    /// - `loopAlive` — el loop ya vive (`loopTask != nil`): single-instance, no duplicar.
    ///
    /// Ninguna parada del loop se queda puesta: el que terminó —sesión caducada, kill del canal o
    /// `.accountUnavailable`— lo vuelve a intentar el próximo `startIfEligible` con flag y sesión.
    static func shouldStart(
        flagOn: Bool,
        hasSession: Bool,
        loopAlive: Bool
    ) -> Bool {
        guard flagOn, hasSession else { return false }
        guard !loopAlive else { return false }
        return true
    }

    /// ¿Debe `startIfEligible` DESPERTAR el loop que ya vive, en vez de arrancar otro?
    ///
    /// Complemento exacto de `shouldStart` sobre las mismas tres entradas: mismo gate de flag y sesión, y
    /// `loopAlive` invertido. Los dos son mutuamente excluyentes y su unión es «flag ON y sesión viva», así
    /// que la tabla de tres columnas queda cubierta entera y sin solape.
    ///
    /// **Existe porque el loop vivo no siempre está trabajando: puede estar DURMIENDO** el backoff de un
    /// fallo pasajero, que crece hasta 5 minutos (`SyncCadencePolicy.backoffDelay`). Volver a Yala con la red
    /// ya recuperada no adelantaba nada — el `false` de `shouldStart` dejaba el sueño entero por delante y los
    /// cambios de grupos esperaban al reintento (ticket
    /// `groups-loop-in-backoff-ignores-the-return-to-foreground`). El runtime personal sí lo hace desde I9:
    /// su `handleBecameActive` re-arranca la cadencia y con ella corta el sueño en curso.
    ///
    /// **No es una tabla redundante aunque hoy el caller ya haya comprobado flag y sesión.** Lo que la hace
    /// valer es lo que pase el día que `shouldStart` gane una condición nueva: sin este gate, el `else` de
    /// aquel guard despertaría el loop justo en el caso que la condición nueva vino a excluir.
    static func shouldWake(
        flagOn: Bool,
        hasSession: Bool,
        loopAlive: Bool
    ) -> Bool {
        guard flagOn, hasSession else { return false }
        return loopAlive
    }

    /// ¿Arranca (o despierta) el canal la pestaña Grupos al aparecer? (QA guiado del 2026-10-19, D5: tras «Ya tengo
    /// una cuenta» con una cuenta solo-grupos, nada lo arrancaba hasta relanzar.) Flag y sesión los mira
    /// `startIfEligible`; aquí van las dos cosas que solo sabe quien llama:
    ///
    /// - `isUITesting` — bajo `-uitest` no, como los otros dos arranques de la app: la sesión fingida no tiene JWT.
    /// - `exitInFlight` — un cierre de sesión o un desasociar en curso (`CloudSessionSignOut`). Esos gestos cortan el
    ///   canal (teardown) ANTES de soltar la sesión, y la pestaña sigue a un toque: arrancarlo ahí devolvería un loop
    ///   vivo encima de lo que el gesto está borrando. El primer plano no tiene este riesgo tan a mano —el gesto corre
    ///   con la app delante—; la pestaña sí, y por eso la condición vive aquí.
    static func tabStartsChannel(isUITesting: Bool, exitInFlight: Bool) -> Bool {
        !isUITesting && !exitInFlight
    }
}
