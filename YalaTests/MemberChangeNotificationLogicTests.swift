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

    // MARK: - Autoexclusión por identidad (bug "Jür se unió al grupo")

    @Test func selfMember_ignored_forEveryStatus() {
        let statuses: [String?] = [
            SplitMemberStatus.active.rawValue,
            SplitMemberStatus.pendingApproval.rawValue,
            SplitMemberStatus.rejected.rawValue,
            nil, "garbage"
        ]
        for status in statuses {
            #expect(MemberChangeNotificationLogic.classifyNewMember(
                rawStatus: status,
                isCurrentUserAdmin: true,
                memberUserRecordID: "_abc123",
                currentUserRecordID: "_abc123") == .ignore)
        }
    }

    @Test func distinctRecordIDs_doNotExclude() {
        #expect(MemberChangeNotificationLogic.classifyNewMember(
            rawStatus: SplitMemberStatus.active.rawValue,
            isCurrentUserAdmin: false,
            memberUserRecordID: "_abc123",
            currentUserRecordID: "_zzz999") == .joined)
    }

    @Test func emptyOrNilRecordIDs_doNotExclude() {
        // Identidad no resuelta (cache nil o campo vacío) → NO se aplica la
        // exclusión (el baseline cubre el caso grande del primer import).
        #expect(MemberChangeNotificationLogic.classifyNewMember(
            rawStatus: SplitMemberStatus.active.rawValue,
            isCurrentUserAdmin: false,
            memberUserRecordID: "",
            currentUserRecordID: "") == .joined)
        #expect(MemberChangeNotificationLogic.classifyNewMember(
            rawStatus: SplitMemberStatus.active.rawValue,
            isCurrentUserAdmin: false,
            memberUserRecordID: "_abc123",
            currentUserRecordID: nil) == .joined)
    }

    // MARK: - zoneBaseline

    private let ref = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func zoneBaseline_groupNotLocal_isInitialImport() {
        // Red intra-batch: el member llegó ANTES que el GroupMeta.
        #expect(MemberChangeNotificationLogic.zoneBaseline(
            groupExistsLocally: false, importStartedAt: nil, now: ref) == .initialImport)
    }

    @Test func zoneBaseline_freshStartedAt_isInitialImport() {
        #expect(MemberChangeNotificationLogic.zoneBaseline(
            groupExistsLocally: true,
            importStartedAt: ref.addingTimeInterval(-60),
            now: ref) == .initialImport)
    }

    @Test func zoneBaseline_staleStartedAt_isEstablished() {
        // Flag colgado (didFetch perdido): pasada la ventana de 15 min se auto-sana.
        #expect(MemberChangeNotificationLogic.zoneBaseline(
            groupExistsLocally: true,
            importStartedAt: ref.addingTimeInterval(-16 * 60),
            now: ref) == .established)
    }

    @Test func zoneBaseline_nilStartedAt_isEstablished() {
        // Grupo creado localmente por el owner (nunca pasó por applyGroupMeta
        // rama NUEVO) → jamás se suprime "X quiere unirse".
        #expect(MemberChangeNotificationLogic.zoneBaseline(
            groupExistsLocally: true, importStartedAt: nil, now: ref) == .established)
    }

    // MARK: - Supresión durante initialImport

    @Test func initialImport_suppressesJoinedAndPending() {
        // El member ACTIVE del owner preexistente NO notifica "se unió" al
        // invitado durante su primer import (EL bug de Pia).
        #expect(MemberChangeNotificationLogic.classifyNewMember(
            rawStatus: SplitMemberStatus.active.rawValue,
            isCurrentUserAdmin: false,
            memberUserRecordID: "_owner",
            currentUserRecordID: "_invitee",
            zoneBaseline: .initialImport) == .ignore)
        // Y los pending históricos tampoco re-notifican al admin en un re-import.
        #expect(MemberChangeNotificationLogic.classifyNewMember(
            rawStatus: SplitMemberStatus.pendingApproval.rawValue,
            isCurrentUserAdmin: true,
            memberUserRecordID: "_other",
            currentUserRecordID: "_admin",
            zoneBaseline: .initialImport) == .ignore)
    }

    @Test func establishedBaseline_preservesOriginalClassification() {
        // Regresión: con baseline established y recordIDs distintos, la
        // clasificación original queda intacta.
        #expect(MemberChangeNotificationLogic.classifyNewMember(
            rawStatus: SplitMemberStatus.pendingApproval.rawValue,
            isCurrentUserAdmin: true,
            memberUserRecordID: "_other",
            currentUserRecordID: "_admin",
            zoneBaseline: .established) == .pendingRequestForAdmin)
        #expect(MemberChangeNotificationLogic.classifyNewMember(
            rawStatus: SplitMemberStatus.active.rawValue,
            isCurrentUserAdmin: false,
            memberUserRecordID: "_other",
            currentUserRecordID: "_me",
            zoneBaseline: .established) == .joined)
    }
}
