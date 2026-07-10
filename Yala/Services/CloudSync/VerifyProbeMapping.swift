//
//  VerifyProbeMapping.swift
//  Yala
//
//  Mapping PURO `MerkleVerdict → VerifyProbe` de la fase `verifying` de la migración (I10-wiring w5). Es la
//  traducción del veredicto del verificador Merkle (`CloudSyncEngine.verifyIntegrity`, count+hash POR
//  ENTIDAD con guards anti-falsa-divergencia) al sondeo que consume la máquina de estados. Los `reason` de
//  `.skipped` están VERIFICADOS contra `SyncMerkle.swift:verifyIntegrity` — cada uno decide si el retry es
//  de MISMATCH (contrato roto / rechazo definitivo: consume tope → `failedRollback`) o de RED (idempotente,
//  contador independiente), o si es un re-run barato que NO consume tope.
//
//  `nonisolated` + sin efectos: función pura testeable con tabla completa. El CANARIO de un reason
//  DESCONOCIDO lo emite el CALLER (`MigrationWorkExecutor`, que sí es `@MainActor`) usando `isUnknownSkip`.
//

import Foundation

nonisolated enum VerifyProbeMapping {

    /// Mapea el veredicto Merkle al sondeo de verificación (tabla EXACTA del plan):
    ///  - `.converged` → `.match`.
    ///  - `.diverged` → `.mismatch` (consume retry de mismatch; tope → `failedRollback`).
    ///  - `.skipped("outbox-pending")` → `.newDeltaDetected` (delta aterrizó durante la corrida — re-run, NO consume).
    ///  - `.skipped("dead-letters")` → `.mismatch` (rechazo DEFINITIVO del server: jamás auto-sana → tope).
    ///  - `.skipped("canon-version-mismatch"|"capability-set-mismatch")` → `.mismatch` (contrato roto mid-migración: terminal por tope).
    ///  - `.skipped("no-completed-pull"|"fetch-failed"|"outbox-fetch-failed"|"quarantine-fetch-failed")` → `.networkTimeout` (retry idempotente).
    ///  - reason DESCONOCIDO → `.networkTimeout` conservador (el caller emite el canario vía `isUnknownSkip`).
    static func map(verdict: MerkleVerdict) -> VerifyProbe {
        switch verdict {
        case .converged:
            return .match
        case .diverged:
            return .mismatch
        case .skipped(let reason):
            switch reason {
            case "outbox-pending":
                return .newDeltaDetected
            case "dead-letters", "canon-version-mismatch", "capability-set-mismatch":
                return .mismatch
            case "no-completed-pull", "fetch-failed", "outbox-fetch-failed", "quarantine-fetch-failed":
                return .networkTimeout
            default:
                return .networkTimeout  // conservador: nunca crashear ni consumir mismatch por un reason nuevo
            }
        }
    }

    /// `true` si el veredicto es un `.skipped` con un `reason` que NO está en el contrato conocido (futuro).
    /// El caller (`@MainActor`) lo usa para emitir el canario `migrationVerifyUnknownReason` — este tipo es
    /// `nonisolated` y no puede tocar el logger.
    static func isUnknownSkip(_ verdict: MerkleVerdict) -> Bool {
        guard case .skipped(let reason) = verdict else { return false }
        switch reason {
        case "outbox-pending", "dead-letters", "canon-version-mismatch", "capability-set-mismatch",
             "no-completed-pull", "fetch-failed", "outbox-fetch-failed", "quarantine-fetch-failed":
            return false
        default:
            return true
        }
    }
}
