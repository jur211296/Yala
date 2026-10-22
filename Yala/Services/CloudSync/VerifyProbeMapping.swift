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
//  **`.networkTimeout` dejó de ser un cajón el 2026-09-22** (ticket
//  `reverse-verify-network-bucket-hides-a-definitive-server-no`). Hasta ese día caían aquí el 401 y el 403 de
//  `/sync/merkle` —que `SyncMerkle` aplanaba en un solo `fetch-failed`—, los `fetch` de SwiftData que lanzan (eran
//  dos ese día; el tercero, el del cómputo del árbol local, ni siquiera podía decirlo hasta
//  `verify-reads-a-failed-local-fetch-as-an-empty-outbox`) y
//  cualquier `reason` que este build no conozca; y como la vuelta a iCloud manda la red al techo LARGO, esa mitad
//  esperaba 72 h en «Comprobando que todo llegó…» ante algo que no se arregla esperando. Hoy `.networkTimeout` es
//  SOLO red.
//
//  **El 401 es la excepción y conviene decirlo**: sale tipado, pero en la vuelta su rama pasa por
//  `observeReversePreMountStall(blocker: nil)` ⇒ sigue con el techo LARGO. Es deliberado — a la sesión la renueva la
//  persona, que ahora sí ve la tarjeta de «vuelve a entrar» mucho antes de que venzan las 72 h; lo que el ticket le
//  quitó fue el silencio, no la espera. Los que eligen el techo corto son el 403 y los dos `blocked` nuevos.
//
//  `nonisolated` + sin efectos: función pura testeable con tabla completa. El CANARIO de un reason
//  DESCONOCIDO lo emite el CALLER (`MigrationWorkExecutor`, que sí es `@MainActor`) usando `isUnknownSkip`.
//

import Foundation

nonisolated enum VerifyProbeMapping {

    /// Mapea el veredicto Merkle al sondeo de verificación (tabla EXACTA del plan):
    ///  - `.converged` → `.match`.
    ///  - `.diverged` → `.mismatch` (consume retry de mismatch; tope → `failedRollback`).
    ///  - `.sessionExpired` (401 de `/sync/merkle`) → `.sessionExpired`: en la VUELTA enciende el aviso de «vuelve a
    ///    entrar»; en la ida se lee como red, igual que el 401 del push y el del pull.
    ///  - `.accountUnavailable` (403) → `.blocked(.accountUnavailable)`: techo CORTO — el servidor dijo que no.
    ///  - `.skipped("outbox-pending")` → `.newDeltaDetected` (delta aterrizó durante la corrida — re-run, NO consume).
    ///  - `.skipped("dead-letters")` → `.mismatch` (rechazo DEFINITIVO del server: jamás auto-sana → tope).
    ///  - `.skipped("canon-version-mismatch"|"capability-set-mismatch")` → `.mismatch` (contrato roto mid-migración: terminal por tope).
    ///  - `.skipped("no-completed-pull"|"fetch-failed")` → `.networkTimeout` (retry idempotente). Estas dos SÍ son red.
    ///  - `.skipped("outbox-fetch-failed"|"quarantine-fetch-failed"|"local-merkle-fetch-failed")` →
    ///    `.blocked(.localFailure)`: la base de datos LOCAL falló al leer. No es red ni es el servidor, así que el
    ///    techo largo no le corresponde — y con él la persona esperaba tres días delante de un fallo del propio
    ///    teléfono. **El tercero entró el 2026-09-22** con `verify-reads-a-failed-local-fetch-as-an-empty-outbox`:
    ///    es el cómputo del árbol local, que hasta ese día no tenía cómo decir que no pudo leer —hasheaba la tabla
    ///    ilegible como VACÍA y salía por `.diverged`, o sea por la rama del contrato roto, gastando el presupuesto
    ///    de MISMATCH por una divergencia que no existía.
    ///  - reason DESCONOCIDO → `.blocked(.unknownVerdict)`: techo CORTO. «Conservador» dejó de significar «espera» el
    ///    día en que detrás había 72 h; un motivo que nadie sabe leer no se presume pasajero, que es lo mismo que el
    ///    claim decidió para su `claimRefused`. El canario lo sigue emitiendo el caller vía `isUnknownSkip`.
    static func map(verdict: MerkleVerdict) -> VerifyProbe {
        switch verdict {
        case .converged:
            return .match
        case .diverged:
            return .mismatch
        case .sessionExpired:
            return .sessionExpired
        case .accountUnavailable:
            return .blocked(.accountUnavailable)
        case .skipped(let reason):
            // Los literales salen de `MerkleSkipReason`, el mismo sitio del que los escribe `verifyIntegrity`. Con
            // literales a los dos lados, un renombrado en uno solo cambiaba el desenlace de producción sin un rojo:
            // el test de esta tabla construye su veredicto con el mismo literal que consume.
            switch reason {
            case MerkleSkipReason.outboxPending:
                return .newDeltaDetected
            case MerkleSkipReason.deadLetters, MerkleSkipReason.canonVersionMismatch,
                 MerkleSkipReason.capabilitySetMismatch:
                return .mismatch
            case MerkleSkipReason.noCompletedPull, MerkleSkipReason.fetchFailed:
                return .networkTimeout
            case MerkleSkipReason.outboxFetchFailed, MerkleSkipReason.quarantineFetchFailed,
                 MerkleSkipReason.localMerkleFetchFailed:
                return .blocked(.localFailure)
            default:
                return .blocked(.unknownVerdict)  // nunca crashea ni consume mismatch, pero tampoco espera 72 h
            }
        }
    }

    /// `true` si el veredicto es un `.skipped` con un `reason` que NO está en el contrato conocido (futuro).
    /// El caller (`@MainActor`) lo usa para emitir el canario `migrationVerifyUnknownReason` — este tipo es
    /// `nonisolated` y no puede tocar el logger.
    ///
    /// Los dos veredictos TIPADOS (`.sessionExpired`, `.accountUnavailable`) no son `.skipped` y por tanto nunca son
    /// desconocidos: su lectura la fija el compilador, no una lista de literales.
    static func isUnknownSkip(_ verdict: MerkleVerdict) -> Bool {
        guard case .skipped(let reason) = verdict else { return false }
        return !MerkleSkipReason.all.contains(reason)
    }
}
