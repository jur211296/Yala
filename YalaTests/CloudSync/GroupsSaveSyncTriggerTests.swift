//
//  GroupsSaveSyncTriggerTests.swift
//  YalaTests / CloudSync
//
//  Seam del trigger por save de un gasto de grupo: se PIDE el background task y se PIDE un ciclo.
//  No afirma que iOS concedió tiempo (handle `.invalid` y expiration son respuestas válidas).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

// MARK: - Trigger (instancia fresca, sin UIApplication)

@Suite("GroupsSaveSyncTrigger · seam de background task + ciclo")
@MainActor
struct GroupsSaveSyncTriggerTests {

    private final class Hold: @unchecked Sendable {
        private let lock = NSLock()
        private var continuation: CheckedContinuation<Void, Never>?
        private var waiting = false

        var isWaiting: Bool {
            lock.lock(); defer { lock.unlock() }
            return waiting
        }

        func wait() async {
            await withTaskCancellationHandler {
                await withCheckedContinuation { continuation in
                    self.lock.lock()
                    self.continuation = continuation
                    self.waiting = true
                    self.lock.unlock()
                }
            } onCancel: {
                self.resume()
            }
        }

        func resume() {
            lock.lock()
            let pending = continuation
            continuation = nil
            waiting = false
            lock.unlock()
            pending?.resume()
        }
    }

    private func makeTrigger(
        begin: @escaping GroupsSaveSyncTrigger.Begin,
        end: @escaping GroupsSaveSyncTrigger.End = { _ in },
        sleeper: @escaping (TimeInterval) async -> Void = { _ in },
        runCycle: @escaping () async -> Void
    ) -> GroupsSaveSyncTrigger {
        GroupsSaveSyncTrigger(
            beginBackgroundTask: begin,
            endBackgroundTask: end,
            sleeper: sleeper,
            runCycle: runCycle
        )
    }

    @Test func request_asksForBackgroundTaskBeforeTheCycle() async {
        var begins = 0
        var cycles = 0
        var slept: TimeInterval?
        let trigger = makeTrigger(
            begin: { _, _ in
                begins += 1
                return GroupsBackgroundTaskID(rawValue: 1)
            },
            sleeper: { seconds in
                slept = seconds
                #expect(begins == 1)
                #expect(cycles == 0)
            },
            runCycle: { cycles += 1 }
        )

        trigger.requestAfterLocalSave()
        await trigger._testAwaitInFlight()

        #expect(begins == 1)
        #expect(cycles == 1)
        #expect(slept == SyncCadencePolicy.pushDebounce)
    }

    @Test func request_endsTheBackgroundTaskAfterTheCycle() async {
        var ends: [GroupsBackgroundTaskID] = []
        let handle = GroupsBackgroundTaskID(rawValue: 7)
        let trigger = makeTrigger(
            begin: { _, _ in handle },
            end: { ends.append($0) },
            runCycle: {}
        )

        trigger.requestAfterLocalSave()
        await trigger._testAwaitInFlight()

        #expect(ends == [handle])
    }

    @Test func invalidHandle_stillRequestsTheCycle_doesNotClaimGrantedTime() async {
        var cycles = 0
        var ends = 0
        let trigger = makeTrigger(
            begin: { _, _ in .invalid },
            end: { _ in ends += 1 },
            runCycle: { cycles += 1 }
        )

        trigger.requestAfterLocalSave()
        await trigger._testAwaitInFlight()

        #expect(cycles == 1)
        #expect(ends == 0)
    }

    @Test func rapidRequests_coalesceToOneCycle() async {
        var begins = 0
        var cycles = 0
        let trigger = makeTrigger(
            begin: { _, _ in
                begins += 1
                return GroupsBackgroundTaskID(rawValue: 1)
            },
            runCycle: { cycles += 1 }
        )

        trigger.requestAfterLocalSave()
        trigger.requestAfterLocalSave()
        trigger.requestAfterLocalSave()
        await trigger._testAwaitInFlight()

        #expect(begins == 1)
        #expect(cycles == 1)
    }

