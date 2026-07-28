//
//  GroupPullRescueWiringTests.swift
//  YalaTests / CloudSync
//
//  C-4 (PIEZA 2): cableado de producción del rescate (source-scan).
//
//  POR QUÉ HACE FALTA. El evento del delegate (`CKSyncEngine.Event.FetchedRecordZoneChanges`) no es
//  construible desde tests, así que el BUCLE donde vive el rescate no se puede ejercitar. Los tests de
//  decisión (gate puro) y de mutación (`applyRemoteRecordIfAbsent`) quedarían los dos en verde con el
//  rescate desconectado, con las deletions rescatadas por error, o con un seam inerte que lo mata en
//  producción. Estos scans nombran al culpable. Mismo patrón y misma razón que `GroupFetchGateWiringTests`.
//

import Foundation
import Testing

@testable import Yala

@Suite("C-4 PIEZA 2 · cableado del rescate (source-scan)")
struct GroupPullRescueWiringTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
    }

    /// Igual que `source(_:)` pero SIN líneas de comentario: los asserts NEGATIVOS hablan de CÓDIGO, y
    /// esta feature documenta en prosa justo lo que no debe hacer (actualizar, tocar deletions) — un
    /// `contains` sobre el fuente crudo se auto-refutaría contra su propia explicación.
    private static func code(_ path: String) throws -> String {
        try source(path)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    private static let manager = "Yala/Services/Groups/SplitSyncManager.swift"

    /// Cuerpo de `applyRemoteRecordIfAbsent`, para poder afirmar cosas SOBRE ÉL y no sobre el archivo
    /// entero (que legítimamente llama a `CKRecordTranslator.update` en los applies normales).
    private static func rescueBody() throws -> String {
        let src = try code(manager)
        let start = try #require(src.range(of: "func applyRemoteRecordIfAbsent("))
        let end = try #require(src.range(of: "private func applyGroupMeta(", range: start.upperBound..<src.endIndex))
        return String(src[start.lowerBound..<end.lowerBound])
    }

    // MARK: - El rescate está conectado al bucle

    /// El guard de las MODIFICACIONES consulta el gate y solo adopta con `.rescue`. Sin esto la feature
    /// no existe en producción por mucho que sus piezas estén verdes.
    @Test func theModificationLoopConsultsTheGate() throws {
        let src = try Self.code(Self.manager)
        #expect(src.contains("GroupPullRescueGate.Signal("))
        #expect(src.contains("guard GroupPullRescueGate.decide(signal) == .rescue else"))
        #expect(src.contains("applyRemoteRecordIfAbsent(record, context: modelContext, engineName: engineName)"))
        // El descarte deja de ser mudo: lleva el motivo del gate, que es lo que separa el eco stale
        // legítimo del dinero perdido cuando se lee Console.app.
        #expect(src.contains("reason: GroupPullRescueGate.skipReason(signal)"))
    }

    /// Las SIETE entradas de la señal salen del estado real del manager. Una constante colada aquí
    /// (`prefetchFailed: false`, `replayingFullCorpus: false`) desactivaría un gate entero sin que
    /// ningún test de comportamiento se enterase.
    @Test func theSignalIsBuiltFromRealState() throws {
        let src = try Self.code(Self.manager)
        #expect(src.contains("flagOn: rescueFlagOn"))
        #expect(src.contains("let rescueFlagOn = CloudSyncFlags.groupsBackendEnabled"))
        #expect(src.contains("replayingFullCorpus: replayingFullCorpus"))
        #expect(src.contains("prefetchFailed: prefetchFailed"))
        #expect(src.contains("backendPullCompletedThisSession: pull.completed"))
        #expect(src.contains("groupHasBackendCursor: pull.hasCursor"))
        #expect(src.contains("isRescuableType: GroupPullRescueGate.entityName(forRecordType: record.recordType) != nil"))
        #expect(src.contains("existsLocally: recordExistsLocally(record, context: modelContext)"))
    }

    /// El default del seam lee el canal REAL. Es el único assert que distingue «rescate cableado» de
    /// «rescate presente pero muerto»: un default constante `false` deja todo en verde y el gate cerrado
    /// para siempre en producción.
    @Test func theProductionSeamReadsTheRealBackendChannel() throws {
        let src = try Self.code(Self.manager)
        #expect(src.contains("GroupsSyncClient.shared.backendPullSignal(groupID: zoneName, context: context)"))
        #expect(src.contains("backendPullSignalProvider(zoneName, modelContext)"))
    }

    // MARK: - Invariante 1: el rescate jamás actualiza

    /// El candado vive en el SITIO DE LA MUTACIÓN. `applyRemoteRecordIfAbsent` no puede contener ni una
    /// llamada a `CKRecordTranslator.update` ni delegar en `applyRemoteRecord` (que sí actualiza).
    @Test func theRescueNeverUpdates() throws {
        let body = try Self.rescueBody()
        #expect(!body.contains("CKRecordTranslator.update"))
        #expect(!body.contains("applyRemoteRecord(record"))
        // Y re-pregunta por la existencia, en vez de fiarse del Set best-effort del pre-fetch.
        #expect(body.contains("!recordExistsLocally(record, context: context)"))
        #expect(!body.contains("existingExpenseIDs"))
        #expect(!body.contains("existingSettlementIDs"))
        #expect(!body.contains("existingMemberIDs"))
    }

    /// La existencia se pregunta con los helpers CONCRETOS por tipo (regla inviolable del repo:
    /// `#Predicate` concreto, nunca genérico-protocolo — el genérico crashea al ejecutar el fetch).
    @Test func existenceUsesTheConcreteHelpers() throws {
        let src = try Self.code(Self.manager)
        let start = try #require(src.range(of: "func recordExistsLocally("))
        let end = try #require(src.range(of: "func applyRemoteRecordIfAbsent(", range: start.upperBound..<src.endIndex))
        let body = String(src[start.lowerBound..<end.lowerBound])
        for helper in ["splitGroup(byID:", "splitExpense(byID:", "splitMember(byID:",
                       "splitShare(byID:", "splitSettlement(byID:"] {
            #expect(body.contains(helper.replacingOccurrences(of: ":", with: ": modelID, in: context)")))
        }
    }

    // MARK: - Invariante 2: las deletions no se rescatan nunca

    /// El bucle de deletions descarta incondicionalmente. Si alguien colase ahí el gate, el rescate
    /// «adoptaría» bajas y borraría en local lo que el backend conserva.
    @Test func theDeletionLoopNeverConsultsTheGate() throws {
        let src = try Self.code(Self.manager)
        // Anclar DESPUÉS del bucle de modificaciones: `handleFetchedDatabaseChanges` tiene su propio
        // `for deletion in fetched.deletions` más arriba, y buscarlo a secas capturaría el rango
        // equivocado (que además contiene el gate legítimamente → el test pasaría en verde por error).
        let modifications = try #require(src.range(of: "for modification in fetched.modifications {"))
        let start = try #require(src.range(of: "for deletion in fetched.deletions {",
                                           range: modifications.upperBound..<src.endIndex))
        let end = try #require(src.range(of: "SaveBreadcrumb.willSave(\"SplitSync.fetchedRecordZoneChanges\")",
                                         range: start.upperBound..<src.endIndex))
        let body = String(src[start.lowerBound..<end.lowerBound])
        #expect(!body.contains("GroupPullRescueGate"))
        #expect(!body.contains("applyRemoteRecordIfAbsent"))
        #expect(body.contains("reason: \"deletion\""))
    }

    // MARK: - Los testigos de sesión y de batch

    /// `replayingFullCorpus` se enciende en los CINCO caminos que dejan a CloudKit re-entregando el
    /// corpus entero (arranque sin state, reset de tokens, engines recreados por cambio de identidad,
    /// zona purgada y `encryptedDataReset`), y NUNCA se apaga dentro de la sesión (la re-entrega dura
    /// toda la sesión, no un ciclo). Un `= false` colado en cualquier sitio reabriría la resurrección
    /// en masa.
    @Test func fullCorpusReplayWitnessIsSetEverywhereAndNeverCleared() throws {
        let src = try Self.code(Self.manager)
        #expect(src.components(separatedBy: "replayingFullCorpus = true").count - 1 == 5)
        let clears = src
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { $0.contains("replayingFullCorpus = false") }
        #expect(clears.count == 1, "solo la declaración puede inicializarlo a false")
        #expect(clears.first?.contains("var replayingFullCorpus") == true)
        // Y el arranque fresco lo detecta donde se decide: `loadState` devolviendo nil.
        #expect(src.contains("if privateState == nil || sharedState == nil { replayingFullCorpus = true }"))
    }

    /// El `catch` del pre-fetch enciende la bandera del batch. Sin ella, un fetch fallido haría que todo
    /// el batch pareciera «nunca visto».
    @Test func theBestEffortPrefetchRaisesItsFlag() throws {
        let src = try Self.code(Self.manager)
        let start = try #require(src.range(of: "var prefetchFailed = false"))
        let end = try #require(src.range(of: "let rescueFlagOn", range: start.upperBound..<src.endIndex))
        #expect(String(src[start.lowerBound..<end.lowerBound]).contains("prefetchFailed = true"))
    }

    /// El canario del rescate va DESPUÉS del `save()` y dentro de su `do` — un rescate que no persistió
    /// no rescató nada, y contarlo antes mentiría en el dashboard del encendido.
    @Test func theRescueCanaryFiresOnlyAfterASuccessfulSave() throws {
        let src = try Self.code(Self.manager)
        let save = try #require(src.range(of: "SaveBreadcrumb.didSave(\"SplitSync.fetchedRecordZoneChanges\")"))
        let canary = try #require(src.range(of: "MetricsService.canary(.groupCkPullRescued"))
        let failure = try #require(src.range(of: "GroupsSyncBreadcrumb.groupsCkFetchApplyFailed(reason: \"save-failed\")"))
        #expect(save.upperBound < canary.lowerBound)
        #expect(canary.upperBound < failure.lowerBound, "el canario debe quedar en la rama de ÉXITO")
    }

    /// El drain en caliente corre FUERA del handler del engine (en la tarea diferida) y bajo el flag.
    @Test func theOpportunisticDrainRunsOutsideTheDelegateHandler() throws {
        let src = try Self.code(Self.manager)
        let start = try #require(src.range(of: "private func processPendingRemoteChanges() async {"))
        let end = try #require(src.range(of: "await GroupService.shared.refreshCurrentUserFlags",
                                         range: start.upperBound..<src.endIndex))
        let body = String(src[start.lowerBound..<end.lowerBound])
        #expect(body.contains("if CloudSyncFlags.groupsBackendEnabled"))
        #expect(body.contains("GroupsSyncClient.shared.drainOnce(context: modelContext)"))
    }

    // MARK: - El suelo del corte de History incluye el canal de Grupos

    /// El History es por CONTAINER: si el corte solo mira el outbox personal, puede borrar la
    /// transacción de una fila recién rescatada antes de que el drain de Grupos la vea.
    @Test func theHistoryCutFloorIncludesTheGroupsChannel() throws {
        let src = try Self.code("Yala/Services/CloudSync/CloudSyncEngine.swift")
        let start = try #require(src.range(of: "func deleteHistorySafeCut("))
        let end = try #require(src.range(of: "private func oldestUnconfirmedOutboxDate(",
                                         range: start.upperBound..<src.endIndex))
        let body = String(src[start.lowerBound..<end.lowerBound])
        #expect(body.contains("groupDrainedBoundary(context)"))
        #expect(body.contains("oldestLiveGroupOutboxDate(context)"))
        // El corte es el MÍNIMO de todos los suelos: un `max` o un suelo olvidado adelantaría la purga.
        #expect(body.contains(".min()"))
    }
}
