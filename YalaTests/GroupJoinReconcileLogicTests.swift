//
//  GroupJoinReconcileLogicTests.swift
//  YalaTests
//
//  Pure-logic del reconciliador de join intents. Sin SwiftData/CloudKit-container
//  (CKRecordZone.ID / CKRecord.ID son value types instanciables offline).
//

import CloudKit
import Foundation
import Testing

@testable import Yala

struct GroupJoinReconcileLogicTests {

    // MARK: - decide

    @Test func decide_noIntent_skips() {
        #expect(GroupJoinReconcileLogic.decide(
            hasIntent: false, groupExistsLocally: true, engineReady: true) == .skip)
    }

    @Test func decide_groupNotLocal_waitsForGroup() {
        // EL caso del bug: la zona compartida aún no materializó.
        #expect(GroupJoinReconcileLogic.decide(
            hasIntent: true, groupExistsLocally: false, engineReady: true) == .waitForGroup)
        // engineReady no importa si no hay grupo.
        #expect(GroupJoinReconcileLogic.decide(
            hasIntent: true, groupExistsLocally: false, engineReady: false) == .waitForGroup)
    }

    @Test func decide_engineNil_waitsForEngines() {
        #expect(GroupJoinReconcileLogic.decide(
            hasIntent: true, groupExistsLocally: true, engineReady: false) == .waitForEngines)
    }

    @Test func decide_allReady_reconciles() {
        #expect(GroupJoinReconcileLogic.decide(
            hasIntent: true, groupExistsLocally: true, engineReady: true) == .reconcile)
    }

    // MARK: - shouldClearIntent

    @Test func shouldClearIntent_onlyWhenEnsuredAndEnqueued() {
        #expect(GroupJoinReconcileLogic.shouldClearIntent(
            memberEnsured: true, enqueueReachedEngine: true) == true)
        // Member asegurado pero engine nil (enqueue fue no-op) → conservar intent.
        #expect(GroupJoinReconcileLogic.shouldClearIntent(
            memberEnsured: true, enqueueReachedEngine: false) == false)
        #expect(GroupJoinReconcileLogic.shouldClearIntent(
            memberEnsured: false, enqueueReachedEngine: true) == false)
        #expect(GroupJoinReconcileLogic.shouldClearIntent(
            memberEnsured: false, enqueueReachedEngine: false) == false)
    }

    // MARK: - shouldApplyIntentDisplayName (guard anti-pisado)

    @Test func displayName_appliesWhenMemberJustCreated() {
        #expect(GroupJoinReconcileLogic.shouldApplyIntentDisplayName(
            memberWasCreated: true, currentDisplayName: "Otro Nombre", defaultName: "Usuario"))
    }

    @Test func displayName_appliesOverDefaultOrEmpty() {
        #expect(GroupJoinReconcileLogic.shouldApplyIntentDisplayName(
            memberWasCreated: false, currentDisplayName: "Usuario", defaultName: "Usuario"))
        #expect(GroupJoinReconcileLogic.shouldApplyIntentDisplayName(
            memberWasCreated: false, currentDisplayName: "  ", defaultName: "Usuario"))
    }

    @Test func displayName_neverOverwritesManualRename() {
        #expect(!GroupJoinReconcileLogic.shouldApplyIntentDisplayName(
            memberWasCreated: false, currentDisplayName: "Pia Renombrada", defaultName: "Usuario"))
    }

    // MARK: - shouldApplyGroupCurrency

    @Test func currency_appliesOnlyWhileStillOnRegionFallback() {
        // Pref sigue en el fallback regional → re-aplicar la del grupo.
        #expect(GroupJoinReconcileLogic.shouldApplyGroupCurrency(
            currentPreferenceCode: "PEN", regionFallbackCode: "PEN", groupCode: "USD"))
        // El usuario ya cambió la moneda a mano → no tocar.
        #expect(!GroupJoinReconcileLogic.shouldApplyGroupCurrency(
            currentPreferenceCode: "EUR", regionFallbackCode: "PEN", groupCode: "USD"))
        // Sin fallback registrado (el grupo SÍ estaba al hacer setup) → no tocar.
        #expect(!GroupJoinReconcileLogic.shouldApplyGroupCurrency(
            currentPreferenceCode: "PEN", regionFallbackCode: nil, groupCode: "USD"))
        // Grupo ya coincide → no-op.
        #expect(!GroupJoinReconcileLogic.shouldApplyGroupCurrency(
            currentPreferenceCode: "PEN", regionFallbackCode: "PEN", groupCode: "PEN"))
    }

    // MARK: - enqueuePlan (contenido REAL del enqueue — lección d49d2e47)

    @Test func enqueuePlan_invitedMember_routesToSharedWithOwnerZone() {
        let memberID = UUID()
        let groupID = UUID()
        let zoneName = "SplitGroup-\(groupID.uuidString)"
        let plan = GroupJoinReconcileLogic.enqueuePlan(
            memberID: memberID,
            zoneName: zoneName,
            zoneOwnerName: "_ownerRecord123",
            isOwner: false
        )
        // Oráculo: el mismo CKConstants.recordID que usa enqueueSharedSave.
        let expectedZone = CKRecordZone.ID(zoneName: zoneName, ownerName: "_ownerRecord123")
        let expected = CKConstants.recordID(for: memberID, in: expectedZone)
        #expect(plan.recordName == expected.recordName)
        #expect(plan.recordName == memberID.uuidString)
        #expect(plan.zoneName == zoneName)
        #expect(plan.zoneOwnerName == "_ownerRecord123")
        #expect(plan.routesToSharedEngine)
    }

    @Test func enqueuePlan_emptyOwnerName_fallsBackToCurrentUser() {
        // Espejo del fallback de enqueueSharedSave (ownerName vacío).
        let plan = GroupJoinReconcileLogic.enqueuePlan(
            memberID: UUID(),
            zoneName: "SplitGroup-X",
            zoneOwnerName: "",
            isOwner: false
        )
        #expect(plan.zoneOwnerName == CKCurrentUserDefaultName)
        #expect(plan.routesToSharedEngine)
    }

    @Test func enqueuePlan_owner_routesToPrivate() {
        let plan = GroupJoinReconcileLogic.enqueuePlan(
            memberID: UUID(),
            zoneName: "SplitGroup-Y",
            zoneOwnerName: "_ownerRecord123",
            isOwner: true
        )
        // El private engine opera sobre la zona propia (owner = current user).
        #expect(plan.zoneOwnerName == CKCurrentUserDefaultName)
        #expect(!plan.routesToSharedEngine)
    }
}
