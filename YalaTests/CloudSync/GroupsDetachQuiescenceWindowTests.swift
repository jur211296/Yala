//
//  GroupsDetachQuiescenceWindowTests.swift
//  YalaTests / CloudSync
//
//  **El desasociar no guarda el grafo personal fuera de la ventana de quiescencia.** Ticket
//  `detach-saves-the-personal-graph-outside-the-quiescence-window`.
//
//  Hasta el 2026-10-02 la única comprobación de quiescencia del desasociar vivía dentro del push-all
//  (`attemptGroupsOnlyClose`). Entre ella y el `save()` del puente (`GroupsAssociationDetach.detachBridge`) pasaban hasta
//  20 ciclos con red y el `signOut()`, y en `.icloud` el espejo sigue vivo sobre el `mainContext` compartido: un import a
//  medio asentar más ese `save()` —que escribe `TransactionItem` e `InboxDraft`— es el `_assertionFailure` que ningún
//  `do/catch` atrapa. Ahora el puente y el borrado pasan por `CloudSessionSignOut.writeDetachUnderQuiescence`, que vuelve a
//  pedir la puerta pegada a sus dos `save()`.
//
//  ## Las dos redes
//
//   1. **Comportamiento, con los tres stores on-disk y el seam de la puerta.** «No quieto» en el momento del `save()`:
//      no se escribe nada, ni en el contexto ni en disco. «Quieto» tras esperar: la puerta corre ANTES de tocar nada y
//      después entra todo. El momento entre el push y el `save()` es exactamente el que este seam representa: lo que
//      el método ve al llegar a la puerta.
//   2. **Cableado, source-scan.** `detachGroupsAccount` toca cinco singletons de proceso (cabecera de
//      `GroupsDetachPurgeFailureTests`), así que lo que se fija leyendo el fuente es que el gesto y su reintento escriben
//      SOLO por este método, con la puerta de producción, y que dentro de él no hay un `await` entre la puerta y los
//      `save()` — un `Task.yield()` ahí reabriría la ventana entera y ningún test de comportamiento lo vería.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Grupos · el desasociar re-comprueba la quiescencia pegada a sus save()", .serialized)
@MainActor
struct GroupsDetachQuiescenceWindowTests {

