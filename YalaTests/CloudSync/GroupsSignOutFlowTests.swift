//
//  GroupsSignOutFlowTests.swift
//  YalaTests / CloudSync
//
//  G5-B — sesión solo-grupos y ampliación del wipe `.cloud`. Cubre las unidades testeables del
//  camino sin arrastrar los singletons (GroupsSyncClient/CloudAuthService/CloudMigrationController):
//   - `liveGroupsPendingCount` (agregado del outbox de grupos, base del veredicto push-all).
//   - `purgeGroupsSyncState` (purga in-session del outbox + cursor de grupos).
//   - Boot hook `performGroupsOnlySignOutWipeIfArmed` (idempotencia, kill-safe, solo-grupos).
//   - Markers de arm (`.cloud` incluye-grupos + groups-only) con UserDefaults aislado.
//   - C6: la señal de wipe personal (`DataWipeService`) JAMÁS toca modelos `Split*`.
//
//  Container ON-DISK temp con los 3 stores (todos `.none`), `.serialized`, cleanup por test.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("G5-B · sesión solo-grupos + wipe .cloud ampliado", .serialized)
@MainActor
struct GroupsSignOutFlowTests {

    // MARK: - Infra

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GroupsSignOut-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "GSO-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "GSO-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "GSO-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema,
            configurations: personalCfg, groupsCfg, syncMetaCfg)
        return ModelContext(container)
    }

    private func makeOutboxRow(group: String, rejected: String?, context: ModelContext) {
        let row = GroupSyncOutbox(
            syncID: UUID(), groupID: group, entityType: "SplitExpense",
            op: .upsert, hlc: "hlc", fieldsJSON: "{}", author: "a",
            rejectedReason: rejected)
        context.insert(row)
    }

    // MARK: - liveGroupsPendingCount (base del veredicto push-all)

    @Test func liveGroupsPendingCount_countsLive_excludesDeadLetters() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        makeOutboxRow(group: "g1", rejected: nil, context: context)
        makeOutboxRow(group: "g1", rejected: nil, context: context)
        makeOutboxRow(group: "g2", rejected: nil, context: context)          // otro grupo → SÍ cuenta (agregado)
        makeOutboxRow(group: "g1", rejected: "upstream_400:x", context: context)  // dead-letter → NO cuenta
        try context.save()

        #expect(CloudSessionSignOut.liveGroupsPendingCount(context: context) == 3)
    }

    @Test func liveGroupsPendingCount_zeroWhenEmpty() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        #expect(CloudSessionSignOut.liveGroupsPendingCount(context: context) == 0)
    }

    @Test func liveGroupsPendingCount_zeroWhenOnlyDeadLetters() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        makeOutboxRow(group: "g1", rejected: "upstream_400:x", context: context)
        try context.save()
        // Dead-letters no bloquean el sign-out (permanentes) → cuenta viva 0 = drained.
        #expect(CloudSessionSignOut.liveGroupsPendingCount(context: context) == 0)
    }

    // MARK: - purgeGroupsSyncState (paso 4 del camino solo-grupos)

    @Test func purge_deletesAllOutboxRows_includingDeadLetters_andCursor() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        makeOutboxRow(group: "g1", rejected: nil, context: context)
        makeOutboxRow(group: "g1", rejected: "upstream_400:x", context: context)
        context.insert(GroupSyncCursor(groupCursorsJSON: "{\"g1\":5}"))
        try context.save()

        CloudSessionSignOut.purgeGroupsSyncState(context: context)

        #expect(try context.fetchCount(FetchDescriptor<GroupSyncOutbox>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<GroupSyncCursor>()) == 0)
    }

    // MARK: - Boot hook groups-only (idempotencia / kill-safe / solo-grupos)

    private func armedGroupsOnly(prefix: String) -> UserDefaults {
        let defaults = makeIsolatedDefaults(prefix: prefix)
        StorageModePersistence.armGroupsOnlyWipe(defaults)
        return defaults
    }

    @Test func groupsOnlyBoot_notArmed_isNoOp() {
        let defaults = makeIsolatedDefaults(prefix: "gowipe.noop")
        var touched = false
        SwiftDataConfiguration.performGroupsOnlySignOutWipeIfArmed(
            defaults: defaults, deleteFiles: { _, _ in touched = true; return true })
        #expect(touched == false)
    }

    @Test func groupsOnlyBoot_deletesOnlyGroupsFile_thenClearsArmLast() {
        let defaults = armedGroupsOnly(prefix: "gowipe.ok")
        var deleted: [String] = []
        SwiftDataConfiguration.performGroupsOnlySignOutWipeIfArmed(
            defaults: defaults, deleteFiles: { name, _ in deleted.append(name); return true })
        // SOLO el store de grupos — jamás YalaModel ni YalaSyncMeta.
        #expect(deleted == [SwiftDataConfiguration.groupsDatabaseName])
        #expect(deleted.allSatisfy { !$0.contains("YalaModel") && !$0.contains("YalaSyncMeta") })
        #expect(StorageModePersistence.isGroupsOnlyWipeArmed(defaults) == false)
    }

    @Test func groupsOnlyBoot_baseFail_abortsPreservingArm() {
        let defaults = armedGroupsOnly(prefix: "gowipe.abort")
        SwiftDataConfiguration.performGroupsOnlySignOutWipeIfArmed(
            defaults: defaults, deleteFiles: { _, _ in false })   // kill-simulado
        // Arm persiste → el próximo boot reintenta.
        #expect(StorageModePersistence.isGroupsOnlyWipeArmed(defaults))
    }

    @Test func groupsOnlyBoot_retryAfterAbort_completes() {
        let defaults = armedGroupsOnly(prefix: "gowipe.retry")
        SwiftDataConfiguration.performGroupsOnlySignOutWipeIfArmed(
            defaults: defaults, deleteFiles: { _, _ in false })
        #expect(StorageModePersistence.isGroupsOnlyWipeArmed(defaults))   // sigue armado
        SwiftDataConfiguration.performGroupsOnlySignOutWipeIfArmed(
            defaults: defaults, deleteFiles: { _, _ in true })
        #expect(StorageModePersistence.isGroupsOnlyWipeArmed(defaults) == false)
    }

    // MARK: - Markers de arm

    @Test func cloudWipeIncludesGroupsMarker_roundTrips() {
        let defaults = makeIsolatedDefaults(prefix: "marker.cloudGroups")
        #expect(StorageModePersistence.signOutWipeIncludesGroups(defaults) == false)
        StorageModePersistence.markSignOutWipeIncludesGroups(defaults)
        #expect(StorageModePersistence.signOutWipeIncludesGroups(defaults))
        StorageModePersistence.clearSignOutWipeIncludesGroups(defaults)
        #expect(StorageModePersistence.signOutWipeIncludesGroups(defaults) == false)
    }

    @Test func groupsOnlyWipeMarker_roundTrips() {
        let defaults = makeIsolatedDefaults(prefix: "marker.groupsOnly")
        #expect(StorageModePersistence.isGroupsOnlyWipeArmed(defaults) == false)
        StorageModePersistence.armGroupsOnlyWipe(defaults)
        #expect(StorageModePersistence.isGroupsOnlyWipeArmed(defaults))
        StorageModePersistence.clearGroupsOnlyWipeArm(defaults)
        #expect(StorageModePersistence.isGroupsOnlyWipeArmed(defaults) == false)
    }

    // MARK: - C6 — la señal de wipe personal NO toca modelos Split*

    @Test func personalWipe_doesNotTouchGroups() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        // Dominio de grupos (store de grupos).
        let group = SplitGroup(name: "G")
        context.insert(group)
        let expense = SplitExpense(
            groupZoneID: group.cloudKitZoneID, amount: 12.5, currencyCode: "USD",
            expenseDescription: "Dinner", paidByMemberID: "m1")
        context.insert(expense)
        // Dato personal (store personal).
        let tx = TransactionItem(date: .now, amount: -100, currencyCode: "PEN")
        context.insert(tx)
        try context.save()

        // broadcastSignal:false → no toca el iKV compartido (regla del repo en tests).
        try DataWipeService.wipeAllUserData(in: context, broadcastSignal: false)

        // El dominio Grupos SOBREVIVE (store propio, exento del wipe personal — ya en DataWipeService).
        #expect(try context.fetchCount(FetchDescriptor<SplitGroup>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<SplitExpense>()) == 1)
        // El dato personal se borró.
        #expect(try context.fetchCount(FetchDescriptor<TransactionItem>()) == 0)
    }
}
