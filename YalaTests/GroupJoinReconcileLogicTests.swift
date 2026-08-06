//
//  GroupJoinReconcileLogicTests.swift
//  YalaTests
//
//  Pure-logic del reconciliador de join intents. Sin SwiftData/CloudKit-container
//

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

    // MARK: - decideBackend (G4-invites, tabla)

    @Test func decideBackend_flagOff_skipsRegardlessOfState() {
        // R5: prioridad sobre el flag — jamás cae al camino CloudKit.
        #expect(GroupJoinReconcileLogic.decideBackend(
            flagEnabled: false, hasSession: true, isConsented: true, memberLocallyPresent: false) == .skipFlagOff)
        #expect(GroupJoinReconcileLogic.decideBackend(
            flagEnabled: false, hasSession: false, isConsented: false, memberLocallyPresent: true) == .skipFlagOff)
    }

    @Test func decideBackend_memberPresent_correctsAndClears() {
        // Member local ya materializó (pull) → limpia intent (gana sobre sesión/consent).
        #expect(GroupJoinReconcileLogic.decideBackend(
            flagEnabled: true, hasSession: false, isConsented: false, memberLocallyPresent: true) == .correctAndClear)
    }

    @Test func decideBackend_noSession_presentsSignIn() {
        #expect(GroupJoinReconcileLogic.decideBackend(
            flagEnabled: true, hasSession: false, isConsented: false, memberLocallyPresent: false) == .presentSignIn)
    }

    @Test func decideBackend_sessionNoConsent_presentsConsent() {
        #expect(GroupJoinReconcileLogic.decideBackend(
            flagEnabled: true, hasSession: true, isConsented: false, memberLocallyPresent: false) == .presentConsent)
    }

    @Test func decideBackend_ready_joins() {
        #expect(GroupJoinReconcileLogic.decideBackend(
            flagEnabled: true, hasSession: true, isConsented: true, memberLocallyPresent: false) == .join)
    }

    @Test func shouldClearBackendIntent_onlyWhenMemberPresent() {
        #expect(GroupJoinReconcileLogic.shouldClearBackendIntent(memberLocallyPresent: true))
        #expect(!GroupJoinReconcileLogic.shouldClearBackendIntent(memberLocallyPresent: false))
    }

    // MARK: - backendMemberMatchesCurrentUser (S1: match sin isCurrentUser)

    @Test func backendMatch_byUserID_caseInsensitive() {
        #expect(GroupJoinReconcileLogic.backendMemberMatchesCurrentUser(
            memberUserID: "SUB-abc", memberKey: nil, currentUserID: "sub-ABC"))
    }

    @Test func backendMatch_fallbackByMemberKey() {
        // Anonimización server-side NULLea userID; memberKey (== sub para el propio member) aún matchea.
        #expect(GroupJoinReconcileLogic.backendMemberMatchesCurrentUser(
            memberUserID: nil, memberKey: "sub-abc", currentUserID: "sub-abc"))
    }

    @Test func backendMatch_noMatchOrNoSession_false() {
        #expect(!GroupJoinReconcileLogic.backendMemberMatchesCurrentUser(
            memberUserID: "sub-other", memberKey: "sub-other", currentUserID: "sub-abc"))
        #expect(!GroupJoinReconcileLogic.backendMemberMatchesCurrentUser(
            memberUserID: "sub-abc", memberKey: "sub-abc", currentUserID: nil))
        #expect(!GroupJoinReconcileLogic.backendMemberMatchesCurrentUser(
            memberUserID: "sub-abc", memberKey: "sub-abc", currentUserID: ""))
        #expect(!GroupJoinReconcileLogic.backendMemberMatchesCurrentUser(
            memberUserID: nil, memberKey: nil, currentUserID: "sub-abc"))
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

    // MARK: - enqueuePlan — RETIRADO en la Fase 3
    //
    // Las 3 celdas proyectaban lo que `SplitSyncManager.enqueueSave(modelID:group:)` iba a encolar
    // (recordName, zona, owner, engine privado vs compartido). Borrado el transporte, esa proyección no
    // tiene oráculo: describía un encolado que ya no ocurre. La función se fue con ellas — dejarla habría
    // sido una tabla verde de algo que el producto no hace, la familia de `AppAttestClient.ensureRegistered()`.

}
