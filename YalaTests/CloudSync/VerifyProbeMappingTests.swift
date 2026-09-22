//
//  VerifyProbeMappingTests.swift
//  YalaTests / CloudSync
//
//  Tabla COMPLETA del mapping puro `MerkleVerdict → VerifyProbe` (I10-wiring w5). Cada `reason` de
//  `.skipped` está anclado a `SyncMerkle.verifyIntegrity` — este test es el contrato de qué lectura merece
//  cada desenlace, y sobre todo de CUÁLES esperan y cuáles no.
//
//  **Reescrito el 2026-09-22** (`reverse-verify-network-bucket-hides-a-definitive-server-no`). Hasta ese día
//  seis desenlaces distintos salían por `.networkTimeout` y la vuelta a iCloud manda la red a 72 h, así que la
//  tabla decía «espera tres días» para un 403, un 401, dos fallos de la base local y cualquier motivo futuro.
//  **Los `#expect` son igualdades a secas, sin su `!= .networkTimeout` al lado**: `VerifyProbe` tiene casos
//  disjuntos, así que el `==` ya mata todo lo que mataría el `!=`. La primera versión los llevaba y este encabezado
//  les atribuía el trabajo — una lente de la review midió que no aportaban ni un mutante. Igual con el caso que
//  recorría los `blocked` para comprobar su techo: lo subsumen los tres de arriba, y `stallCause` es un `switch` de
//  un solo `case` cuya propia fuente avisa de que una aserción por caso sobre él no puede fallar. Ese techo se fija
//  donde SÍ se puede medir, en el recorrido del runner (`MigrationRunnerTests`).
//
//  Los literales de `.skipped` salen de `MerkleSkipReason`, igual que los que escribe `verifyIntegrity`: con un
//  literal a cada lado, esta tabla se medía contra sí misma y un renombrado a un solo lado cambiaba el desenlace de
//  producción sin un rojo.
//

import Foundation
import Testing

@testable import Yala

@Suite("VerifyProbeMapping · mapping puro (I10-wiring w5)")
@MainActor
struct VerifyProbeMappingTests {

    @Test("converged → match")
    func converged() {
        #expect(VerifyProbeMapping.map(verdict: .converged) == .match)
        #expect(!VerifyProbeMapping.isUnknownSkip(.converged))
    }

    @Test("diverged → mismatch")
    func diverged() {
        #expect(VerifyProbeMapping.map(verdict: .diverged(entities: ["tx_items"])) == .mismatch)
        #expect(!VerifyProbeMapping.isUnknownSkip(.diverged(entities: ["tx_items"])))
    }

    @Test("skipped(outbox-pending) → newDeltaDetected (re-run, NO consume)")
    func outboxPending() {
        #expect(VerifyProbeMapping.map(verdict: .skipped(reason: MerkleSkipReason.outboxPending)) == .newDeltaDetected)
        #expect(!VerifyProbeMapping.isUnknownSkip(.skipped(reason: MerkleSkipReason.outboxPending)))
    }

    @Test("skipped(dead-letters) → mismatch (rechazo definitivo, tope → failedRollback)")
    func deadLetters() {
        #expect(VerifyProbeMapping.map(verdict: .skipped(reason: MerkleSkipReason.deadLetters)) == .mismatch)
        #expect(!VerifyProbeMapping.isUnknownSkip(.skipped(reason: MerkleSkipReason.deadLetters)))
    }

    @Test("skipped(canon-version-mismatch) → mismatch")
    func canonVersionMismatch() {
        #expect(VerifyProbeMapping.map(verdict: .skipped(reason: MerkleSkipReason.canonVersionMismatch)) == .mismatch)
    }

    @Test("skipped(capability-set-mismatch) → mismatch")
    func capabilitySetMismatch() {
        #expect(VerifyProbeMapping.map(verdict: .skipped(reason: MerkleSkipReason.capabilitySetMismatch)) == .mismatch)
    }

    /// Los DOS que de verdad son red, y son los únicos que quedan en el cajón: el transporte que no llegó
    /// (`fetch-failed`, ya solo el `.transient` del cliente) y el pull que no cerró su ciclo.
    @Test("skipped reasons de RED → networkTimeout", arguments: [
        MerkleSkipReason.noCompletedPull, MerkleSkipReason.fetchFailed,
    ])
    func networkReasons(_ reason: String) {
        #expect(VerifyProbeMapping.map(verdict: .skipped(reason: reason)) == .networkTimeout)
        #expect(!VerifyProbeMapping.isUnknownSkip(.skipped(reason: reason)))
    }

    /// **El 401 del Merkle sale TIPADO**, que es lo que en la vuelta enciende el aviso de «vuelve a entrar»
    /// (`driveReverseVerify` rama `.sessionExpired` → `noteReverseSessionExpiry(.verify)`). Antes llegaba aquí
    /// aplanado en `fetch-failed` y la persona no veía nada durante 72 h.
    @Test("sessionExpired (401 del Merkle) → sessionExpired")
    func merkleSessionExpired() {
        #expect(VerifyProbeMapping.map(verdict: .sessionExpired) == .sessionExpired)
        #expect(!VerifyProbeMapping.isUnknownSkip(.sessionExpired))
    }

    /// **El 403 elige el techo CORTO** por la vía del `blocked`, como ya hacían el del push y el del pull.
    @Test("accountUnavailable (403 del Merkle) → blocked(.accountUnavailable)")
    func merkleAccountUnavailable() {
        #expect(VerifyProbeMapping.map(verdict: .accountUnavailable) == .blocked(.accountUnavailable))
        #expect(!VerifyProbeMapping.isUnknownSkip(.accountUnavailable))
    }

    /// Los dos `fetch` de SwiftData que `verifyIntegrity` puede ver lanzar. No es red ni es el servidor: es el
    /// teléfono. Techo corto y desenlace visible — esperar tres días delante de una avería local no arregla nada.
    @Test("fallos de la base LOCAL → blocked(.localFailure)", arguments: [
        MerkleSkipReason.outboxFetchFailed, MerkleSkipReason.quarantineFetchFailed,
    ])
    func localFailures(_ reason: String) {
        #expect(VerifyProbeMapping.map(verdict: .skipped(reason: reason)) == .blocked(.localFailure))
        #expect(!VerifyProbeMapping.isUnknownSkip(.skipped(reason: reason)),
                "siguen siendo reasons CONOCIDOS: no deben encender el canario de motivo desconocido")
    }

    /// El `default`. **Sigue sin crashear y sin consumir mismatch —eso no cambia— pero ya no espera.**
    /// «Conservador» dejó de significar «espera» el día que detrás hubo 72 h.
    @Test("reason DESCONOCIDO → blocked(.unknownVerdict) + isUnknownSkip true (canario)")
    func unknownReason() {
        let verdict = MerkleVerdict.skipped(reason: "some-future-reason-v2")
        #expect(VerifyProbeMapping.map(verdict: verdict) == .blocked(.unknownVerdict))
        #expect(VerifyProbeMapping.isUnknownSkip(verdict))
    }

}