    // MARK: - Infra

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GDQW-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    /// `UserDefaults` aislado: el host de los unit tests es la propia app, y el libro de conservados escrito en
    /// `.standard` sobreviviría a la corrida.
    private func isolatedDefaults(_ name: String) -> UserDefaults {
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    /// Los tres stores, como en producción. Molde de `GroupsDetachPurgeFailureTests`.
    private func makeFullContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "GDQW-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "GDQW-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "GDQW-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema,
            configurations: personalCfg, groupsCfg, syncMetaCfg)
        return ModelContext(container)
    }

    /// Un grupo del canal backend con su gasto, una transacción del Panel puenteada a él, una fila de outbox y el
    /// cursor: lo que el desasociar escribe, en los tres stores, PERSISTIDO. Devuelve el id del gasto puenteado.
    @discardableResult
    private func seedBridgedDomain(_ context: ModelContext, withBridge: Bool = true) throws -> String {
        let zone = "zona-\(UUID().uuidString)"
        let group = SplitGroup(name: "Viaje")
        group.isBackendGroup = true
        group.cloudKitZoneID = zone
        context.insert(group)
        context.insert(SplitExpense(groupZoneID: zone, amount: 20, expenseDescription: "Cena"))
        let expenseID = UUID().uuidString
        if withBridge {
            let tx = TransactionItem(date: .now, amount: -20, currencyCode: "PEN")
            tx.splitExpenseID = expenseID
            tx.splitGroupZoneID = zone
            context.insert(tx)
        }
        context.insert(GroupSyncOutbox(
            syncID: UUID(), groupID: zone, entityType: "SplitExpense", op: .upsert, hlc: "0", fieldsJSON: "{}",
            author: "test"))
        context.insert(GroupSyncCursor())
        try context.save()
        return expenseID
    }

    /// Lo que hay EN DISCO, leído con un contexto nuevo sobre el mismo container: lo que el contexto del gesto tenga
    /// sucio sin guardar no aparece aquí.
    private struct DiskState: Equatable {
        var bridgedTransactions: Int
        var splitGroups: Int
        var splitExpenses: Int
        var outboxRows: Int
        var cursors: Int

        static let empty = DiskState(bridgedTransactions: 0, splitGroups: 0, splitExpenses: 0, outboxRows: 0, cursors: 0)
    }

    private func diskState(_ context: ModelContext) throws -> DiskState {
        let fresh = ModelContext(context.container)
        return DiskState(
            bridgedTransactions: try fresh.fetchCount(FetchDescriptor<TransactionItem>(
                predicate: #Predicate { $0.splitExpenseID != nil })),
            splitGroups: try fresh.fetchCount(FetchDescriptor<SplitGroup>()),
            splitExpenses: try fresh.fetchCount(FetchDescriptor<SplitExpense>()),
            outboxRows: try fresh.fetchCount(FetchDescriptor<GroupSyncOutbox>()),
            cursors: try fresh.fetchCount(FetchDescriptor<GroupSyncCursor>()))
    }

    // MARK: - (1) Comportamiento

    @Test("Sin quiescencia, el desasociar no toca el puente ni el dominio Grupos: ni en memoria ni en disco")
    func notQuiescent_writesNothing() async throws {
        let dir = freshDir()
        defer { cleanup(dir) }
        let context = try makeFullContext(dir)
        let suite = "GDQW-notquiet-\(UUID().uuidString)"
        let defaults = isolatedDefaults(suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        try seedBridgedDomain(context)
        let before = try diskState(context)
        try #require(before == DiskState(bridgedTransactions: 1, splitGroups: 1, splitExpenses: 1, outboxRows: 1,
                                         cursors: 1), "el andamio no sembró lo que el gesto escribe: el caso no mediría nada")

        var gateCalls = 0
        let outcome = await CloudSessionSignOut.writeDetachUnderQuiescence(
            context: context,
            bridge: .init(choice: .keep, associatedSub: "sub-x"),
            defaults: defaults,
            stillMayWrite: { true },
            awaitPersonalSaveSafe: { gateCalls += 1; return false })

        #expect(gateCalls == 1, "la puerta de quiescencia no se consultó antes de escribir")
        #expect(outcome == .notQuiescent, """
            Con el store personal sin quietud el desasociar siguió adelante. Ese `save()` del puente, con un import de \
            CloudKit a medio asentar sobre el `mainContext` compartido, es el `_assertionFailure` que no atrapa nada.
            """)
        #expect(!context.hasChanges, """
            El contexto quedó sucio: algo se mutó ANTES de la puerta. El siguiente `save()` de cualquier camino lo \
            comitearía igualmente sobre el store a medio asentar.
            """)
        #expect(try diskState(context) == before, "se guardó algo con el store personal sin quietud")
        #expect(GroupsDetachedBridgeLedger.read(defaults: defaults) == nil,
                "el libro de conservados se escribió sin que el puente se soltara")
    }

    @Test("La puerta corre ANTES de tocar nada; si espera y llega la quietud, el puente y el borrado entran")
    func quiescentAfterWaiting_gateRunsFirst_thenWrites() async throws {
        let dir = freshDir()
        defer { cleanup(dir) }
        let context = try makeFullContext(dir)
        let suite = "GDQW-quiet-\(UUID().uuidString)"
        let defaults = isolatedDefaults(suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        let expenseID = try seedBridgedDomain(context)

        // Lo que la puerta ve al ser consultada: el puente intacto y el contexto limpio. Si el puente se moviera por
        // delante de la puerta, esto lo diría aunque el resultado final fuera el mismo.
        var bridgedAtGate: Int?
        var dirtyAtGate: Bool?
        let outcome = await CloudSessionSignOut.writeDetachUnderQuiescence(
            context: context,
            bridge: .init(choice: .keep, associatedSub: "sub-x"),
            defaults: defaults,
            stillMayWrite: { true },
            awaitPersonalSaveSafe: {
                bridgedAtGate = try? context.fetchCount(FetchDescriptor<TransactionItem>(
                    predicate: #Predicate { $0.splitExpenseID != nil }))
                dirtyAtGate = context.hasChanges
                // El store se está asentando: la puerta suspende antes de contestar que sí.
                for _ in 0..<3 { await Task.yield() }
                return true
            })

        #expect(bridgedAtGate == 1 && dirtyAtGate == false, """
            La puerta se consultó con el puente ya tocado (transacciones puenteadas: \(String(describing: bridgedAtGate)), \
            contexto sucio: \(String(describing: dirtyAtGate))). La comprobación tiene que ir delante de los `save()`, \
            no detrás.
            """)
        #expect(outcome == .written)
        #expect(try diskState(context) == .empty,
                "con la quietud confirmada el desasociar no escribió el puente y el borrado")
        #expect(GroupsDetachedBridgeLedger.read(defaults: defaults)?.expenseIDs == [expenseID],
                "`.keep` no dejó el gasto en el libro de conservados")
    }

    @Test("El reintento del borrado pasa por la misma puerta y, sin quietud, no borra")
    func retryPath_notQuiescent_keepsTheGroupsDomain() async throws {
        let dir = freshDir()
        defer { cleanup(dir) }
        let context = try makeFullContext(dir)
        // El estado del reintento: el puente ya se soltó en el primer intento.
        try seedBridgedDomain(context, withBridge: false)
        let before = try diskState(context)

        let blocked = await CloudSessionSignOut.writeDetachUnderQuiescence(
            context: context, bridge: nil, stillMayWrite: { true }, awaitPersonalSaveSafe: { false })
        #expect(blocked == .notQuiescent)
        #expect(!context.hasChanges)
        #expect(try diskState(context) == before, "el reintento borró el dominio Grupos con el store sin quietud")

        // Control positivo: con quietud, el mismo reintento sí borra.
        let written = await CloudSessionSignOut.writeDetachUnderQuiescence(
            context: context, bridge: nil, stillMayWrite: { true }, awaitPersonalSaveSafe: { true })
        #expect(written == .written)
        #expect(try diskState(context) == .empty)
    }

    @Test("Si la condición de quien llama cae DURANTE la espera, no se escribe nada aunque llegue la quietud")
    func preconditionLostDuringTheWait_writesNothing() async throws {
        let dir = freshDir()
        defer { cleanup(dir) }
        let context = try makeFullContext(dir)
        let suite = "GDQW-precondition-\(UUID().uuidString)"
        let defaults = isolatedDefaults(suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        try seedBridgedDomain(context)
        let before = try diskState(context)

        // La sesión vuelve mientras la puerta espera: la condición se tiene que leer DESPUÉS de la espera, no antes.
        var sessionCameBack = false
        let outcome = await CloudSessionSignOut.writeDetachUnderQuiescence(
            context: context,
            bridge: .init(choice: .remove, associatedSub: "sub-x"),
            defaults: defaults,
            stillMayWrite: { !sessionCameBack },
            awaitPersonalSaveSafe: {
                sessionCameBack = true
                await Task.yield()
                return true
            })

        #expect(outcome == .preconditionLost, """
            La sesión volvió durante la espera de quiescencia y el desasociar escribió igual. Antes de la puerta no había \
            un solo `await` entre comprobar la sesión y los `save()`; la espera abre esa ventana y la condición se tiene \
            que volver a mirar tras ella.
            """)
        #expect(!context.hasChanges)
        #expect(try diskState(context) == before)
        #expect(GroupsDetachedBridgeLedger.read(defaults: defaults) == nil)
    }

    // MARK: - (2) Cableado

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    /// Código SIN líneas de comentario: el porqué de cada pieza se explica ahí nombrándola.
    private static func code() throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent("Yala/Services/CloudSync/CloudSessionSignOut.swift"),
                   encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// Del `signature` hasta la primera llave de cierre a la indentación de un miembro (`    }`).
    private static func body(from signature: String) throws -> String {
        let source = try code()
        guard let start = source.range(of: signature) else {
            Issue.record("`\(signature)` desapareció o se renombró")
            return ""
        }
        let tail = source[start.lowerBound...]
        guard let end = tail.range(of: "\n    }\n") else { return String(tail) }
        return String(tail[..<end.upperBound])
    }

    @Test("Dentro del escritor, la puerta es el ÚNICO `await` y va delante del puente y del borrado")
    func writer_gateIsTheOnlySuspensionAndPrecedesTheSaves() throws {
        // Se parte por la apertura del cuerpo: la firma lleva la puerta de producción como valor por defecto.
        let whole = try Self.body(from: "static func writeDetachUnderQuiescence(")
        guard let open = whole.range(of: ") async -> DetachWrite {") else {
            Issue.record("la firma de `writeDetachUnderQuiescence` cambió"); return
        }
        let signature = whole[..<open.lowerBound]
        let body = String(whole[open.upperBound...])

        #expect(signature.contains(
            "awaitPersonalSaveSafe: () async -> Bool = { await CloudSessionSignOut.awaitPersonalQuiescenceForGroupsSignOut() }"),
            "la puerta por defecto ya no es la de quiescencia del store personal")

        guard let gate = body.range(of: "guard await awaitPersonalSaveSafe() else { return .notQuiescent }"),
              let condition = body.range(of: "guard stillMayWrite() else { return .preconditionLost }"),
              let bridge = body.range(of: "GroupsAssociationDetach.detachBridge("),
              let purge = body.range(of: "try purgeGroupsDomainForDetach(context: context)") else {
            Issue.record("el escritor del desasociar cambió de forma: relee el ticket antes de reescribir este test")
            return
        }
        #expect(gate.lowerBound < condition.lowerBound && condition.lowerBound < bridge.lowerBound
                && bridge.lowerBound < purge.lowerBound,
                "el orden ya no es puerta → condición de quien llama → puente → borrado")
        #expect(!signature.contains("stillMayWrite: () -> Bool ="), """
            `stillMayWrite` ganó un valor por defecto. Un `{ true }` heredado deja sin re-comprobar la sesión tras la \
            espera: una puerta que falla abierta.
            """)
        // La PALABRA `await`, no la subcadena: el seam se llama `awaitPersonalSaveSafe`.
        let suspensions = body.matches(of: /\bawait\b/).count
        #expect(suspensions == 1, """
            Hay otro `await` en el escritor del desasociar además de la puerta. Cualquier suspensión entre la puerta y \
            los `save()` deja entrar las notificaciones del import en el main actor, y la quietud que se comprobó ya no \
            describe el store sobre el que se guarda.
            """)
    }

    @Test("El gesto y su reintento escriben SOLO por el escritor con puerta, y con la puerta de producción")
    func coordinator_writesOnlyThroughTheGatedWriter() throws {
        let detach = try Self.body(from: "func detachGroupsAccount(")
        let retry = try Self.body(from: "func retryDetachPurge(")

        for (nombre, cuerpo) in [("detachGroupsAccount", detach), ("retryDetachPurge", retry)] {
            #expect(cuerpo.contains("await Self.writeDetachUnderQuiescence("),
                    "`\(nombre)` ya no escribe por `writeDetachUnderQuiescence`")
            for directo in ["detachBridge(", "purgeGroupsDomainForDetach("] {
                #expect(!cuerpo.contains(directo), """
                    `\(nombre)` vuelve a llamar a `\(directo)` directamente: ese `save()` queda fuera de la puerta de \
                    quiescencia, que es el bug del ticket.
                    """)
            }
            #expect(!cuerpo.contains("awaitPersonalSaveSafe:"), """
                `\(nombre)` le pasa al escritor una puerta propia. Producción tiene que usar la de quiescencia; el seam es \
                de los tests.
                """)
        }
        #expect(retry.contains("context: context, bridge: nil,"), """
            El reintento le pasa un puente al escritor. El puente ya se soltó en el primer intento con la salida elegida, \
            y una segunda pasada la ignoraría.
            """)

        // Los testigos que se re-comprueban tras la espera: los mismos que cada uno comprueba antes de ella.
        #expect(detach.contains("stillMayWrite: { CloudAuthService.shared.storedSessionIsGone }"),
                "el gesto ya no vuelve a mirar que la sesión siga cerrada tras la espera")
        #expect(retry.contains(
            "stillMayWrite: { CloudAuthService.shared.currentUserID != GroupsDetachPendingPurge.armedSub() }"),
            "el reintento ya no vuelve a mirar, tras la espera, que la sesión viva no sea la de la cuenta pendiente")

        // Las ramas del reintento que no escriben: sin quietud, aviso de «no pudimos soltar» sin canario; con la sesión
        // de esa cuenta de vuelta, ocupado. Ninguna remata: con `break` caería en `finishDetach` y diría `.detached`
        // con los grupos enteros en el teléfono.
        for (rama, siguiente, devuelve) in [("case .notQuiescent, .bridgeUnreadable:", "\n        }\n", "return .purgeFailed"),
                                           ("case .preconditionLost:", "        case .", "return .busy")] {
            guard let start = retry.range(of: rama),
                  let end = retry.range(of: siguiente, range: start.upperBound..<retry.endIndex) else {
                Issue.record("el reintento ya no tiene la rama `\(rama)`"); continue
            }
            let branch = String(retry[start.upperBound..<end.lowerBound])
            #expect(branch.contains("phase = .idle") && branch.contains(devuelve),
                    "la rama `\(rama)` del reintento ya no deja la fase libre y devuelve `\(devuelve)`")
            for prohibido in ["finishDetach", "MetricsService.canary", "break"] {
                #expect(!branch.contains(prohibido), "la rama `\(rama)` del reintento hace `\(prohibido)`")
            }
        }

        // El escritor va DETRÁS del cierre de sesión comprobado, el último `await` de antes.
        guard let signOut = detach.range(of: "guard await CloudAuthService.shared.signOut() else {"),
              let write = detach.range(of: "await Self.writeDetachUnderQuiescence(") else {
            Issue.record("el desasociar cambió de forma"); return
        }
        #expect(signOut.lowerBound < write.lowerBound, "el escritor ya no va detrás del cierre de sesión")

        // Sin quietud, el gesto se para sin escribir nada y con el motivo del puente sin revisar.
        guard let notQuiet = detach.range(of: "case .notQuiescent, .bridgeUnreadable:"),
              let purgeFailed = detach.range(of: "case .purgeFailed:") else {
            Issue.record("el desasociar ya no distingue el bloqueo por falta de quietud"); return
        }
        let branch = String(detach[notQuiet.upperBound..<purgeFailed.lowerBound])
        #expect(branch.contains("phase = .blocked(pendingCount: 0, reason: .bridgeUnreadable)"), """
            Sin quietud el gesto ya no se para con `.bridgeUnreadable`. `.transient` diría «quedan cambios de tus grupos \
            sin subir», y aquí el push-all ya drenó.
            """)
        #expect(branch.contains("return .blockedBeforeWriting"))
        for prohibido in ["GroupsDetachPendingPurge.arm", "finishDetach", "MetricsService.canary"] {
            #expect(!branch.contains(prohibido), "la rama sin quietud hace `\(prohibido)`")
        }
        guard let lost = detach.range(of: "case .preconditionLost:") else {
            Issue.record("el gesto ya no distingue la sesión que volvió durante la espera"); return
        }
        let lostBranch = String(detach[lost.upperBound..<notQuiet.lowerBound])
        #expect(lostBranch.contains("phase = .blocked(pendingCount: 0, reason: .sessionNotClosed)")
                && lostBranch.contains("return .blockedBeforeWriting")
                && lostBranch.contains(".groupsDetachSessionSurvived"),
                "con la sesión de vuelta el gesto ya no se para como con la que sobrevive a su cierre")
        for prohibido in ["GroupsDetachPendingPurge.arm", "finishDetach"] {
            #expect(!lostBranch.contains(prohibido), "la rama de la sesión que volvió hace `\(prohibido)`")
        }
    }
}
