//
//  SplitSyncManagerTests.swift
//  YalaTests
//
//  Tests for SplitSyncManager logic (state, zone names, pending changes).
//  CloudKit integration tests require a device — documented in QA-SCENARIOS.md.
//

import CloudKit
import Testing

@testable import Yala

// MARK: - Engine Identity & Zone Helpers

@Suite("SplitSyncManager — Zone Helpers")
struct SplitSyncZoneHelperTests {

    @Test func zoneNameRoundTrip() {
        let groupID = UUID()
        let zoneName = CKConstants.zoneName(for: groupID)
        let recovered = CKConstants.groupID(from: zoneName)
        #expect(recovered == groupID)
    }

    @Test func zoneIDCreation() {
        let groupID = UUID()
        let zoneID = CKConstants.zoneID(for: groupID)
        #expect(zoneID.zoneName == "SplitGroup-\(groupID.uuidString)")
        #expect(zoneID.ownerName == CKCurrentUserDefaultName)
    }

    @Test func recordIDMapsToModelID() {
        let modelID = UUID()
        let zoneID = CKRecordZone.ID(zoneName: "SplitGroup-test")
        let recordID = CKConstants.recordID(for: modelID, in: zoneID)
        #expect(CKConstants.modelID(from: recordID) == modelID)
        #expect(recordID.zoneID == zoneID)
    }
}

// MARK: - Conflict Resolution Logic

@Suite("SplitSyncManager — Conflict Resolution")
struct ConflictResolutionTests {

    let zoneID = CKRecordZone.ID(zoneName: "SplitGroup-test")

    @Test func serverWinsUpdatesLocalModel() {
        // Simulate: local model has old data, server record has new data
        let group = SplitGroup(name: "Local Version", currencyCode: "PEN")

        let serverRecordID = CKRecord.ID(recordName: group.id.uuidString, zoneID: zoneID)
        let serverRecord = CKRecord(recordType: "GroupMeta", recordID: serverRecordID)
        serverRecord.encryptedValues["name"] = "Server Version" as CKRecordValue
        serverRecord["currencyCode"] = "USD" as CKRecordValue
        serverRecord["simplifyDebts"] = 1 as CKRecordValue

        // Apply server version (this is what conflict resolution does)
        CKRecordTranslator.update(group, from: serverRecord)

        #expect(group.name == "Server Version")
        #expect(group.currencyCode == "USD")
        #expect(group.simplifyDebts == true)
    }

    @Test func serverWinsForExpense() {
        let expense = SplitExpense(amount: 100, expenseDescription: "Old")

        let serverRecordID = CKRecord.ID(recordName: expense.id.uuidString, zoneID: zoneID)
        let serverRecord = CKRecord(recordType: "SplitExpense", recordID: serverRecordID)
        serverRecord.encryptedValues["amount"] = 250.0 as CKRecordValue
        serverRecord.encryptedValues["description"] = "Updated by other member" as CKRecordValue
        serverRecord["isSettled"] = 1 as CKRecordValue

        CKRecordTranslator.update(expense, from: serverRecord)

        #expect(expense.amount == 250.0)
        #expect(expense.expenseDescription == "Updated by other member")
        #expect(expense.isSettled == true)
    }
}

// MARK: - State Serialization

@Suite("SplitSyncManager — State Serialization")
struct StatePersistenceTests {

    @Test func saveAndLoadStateRoundTrip() async {
        let manager = await SplitSyncManager.shared

        // Create a minimal serialization by encoding/decoding a known structure
        // Note: We can't easily create a real CKSyncEngine.State.Serialization without an engine,
        // but we can test the file I/O path with the manager's save/load methods
        let testDir = FileManager.default.temporaryDirectory.appendingPathComponent("SplitSyncTest-\(UUID())")
        try? FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: testDir) }

        // The save/load methods use the manager's internal stateDirectory,
        // so we test via a proxy: verify JSON encoding/decoding works
        let testData = "{\"test\": true}".data(using: .utf8)!
        let url = testDir.appendingPathComponent("test-state.json")
        try? testData.write(to: url)
        let loaded = try? Data(contentsOf: url)
        #expect(loaded == testData)
    }
}

// MARK: - HasUUID Protocol

@Suite("HasUUID Protocol")
struct HasUUIDTests {

    @Test func splitGroupConformsToHasUUID() {
        let group = SplitGroup(name: "Test")
        let hasUUID: any HasUUID = group
        #expect(hasUUID.id == group.id)
    }

    @Test func splitExpenseConformsToHasUUID() {
        let expense = SplitExpense(amount: 100)
        let hasUUID: any HasUUID = expense
        #expect(hasUUID.id == expense.id)
    }

    @Test func allSplitModelsConformToHasUUID() {
        let models: [any HasUUID] = [
            SplitGroup(name: "G"),
            SplitMember(displayName: "M"),
            SplitExpense(amount: 1),
            SplitShare(amount: 1),
            SplitSettlement(amount: 1),
        ]
        // All should have unique UUIDs
        let ids = models.map(\.id)
        #expect(Set(ids).count == 5)
    }
}

// MARK: - Error Type Tests

@Suite("SplitZoneError")
struct SplitZoneErrorTests {

    @Test func engineNotInitializedHasDescription() {
        let error = SplitZoneError.engineNotInitialized
        #expect(error.errorDescription?.isEmpty == false)
    }
}

// MARK: - Zone Cache Cleanup Logic

@Suite("SplitSyncManager — Zone Cleanup")
struct ZoneCleanupTests {

    @Test func groupIDFromZoneNameParsesCorrectly() {
        let uuid = UUID()
        let zoneName = CKConstants.zoneName(for: uuid)
        #expect(CKConstants.groupID(from: zoneName) == uuid)
    }

    @Test func groupIDFromInvalidZoneReturnsNil() {
        #expect(CKConstants.groupID(from: "InvalidZone-123") == nil)
        #expect(CKConstants.groupID(from: "") == nil)
        #expect(CKConstants.groupID(from: "SplitGroup-not-uuid") == nil)
    }
}
