//
//  SyncCadencePolicy.swift
//  Yala
//
//  Política PURA de cadencia del motor Modo Nube (incremento I9, §i.2/§d.5). Decide, a partir del
//  RESULTADO de un ciclo (drain→push→pull→apply) y del número de fallos transitorios consecutivos, la
//  próxima acción del orquestador (`CloudSyncRuntime`): reprogramar, backoff exponencial, o DETENER.
//  Golden-testeable en aislamiento (sin motor, sin red, sin reloj real — `now` inyectado).
//
//  DECISIONES DE STOP (§d.5 S6):
//    - `.accountUnavailable` (403) → `stopUntilRelaunch`: cuenta suspendida/deshabilitada. NUNCA se
//      reintenta en loop (un backoff giraría para siempre sobre un veredicto definitivo). Se re-evalúa
//      solo al relanzar / firmar de nuevo (`handleBecameActive` lo deja pegado A PROPÓSITO).
//    - `.sessionExpired` (401 / sesión no renovable con pendientes) → `stopUntilSignIn`: re-evaluable
//      en `handleBecameActive` (el usuario pudo re-firmar).
//
//  MERKLE (§d.7): el verificador es CARO server-side (~3s) → se corre solo cuando SE CUMPLEN AMBAS
//  condiciones (AND): ≥ `merkleEveryNPulls` pulls COMPLETOS desde la última verificación **y** ≥
//  `merkleMinInterval` de reloj. El contador de pulls solo avanza en ciclos `.completed` (el guard A-3
//  del verdict exige un pull completo para no comparar árboles con trabajo en vuelo).
//
//  `nonisolated`: constantes + funciones puras; se consultan desde el ciclo `@MainActor` del runtime.
//

import Foundation

nonisolated enum SyncCadencePolicy {

    // MARK: - Constantes (con rationale)

    /// Intervalo entre pulls en foreground con un ciclo `.completed`. 60s = compromiso latencia/energía
    /// en v1 (el trigger por save local queda diferido — ver D1 del plan; 60s es el peor caso aceptable).
    static let pullInterval: TimeInterval = 60

    /// Debounce del push tras un save local (coalescing de ráfagas de ediciones). No lo consume el loop
    /// de I9 (el push va dentro del ciclo); queda declarado para el trigger por save de I10.
    static let pushDebounce: TimeInterval = 2

    /// Base del backoff exponencial ante fallos transitorios (red/HTTP/decode/save de página).
    static let backoffBase: TimeInterval = 5

    /// Techo del backoff exponencial (5min): un backend caído no debe empujar el reintento más allá.
    static let backoffCap: TimeInterval = 300

    /// Umbral de pulls completos para correr Merkle (condición 1 del AND).
    static let merkleEveryNPulls = 20

    /// Intervalo mínimo de reloj entre verificaciones Merkle (condición 2 del AND). El handler es caro.
    static let merkleMinInterval: TimeInterval = 30 * 60

    // MARK: - Outcome normalizado del ciclo

    /// Resultado NORMALIZADO de un ciclo del runtime (mapea `PullApplyOutcome`/`PushOutcome` a un eje
    /// común para la política). El runtime traduce sus outcomes internos a este enum.
    enum CadenceOutcome: Equatable {
        /// El ciclo agotó push+pull sin fallo → cadencia normal.
        case completed
        /// Fallo transitorio (red/HTTP/decode/save/página incompleta) → backoff.
        case transient
        /// 401 / sesión no renovable con pendientes → stop hasta re-firmar.
        case sessionExpired
        /// 403 / attest terminal → stop hasta relanzar (sin loop).
        case accountUnavailable
        /// El ciclo NO corrió / abortó SIN señal de red: coalescido con otro en vuelo, o abortado por
        /// teardown (cambio de `sessionEpoch`, SERIO-2 del review). Cadencia normal, contador de
        /// transitorios INTACTO (tratarlo como `.transient` produciría backoff espurio tras ráfagas
        /// de `handleBecameActive` sin fallo real de red).
        case coalesced
    }

    // MARK: - Acción de cadencia

    enum CadenceAction: Equatable {
        /// Reprogramar el próximo ciclo tras `TimeInterval` segundos (cadencia normal).
        case scheduleNext(TimeInterval)
        /// Reintentar tras `TimeInterval` segundos (backoff exponencial ante transitorios).
        case backoff(TimeInterval)
        /// Detener la cadencia hasta que el usuario firme de nuevo (401 / sesión no renovable).
        case stopUntilSignIn
        /// Detener la cadencia hasta relanzar la app (403 / attest terminal). SIN loop de reintentos.
        case stopUntilRelaunch
    }

    /// Delay del backoff exponencial: `backoffBase × 2^(n-1)`, tope `backoffCap`. `n` =
    /// `consecutiveTransients` (INCLUYE el fallo actual; n≥1). n≤0 → base (defensivo).
    static func backoffDelay(consecutiveTransients n: Int) -> TimeInterval {
        guard n > 0 else { return backoffBase }
        let scaled = backoffBase * pow(2.0, Double(n - 1))
        return min(scaled, backoffCap)
    }

    /// Próxima acción a partir del outcome del ciclo y el número de transitorios consecutivos (el caller
    /// ya lo incrementó en `.transient`, lo reseteó en `.completed`/stops, y lo dejó INTACTO en
    /// `.coalesced`).
    static func nextAction(outcome: CadenceOutcome, consecutiveTransients: Int) -> CadenceAction {
        switch outcome {
        case .completed, .coalesced:
            return .scheduleNext(pullInterval)
        case .transient:
            return .backoff(backoffDelay(consecutiveTransients: consecutiveTransients))
        case .sessionExpired:
            return .stopUntilSignIn
        case .accountUnavailable:
            return .stopUntilRelaunch
        }
    }

    // MARK: - Merkle (AND de dos condiciones)

    /// ¿Correr la verificación Merkle ahora? Exige AMBAS condiciones (AND): suficientes pulls completos
    /// **y** suficiente tiempo de reloj desde la última verificación. `lastMerkleAt == nil` (nunca
    /// verificado) satisface la condición temporal. `now` inyectado (regla de tests).
    static func shouldRunMerkle(completedPullsSinceMerkle: Int, lastMerkleAt: Date?, now: Date) -> Bool {
        guard completedPullsSinceMerkle >= merkleEveryNPulls else { return false }
        guard let lastMerkleAt else { return true }
        return now.timeIntervalSince(lastMerkleAt) >= merkleMinInterval
    }
}
