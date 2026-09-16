//
//  GroupsLoopRestartLogic.swift
//  Yala
//
//  Pure-logic gate for (re)starting the OWN cadence loop of the Groups→backend sync channel
//  (`GroupsSyncClient.startIfEligible`). Extracted so the restart decision — INCLUDING the D8
//  mount-mismatch guard that makes MID-SESSION calls safe (foreground resume / post-sign-in, the
//  H-2026-07-18-4 fix) — is a single testable table instead of scattered guards. Molde: `SplitSyncStartGate`
//  (pure, nonisolated, exhaustive table).
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

    /// ¿Debe `startIfEligible` (re)arrancar el loop propio del canal AHORA?
    ///
    /// - `flagOn` — `CloudSyncFlags.groupsBackendEnabled`. Con el flag OFF (producción hoy) SIEMPRE
    ///   `false` → byte-identidad DARK: el re-arranque en foreground / post-sign-in es un no-op.
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
}