    @Test func expirationDuringDebounce_doesNotRunTheCycle() async {
        let hold = Hold()
        var cycles = 0
        var expiration: (() -> Void)?
        var ends = 0
        let trigger = makeTrigger(
            begin: { _, exp in
                expiration = exp
                return GroupsBackgroundTaskID(rawValue: 1)
            },
            end: { _ in ends += 1 },
            sleeper: { _ in await hold.wait() },
            runCycle: { cycles += 1 }
        )

        trigger.requestAfterLocalSave()
        while !hold.isWaiting { await Task.yield() }
        let expire = try #require(expiration)
        expire()
        await trigger._testAwaitInFlight()

        #expect(cycles == 0)
        #expect(ends == 1)
    }
}

// MARK: - Call-site real: crear / editar gasto

@Suite("GroupExpenseService · pide sync al guardar un gasto", .serialized)
@MainActor
struct GroupExpenseSaveSyncCallSiteTests {

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GxSaveSync-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "GxSS-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "GxSS-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "GxSS-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema, configurations: personalCfg, groupsCfg, syncMetaCfg)
        return ModelContext(container)
    }

    @Test func createExpense_requestsSyncAfterSave() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let service = GroupExpenseService.shared
        service.setContext(context)
        GroupService.shared.setContext(context)
        var requests = 0
        service.requestSyncAfterLocalSave = { requests += 1 }
        defer {
            service._testResetContext()
            GroupService.shared._testResetContext()
        }

        let group = SplitGroup(name: "Viaje", currencyCode: "USD", isOwner: true)
        context.insert(group)
        let me = SplitMember(groupZoneID: group.cloudKitZoneID, displayName: "Yo", isCurrentUser: true)
        context.insert(me)
        let ana = SplitMember(groupZoneID: group.cloudKitZoneID, displayName: "Ana")
        context.insert(ana)
        try context.save()

        _ = try service.createExpense(
            in: group,
            amount: 20,
            currencyCode: "USD",
            description: "Taxi",
            note: nil,
            date: Date(timeIntervalSince1970: 1_700_000_000),
            paidByMemberID: me.id.uuidString,
            splitType: "equal",
            subcategoryName: nil,
            shares: [
                (memberID: me.id.uuidString, amount: 10),
                (memberID: ana.id.uuidString, amount: 10)
            ]
        )

        #expect(requests == 1)
    }

    @Test func updateExpense_requestsSyncAfterSave() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let service = GroupExpenseService.shared
        service.setContext(context)
        GroupService.shared.setContext(context)
        var requests = 0
        service.requestSyncAfterLocalSave = { requests += 1 }
        defer {
            service._testResetContext()
            GroupService.shared._testResetContext()
        }

        let group = SplitGroup(name: "Viaje", currencyCode: "USD", isOwner: true)
        context.insert(group)
        let me = SplitMember(groupZoneID: group.cloudKitZoneID, displayName: "Yo", isCurrentUser: true)
        context.insert(me)
        let ana = SplitMember(groupZoneID: group.cloudKitZoneID, displayName: "Ana")
        context.insert(ana)
        try context.save()

        let expense = try service.createExpense(
            in: group,
            amount: 20,
            currencyCode: "USD",
            description: "Taxi",
            note: nil,
            date: Date(timeIntervalSince1970: 1_700_000_000),
            paidByMemberID: me.id.uuidString,
            splitType: "equal",
            subcategoryName: nil,
            shares: [
                (memberID: me.id.uuidString, amount: 10),
                (memberID: ana.id.uuidString, amount: 10)
            ]
        )
        #expect(requests == 1)

        try service.updateExpense(
            expense,
            in: group,
            amount: 30,
            currencyCode: "USD",
            description: "Taxi",
            note: nil,
            date: Date(timeIntervalSince1970: 1_700_000_000),
            paidByMemberID: me.id.uuidString,
            splitType: "equal",
            subcategoryName: nil,
            shares: [
                (memberID: me.id.uuidString, amount: 15),
                (memberID: ana.id.uuidString, amount: 15)
            ]
        )

        #expect(requests == 2)
    }

    @Test func invalidAmount_doesNotRequestSync() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let service = GroupExpenseService.shared
        service.setContext(context)
        var requests = 0
        service.requestSyncAfterLocalSave = { requests += 1 }
        defer { service._testResetContext() }

        let group = SplitGroup(name: "Viaje", currencyCode: "USD")
        do {
            _ = try service.createExpense(
                in: group,
                amount: 0,
                currencyCode: "USD",
                description: "Taxi",
                note: nil,
                date: Date(timeIntervalSince1970: 1_700_000_000),
                paidByMemberID: "payer",
                splitType: "equal",
                subcategoryName: nil,
                shares: [(memberID: "payer", amount: 0)]
            )
            Issue.record("createExpense with amount 0 should throw")
        } catch GroupExpenseServiceError.invalidAmount {
        } catch {
            Issue.record("expected invalidAmount, got \(error)")
        }
        #expect(requests == 0)
    }
}

