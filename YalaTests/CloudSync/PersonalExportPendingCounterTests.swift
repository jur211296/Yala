//
//  PersonalExportPendingCounterTests.swift
//  YalaTests / CloudSync
//
//  Paso 9 del rediseño de sesiones: el contador de cambios LOCALES del store personal que el espejo aún
//  podría no haber subido, sobre HISTORIAL REAL. Container ON-DISK temp con los tres stores y un solo
//  `ModelContext` que los abarca (espejo del mainContext de producción): el historial es por CONTAINER, y
//  eso es justo lo que el contador tiene que acotar al store personal.
//
//  El autor del espejo (`NSCloudKitMirroringDelegate…`) se finge poniendo ese `author` al contexto: no hay
//  CloudKit en el simulador, así que lo que se prueba aquí es el FILTRO; que el espejo real firme así sus
//  importaciones lo verifica el device-QA del ticket.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Cierre privado · contador de cambios sin subir (historial real, on-disk)", .serialized)
@MainActor
struct PersonalExportPendingCounterTests {

    // MARK: - Infra (andamio de `CloudSyncEngineTests`)

    private func freshDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PendingCounter-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) {
        do {
            try FileManager.default.removeItem(at: dir)
        } catch {
            print("PersonalExportPendingCounterTests: no se pudo borrar \(dir.lastPathComponent): \(error)")
        }
    }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "PC-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "PC-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "PC-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema,
            configurations: personalCfg, groupsCfg, syncMetaCfg)
        return ModelContext(container)
    }

    @discardableResult
    private func insertTx(_ context: ModelContext, amount: Double = -12) throws -> TransactionItem {
        let tx = TransactionItem(date: Date(timeIntervalSince1970: 1_700_000_000), amount: amount, currencyCode: "USD")
        context.insert(tx)
        try context.save()
        return tx
    }

    private func count(_ context: ModelContext, since anchor: Date?) -> Int? {
        PersonalExportPendingCounter.pendingChangeCount(context: context, confirmedExportStart: anchor)
    }

    /// Un ancla anterior a todo: el contador da NÚMEROS y el filtro por timestamp no quita nada.
    private let everything = Date.distantPast

    /// Instante de la última transacción del historial: el ancla de los tests que la necesitan, sin `Date()`.
    private func lastTransactionTimestamp(_ context: ModelContext) throws -> Date {
        let all = try context.fetchHistory(HistoryDescriptor<DefaultHistoryTransaction>())
        return try #require(all.map(\.timestamp).max())
    }

    /// Deja pasar el tiempo suficiente para que la transacción siguiente tenga otro timestamp.
    private func tick() async throws {
        try await Task.sleep(for: .milliseconds(20))
    }

    // MARK: - Sin ancla: cero honesto o «no se puede dar un número»

    /// Sin ancla no se sabe qué viajó ya: un número sería inventado («3.412 cambios sin subir» a quien lo
    /// tiene todo en iCloud). La respuesta honesta es «no se puede contar».
    @Test("sin ancla y con escrituras locales, no hay número honesto")
    func withoutAnchor_localWrites_areUnknown() throws {
        let dir = try freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        try insertTx(context)
        #expect(count(context, since: nil) == nil)
    }

    @Test("sin ancla y sin nada local (solo lo que bajó del espejo), el cero es honesto")
    func withoutAnchor_onlyMirrorWrites_isZero() throws {
        let dir = try freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        context.author = "NSCloudKitMirroringDelegate.import"
        try insertTx(context)
        context.author = nil
        #expect(count(context, since: nil) == 0)
    }

    // MARK: - Con ancla: el número

    @Test("lo que firmó el espejo no cuenta: bajó de iCloud, no hay nada que subir")
    func mirrorAuthored_isExcluded() throws {
        let dir = try freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        context.author = "NSCloudKitMirroringDelegate.import"
        try insertTx(context)
        try insertTx(context, amount: -3)
        context.author = nil
        #expect(count(context, since: everything) == 0)
        // Control: un cambio local en el mismo store sí cuenta — el cero de arriba no es un conteo roto.
        try insertTx(context, amount: -7)
        #expect(count(context, since: everything) == 1)
    }

    @Test("el ancla separa lo que ya viajó de lo que no")
    func anchor_splitsExportedFromPending() async throws {
        let dir = try freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        try insertTx(context)
        let exportedAt = try lastTransactionTimestamp(context)
        try await tick()
        try insertTx(context, amount: -5)
        // El primero es anterior al ancla (viajó en ese export); el segundo, posterior.
        #expect(count(context, since: exportedAt.addingTimeInterval(0.010)) == 1)
        // Y con el ancla en el propio instante del primero, el borde cuenta como pendiente (`>=`).
        #expect(count(context, since: exportedAt) == 2)
    }

    @Test("un objeto editado varias veces es UN cambio")
    func sameObjectEditedTwice_countsOnce() throws {
        let dir = try freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let tx = try insertTx(context)
        tx.amount = -20
        try context.save()
        tx.amount = -30
        try context.save()
        #expect(count(context, since: everything) == 1)
    }

    @Test("un borrado de algo que ya viajó está pendiente de subir")
    func deletion_counts() async throws {
        let dir = try freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let tx = try insertTx(context)
        let exportedAt = try lastTransactionTimestamp(context)
        try await tick()
        context.delete(tx)
        try context.save()
        #expect(count(context, since: exportedAt.addingTimeInterval(0.010)) == 1)
    }

    /// Creado y borrado después del ancla. El ancla es el INICIO de un export, y ese export pudo llevarse el
    /// alta: entonces el objeto está en iCloud y el borrado tiene que viajar, o reaparece al restaurar. Contar
    /// de más cuesta una espera; netear a cero resucitaba datos borrados (review adversarial del paso 9).
    @Test("creado y borrado tras el ancla cuenta: el borrado tiene que viajar")
    func insertThenDeleteAfterAnchor_stillCounts() async throws {
        let dir = try freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        try insertTx(context)
        let exportedAt = try lastTransactionTimestamp(context)
        try await tick()
        let temp = try insertTx(context, amount: -99)
        context.delete(temp)
        try context.save()
        #expect(count(context, since: exportedAt.addingTimeInterval(0.010)) == 1)
    }

    /// La reescritura idéntica (`swiftdata-cloudkit.md`): el contexto queda sucio pero no cambia nada que
    /// subir. Contarla dejaría el cierre esperando un export que no la lleva.
    ///
    /// **Lo que este test NO prueba** (mutante M15, 2026-09-11): quitarle el `> 0` al filtro de
    /// `updatedAttributes` del contador lo deja verde igual. El cero de aquí lo pone el HISTORIAL, que no
    /// registra la reescritura idéntica en absoluto — si registrara una actualización con la lista vacía,
    /// el mutante la contaría y esto saldría en rojo. El filtro del contador es cinturón sobre tirantes y
    /// se queda por eso, no porque una medición lo exija.
    @Test("una reescritura idéntica no cuenta")
    func identicalRewrite_isNotAChange() async throws {
        let dir = try freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let tx = try insertTx(context, amount: -12)
        let exportedAt = try lastTransactionTimestamp(context)
        try await tick()
        tx.amount = -12
        try context.save()
        let anchor = exportedAt.addingTimeInterval(0.010)
        #expect(count(context, since: anchor) == 0)
        // Control del escenario: con un cambio REAL después, el mismo objeto sí cuenta. Sin él, un contador
        // que no mirara nada daría el mismo cero de arriba.
        tx.amount = -13
        try context.save()
        #expect(count(context, since: anchor) == 1)
    }

    /// El historial es por CONTAINER: sin acotar por entidad, un gasto de grupo contaría como un cambio
    /// PERSONAL sin subir y el cierre privado esperaría a un export que nunca llega.
    @Test("los cambios de otros stores no cuentan")
    func otherStores_areIgnored() throws {
        let dir = try freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        context.insert(SplitGroup(name: "Viaje"))
        context.insert(SyncCursor())
        try context.save()
        #expect(count(context, since: everything) == 0)
        // Control: el mismo contexto sí ve lo personal.
        try insertTx(context)
        #expect(count(context, since: everything) == 1)
    }
}
