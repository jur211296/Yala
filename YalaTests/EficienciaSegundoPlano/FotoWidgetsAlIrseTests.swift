//
//  FotoWidgetsAlIrseTests.swift
//  YalaTests
//
//  Lote 3 de eficiencia (26-nov-2026): al pasar a segundo plano, la foto de los widgets pedida se termina por etapas y con
//  el permiso de segundo plano de iOS, no de una vez. Medido en el iPhone 14 con 16.004 movimientos: abrir Yala en frío y
//  salir a los 3 s acabó con la app cerrada por iOS (`0x8BADF00D`) en 4 de 5 vueltas, con el hilo principal dentro de
//  `WidgetDataCache.flushPendingUpdate()` → `buildSnapshot`, que se llamaba desde `YalaApp.handleScenePhase`.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Segundo plano · la foto de los widgets al irse va por etapas", .serialized)
@MainActor
struct FotoWidgetsAlIrseTests {

    private func waitUntilPublished() async throws {
        for _ in 0..<1_500 where WidgetDataCache.hasPendingUpdate {
            try await Task.sleep(for: .milliseconds(20))
        }
    }

    @Test("Irse con una foto pedida: no la hace de una vez, cede el hilo y queda publicada sin esperar el segundo")
    func flushOnBackground_buildsInStagesAndPublishes() async throws {
        let dir = CuelguesFixture.freshDir(); defer { discardTestStoreDirectory(dir) }
        let container = try CuelguesFixture.makeContainer(dir)
        try CuelguesFixture.seed(container, count: 3_000, now: .now, spacing: 1_800)
        let context = ModelContext(container)
        WidgetDataCache.cancelPendingUpdate()
        defer { WidgetDataCache.cancelPendingUpdate() }

        WidgetDataCache.updateCache(context: context)   // pedida: espera un segundo
        let clock = ContinuousClock()
        let start = clock.now
        WidgetDataCache.flushPendingUpdate()           // el paso a segundo plano

        // De una vez, aquí ya estaría publicada.
        #expect(WidgetDataCache.hasPendingUpdate, "la foto se hizo de una vez al irse, con el hilo principal ocupado")
        let measured = try await CuelguesFixture.measureMainThread(while: { WidgetDataCache.hasPendingUpdate })
        #expect(measured.turns >= 8, "el hilo principal solo atendió \(measured.turns) tareas mientras se hacía la foto")
        try await waitUntilPublished()
        #expect(!WidgetDataCache.hasPendingUpdate)
        #expect(WidgetDataCache.debugLastStagedBuildStages >= 10)
        // No esperó la ventana de un segundo de `updateCache`: arrancó al irse.
        #expect(clock.now - start < .seconds(30))
    }

    @Test("Irse sin nada pedido no hace nada")
    func flushOnBackground_withNothingPending_doesNothing() {
        WidgetDataCache.cancelPendingUpdate()
        WidgetDataCache.flushPendingUpdate()
        #expect(!WidgetDataCache.hasPendingUpdate)
    }

    @Test("El paso a segundo plano de la app llama a esta foto (source-scan)")
    func appBackground_callsTheStagedFlush() throws {
        let root = URL(fileURLWithPath: "\(#filePath)")
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let cache = try String(contentsOf: root.appending(path: "Yala/Services/WidgetDataCache.swift"), encoding: .utf8)
        let flush = try #require(cache.range(of: "static func flushPendingUpdate() {"))
        let end = try #require(cache[flush.upperBound...].range(of: "\n    }\n"))
        let body = cache[flush.upperBound..<end.lowerBound]
        #expect(body.contains("rebuildPendingInStages()"), "la foto al irse vuelve a hacerse de una vez")
        #expect(body.contains("assertion.begin(name:"), "sin permiso de segundo plano, iOS suspende la foto a medias")
        #expect(!body.contains("updateCacheNow("), "la foto al irse vuelve a hacerse de una vez")
    }
}
