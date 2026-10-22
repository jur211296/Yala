//
//  SyncStatusSectionLogicTests.swift
//  YalaTests / CloudSync
//
//  Ticket `cloud-sync-status-says-all-synced-with-changes-still-pending` (decisión de Jürgen, 2026-10-07): con cambios sin
//  subir, «Dónde viven tus datos» decía «Todo sincronizado». Hasta este ticket la sección era un `if` de dos ramas con el
//  check verde en el `else`; el control rojo de estos tests es ese `else` (la tercera rama de `decide` quitada).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("La tarjeta «Sincronización» no dice «Todo sincronizado» con cambios sin subir", .serialized)
@MainActor
struct SyncStatusSectionLogicTests {

    private typealias Logic = SyncStatusSectionLogic

    /// El estado de la sección en la nube, sin attest terminal ni puerta de firmar: lo que antes caía al `else`.
    private func cloudStatus(pending: Int?, healthy: Bool) -> Logic.Status {
        Logic.decide(attestNoticeShowing: false, needsSignIn: false, signInPendingCount: 0,
                     isCloud: true, pendingCount: pending, engineIsHealthy: healthy)
    }

    // MARK: - Las dos direcciones

    @Test("MUTACIÓN: sin red y con cambios pendientes (motor en backoff), no dice «Todo sincronizado»")
    func offlineWithPendingChanges_isNotUpToDate() {
        // El motor en backoff: corre su cadencia pero el último ciclo con señal de red fue `.transient`.
        let backoff = Logic.engineIsHealthy(state: .running, consecutiveTransients: 3)
        #expect(!backoff)
        #expect(cloudStatus(pending: 2, healthy: backoff) == .waitingForConnection(pendingCount: 2))
        #expect(cloudStatus(pending: 1, healthy: backoff) == .waitingForConnection(pendingCount: 1))
    }

    @Test("MUTACIÓN: con el motor `.idle` por el gate de dominio y filas vivas, tampoco")
    func idleEngineWithPendingChanges_isNotUpToDate() {
        let idle = Logic.engineIsHealthy(state: .idle, consecutiveTransients: 0)
        #expect(!idle)
        #expect(cloudStatus(pending: 4, healthy: idle) == .waitingForConnection(pendingCount: 4))
    }

    @Test("Con el outbox vacío y el último ciclo completado, sí dice «Todo sincronizado»")
    func emptyQueuesAndCompletedCycle_isUpToDate() {
        let healthy = Logic.engineIsHealthy(state: .running, consecutiveTransients: 0)
        #expect(healthy)
        #expect(cloudStatus(pending: 0, healthy: healthy) == .upToDate)
        // Y con todo subido, aunque el motor esté en backoff, no hay nada que esperar.
        #expect(cloudStatus(pending: 0, healthy: false) == .upToDate)
    }

    /// Con el último ciclo completado, lo que se apuntó después sale en el siguiente: «esperando conexión» con la red bien
    /// sería otra frase falsa. Es el «sin `.completed` reciente» de la decisión.
    @Test("MUTACIÓN: con el motor sano, lo recién apuntado no se anuncia como «esperando conexión»")
    func healthyEngineWithFreshChanges_isUpToDate() {
        #expect(cloudStatus(pending: 3, healthy: true) == .upToDate)
    }

    @Test("MUTACIÓN: un recuento ilegible sale sin cifra, nunca como «Todo sincronizado»")
    func unreadableCount_isWaitingWithoutANumber() {
        #expect(cloudStatus(pending: nil, healthy: false) == .waitingForConnection(pendingCount: nil))
    }

