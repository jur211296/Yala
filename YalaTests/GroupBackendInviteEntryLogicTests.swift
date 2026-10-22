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

    /// **Cambió de significado el 2026-09-05, y el cambio es el arreglo.** Con los defaults de la firma
    /// vieja esta llamada daba `.join`; con los de la nueva (`hasConfirmedInvite: false`) da la hoja. El
    /// default seguro es el que PIDE confirmación: quien llame sin decir nada no puede meter a nadie en un
    /// grupo por omisión.
    @Test func nextStep_sessionAndConsent_presentsSheetUntilConfirmed() {
        #expect(L.nextStep(hasSession: true, isConsented: true) == .presentInviteOnboarding)
        #expect(L.nextStep(hasSession: true, isConsented: true, hasConfirmedInvite: true) == .join)
    }

    // MARK: - nextStep con el fork de la invitación SIN CONFIRMAR (A2, paso 6)

    @Test func nextStep_unconfirmedInvite_presentsInviteOnboardingBeforeJoin() {
        // Sesión + consent listos pero la invitación sin confirmar → la hoja primero.
        #expect(L.nextStep(
            hasSession: true, isConsented: true,
            hasConfirmedInvite: false, canPresentOnboarding: true) == .presentInviteOnboarding)
    }

    @Test func nextStep_unconfirmedInvite_signInAndConsentStillComeFirst() {
        // El fork de la hoja NO adelanta a sign-in/consent (orden del flujo encadenado).
        #expect(L.nextStep(
            hasSession: false, isConsented: false,
            hasConfirmedInvite: false, canPresentOnboarding: true) == .presentSignIn)
        #expect(L.nextStep(
            hasSession: true, isConsented: false,
            hasConfirmedInvite: false, canPresentOnboarding: true) == .presentConsent)
    }

    @Test func nextStep_userActionFromOnboardingCTA_joinsWithoutRePresenting() {
        // El CTA del propio onboarding (source .userAction) JAMÁS re-presenta la vista.
        #expect(L.nextStep(
            hasSession: true, isConsented: true,
            hasConfirmedInvite: false, canPresentOnboarding: false) == .join)
    }

    /// **Sustituye a `nextStep_onboardingComplete_joinsDirect`, que documentaba el defecto.** Aquél fijaba
    /// que con el onboarding hecho el invitado se unía directo — o sea, que a quien ya tenía cuenta el
    /// enlace lo metía en el grupo sin enseñarle la hoja. Lo que hoy manda al join es haber confirmado ESTA
    /// invitación, y eso ya no depende de si la persona tenía cuenta: el término del alta salió de la
    /// firma, así que esa confusión no se puede volver a escribir ni por accidente.
    @Test func nextStep_confirmedInvite_joinsDirect() {
        #expect(L.nextStep(
            hasSession: true, isConsented: true,
            hasConfirmedInvite: true, canPresentOnboarding: true) == .join)
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
