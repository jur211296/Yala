//
//  PrivateExitInboundCaptureTests.swift
//  YalaTests / CloudSync
//
//  Ticket `private-exit-loses-unmaterialized-inbound-captures`: un pago de Apple Pay o un dictado de Siri que
//  espera en el App Group se perdía al cerrar una sesión privada. No estaba en el store, así que la espera del
//  export no lo contaba, y el arranque siguiente lo purgaba.
//
//  Las dos direcciones del arreglo:
//   - **El cierre privado materializa ANTES de contar**: lo capturado viaja a iCloud como cualquier cambio, y lo
//     que no se pudo materializar cuenta como pendiente.
//   - **Con el borrado armado nadie drena** al store condenado.
//
//  Tres capas: la lógica pura (orden y suma), una integración sobre historial REAL en disco con el servicio de
//  Apple Pay de verdad, y el cableado por source-scan —el coordinador del cierre es privado y exige singletons—.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

// MARK: - Lógica pura

@Suite("Cierre privado · capturas del App Group (lógica pura)", .serialized)
@MainActor
struct PrivateExitInboundCaptureLogicTests {

    @Test("con el borrado de cierre armado no se drena nada")
    func drain_wipeArmed_touchesNothing() throws {
        var calls: [String] = []
        let created = InboundCaptureDrain.drain(
            context: try makeTestContext(),
            wipeArmed: true,
            applePay: { _ in calls.append("applePay"); return 1 },
            siri: { _ in calls.append("siri"); return 1 })
        #expect(created == 0)
        #expect(calls.isEmpty, "el store está condenado: drenar ahí escribe lo que nadie va a subir")
    }

    @Test("sin borrado armado drena Apple Pay y Siri y suma lo creado")
    func drain_notArmed_drainsBoth() throws {
        var calls: [String] = []
        let created = InboundCaptureDrain.drain(
            context: try makeTestContext(),
            wipeArmed: false,
            applePay: { _ in calls.append("applePay"); return 2 },
            siri: { _ in calls.append("siri"); return 1 })
        #expect(created == 3)
        #expect(calls == ["applePay", "siri"])
    }