    @Test("Fuera de la nube, la sección no habla de cambios esperando")
    func outsideTheCloud_isUpToDate() {
        #expect(Logic.decide(attestNoticeShowing: false, needsSignIn: false, signInPendingCount: 0,
                             isCloud: false, pendingCount: 5, engineIsHealthy: false) == .upToDate)
    }

    // MARK: - Prioridad

    @Test("MUTACIÓN: el aviso del attest gana a la puerta de firmar y a los cambios esperando")
    func attestWins() {
        #expect(Logic.decide(attestNoticeShowing: true, needsSignIn: true, signInPendingCount: 2,
                             isCloud: true, pendingCount: 2, engineIsHealthy: false) == .attestUnavailable)
        #expect(Logic.decide(attestNoticeShowing: true, needsSignIn: false, signInPendingCount: 0,
                             isCloud: true, pendingCount: 2, engineIsHealthy: false) == .attestUnavailable)
    }

    @Test("MUTACIÓN: la puerta de firmar gana a los cambios esperando, con su cifra o sin ella")
    func signInWinsOverWaiting() {
        #expect(Logic.decide(attestNoticeShowing: false, needsSignIn: true, signInPendingCount: 2,
                             isCloud: true, pendingCount: 2, engineIsHealthy: false) == .needsSignIn(pendingCount: 2))
        #expect(Logic.decide(attestNoticeShowing: false, needsSignIn: true, signInPendingCount: nil,
                             isCloud: true, pendingCount: nil, engineIsHealthy: false) == .needsSignIn(pendingCount: nil))
    }

    // MARK: - Qué es un motor sano

    @Test("MUTACIÓN: sano es solo corriendo con el último ciclo completado")
    func whichEnginesAreHealthy() {
        #expect(Logic.engineIsHealthy(state: .running, consecutiveTransients: 0))
        #expect(!Logic.engineIsHealthy(state: .running, consecutiveTransients: 1))
        for state in [CloudSyncRuntime.RuntimeState.idle, .idleSignedOut, .stoppedUntilSignIn, .stoppedUntilRelaunch] {
            #expect(!Logic.engineIsHealthy(state: state, consecutiveTransients: 0), "\(state)")
        }
        #expect(!Logic.engineIsHealthy(state: nil, consecutiveTransients: 0))
    }

    // MARK: - El recuento

    @Test("MUTACIÓN: la cifra suma las tres colas, y una ilegible deja la cifra sin leer")
    func theCountAddsTheThreeQueues() {
        #expect(Logic.pendingCount(personalRows: 1, personalUncaptured: 2, groupsRows: 3) == 6)
        #expect(Logic.pendingCount(personalRows: 0, personalUncaptured: 2, groupsRows: 0) == 2)
        #expect(Logic.pendingCount(personalRows: nil, personalUncaptured: 0, groupsRows: 0) == nil)
        #expect(Logic.pendingCount(personalRows: 0, personalUncaptured: nil, groupsRows: 0) == nil)
        #expect(Logic.pendingCount(personalRows: 0, personalUncaptured: 0, groupsRows: nil) == nil)
    }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "SSS-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "SSS-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "SSS-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(for: SwiftDataConfiguration.schema,
                                           configurations: personalCfg, groupsCfg, syncMetaCfg)
        return ModelContext(container)
    }

    private static let hlc = "2023-11-14T22:13:20.000Z-0001-0123456789abcdef"

    /// De punta a punta por el cuerpo que recuenta la sección (`CloudMigrationController.pendingSyncCount`): con un store
    /// real, las filas vivas de las dos colas y la mitad del History suman; los rechazados no cuentan.
    @Test("MUTACIÓN: con un store real, cuentan las filas vivas de las dos colas más el History sin capturar")
    func realStore_countsLiveRowsOfBothQueuesPlusUncaptured() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SSS-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer {
            do { try FileManager.default.removeItem(at: dir) } catch { print("SSS cleanup: \(error)") }
        }
        let context = try makeContext(dir)
        for rejected in [nil, nil, "poison"] as [String?] {
            context.insert(SyncOutbox(syncID: UUID(), entityType: SyncEntityType.transactionItem, op: .upsert,
                                      hlc: Self.hlc, fieldsJSON: "{}", author: "", rejectedReason: rejected))
        }
        for rejected in [nil, "poison"] as [String?] {
            context.insert(GroupSyncOutbox(syncID: UUID(), groupID: "g1", entityType: "SplitExpense", op: .upsert,
                                           hlc: Self.hlc, fieldsJSON: "{}", author: "", rejectedReason: rejected))
        }
        try context.save()

        // 2 personales vivas + 1 de grupos viva + 3 cambios del History sin capturar.
        #expect(CloudMigrationController.pendingSyncCount(context: context, uncapturedPersonal: { 3 }) == 6)
        // Sin runtime no hay quien lea el History: la cifra no se inventa.
        #expect(CloudMigrationController.pendingSyncCount(context: context, uncapturedPersonal: { nil }) == nil)
    }

    @Test("Con las dos colas vacías y nada en el History, la cifra es cero")
    func realStore_emptyQueues_countZero() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SSS-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer {
            do { try FileManager.default.removeItem(at: dir) } catch { print("SSS cleanup: \(error)") }
        }
        let context = try makeContext(dir)
        #expect(CloudMigrationController.pendingSyncCount(context: context, uncapturedPersonal: { 0 }) == 0)
    }

    // MARK: - El texto, con su plural, en los 16 idiomas

    private static let resources: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Yala/Resources")

    /// Las variantes regionales no pueden tener `.stringsdict` propio: llevan la forma `other` como entrada flat.
    private static let variants = ["en-GB", "es-AR", "es-ES", "pt-PT"]
    private static let bases = ["de", "en", "es", "es-419", "fr", "it", "ja", "nl", "pl", "pt", "pt-BR", "zh-Hans"]

    @Test("El plural existe en los 12 `.stringsdict` y cambia entre 1 y 2 donde el idioma lo distingue")
    func pluralIsInEveryStringsdict() throws {
        for locale in Self.bases {
            let url = Self.resources.appendingPathComponent("\(locale).lproj/Localizable.stringsdict")
            let dict = try #require(NSDictionary(contentsOf: url) as? [String: Any], "\(locale)")
            let entry = try #require(dict["storage.sync.waitingForConnection"] as? [String: Any], "\(locale) sin la key")
            let forms = try #require(entry["count"] as? [String: String], "\(locale)")
            let other = try #require(forms["other"], "\(locale) sin `other`")
            #expect(other.contains("%d"), "\(locale)")
            if !["ja", "zh-Hans"].contains(locale) {
                let one = try #require(forms["one"], "\(locale) sin `one`")
                #expect(one != other, "\(locale): el singular es igual al plural")
            }
        }
        // La referencia, tal cual la decidió Jürgen.
        let es = try #require(NSDictionary(contentsOf: Self.resources
            .appendingPathComponent("es-419.lproj/Localizable.stringsdict")) as? [String: Any])
        let forms = try #require((es["storage.sync.waitingForConnection"] as? [String: Any])?["count"] as? [String: String])
        #expect(forms["one"] == "%d cambio esperando conexión")
        #expect(forms["other"] == "%d cambios esperando conexión")
    }

    @Test("La versión sin cifra está en los 16 `.strings`, y las variantes llevan el plural flat")
    func uncountedIsInEveryStrings() throws {
        for locale in Self.bases + Self.variants {
            let url = Self.resources.appendingPathComponent("\(locale).lproj/Localizable.strings")
            let dict = try #require(NSDictionary(contentsOf: url) as? [String: String], "\(locale)")
            let uncounted = try #require(dict["storage.sync.waitingForConnectionUncounted"], "\(locale)")
            #expect(!uncounted.isEmpty && !uncounted.contains("%"), "\(locale)")
            if Self.variants.contains(locale) {
                #expect(dict["storage.sync.waitingForConnection"]?.contains("%d") == true, "\(locale) sin plural flat")
            }
        }
    }
}