// MARK: - Cableado de producción (source-scan)

@Suite("GroupsSaveSyncTrigger · cableado de producción (source-scan)")
struct GroupsSaveSyncWiringTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func source(_ relative: String) throws -> String {
        try String(contentsOf: Self.repoRoot.appendingPathComponent(relative), encoding: .utf8)
    }

    /// El debounce declarado deja de ser huérfano: el trigger duerme `pushDebounce` y luego pide el ciclo.
    @Test func trigger_consumesPushDebounce_andAsksForACycle() throws {
        let src = try source("Yala/Services/CloudSync/Groups/GroupsSaveSyncTrigger.swift")
        #expect(src.contains("SyncCadencePolicy.pushDebounce"))
        #expect(src.contains("GroupsSyncClient.shared.syncNowAfterLocalSave()"))
        #expect(src.contains("beginBackgroundTask"))
        #expect(src.contains("UIApplication.shared.beginBackgroundTask(withName:"))
        #expect(src.contains("BGAppRefreshTask") == false)
        #expect(src.contains("BGProcessingTask") == false)
    }

    @Test func expenseService_createAndUpdate_callTheHook() throws {
        let src = try source("Yala/Services/Groups/GroupExpenseService.swift")
        #expect(src.contains("GroupsSaveSyncTrigger.shared.requestAfterLocalSave()"))
        let create = try #require(Self.body(of: "func createExpense(", in: src))
        let update = try #require(Self.body(of: "func updateExpense(", in: src))
        #expect(create.contains("requestSyncAfterLocalSave()"))
        #expect(update.contains("requestSyncAfterLocalSave()"))
        let delete = try #require(Self.body(of: "func deleteExpense(", in: src))
        #expect(delete.contains("requestSyncAfterLocalSave()") == false)
    }

    @Test func teardown_cancelsTheTrigger() throws {
        let src = try source("Yala/Services/CloudSync/Groups/GroupsSyncClient.swift")
        let teardown = try #require(Self.body(of: "func teardownForSignOut()", in: src))
        #expect(teardown.contains("GroupsSaveSyncTrigger.shared.cancel()"))
        #expect(src.contains("func syncNowAfterLocalSave()"))
    }

    /// Extrae el cuerpo hasta el `}` que cierra al mismo nivel que el `{` de la firma.
    private static func body(of signature: String, in src: String) -> String? {
        guard let start = src.range(of: signature) else { return nil }
        guard let open = src[start.upperBound...].firstIndex(of: "{") else { return nil }
        var depth = 0
        var i = open
        while i < src.endIndex {
            let ch = src[i]
            if ch == "{" { depth += 1 }
            if ch == "}" {
                depth -= 1
                if depth == 0 {
                    return String(src[open...i])
                }
            }
            i = src.index(after: i)
        }
        return nil
    }
}
