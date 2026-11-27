//
//  FotoWidgetPorEtapasTests.swift
//  YalaTests / CuelguesHeroWidget
//
//  Sentry YALA-IOS-M (2026-11-18): la foto de los widgets (`WidgetDataCache.buildSnapshot`) recorría el historial unas
//  quince veces de un tirón en el hilo principal —~3 s con 20.000 movimientos en el simulador— y la app dejaba de
//  responder. Ahora la foto diferida (la de `updateCache`) se hace por etapas y cede el hilo entre una y otra; las tareas
//  de fondo la siguen haciendo de una vez. El paso a segundo plano también va por etapas desde el lote 3 de eficiencia
//  (`YalaTests/EficienciaSegundoPlano/FotoWidgetsAlIrseTests`).
//
//  Se fija: (1) por etapas sale la misma foto que de una vez; (2) mientras se hace, el hilo principal atiende otras
//  tareas —de una vez, ninguna— y al acabar queda publicada; y (3) un guardado a mitad tira la foto a medias y pide
//  otra, que sí se publica.
//
//  Aislada de lo que dejan las suites anteriores (deuda de 2.3, 27-nov-2026). En `YalaTests` entero caía y sola pasaba,
//  por tres restos medidos: (a) otra suite deja ARMADO el borrado de cierre de sesión en `UserDefaults.standard` y
//  `updateCache` no arranca la foto (`measured.turns` → 1); (b) una foto pedida o a medias de otra suite sigue viva al
//  empezar; (c) un guardado o un aviso remoto tardío de otra suite cae durante la foto y la reinicia una vez más
//  (13 en vez de 12). Cada caso de los tres con `updateCache` pasa por `aislar()`, que desarma el borrado y lo restaura
//  al salir, y espera a que no quede foto en marcha; y el contador de reinicios se lee pegado al gesto que reinicia.
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

    /// Deja `WidgetDataCache` como si ninguna otra suite hubiera corrido: sin borrado armado, sin foto pedida y sin
    /// foto a medias. Devuelve lo que hay que restaurar al salir (el borrado armado es de quien lo armó).
    private func aislar() async throws -> () -> Void {
        let wipeWasArmed = StorageModePersistence.isSignOutWipeArmed()
        if wipeWasArmed { StorageModePersistence.clearSignOutWipeArm() }
        WidgetDataCache.cancelPendingUpdate()
        // Una foto cancelada sale en su siguiente pausa entre etapas.
        for _ in 0..<500 where WidgetDataCache.debugIsStagedBuildRunning {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(!WidgetDataCache.isWipeArmed)
        #expect(!WidgetDataCache.debugIsStagedBuildRunning, "quedó una foto de otra suite en marcha")
        return {
            WidgetDataCache.cancelPendingUpdate()
            if wipeWasArmed { StorageModePersistence.armSignOutWipe() }
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
        let restore = try await aislar()
        defer { restore() }

        WidgetDataCache.updateCache(context: context)
        try await waitUntilStagedBuildStarts()
        #expect(WidgetDataCache.debugIsStagedBuildRunning, "la foto pedida no se hizo por etapas")
        let measured = try await CuelguesFixture.measureMainThread(while: { WidgetDataCache.debugIsStagedBuildRunning })
        // De una vez, la foto acaba en un solo bloque y aquí no se atiende nada (0 o 1 vueltas). Con la máquina cargada
        // caben menos vueltas por etapa, así que el umbral separa «cede» de «no cede» sin pedir un ritmo.
        #expect(measured.turns >= 3, "el hilo principal solo atendió \(measured.turns) tareas mientras se hacía la foto")
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
        let restore = try await aislar()
        defer { restore() }

        WidgetDataCache.updateCache(context: context)
        try await waitUntilStagedBuildStarts()
        #expect(WidgetDataCache.debugIsStagedBuildRunning)
        // Otra pantalla guarda (borra) mientras la foto va a medias. El contador se lee pegado al guardado: un aviso
        // tardío de otra suite puede sumar otro reinicio, y eso no es lo que se mide aquí.
        let newest = try #require(try CuelguesFixture.allTransactions(context).first)
        let restarted = WidgetDataCache.debugStagedBuildsRestarted
        context.delete(newest)
        try context.save()

        try await waitUntilPublished()
        #expect(WidgetDataCache.debugStagedBuildsRestarted >= restarted + 1, "el guardado a mitad no reinició la foto")
        #expect(!WidgetDataCache.hasPendingUpdate, "la foto que se pidió de nuevo tiene que acabar publicada")
    }

    /// Lo que funde el espejo de iCloud no pasa por `ModelContext.didSave`: la foto lo ve por el aviso de cambio remoto.
    @Test func unCambioDelEspejoAMitad_tiraLaFotoYPideOtra() async throws {
        let dir = CuelguesFixture.freshDir(); defer { discardTestStoreDirectory(dir) }
        let container = try CuelguesFixture.makeContainer(dir)
        try CuelguesFixture.seed(container, count: 3_000, now: .now, spacing: 1_800)
        let context = ModelContext(container)
        let restore = try await aislar()
        defer { restore() }

        WidgetDataCache.updateCache(context: context)
        try await waitUntilStagedBuildStarts()
        #expect(WidgetDataCache.debugIsStagedBuildRunning)
        let restarted = WidgetDataCache.debugStagedBuildsRestarted
        NotificationCenter.default.post(name: .NSPersistentStoreRemoteChange, object: nil)

        try await waitUntilPublished()
        #expect(WidgetDataCache.debugStagedBuildsRestarted >= restarted + 1, "el aviso remoto a mitad no reinició la foto")
        #expect(!WidgetDataCache.hasPendingUpdate)
    }
}
