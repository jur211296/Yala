//
//  GroupBackendInviteEntryLogicTests.swift
//  YalaTests
//
//  Pure-logic del flujo de entrada del invite backend (G4, §A1): nextStep (sign-in→consent→join),
//  routesToBackend (gate C2 flag-OFF byte-idéntico), resolveJoinDisplayName + shouldCorrectMemberDisplayName (R1).
//

import Foundation
import Testing

@testable import Yala

struct GroupBackendInviteEntryLogicTests {

    typealias L = GroupBackendInviteEntryLogic

    // MARK: - nextStep (flujo encadenado)

    @Test func nextStep_noSession_presentsSignIn() {
        #expect(L.nextStep(hasSession: false, isConsented: false) == .presentSignIn)
        #expect(L.nextStep(hasSession: false, isConsented: true) == .presentSignIn)
    }

    @Test func nextStep_sessionNoConsent_presentsConsent() {
        #expect(L.nextStep(hasSession: true, isConsented: false) == .presentConsent)
    }

    @Test func nextStep_sessionAndConsent_joins() {
        #expect(L.nextStep(hasSession: true, isConsented: true) == .join)
    }

    // MARK: - routesToBackend (C2 — con flag OFF NUNCA se toma la rama backend)

    @Test func routesToBackend_flagOff_isFalseEvenWithParsedInvite() {
        #expect(L.routesToBackend(flagEnabled: false, backendInviteParsed: true) == false)
    }

    @Test func routesToBackend_flagOn_requiresParsedInvite() {
        #expect(L.routesToBackend(flagEnabled: true, backendInviteParsed: true) == true)
        #expect(L.routesToBackend(flagEnabled: true, backendInviteParsed: false) == false)
    }

    // MARK: - resolveJoinDisplayName (R1: JAMÁS vacío)

    @Test func displayName_prefersIntentName() {
        #expect(L.resolveJoinDisplayName(
            intentName: "  Pia  ", profileName: "Alice", defaultName: "Usuario") == "Pia")
    }

    @Test func displayName_fallsBackToProfileWhenIntentEmpty() {
        #expect(L.resolveJoinDisplayName(
            intentName: nil, profileName: "  Alice ", defaultName: "Usuario") == "Alice")
        #expect(L.resolveJoinDisplayName(
            intentName: "   ", profileName: "Alice", defaultName: "Usuario") == "Alice")
    }

    @Test func displayName_fallsBackToDefaultWhenAllEmpty() {
        #expect(L.resolveJoinDisplayName(
            intentName: nil, profileName: "", defaultName: "Usuario") == "Usuario")
        #expect(L.resolveJoinDisplayName(
            intentName: "  ", profileName: "  ", defaultName: "Usuario") == "Usuario")
    }

    // MARK: - shouldCorrectMemberDisplayName (R1: corrección una vez, anti-pisado)

    @Test func correct_whenRealNameCapturedOverPlaceholder() {
        #expect(L.shouldCorrectMemberDisplayName(
            intentName: "Pia", currentMemberDisplayName: "Usuario", defaultName: "Usuario"))
        #expect(L.shouldCorrectMemberDisplayName(
            intentName: "Pia", currentMemberDisplayName: "", defaultName: "Usuario"))
    }

    @Test func correct_neverOverwritesManualRename() {
        #expect(!L.shouldCorrectMemberDisplayName(
            intentName: "Pia", currentMemberDisplayName: "Pia Renombrada", defaultName: "Usuario"))
    }

    @Test func correct_noopWhenIntentEmptyOrEqual() {
        #expect(!L.shouldCorrectMemberDisplayName(
            intentName: nil, currentMemberDisplayName: "Usuario", defaultName: "Usuario"))
        #expect(!L.shouldCorrectMemberDisplayName(
            intentName: "Pia", currentMemberDisplayName: "Pia", defaultName: "Usuario"))
    }
}
