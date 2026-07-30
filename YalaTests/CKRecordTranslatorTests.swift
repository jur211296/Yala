//
//  CKRecordTranslatorTests.swift
//  YalaTests
//
//  Tests for bidirectional CKRecord ↔ SwiftData translation with encryption.
//

import CloudKit
import Testing

@testable import Yala

// MARK: - Constants Tests

@Suite("CKConstants")
struct CKConstantsTests {

    @Test func zoneNameFromGroupID() {
        let id = UUID()
        let name = SplitGroupZone.zoneName(for: id)
        #expect(name == "SplitGroup-\(id.uuidString)")
    }

    @Test func groupIDFromZoneName() {
        let id = UUID()
        let zoneName = "SplitGroup-\(id.uuidString)"
        #expect(CKConstants.groupID(from: zoneName) == id)
    }

    @Test func groupIDFromInvalidZoneName() {
        #expect(CKConstants.groupID(from: "InvalidZone") == nil)
        #expect(CKConstants.groupID(from: "SplitGroup-not-a-uuid") == nil)
    }

    @Test func recordIDUsesModelUUID() {
        let modelID = UUID()
        let zoneID = CKRecordZone.ID(zoneName: "SplitGroup-test")
        let recordID = CKConstants.recordID(for: modelID, in: zoneID)
        #expect(recordID.recordName == modelID.uuidString)
        #expect(recordID.zoneID == zoneID)
    }

    @Test func modelIDFromRecordID() {
        let uuid = UUID()
        let recordID = CKRecord.ID(recordName: uuid.uuidString, zoneID: CKRecordZone.ID(zoneName: "test"))
        #expect(CKConstants.modelID(from: recordID) == uuid)
    }
}

// MARK: - GroupMeta Translation

@Suite("CKRecordTranslator — GroupMeta")
struct GroupMetaTranslatorTests {

    let zoneID = CKRecordZone.ID(zoneName: "SplitGroup-test")

    @Test func groupToRecord() {
        let group = SplitGroup(name: "Depa", currencyCode: "PEN", simplifyDebts: true, isOwner: true)
        let record = CKRecordTranslator.record(from: group, in: zoneID)

        #expect(record.recordType == "GroupMeta")
        #expect(record.recordID.recordName == group.id.uuidString)
        // Encrypted
        #expect(record.encryptedValues["name"] as? String == "Depa")
        // Plain
        #expect(record["currencyCode"] as? String == "PEN")
        #expect(record["iconName"] as? String == "person.2.fill")
        #expect(record["colorHex"] as? String == "#8B5CF6")
        #expect(record["simplifyDebts"] as? Int64 == 1)
    }

    @Test func recordToGroup() {
        let recordID = CKRecord.ID(recordName: UUID().uuidString, zoneID: zoneID)
        let record = CKRecord(recordType: "GroupMeta", recordID: recordID)
        record.encryptedValues["name"] = "Viaje" as CKRecordValue
        record["currencyCode"] = "USD" as CKRecordValue
        record["iconName"] = "airplane" as CKRecordValue
        record["colorHex"] = "#FF0000" as CKRecordValue
        record["simplifyDebts"] = 0 as CKRecordValue
        record["createdAt"] = Date.now as CKRecordValue

        let group = CKRecordTranslator.group(from: record)
        #expect(group != nil)
        #expect(group?.name == "Viaje")
        #expect(group?.currencyCode == "USD")
        #expect(group?.iconName == "airplane")
        #expect(group?.colorHex == "#FF0000")
        #expect(group?.simplifyDebts == false)
        #expect(group?.cloudKitZoneID == zoneID.zoneName)
    }

    @Test func updateGroupFromRecord() {
        let group = SplitGroup(name: "Old", currencyCode: "PEN")
        let record = CKRecord(recordType: "GroupMeta", recordID: CKRecord.ID(recordName: UUID().uuidString, zoneID: zoneID))
        record.encryptedValues["name"] = "New" as CKRecordValue
        record["currencyCode"] = "EUR" as CKRecordValue
        record["simplifyDebts"] = 1 as CKRecordValue

        CKRecordTranslator.update(group, from: record)
        #expect(group.name == "New")
        #expect(group.currencyCode == "EUR")
        #expect(group.simplifyDebts == true)
    }

    // MARK: - G6-3: marcador de migración (movedToBackendAt + backendReInviteToken)