    @Test("el cierre materializa ANTES de leer el historial")
    func count_materializesBeforeReadingHistory() {
        var events: [String] = []
        let count = PrivateSignOutExportGateLogic.pendingCountMaterializingInbound(
            materialize: { events.append("materialize"); return (created: 1, stillQueued: 0) },
            historyPending: { _ in events.append("history"); return 1 })
        #expect(events == ["materialize", "history"], """
            Contar antes de materializar deja fuera la captura: el cero autoriza el borrado y la purga del \
            arranque se la lleva.
            """)
        #expect(count == 1)
    }

    @Test("lo que no se pudo materializar cuenta como pendiente")
    func count_stillQueued_addsToPending() {
        let count = PrivateSignOutExportGateLogic.pendingCountMaterializingInbound(
            materialize: { (created: 0, stillQueued: 2) },
            historyPending: { _ in 0 })
        #expect(count == 2, "un historial a cero con capturas en cola no es un cero: la espera no puede confirmar")
    }

    @Test("un historial que no se pudo contar sigue sin número, haya o no cola")
    func count_unknownHistory_staysUnknown() {
        let count = PrivateSignOutExportGateLogic.pendingCountMaterializingInbound(
            materialize: { (created: 0, stillQueued: 3) },
            historyPending: { _ in nil })
        #expect(count == nil)
    }

    @Test("el historial se entera de si el store cambió en esta vuelta")
    func count_reportsStoreChange() {
        var seen: [Bool] = []
        _ = PrivateSignOutExportGateLogic.pendingCountMaterializingInbound(
            materialize: { (created: 1, stillQueued: 0) },
            historyPending: { changed in seen.append(changed); return 0 })
        _ = PrivateSignOutExportGateLogic.pendingCountMaterializingInbound(
            materialize: { (created: 0, stillQueued: 0) },
            historyPending: { changed in seen.append(changed); return 0 })
        #expect(seen == [true, false], "sin esto, un cero cacheado sin ancla sobreviviría a un borrador recién creado")
    }

    @Test("la cola que se cuenta es la de Apple Pay Y la de Siri")
    func queuedCount_countsBothQueues() {
        let applePay = makeIsolatedDefaults(prefix: "test.inboundQueue.applePay")
        let siri = makeIsolatedDefaults(prefix: "test.inboundQueue.siri")
        #expect(InboundCaptureDrain.queuedCount(applePayDefaults: applePay, siriDefaults: siri) == 0)
        SiriPendingStore.append(
            SiriPendingEntry(rawText: "20 en café", transactions: [], savedAt: 1_700_000_000), defaults: siri)
        #expect(InboundCaptureDrain.queuedCount(applePayDefaults: applePay, siriDefaults: siri) == 1, """
            Un dictado de Siri en cola con el import activo no contaba: el recuento decía cero y la purga del \
            arranque se lo llevaba.
            """)
        ApplePayPendingStore.append(
            ApplePayPendingExpense(rawAmount: "S/ 25,90", merchant: nil, savedAt: 1_700_000_000), defaults: applePay)
        #expect(InboundCaptureDrain.queuedCount(applePayDefaults: applePay, siriDefaults: siri) == 2)
    }

    @Test("la pasada del cierre materializa y luego mira la cola")
    func forSignOut_drainsThenReadsQueue() throws {
        var events: [String] = []
        let outcome = InboundCaptureDrain.forSignOut(
            context: try makeTestContext(),
            drain: { _ in events.append("drain"); return 1 },
            queued: { events.append("queued"); return 0 })
        #expect(events == ["drain", "queued"])
        #expect(outcome.created == 1)
        #expect(outcome.stillQueued == 0)
    }
}

// MARK: - Integración: historial real, servicio de Apple Pay de verdad

/// La cadena entera con piezas reales: una captura de Apple Pay en una cola aislada, el servicio que la convierte
/// y el contador del historial sobre un store en DISCO (el historial in-memory no sirve). Solo se inyectan la
/// cola y la quiescencia; Siri queda fuera para no leer el App Group compartido del proceso.
@Suite("Cierre privado · la captura sube con el export (historial real, on-disk)", .serialized, .lastUsedAccountIsolated)
@MainActor
struct PrivateExitInboundCaptureIntegrationTests {

    private func freshDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("InboundCapture-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) {
        do {
            try FileManager.default.removeItem(at: dir)
        } catch {
            print("PrivateExitInboundCaptureIntegrationTests: no se pudo borrar \(dir.lastPathComponent): \(error)")
        }
    }

    /// El mismo andamio que `PersonalExportPendingCounterTests`: tres stores y un contexto que los abarca.
    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "IC-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "IC-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "IC-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema,
            configurations: personalCfg, groupsCfg, syncMetaCfg)
        return ModelContext(container)
    }

    /// Una vuelta del recuento del cierre con piezas reales. `quiescent` finge el estado del import.
    private func signOutCount(_ context: ModelContext, queue: UserDefaults, quiescent: Bool,
                              anchor: Date? = .distantPast) -> Int? {
        PrivateSignOutExportGateLogic.pendingCountMaterializingInbound(
            materialize: {
                InboundCaptureDrain.forSignOut(
                    context: context,
                    drain: { ctx in
                        InboundCaptureDrain.drain(
                            context: ctx,
                            wipeArmed: false,
                            applePay: { ApplePayDraftService.processPending(
                                context: $0, pendingStoreDefaults: queue, importQuiescent: quiescent) },
                            siri: { _ in 0 })
                    },
                    queued: { ApplePayPendingStore.peekAll(defaults: queue).count })
            },
            historyPending: { _ in
                PersonalExportPendingCounter.pendingChangeCount(context: context, confirmedExportStart: anchor)
            })
    }

    private func drafts(_ context: ModelContext) throws -> [InboxDraft] {
        try context.fetch(FetchDescriptor<InboxDraft>())
    }

    private func enqueuePayment(_ queue: UserDefaults) {
        ApplePayPendingStore.append(
            ApplePayPendingExpense(rawAmount: "S/ 25,90", merchant: nil, savedAt: 1_700_000_000),
            defaults: queue)
    }

    @Test("el pago pendiente se convierte en borrador y el recuento lo ve")
    func pendingPayment_becomesDraft_andCounts() throws {
        let dir = try freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let queue = makeIsolatedDefaults(prefix: "test.inboundCapture")
        enqueuePayment(queue)
        // Control: con el store vacío el historial dice cero. Es el cero que autorizaba el borrado.
        #expect(PersonalExportPendingCounter.pendingChangeCount(context: context, confirmedExportStart: .distantPast) == 0)

        let count = signOutCount(context, queue: queue, quiescent: true)

        #expect(try drafts(context).count == 1, "el pago no se convirtió en borrador: la purga del arranque se lo lleva")
        #expect(ApplePayPendingStore.peekAll(defaults: queue).isEmpty)
        #expect(count == 1, "el borrador es un cambio local sin subir: la espera tiene que verlo")
    }

    /// Sin ancla (nunca se vio un export con éxito) el contador no da número si hay escrituras locales. Con el
    /// store sin nada local el historial dice cero, y es justo el cero que autorizaba el borrado: el borrador
    /// recién creado tiene que convertirlo en «no se puede confirmar», nunca dejarlo en cero.
    @Test("sin ancla, el borrador recién creado deja el recuento sin número, nunca en cero")
    func withoutAnchor_newDraft_makesTheCountUnknown() throws {
        let dir = try freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let queue = makeIsolatedDefaults(prefix: "test.inboundCapture")
        enqueuePayment(queue)
        #expect(PersonalExportPendingCounter.pendingChangeCount(context: context, confirmedExportStart: nil) == 0)

        let count = signOutCount(context, queue: queue, quiescent: true, anchor: nil)

        #expect(try drafts(context).count == 1)
        #expect(count == nil, "sin ancla y con un cambio local no hay cero honesto: la espera no puede confirmar")
    }

    @Test("con el import activo el pago no se materializa, pero cuenta como pendiente")
    func importBusy_paymentStaysQueued_andStillCounts() throws {
        let dir = try freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let queue = makeIsolatedDefaults(prefix: "test.inboundCapture")
        enqueuePayment(queue)

        let count = signOutCount(context, queue: queue, quiescent: false)

        #expect(try drafts(context).isEmpty)
        #expect(ApplePayPendingStore.peekAll(defaults: queue).count == 1)
        #expect(count == 1, "una captura sin materializar no es un cero: el cierre no puede borrar")

        // En cuanto el import se aquieta, la vuelta siguiente la materializa y sigue contando: ahora como cambio.
        let next = signOutCount(context, queue: queue, quiescent: true)
        #expect(try drafts(context).count == 1)
        #expect(ApplePayPendingStore.peekAll(defaults: queue).isEmpty)
        #expect(next == 1)
    }
}

// MARK: - Cableado (source-scan)

/// El coordinador del cierre y el observer de cambios remotos no se pueden instanciar en un test (singletons,
/// red, espejo). Lo que se fija aquí es que TODOS los recuentos del cierre pasan por la materialización, y que
/// TODOS los drenajes pasan por el guard del borrado armado.
@Suite("Cierre privado · capturas del App Group (cableado, source-scan)")
struct PrivateExitInboundCaptureWiringTests {

    private static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // CloudSync/
        .deletingLastPathComponent()  // YalaTests/
        .deletingLastPathComponent()  // raíz del repo

    private static func source(_ relativePath: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// El cuerpo de la función que empieza en `marker`. Salta la firma entera —los paréntesis, con las llaves
    /// de los closures por defecto dentro— y corta en la llave que cierra el cuerpo, no en la del tipo.
    private static func body(of marker: String, in source: String) throws -> String {
        let start = try #require(source.range(of: marker), "no se encontró `\(marker)`")
        var parens = 0
        var index = start.lowerBound
        while index < source.endIndex {
            let ch = source[index]
            if ch == "(" { parens += 1 }
            if ch == ")" { parens -= 1 }
            if ch == "{" && parens == 0 { break }
            index = source.index(after: index)
        }
        #expect(index < source.endIndex, "sin cuerpo tras `\(marker)`")
        var depth = 0
        var out = ""
        for ch in source[index...] {
            if ch == "{" { depth += 1; if depth == 1 { continue } }
            if ch == "}" { depth -= 1; if depth == 0 { break } }
            out.append(ch)
        }
        return out
    }

    private static func occurrences(_ needle: String, in haystack: String) -> Int {
        haystack.components(separatedBy: needle).count - 1
    }

    private static let signOutPath = "Yala/Services/CloudSync/CloudSessionSignOut.swift"
    private static let drainPath = "Yala/App/Services/InboundCaptureDrain.swift"

    /// Todos los `.swift` de la app, sin comentarios, por ruta relativa.
    private static func appSources() throws -> [(path: String, text: String)] {
        let appRoot = root.appendingPathComponent("Yala")
        let enumerator = try #require(FileManager.default.enumerator(at: appRoot, includingPropertiesForKeys: nil))
        var out: [(String, String)] = []
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            let relative = String(url.path.dropFirst(root.path.count + 1))
            out.append((relative, try source(relative)))
        }
        return out
    }

    @Test("nadie fuera de InboundCaptureDrain drena las colas de Apple Pay y Siri")
    func onlyTheDrainCallsProcessPending() throws {
        var callers: [String] = []
        for (path, text) in try Self.appSources() {
            for call in ["ApplePayDraftService.processPending(", "SiriDraftService.processPending("]
            where text.contains(call) {
                callers.append("\(path): \(call)")
            }
        }
        #expect(callers.sorted() == [
            "\(Self.drainPath): ApplePayDraftService.processPending(",
            "\(Self.drainPath): SiriDraftService.processPending(",
        ], """
            Un drenaje fuera del helper se salta el guard del borrado armado: escribe en el store condenado.
            """)
    }

    @Test("el guard del borrado armado va antes de drenar, y lee el arm de verdad")
    func drainGuardsTheArmedWipe() throws {
        let src = try Self.source(Self.drainPath)
        #expect(src.contains("wipeArmed: Bool = StorageModePersistence.isSignOutWipeArmed(),"))
        #expect(src.contains("applePay: @MainActor (ModelContext) -> Int = { ApplePayDraftService.processPending(context: $0) },"))
        #expect(src.contains("siri: @MainActor (ModelContext) -> Int = { SiriDraftService.processPending(context: $0) }"))
        let drain = try Self.body(of: "static func drain(", in: src)
        let guardRange = try #require(drain.range(of: "guard !wipeArmed else { return 0 }"))
        let firstDrain = try #require(drain.range(of: "applePay(context)"))
        #expect(guardRange.lowerBound < firstDrain.lowerBound)
        let forSignOut = try Self.body(of: "static func forSignOut(", in: src)
        #expect(forSignOut.contains("let created = drain(context)"))
        #expect(src.contains("drain: @MainActor (ModelContext) -> Int = { InboundCaptureDrain.drain(context: $0) },"))
        #expect(src.contains("queued: @MainActor () -> Int = { InboundCaptureDrain.queuedCount() }"))
        let queuedCount = try Self.body(of: "static func queuedCount(", in: src)
        #expect(queuedCount.contains("ApplePayPendingStore.peekAll(defaults: applePayDefaults).count"))
        #expect(queuedCount.contains("SiriPendingStore.peekAll(defaults: siriDefaults).count"))
    }

    @Test("el remote-change, el foreground y el arranque drenan por el helper")
    func bootstrapperDrainsThroughTheHelper() throws {
        let src = try Self.source("Yala/App/AppBootstrapper.swift")
        let observer = try Self.body(of: "private func observeRemoteStoreChanges() {", in: src)
        #expect(observer.contains("InboundCaptureDrain.drain(context: ctx) > 0"), """
            El final de la ráfaga de cambios remotos dejó de drenar por el helper: con el borrado armado \
            materializaría en el store que el arranque va a borrar.
            """)
        let becameActive = try Self.body(of: "func handleBecameActive(context: ModelContext) {", in: src)
        #expect(becameActive.contains("InboundCaptureDrain.drain(context: context) > 0"))
        let bootstrap = try Self.body(of: "func bootstrap(container: ModelContainer) async {", in: src)
        #expect(bootstrap.contains("InboundCaptureDrain.drain(context: context)"))
        #expect(Self.occurrences("InboundCaptureDrain.drain(context:", in: src) == 3)
    }

    @Test("todo recuento del cierre materializa antes, y el historial solo se lee por un sitio")
    func everySignOutCountMaterializesFirst() throws {
        let src = try Self.source(Self.signOutPath)
        let wrapper = try Self.body(of: "static func pendingPersonalExportCount(context: ModelContext) -> Int? {", in: src)
        #expect(wrapper.contains("PrivateSignOutExportGateLogic.pendingCountMaterializingInbound("))
        #expect(wrapper.contains("materialize: { InboundCaptureDrain.forSignOut(context: context) },"), """
            El recuento pegado al arm dejó de materializar: una captura llegada durante la espera muere con el \
            borrado sin haberse contado.
            """)
        let gate = try Self.body(
            of: "private func confirmExportOrBlock(context: ModelContext, kind: CloudSignOutFlowLogic.ExitKind, credentialsReleased: Bool) async -> Bool {",
            in: src)
        #expect(gate.contains("PrivateSignOutExportGateLogic.pendingCountMaterializingInbound("))
        #expect(gate.contains("let inbound = InboundCaptureDrain.forSignOut(context: context)"), """
            La espera del export dejó de materializar: el cierre privado vuelve a purgar sin convertir las \
            capturas en borrador.
            """)
        let changed = try #require(gate.range(of: "if storeChanged { withoutAnchor = .none }"), """
            Sin esto, un cero cacheado sin ancla sobrevive a un borrador recién creado y el cierre borra.
            """)
        let cached = try #require(gate.range(of: "if case .some(let cached) = withoutAnchor { return cached }"))
        #expect(changed.lowerBound < cached.lowerBound, "invalidar después de leer la caché no invalida nada")
        let shrank = try #require(gate.range(of: "if let lastQueued, inbound.stillQueued < lastQueued { withoutAnchor = .none }"), """
            Sin esto, un drenado ajeno durante la espera (primer plano, remote-change) deja vivo un cero cacheado.
            """)
        let remember = try #require(gate.range(of: "lastQueued = inbound.stillQueued"))
        #expect(shrank.lowerBound < remember.lowerBound)
        // Leer el historial por otro camino es contar sin materializar.
        #expect(Self.occurrences("PersonalExportPendingCounter.pendingChangeCount(", in: src) == 1)
        let history = try Self.body(of: "private static func personalHistoryPendingCount(context: ModelContext) -> Int? {", in: src)
        #expect(history.contains("PersonalExportPendingCounter.pendingChangeCount("))
        #expect(Self.occurrences("personalHistoryPendingCount(context: context)", in: src) == 3,
                "uno en el recuento con materialización y dos en la espera; ninguno más")
    }
}
