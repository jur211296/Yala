//
//  GroupMigrationPayloadBuilderTests.swift
//  YalaTests
//
//  G6-3 (C6): tests pure-logic del builder de payloads de `migrate_group`. Sin SwiftData.
//

import Foundation
import Testing

@testable import Yala

struct GroupMigrationPayloadBuilderTests {

    private func meta(name: String = "Depa", currency: String = "PEN") -> GroupMigrationMetaSnapshot {
        GroupMigrationMetaSnapshot(
            name: name, currencyCode: currency, iconName: "person.2.fill", colorHex: "#8B5CF6",
            defaultSplitType: "equal", simplifyDebts: false, showDebtsInSingleCurrency: false,
            membersCanInvite: false, createdAt: Date(timeIntervalSince1970: 1_700_000_000))
    }

    private func member(
        _ key: String, owner: Bool = false, status: String = "active",
        role: String = "member", name: String = "Jur"
    ) -> GroupMigrationMemberSnapshot {
        GroupMigrationMemberSnapshot(
            memberKey: key, displayName: name, role: role, status: status, isOwner: owner,
            joinedAt: Date(timeIntervalSince1970: 1_700_000_000))
    }

    @Test func build_validPayload_ownerAndMembers() throws {
        let result = GroupMigrationPayloadBuilder.build(
            groupID: "SplitGroup-x",
            meta: meta(),
            members: [member("_owner", owner: true, role: "admin"), member("_m2")])
        let payload = try #require(result)
        #expect(payload.meta["name"] as? String == "Depa")
        #expect(payload.meta["currency_code"] as? String == "PEN")
        #expect(payload.members.count == 2)
        // created_at / joined_at viajan como ISO8601.
        #expect((payload.meta["created_at"] as? String)?.contains("2023") == true)
    }

    @Test func build_nil_whenNoOwner() {
        #expect(GroupMigrationPayloadBuilder.build(
            groupID: "g", meta: meta(), members: [member("_m1"), member("_m2")]) == nil)
    }

    @Test func build_nil_whenTwoOwners() {
        #expect(GroupMigrationPayloadBuilder.build(
            groupID: "g", meta: meta(),
            members: [member("_a", owner: true), member("_b", owner: true)]) == nil)
    }

    @Test func build_nil_whenEmptyName() {
        #expect(GroupMigrationPayloadBuilder.build(
            groupID: "g", meta: meta(name: "   "), members: [member("_o", owner: true)]) == nil)
    }

    @Test func build_nil_whenCurrencyNotThreeLetters() {
        #expect(GroupMigrationPayloadBuilder.build(
            groupID: "g", meta: meta(currency: "PE"), members: [member("_o", owner: true)]) == nil)
    }

    @Test func build_skipsMemberWithEmptyRecordName() throws {
        let result = GroupMigrationPayloadBuilder.build(
            groupID: "g", meta: meta(),
            members: [member("_owner", owner: true), member("")])
        let payload = try #require(result)
        #expect(payload.members.count == 1)   // el member sin recordName se saltó
    }

    @Test func build_skipsRejectedStatus() throws {
        let result = GroupMigrationPayloadBuilder.build(
            groupID: "g", meta: meta(),
            members: [member("_owner", owner: true), member("_r", status: "rejected")])
        let payload = try #require(result)
        #expect(payload.members.count == 1)   // rejected fuera del set aceptado del RPC
    }

    @Test func build_dedupesByMemberKey() throws {
        let result = GroupMigrationPayloadBuilder.build(
            groupID: "g", meta: meta(),
            members: [member("_owner", owner: true), member("_dup"), member("_dup")])
        let payload = try #require(result)
        #expect(payload.members.count == 2)   // el duplicado se colapsa
    }

    @Test func build_acceptsPendingLeftRemovedStatuses() throws {
        let result = GroupMigrationPayloadBuilder.build(
            groupID: "g", meta: meta(),
            members: [
                member("_owner", owner: true),
                member("_p", status: "pendingApproval"),
                member("_l", status: "left"),
                member("_x", status: "removed"),
            ])
        let payload = try #require(result)
        #expect(payload.members.count == 4)
    }
}
