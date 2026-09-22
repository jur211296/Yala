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

    /// Los `fetch` de SwiftData que `verifyIntegrity` puede ver lanzar. No es red ni es el servidor: es el
    /// teléfono. Techo corto y desenlace visible — esperar tres días delante de una avería local no arregla nada.
    ///
    /// **Eran dos y desde el 2026-09-22 son tres** (`verify-reads-a-failed-local-fetch-as-an-empty-outbox`): el
    /// tercero es el cómputo del árbol LOCAL, que hasta ese día no tenía forma de decir que no pudo leer —hasheaba
    /// la tabla ilegible como VACÍA y salía por `.diverged`, la rama del contrato roto—. Motivo propio y no un
    /// reuso de `outboxFetchFailed`: el desenlace de los tres es el mismo, pero el `rawValue` es lo único que
    /// separa en la flota «no pude leer la cola de subida» de «no pude leer los datos».
    @Test("fallos de la base LOCAL → blocked(.localFailure)", arguments: [
        MerkleSkipReason.outboxFetchFailed, MerkleSkipReason.quarantineFetchFailed,
        MerkleSkipReason.localMerkleFetchFailed,
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

    /// `MerkleSkipReason.all` es lo que decide qué motivo enciende el canario de «desconocido». Un motivo que se
    /// añada a las constantes y se olvide en `all` haría que el verificador se acusara a sí mismo de hablar un
    /// contrato que no entiende, en cada pasada y en toda la flota.
    ///
    /// **Es un source-scan y no una lista escrita a mano, y esa es toda la diferencia.** `MerkleSkipReason` es un
    /// namespace de `static let String`, no un `CaseIterable`: con una lista en el test, un décimo `static let`
    /// olvidado en `all` pasaba en VERDE, porque el test no lo conocía. Lo cazó una lente de la review del
    /// 2026-09-22 — el test prometía cazar justo el caso que no podía ver. Leyendo el fichero, un motivo nuevo
    /// entra en el escaneo solo, se quiera o no.
    @Test("MerkleSkipReason: toda constante declarada está en `all`, y `all` no tiene de más")
    func allReasonsAreListed() throws {
        let fuente = try String(contentsOf: Self.repoRoot
            .appendingPathComponent("Yala/Services/CloudSync/SyncMerkle.swift"), encoding: .utf8)
        // El cuerpo del enum, para no cazar `static let` de otros tipos del mismo fichero.
        guard let inicio = fuente.range(of: "enum MerkleSkipReason {"),
              let fin = fuente.range(of: "\n}", range: inicio.upperBound..<fuente.endIndex) else {
            Issue.record("no se pudo acotar el cuerpo de MerkleSkipReason — el escáner mide otra cosa")
            return
        }
        let cuerpo = String(fuente[inicio.upperBound..<fin.lowerBound])

        var declaradas: [String] = []
        for linea in cuerpo.split(separator: "\n") {
            let s = linea.trimmingCharacters(in: .whitespaces)
            guard s.hasPrefix("static let "), s.contains("= \""), !s.hasPrefix("static let all") else { continue }
            guard let a = s.range(of: "= \""), let b = s.range(of: "\"", range: a.upperBound..<s.endIndex) else { continue }
            declaradas.append(String(s[a.upperBound..<b.lowerBound]))
        }

        // Control positivo del ESCÁNER: si no encuentra nada, no está midiendo el fichero que cree.
        #expect(declaradas.count >= 9, "el escáner no encontró las constantes: mide otra cosa (\(declaradas))")
        #expect(declaradas.contains(MerkleSkipReason.localMerkleFetchFailed),
                "control: el motivo del 2026-09-22 tiene que salir del escaneo")

        for reason in declaradas {
            #expect(MerkleSkipReason.all.contains(reason), "declarada y ausente de `all`: \(reason)")
        }
        #expect(Set(MerkleSkipReason.all) == Set(declaradas),
                "y `all` tampoco lleva ninguna que no esté declarada")
        #expect(Set(MerkleSkipReason.all).count == MerkleSkipReason.all.count, "sin literales repetidos")
    }

    /// Raíz del repo desde la ruta de ESTE fichero (molde de `AttestWiringTests`).
    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

}
