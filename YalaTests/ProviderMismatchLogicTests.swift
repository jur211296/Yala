//
//  ProviderMismatchLogicTests.swift
//  YalaTests
//
//  Tabla exhaustiva del guard R9 SUB-FIRST (Google Sign-In sesión 2, H4: GoTrue linkea
//  identidades con mismo email al MISMO sub ⇒ la señal es el SUB, jamás el provider a secas).
//

import Foundation
import Testing

@testable import Yala

@Suite("ProviderMismatchLogic · guard R9 sub-first")
struct ProviderMismatchLogicTests {

    // MARK: - Regla 1: accountExists == true ⇒ proceed SIEMPRE

    @Test func exists_sameHash_proceeds() {
        // Adopt normal: cuenta real del mismo humano.
        #expect(ProviderMismatchLogic.decide(
            accountExists: true, beaconLinked: true,
            beaconAccountHash: "hash-A", beaconProvider: "apple",
            sessionSubHash: "hash-A", sessionProvider: "apple"
        ) == .proceed)
    }

    @Test func exists_differentHash_proceeds_M1SecondaryEntryProtected() {
        // Caso M1: la invitada firma en el device del dueño — el faro (iCloud KV del DUEÑO)
        // trae hash/provider AJENOS. Un R9 aquí ROMPERÍA la entrada secundaria; la ruta la
        // decide CrossAccountEntryGuardLogic, no este guard.
        #expect(ProviderMismatchLogic.decide(
            accountExists: true, beaconLinked: true,
            beaconAccountHash: "hash-OWNER", beaconProvider: "apple",
            sessionSubHash: "hash-GUEST", sessionProvider: "google"
        ) == .proceed)
    }

    @Test func exists_differentProvider_sameSub_proceeds_H4IdentityLinking() {
        // H4: sign-in Google aterriza en el sub creado con Apple (identities linkeadas por
        // email verificado) — mismo hash, provider distinto ⇒ linking legítimo, jamás R9.
        #expect(ProviderMismatchLogic.decide(
            accountExists: true, beaconLinked: true,
            beaconAccountHash: "hash-A", beaconProvider: "apple",
            sessionSubHash: "hash-A", sessionProvider: "google"
        ) == .proceed)
    }

    // MARK: - Regla 2: sin faro ⇒ proceed (cae al .notFound existente)

    @Test func noBeacon_proceeds() {
        #expect(ProviderMismatchLogic.decide(
            accountExists: false, beaconLinked: false,
            beaconAccountHash: nil, beaconProvider: nil,
            sessionSubHash: "hash-A", sessionProvider: "google"
        ) == .proceed)
    }

    @Test func noBeacon_evenWithStaleFields_proceeds() {
        // linked=false manda aunque queden campos residuales (clear parcial improbable).
        #expect(ProviderMismatchLogic.decide(
            accountExists: false, beaconLinked: false,
            beaconAccountHash: "hash-X", beaconProvider: "apple",
            sessionSubHash: "hash-A", sessionProvider: "google"
        ) == .proceed)
    }

    // MARK: - Regla 3: hash igual ⇒ proceed (cuenta borrada server-side, faro stale)

    @Test func sameHash_accountMissing_proceeds_honestNotFound() {
        #expect(ProviderMismatchLogic.decide(
            accountExists: false, beaconLinked: true,
            beaconAccountHash: "hash-A", beaconProvider: "apple",
            sessionSubHash: "hash-A", sessionProvider: "apple"
        ) == .proceed)
    }

    @Test func sameHash_differentProvider_stillProceeds() {
        // El sub manda: misma cuenta (linking H4) sin fila server-side ⇒ .notFound honesto.
        #expect(ProviderMismatchLogic.decide(
            accountExists: false, beaconLinked: true,
            beaconAccountHash: "hash-A", beaconProvider: "apple",
            sessionSubHash: "hash-A", sessionProvider: "google"
        ) == .proceed)
    }

    // MARK: - Regla 4: mismo provider ⇒ proceed (hipótesis "método equivocado" muerta)

    @Test func sameProvider_differentHash_proceeds() {
        // Otro humano sin cuenta (o cuenta borrada): usó el MISMO método que el faro ⇒ no
        // hay "método equivocado" que sugerir.
        #expect(ProviderMismatchLogic.decide(
            accountExists: false, beaconLinked: true,
            beaconAccountHash: "hash-OWNER", beaconProvider: "google",
            sessionSubHash: "hash-B", sessionProvider: "google"
        ) == .proceed)
    }

    // MARK: - Regla 5: mismatch pleno

    @Test func mismatch_differentProvider_differentHash() {
        // exists=false + faro presente + provider distinto + hash distinto ⇒ R9.
        #expect(ProviderMismatchLogic.decide(
            accountExists: false, beaconLinked: true,
            beaconAccountHash: "hash-OWNER", beaconProvider: "apple",
            sessionSubHash: "hash-B", sessionProvider: "google"
        ) == .mismatch(knownProvider: "apple"))
    }

    @Test func mismatch_missingHash_stillMismatches() {
        // Faro sin hash (writeCloudAccountLinked con sub vacío): hash AUSENTE cuenta como
        // no-match — el provider distinto decide.
        #expect(ProviderMismatchLogic.decide(
            accountExists: false, beaconLinked: true,
            beaconAccountHash: nil, beaconProvider: "google",
            sessionSubHash: "hash-B", sessionProvider: "apple"
        ) == .mismatch(knownProvider: "google"))
    }

    @Test func mismatch_beaconProviderNil_carriesNilForGenericCopy() {
        // Faro linked sin provider (residual raro): mismatch requiere provider DISTINTO —
        // con nil no hay comparación posible... regla 4 no aplica (nil != session), cae a 5
        // y el copy será el genérico.
        #expect(ProviderMismatchLogic.decide(
            accountExists: false, beaconLinked: true,
            beaconAccountHash: "hash-OWNER", beaconProvider: nil,
            sessionSubHash: "hash-B", sessionProvider: "google"
        ) == .mismatch(knownProvider: nil))
    }

    // MARK: - Red post-claim (H4: linking legítimo — solo observabilidad)

    @Test func postClaim_nilProfileProvider_false() {
        #expect(!ProviderMismatchLogic.postClaimLinkedDifferentProvider(
            profileProvider: nil, sessionProvider: "google"))
    }

    @Test func postClaim_sameProvider_false() {
        #expect(!ProviderMismatchLogic.postClaimLinkedDifferentProvider(
            profileProvider: "google", sessionProvider: "google"))
    }

    @Test func postClaim_differentProvider_true() {
        #expect(ProviderMismatchLogic.postClaimLinkedDifferentProvider(
            profileProvider: "apple", sessionProvider: "google"))
    }

    // MARK: - Display name (copy del mismatch)

    @Test func displayName_knownProviders() {
        #expect(ProviderMismatchLogic.displayName(forProvider: "apple") == "Apple")
        #expect(ProviderMismatchLogic.displayName(forProvider: "google") == "Google")
    }

    @Test func displayName_unknownOrNil_isNil_genericCopy() {
        // Jamás interpolar un rawValue del wire en UI.
        #expect(ProviderMismatchLogic.displayName(forProvider: "facebook") == nil)
        #expect(ProviderMismatchLogic.displayName(forProvider: nil) == nil)
    }
}