    @Test func markerFields_roundTrip_recordToGroupToRecord() {
        let movedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let group = SplitGroup(name: "Depa", currencyCode: "PEN", isOwner: true)
        group.movedToBackendAt = movedAt
        group.backendReInviteToken = "tok_abc123"

        let record = CKRecordTranslator.record(from: group, in: zoneID)
        #expect(record["movedToBackendAt"] as? Date == movedAt)
        #expect(record.encryptedValues["backendReInviteToken"] as? String == "tok_abc123")

        let restored = CKRecordTranslator.group(from: record)
        #expect(restored?.movedToBackendAt == movedAt)
        #expect(restored?.backendReInviteToken == "tok_abc123")
    }

    @Test func markerFields_nilSafe_absentFromRecord() {
        // Grupo NO migrado: los campos son opcionales → no se escriben; group(from:) los lee como nil.
        let group = SplitGroup(name: "Sin migrar", currencyCode: "PEN", isOwner: true)
        let record = CKRecordTranslator.record(from: group, in: zoneID)
        #expect(record["movedToBackendAt"] == nil)
        #expect(record.encryptedValues["backendReInviteToken"] == nil)

        let restored = CKRecordTranslator.group(from: record)
        #expect(restored?.movedToBackendAt == nil)
        #expect(restored?.backendReInviteToken == nil)
    }

    @Test func markerFields_update_raceTolerant_preservesLocalWhenAbsent() {
        // update(): un record STALE sin los campos NO des-congela un grupo que ya los tenía (fallback a local).
        let movedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let group = SplitGroup(name: "Old", currencyCode: "PEN")
        group.movedToBackendAt = movedAt
        group.backendReInviteToken = "tok_keep"

        let record = CKRecord(recordType: "GroupMeta",
                              recordID: CKRecord.ID(recordName: UUID().uuidString, zoneID: zoneID))
        record.encryptedValues["name"] = "New" as CKRecordValue
        // El record NO trae movedToBackendAt ni backendReInviteToken.

        CKRecordTranslator.update(group, from: record)
        #expect(group.movedToBackendAt == movedAt)       // preservado (race-tolerant)
        #expect(group.backendReInviteToken == "tok_keep")
    }

    @Test func markerFields_update_appliesWhenPresent() {
        let group = SplitGroup(name: "Old", currencyCode: "PEN")
        let movedAt = Date(timeIntervalSince1970: 1_900_000_000)
        let record = CKRecord(recordType: "GroupMeta",
                              recordID: CKRecord.ID(recordName: UUID().uuidString, zoneID: zoneID))
        record["movedToBackendAt"] = movedAt as CKRecordValue
        record.encryptedValues["backendReInviteToken"] = "tok_new" as CKRecordValue

        CKRecordTranslator.update(group, from: record)
        #expect(group.movedToBackendAt == movedAt)
        #expect(group.backendReInviteToken == "tok_new")
    }
}

// MARK: - SplitExpense Translation

@Suite("CKRecordTranslator — SplitExpense")
struct ExpenseTranslatorTests {

    let zoneID = CKRecordZone.ID(zoneName: "SplitGroup-test")

    @Test func expenseToRecord() {
        let expense = SplitExpense(
            groupZoneID: "SplitGroup-test",
            amount: 150.50,
            currencyCode: "PEN",
            expenseDescription: "Cena",
            note: "Incluye propina",
            paidByMemberID: "member-1",
            splitType: "equal"
        )
        let record = CKRecordTranslator.record(from: expense, in: zoneID)

        // Encrypted
        #expect(record.encryptedValues["amount"] as? Double == 150.50)
        #expect(record.encryptedValues["description"] as? String == "Cena")
        #expect(record.encryptedValues["note"] as? String == "Incluye propina")
        // Plain
        #expect(record["paidByMemberID"] as? String == "member-1")
        #expect(record["splitType"] as? String == "equal")
        #expect(record["isSettled"] as? Int64 == 0)
        #expect(record["currencyCode"] as? String == "PEN")
    }

    @Test func recordToExpense() {
        let recordID = CKRecord.ID(recordName: UUID().uuidString, zoneID: zoneID)
        let record = CKRecord(recordType: "SplitExpense", recordID: recordID)
        record.encryptedValues["amount"] = 200.0 as CKRecordValue
        record.encryptedValues["description"] = "Supermercado" as CKRecordValue
        record["paidByMemberID"] = "member-2" as CKRecordValue
        record["splitType"] = "percentage" as CKRecordValue
        record["isSettled"] = 1 as CKRecordValue
        record["currencyCode"] = "USD" as CKRecordValue
        record["date"] = Date.now as CKRecordValue
        record["createdAt"] = Date.now as CKRecordValue

        let expense = CKRecordTranslator.expense(from: record)
        #expect(expense != nil)
        #expect(expense?.amount == 200.0)
        #expect(expense?.expenseDescription == "Supermercado")
        #expect(expense?.paidByMemberID == "member-2")
        #expect(expense?.splitType == "percentage")
        #expect(expense?.isSettled == true)
        #expect(expense?.note == nil)
    }

