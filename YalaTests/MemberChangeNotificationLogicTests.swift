//
//  MemberChangeNotificationLogicTests.swift
//  YalaTests
//
//  Tests pure-logic para MemberChangeNotificationLogic.classifyNewMember.
//  Sin SwiftData/ModelContext — verifica solo la decisión por status + admin.
//

import Foundation
import Testing

@testable import Yala

struct MemberChangeNotificationLogicTests {

    @Test func pendingApproval_admin_notifiesAdmin() {
        #expect(MemberChangeNotificationLogic.classifyNewMember(
            rawStatus: SplitMemberStatus.pendingApproval.rawValue,
            isCurrentUserAdmin: true) == .pendingRequestForAdmin)
    }

    @Test func pendingApproval_nonAdmin_ignored() {
        // FIX: un pending recibido por un no-admin NO debe disparar "se unió".
        #expect(MemberChangeNotificationLogic.classifyNewMember(
            rawStatus: SplitMemberStatus.pendingApproval.rawValue,
            isCurrentUserAdmin: false) == .ignore)
    }

    @Test func active_joined_regardlessOfAdmin() {
        #expect(MemberChangeNotificationLogic.classifyNewMember(
            rawStatus: SplitMemberStatus.active.rawValue, isCurrentUserAdmin: false) == .joined)
        #expect(MemberChangeNotificationLogic.classifyNewMember(
            rawStatus: SplitMemberStatus.active.rawValue, isCurrentUserAdmin: true) == .joined)
    }

    @Test func rejected_ignored() {
        #expect(MemberChangeNotificationLogic.classifyNewMember(
            rawStatus: SplitMemberStatus.rejected.rawValue, isCurrentUserAdmin: true) == .ignore)
    }

    @Test func left_ignored() {
        #expect(MemberChangeNotificationLogic.classifyNewMember(
            rawStatus: SplitMemberStatus.left.rawValue, isCurrentUserAdmin: false) == .ignore)
    }

    @Test func removed_ignored() {
        #expect(MemberChangeNotificationLogic.classifyNewMember(
            rawStatus: SplitMemberStatus.removed.rawValue, isCurrentUserAdmin: true) == .ignore)
    }

    @Test func nilStatus_joined() {
        // Status ausente: el modelo lo materializa como `.active`, así que se
        // notifica "se unió" (coherente con la UI, sin perder la notif).
        #expect(MemberChangeNotificationLogic.classifyNewMember(
            rawStatus: nil, isCurrentUserAdmin: true) == .joined)
    }

    @Test func unknownStatus_joined() {
        // rawValue desconocido (status futuro): mismo trato que ausente → activo.
        #expect(MemberChangeNotificationLogic.classifyNewMember(
            rawStatus: "garbage", isCurrentUserAdmin: true) == .joined)
    }
}
