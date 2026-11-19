//
//  FotoWidgetPorEtapasTests.swift
//  YalaTests / CuelguesHeroWidget
//
//  Sentry YALA-IOS-M (2026-11-18): la foto de los widgets (`WidgetDataCache.buildSnapshot`) recorría el historial unas
//  quince veces de un tirón en el hilo principal —~3 s con 20.000 movimientos en el simulador— y la app dejaba de
//  responder. Ahora la foto diferida (la de `updateCache`) se hace por etapas y cede el hilo entre una y otra; el paso a
//  segundo plano y las tareas de fondo la siguen haciendo de una vez.
//
//  Se fija: (1) por etapas sale la misma foto que de una vez; (2) mientras se hace, el hilo principal atiende otras
//  tareas —de una vez, ninguna— y al acabar queda publicada; y (3) un guardado a mitad tira la foto a medias y pide
//  otra, que sí se publica.
//

import CoreData
import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("YALA-IOS-M · la foto de los widgets se hace por etapas", .serialized)
@MainActor
struct FotoWidgetPorEtapasTests {

    private func encoded(_ snapshot: WidgetDataSnapshot) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(snapshot)
    }

    /// Espera a que la foto pedida empiece a hacerse por etapas.
    private func waitUntilStagedBuildStarts() async throws {
        for _ in 0..<400 where !WidgetDataCache.debugIsStagedBuildRunning {
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    private func waitUntilPublished() async throws {
        for _ in 0..<1_500 where WidgetDataCache.hasPendingUpdate {
            try await Task.sleep(for: .milliseconds(20))
        }
    }

    // MARK: - 1. La misma foto

    @Test func porEtapas_saleLaMismaFotoQueDeUnaVez() throws {
        let dir = CuelguesFixture.freshDir(); defer { discardTestStoreDirectory(dir) }
        let container = try CuelguesFixture.makeContainer(dir)
        let now = Date.now
        try CuelguesFixture.seed(container, count: 1_200, now: now)
        let context = ModelContext(container)

        let whole = WidgetDataCache.buildSnapshot(context: context, now: now)
        var stages: [@MainActor () -> Void] = []
        let finish = WidgetDataCache.buildSnapshot(context: context, now: now, stages: &stages)
        #expect(stages.count >= 10, "la foto tiene que repartirse en etapas (\(stages.count))")
        for stage in stages { stage() }
        let staged = finish()

        #expect(try encoded(staged.widget) == encoded(whole.widget))
        #expect(staged.siri == whole.siri)
        // El fixture no es una foto vacía: hay movimientos, saldo y totales del mes.
        #expect(!whole.widget.transactions.isEmpty)
        #expect(whole.widget.totalBalance != 0)
        #expect(whole.widget.periodSummaries.count == 8)
    }

    // MARK: - 2. Cede el hilo y publica

    @Test func laFotoPedida_cedeElHiloEntreEtapasYQuedaPublicada() async throws {
        let dir = CuelguesFixture.freshDir(); defer { discardTestStoreDirectory(dir) }
        let container = try CuelguesFixture.makeContainer(dir)
        try CuelguesFixture.seed(container, count: 3_000, now: .now, spacing: 1_800)
        let context = ModelContext(container)
        WidgetDataCache.cancelPendingUpdate()
        defer { WidgetDataCache.cancelPendingUpdate() }

        WidgetDataCache.updateCache(context: context)
        try await waitUntilStagedBuildStarts()
        #expect(WidgetDataCache.debugIsStagedBuildRunning, "la foto pedida no se hizo por etapas")
        let measured = try await CuelguesFixture.measureMainThread(while: { WidgetDataCache.debugIsStagedBuildRunning })
        // De una vez, la foto acaba en un solo bloque y aquí no se atiende nada.
        #expect(measured.turns >= 8, "el hilo principal solo atendió \(measured.turns) tareas mientras se hacía la foto")
        try await waitUntilPublished()
        #expect(!WidgetDataCache.hasPendingUpdate)
        #expect(WidgetDataCache.debugLastStagedBuildStages >= 10)
    }

    // MARK: - 3. Un guardado a mitad

    @Test func unGuardadoAMitad_tiraLaFotoYPideOtra() async throws {
        let dir = CuelguesFixture.freshDir(); defer { discardTestStoreDirectory(dir) }
        let container = try CuelguesFixture.makeContainer(dir)
        try CuelguesFixture.seed(container, count: 3_000, now: .now, spacing: 1_800)
        let context = ModelContext(container)
        WidgetDataCache.cancelPendingUpdate()
        defer { WidgetDataCache.cancelPendingUpdate() }
        let restarted = WidgetDataCache.debugStagedBuildsRestarted

        WidgetDataCache.updateCache(context: context)
        try await waitUntilStagedBuildStarts()
        #expect(WidgetDataCache.debugIsStagedBuildRunning)
        // Otra pantalla guarda (borra) mientras la foto va a medias.
        let newest = try #require(try CuelguesFixture.allTransactions(context).first)
        context.delete(newest)
        try context.save()

        try await waitUntilPublished()
        #expect(WidgetDataCache.debugStagedBuildsRestarted == restarted + 1)
        #expect(!WidgetDataCache.hasPendingUpdate, "la foto que se pidió de nuevo tiene que acabar publicada")
    }

    /// Lo que funde el espejo de iCloud no pasa por `ModelContext.didSave`: la foto lo ve por el aviso de cambio remoto.
    @Test func unCambioDelEspejoAMitad_tiraLaFotoYPideOtra() async throws {
        let dir = CuelguesFixture.freshDir(); defer { discardTestStoreDirectory(dir) }
        let container = try CuelguesFixture.makeContainer(dir)
        try CuelguesFixture.seed(container, count: 3_000, now: .now, spacing: 1_800)
        let context = ModelContext(container)
        WidgetDataCache.cancelPendingUpdate()
        defer { WidgetDataCache.cancelPendingUpdate() }
        let restarted = WidgetDataCache.debugStagedBuildsRestarted

        WidgetDataCache.updateCache(context: context)
        try await waitUntilStagedBuildStarts()
        #expect(WidgetDataCache.debugIsStagedBuildRunning)
        NotificationCenter.default.post(name: .NSPersistentStoreRemoteChange, object: nil)

        try await waitUntilPublished()
        #expect(WidgetDataCache.debugStagedBuildsRestarted == restarted + 1)
        #expect(!WidgetDataCache.hasPendingUpdate)
    }
}