    @Test func updateExpenseFromRecord() {
        let expense = SplitExpense(amount: 100, expenseDescription: "Old")
        let record = CKRecord(recordType: "SplitExpense", recordID: CKRecord.ID(recordName: UUID().uuidString, zoneID: zoneID))
        record.encryptedValues["amount"] = 250.0 as CKRecordValue
        record.encryptedValues["description"] = "Updated" as CKRecordValue
        record["isSettled"] = 1 as CKRecordValue

        CKRecordTranslator.update(expense, from: record)
        #expect(expense.amount == 250.0)
        #expect(expense.expenseDescription == "Updated")
        #expect(expense.isSettled == true)
    }
}

// MARK: - SplitMember Translation

@Suite("CKRecordTranslator — SplitMember")
struct MemberTranslatorTests {

    let zoneID = CKRecordZone.ID(zoneName: "SplitGroup-test")

    @Test func memberToRecord() {
        let member = SplitMember(
            groupZoneID: "SplitGroup-test",
            displayName: "Carlos",
            cloudKitUserRecordID: "user-record-123",
            role: "admin",
            isGroupOwner: true,
            isCurrentUser: true
        )
        let record = CKRecordTranslator.record(from: member, in: zoneID)

        #expect(record.encryptedValues["displayName"] as? String == "Carlos")
        #expect(record["memberID"] as? String == "user-record-123")
        #expect(record["role"] as? String == "admin")
        #expect(record["status"] as? String == "active")
        #expect(record["isGroupOwner"] as? Int64 == 1)
    }

    @Test func recordToMember() {
        let recordID = CKRecord.ID(recordName: UUID().uuidString, zoneID: zoneID)
        let record = CKRecord(recordType: "SplitMember", recordID: recordID)
        record.encryptedValues["displayName"] = "Ana" as CKRecordValue
        record["memberID"] = "user-456" as CKRecordValue
        record["role"] = "member" as CKRecordValue
        record["status"] = "left" as CKRecordValue
        record["joinedAt"] = Date.now as CKRecordValue

        let member = CKRecordTranslator.member(from: record)
        #expect(member != nil)
        #expect(member?.displayName == "Ana")
        #expect(member?.cloudKitUserRecordID == "user-456")
        #expect(member?.role == "member")
        #expect(member?.memberStatus == .left)
        #expect(member?.isCurrentUser == false)
    }

    // MARK: - A3: pendingApproval / rejected round-trip

    @Test func memberRoundTrip_preservesPendingApprovalStatus() {
        let member = SplitMember(
            groupZoneID: "SplitGroup-test",
            displayName: "Pending User",
            cloudKitUserRecordID: "user-pending-1",
            role: "member",
            status: .pendingApproval,
            isCurrentUser: true
        )
        let record = CKRecordTranslator.record(from: member, in: zoneID)
        #expect(record["status"] as? String == "pendingApproval")

        let parsed = CKRecordTranslator.member(from: record)
        #expect(parsed?.memberStatus == .pendingApproval)
        #expect(parsed?.isPendingApproval == true)
        #expect(parsed?.isActive == false)
    }

    @Test func memberRoundTrip_preservesRejectedStatus() {
        let member = SplitMember(
            groupZoneID: "SplitGroup-test",
            displayName: "Rejected User",
            cloudKitUserRecordID: "user-rejected-1",
            role: "member",
            status: .rejected
        )
        let record = CKRecordTranslator.record(from: member, in: zoneID)
        #expect(record["status"] as? String == "rejected")

        let parsed = CKRecordTranslator.member(from: record)
        #expect(parsed?.memberStatus == .rejected)
        #expect(parsed?.isRejected == true)
    }
}

// MARK: - SplitShare Translation

@Suite("CKRecordTranslator — SplitShare")
struct ShareTranslatorTests {

    let zoneID = CKRecordZone.ID(zoneName: "SplitGroup-test")

    @Test func shareToRecord() {
        let expenseID = UUID()
        let share = SplitShare(expenseID: expenseID, memberID: "member-1", amount: 75.25, isPaid: true)
        let record = CKRecordTranslator.record(from: share, in: zoneID)

        #expect(record.encryptedValues["amount"] as? Double == 75.25)
        #expect(record["expenseRecordName"] as? String == expenseID.uuidString)
        #expect(record["memberID"] as? String == "member-1")
        #expect(record["isPaid"] as? Int64 == 1)
    }

