//
//  SettlementRetryDuplicateTests.swift
//  YalaTests
//
//  Ticket `settlement-retry-after-a-failed-confirmation-duplicates-the-payment` (lote 2.3 de Grupos, 10-nov).
//  «Apuntar pago» creaba el pago con un guardado y lo confirmaba con otro. Si fallaba el segundo, la hoja enseñaba el
//  error y dejaba reintentar: el pago ya existía y salía otro. Ahora nace confirmado en UN guardado, y si ese guardado
//  falla el pago se retira del contexto, así que reintentar deja uno solo.
//
//  Harness ON-DISK con los 3 stores (molde de `GroupOpeningBalanceFrozenTests`): servicios singleton ⇒ `.serialized`
//  y todo se suelta en `defer`.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Apuntar pago: reintentar tras un fallo no lo duplica", .serialized)
@MainActor
struct SettlementRetryDuplicateTests {

    // MARK: - Infra

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SettlementRetry-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            Issue.record("SettlementRetryDuplicateTests: no se pudo crear \(dir.path): \(error)")
        }
        return dir
    }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "SRD-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none
        )
        let groupsCfg = ModelConfiguration(
            "SRD-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none
        )
        let syncMetaCfg = ModelConfiguration(
            "SRD-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none
        )
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema,
            configurations: personalCfg, groupsCfg, syncMetaCfg
        )
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
    }

    private struct Fixture {
        let group: SplitGroup
        let me: SplitMember
        let ana: SplitMember
    }

    /// Grupo vivo (no congelado) donde yo le debo a Ana.
    private func makeFixture(_ context: ModelContext) throws -> Fixture {
        let group = SplitGroup(name: "Viaje", currencyCode: "PEN", isOwner: true)
        context.insert(group)
        let me = SplitMember(
            groupZoneID: group.cloudKitZoneID, displayName: "Yo", role: "admin",
            isGroupOwner: true, isCurrentUser: true
        )
        context.insert(me)
        let ana = SplitMember(groupZoneID: group.cloudKitZoneID, displayName: "Ana")
        context.insert(ana)
        try context.save()
        return Fixture(group: group, me: me, ana: ana)
    }

    private func withServices(_ context: ModelContext, _ body: () throws -> Void) rethrows {
        GroupExpenseService.shared.setContext(context)
        GroupService.shared.setContext(context)
        GroupTransactionBridge.shared.setContext(context)
        let previousPrivateSession = SessionState.shared.hasPrivateSession
        SessionState.shared.hasPrivateSession = true
        BridgeModeResolver.shared.invalidateCache(forZoneID: nil)
        defer {
            GroupExpenseService._testFailNextSettlementSave = false
            GroupExpenseService.shared._testResetContext()
            GroupService.shared._testResetContext()
            GroupTransactionBridge.shared._testClearContext()
            SessionState.shared.hasPrivateSession = previousPrivateSession
            BridgeModeResolver.shared.invalidateCache(forZoneID: nil)
        }
        try body()
    }

    /// Lo que hay en DISCO: un contexto nuevo sobre el mismo contenedor, no el que escribió.
    private func storedSettlements(_ context: ModelContext, in group: SplitGroup) throws -> [SplitSettlement] {
        let fresh = ModelContext(context.container)
        let zoneID = group.cloudKitZoneID
        return try fresh.fetch(FetchDescriptor<SplitSettlement>(predicate: #Predicate { $0.groupZoneID == zoneID }))
    }

    private func recordPayment(_ f: Fixture) throws {
        try GroupExpenseService.shared.createSettlement(
            in: f.group,
            fromMemberID: f.me.id.uuidString,
            toMemberID: f.ana.id.uuidString,
            amount: 40,
            currencyCode: "PEN",
            note: nil,
            date: Date(timeIntervalSince1970: 1_793_000_000),
            confirmed: true
        )
    }

    // MARK: - Casos

    @Test("Un pago apuntado desde la hoja queda guardado y confirmado de una vez")
    func recordedPayment_isStoredConfirmed() throws {
        let dir = freshDir()
        defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)

        try withServices(context) {
            try recordPayment(f)
        }

        let stored = try storedSettlements(context, in: f.group)
        #expect(stored.count == 1)
        #expect(stored.first?.isConfirmed == true)
        #expect(stored.first?.amount == 40)
    }

    @Test("Si el guardado falla y se reintenta, queda UN pago, no dos")
    func retryAfterAFailedSave_leavesOnePayment() throws {
        let dir = freshDir()
        defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)

        try withServices(context) {
            GroupExpenseService._testFailNextSettlementSave = true
            #expect(throws: GroupExpenseServiceError.self) { try recordPayment(f) }
            // Lo que la hoja hace al tocar otra vez «Apuntar pago».
            try recordPayment(f)
        }

        let stored = try storedSettlements(context, in: f.group)
        #expect(stored.count == 1)
        #expect(stored.first?.isConfirmed == true)
    }

    @Test("La hoja ya no confirma con un segundo guardado: crea el pago confirmado")
    func settlementForm_createsConfirmedInOneCall() throws {
        let source = try String(contentsOf: Self.sourceURL("Yala/App/Views/Groups/SettlementFormView.swift"), encoding: .utf8)
        let code = source.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.hasPrefix("//") }
            .joined(separator: " ")
        #expect(code.contains("createSettlement("))
        #expect(code.contains("confirmed: true"))
        #expect(!code.contains("confirmSettlement("))
    }

    private static func sourceURL(_ relative: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(relative)
    }
}