    @Test func recordToShare() {
        let expenseID = UUID()
        let recordID = CKRecord.ID(recordName: UUID().uuidString, zoneID: zoneID)
        let record = CKRecord(recordType: "SplitShare", recordID: recordID)
        record.encryptedValues["amount"] = 50.0 as CKRecordValue
        record["expenseRecordName"] = expenseID.uuidString as CKRecordValue
        record["memberID"] = "member-2" as CKRecordValue
        record["isPaid"] = 0 as CKRecordValue

        let share = CKRecordTranslator.share(from: record)
        #expect(share != nil)
        #expect(share?.amount == 50.0)
        #expect(share?.expenseID == expenseID)
        #expect(share?.memberID == "member-2")
        #expect(share?.isPaid == false)
    }
}

// MARK: - SplitSettlement Translation

@Suite("CKRecordTranslator — SplitSettlement")
struct SettlementTranslatorTests {

    let zoneID = CKRecordZone.ID(zoneName: "SplitGroup-test")

    @Test func settlementToRecord() {
        let settlement = SplitSettlement(
            groupZoneID: "SplitGroup-test",
            fromMemberID: "member-1",
            toMemberID: "member-2",
            amount: 340.00,
            currencyCode: "PEN",
            note: "Pago parcial"
        )
        let record = CKRecordTranslator.record(from: settlement, in: zoneID)

        #expect(record.encryptedValues["amount"] as? Double == 340.0)
        #expect(record.encryptedValues["note"] as? String == "Pago parcial")
        #expect(record["fromMemberID"] as? String == "member-1")
        #expect(record["toMemberID"] as? String == "member-2")
        #expect(record["isConfirmed"] as? Int64 == 0)
        #expect(record["currencyCode"] as? String == "PEN")
    }

    @Test func recordToSettlement() {
        let recordID = CKRecord.ID(recordName: UUID().uuidString, zoneID: zoneID)
        let record = CKRecord(recordType: "SplitSettlement", recordID: recordID)
        record.encryptedValues["amount"] = 100.0 as CKRecordValue
        record["fromMemberID"] = "from-1" as CKRecordValue
        record["toMemberID"] = "to-2" as CKRecordValue
        record["date"] = Date.now as CKRecordValue
        record["isConfirmed"] = 1 as CKRecordValue
        record["currencyCode"] = "EUR" as CKRecordValue

        let settlement = CKRecordTranslator.settlement(from: record)
        #expect(settlement != nil)
        #expect(settlement?.amount == 100.0)
        #expect(settlement?.fromMemberID == "from-1")
        #expect(settlement?.toMemberID == "to-2")
        #expect(settlement?.isConfirmed == true)
        #expect(settlement?.currencyCode == "EUR")
        #expect(settlement?.note == nil)
    }
}

// MARK: - Edge Cases

@Suite("CKRecordTranslator — Edge Cases")
struct TranslatorEdgeCaseTests {

    let zoneID = CKRecordZone.ID(zoneName: "SplitGroup-test")

    @Test func invalidRecordIDReturnsNil() {
        let recordID = CKRecord.ID(recordName: "not-a-uuid", zoneID: zoneID)
        let record = CKRecord(recordType: "GroupMeta", recordID: recordID)
        #expect(CKRecordTranslator.group(from: record) == nil)
    }

    @Test func emptyStringFieldsHandledGracefully() {
        let recordID = CKRecord.ID(recordName: UUID().uuidString, zoneID: zoneID)
        let record = CKRecord(recordType: "GroupMeta", recordID: recordID)
        // No fields set — all should use defaults
        let group = CKRecordTranslator.group(from: record)
        #expect(group != nil)
        #expect(group?.name == "")
        #expect(group?.currencyCode == "PEN")
        #expect(group?.iconName == "person.2.fill")
    }

    @Test func nilOptionalFieldsPreserved() {
        let recordID = CKRecord.ID(recordName: UUID().uuidString, zoneID: zoneID)
        let record = CKRecord(recordType: "SplitExpense", recordID: recordID)
        record.encryptedValues["amount"] = 100.0 as CKRecordValue
        record["date"] = Date.now as CKRecordValue
        record["createdAt"] = Date.now as CKRecordValue
        // note and subcategoryName intentionally not set
        let expense = CKRecordTranslator.expense(from: record)
        #expect(expense?.note == nil)
        #expect(expense?.subcategoryName == nil)
    }
}
