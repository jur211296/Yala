//
//  ProviderMismatchLogicTests.swift
//  YalaTests
//
//  Tabla exhaustiva del guard R9 SUB-FIRST (Google Sign-In sesión 2, H4: GoTrue linkea
//  identidades con mismo email al MISMO sub ⇒ la señal es el SUB, jamás el provider a secas).
//
//  Paso 6 del rediseño de sesiones (ADR 2026-09-09 §10): `.mismatch` lleva ahora sus DOS salidas.
//  Las cinco reglas no cambian; lo que se fija aquí además es qué método ofrece cada salida.
//

import Foundation
import Testing

@testable import Yala

@Suite("ProviderMismatchLogic · guard R9 sub-first")
struct ProviderMismatchLogicTests {

    private typealias Exits = ProviderMismatchLogic.Exits

    // MARK: - Regla 1: accountExists == true ⇒ proceed SIEMPRE

    @Test func exists_sameHash_proceeds() {
        // Adopt normal: cuenta real del mismo humano.
        #expect(ProviderMismatchLogic.decide(
            accountExists: true, beaconLinked: true,
            beaconAccountHash: "hash-A", beaconProvider: "apple",
            sessionSubHash: "hash-A", sessionProvider: .apple
        ) == .proceed)
    }

    @Test func exists_differentHash_proceeds_M1SecondaryEntryProtected() {
        // Caso M1: la invitada firma en el device del dueño — el faro (iCloud KV del DUEÑO)
        // trae hash/provider AJENOS. Un R9 aquí ROMPERÍA la entrada secundaria; la ruta la
        // decide CrossAccountEntryGuardLogic, no este guard.
        #expect(ProviderMismatchLogic.decide(
            accountExists: true, beaconLinked: true,
            beaconAccountHash: "hash-OWNER", beaconProvider: "apple",
            sessionSubHash: "hash-GUEST", sessionProvider: .google
        ) == .proceed)
    }

    @Test func exists_differentProvider_sameSub_proceeds_H4IdentityLinking() {
        // H4: sign-in Google aterriza en el sub creado con Apple (identities linkeadas por
        // email verificado) — mismo hash, provider distinto ⇒ linking legítimo, jamás R9.
        #expect(ProviderMismatchLogic.decide(
            accountExists: true, beaconLinked: true,
            beaconAccountHash: "hash-A", beaconProvider: "apple",
            sessionSubHash: "hash-A", sessionProvider: .google
        ) == .proceed)
    }

    // MARK: - Regla 2: sin faro ⇒ proceed (cae al .notFound existente)

    @Test func noBeacon_proceeds() {
        #expect(ProviderMismatchLogic.decide(
            accountExists: false, beaconLinked: false,
            beaconAccountHash: nil, beaconProvider: nil,
            sessionSubHash: "hash-A", sessionProvider: .google
        ) == .proceed)
    }

    @Test func noBeacon_evenWithStaleFields_proceeds() {
        // linked=false manda aunque queden campos residuales (clear parcial improbable).
        #expect(ProviderMismatchLogic.decide(
            accountExists: false, beaconLinked: false,
            beaconAccountHash: "hash-X", beaconProvider: "apple",
            sessionSubHash: "hash-A", sessionProvider: .google
        ) == .proceed)
    }

    // MARK: - Regla 3: hash igual ⇒ proceed (cuenta borrada server-side, faro stale)

    @Test func sameHash_accountMissing_proceeds_honestNotFound() {
        #expect(ProviderMismatchLogic.decide(
            accountExists: false, beaconLinked: true,
            beaconAccountHash: "hash-A", beaconProvider: "apple",
            sessionSubHash: "hash-A", sessionProvider: .apple
        ) == .proceed)
    }

    @Test func sameHash_differentProvider_stillProceeds() {
        // El sub manda: misma cuenta (linking H4) sin fila server-side ⇒ .notFound honesto.
        #expect(ProviderMismatchLogic.decide(
            accountExists: false, beaconLinked: true,
            beaconAccountHash: "hash-A", beaconProvider: "apple",
            sessionSubHash: "hash-A", sessionProvider: .google
        ) == .proceed)
    }

    // MARK: - Regla 4: mismo provider ⇒ proceed (hipótesis "método equivocado" muerta)

    @Test func sameProvider_differentHash_proceeds() {
        // Otro humano sin cuenta (o cuenta borrada): usó el MISMO método que el faro ⇒ no
        // hay "método equivocado" que sugerir.
        #expect(ProviderMismatchLogic.decide(
            accountExists: false, beaconLinked: true,
            beaconAccountHash: "hash-OWNER", beaconProvider: "google",
            sessionSubHash: "hash-B", sessionProvider: .google
        ) == .proceed)
    }

    // MARK: - Regla 5: mismatch pleno, con sus DOS salidas (paso 6)

    @Test("faro de Apple, firmó con Google ⇒ entrar con Apple o crear con Google")
    func mismatch_differentProvider_differentHash() {
        #expect(ProviderMismatchLogic.decide(
            accountExists: false, beaconLinked: true,
            beaconAccountHash: "hash-OWNER", beaconProvider: "apple",
            sessionSubHash: "hash-B", sessionProvider: .google
        ) == .mismatch(Exits(accountProvider: .apple, signInWith: .apple, createWith: .google)))
    }

    @Test("faro sin hash: el hash AUSENTE cuenta como no-match y deciden los métodos")
    func mismatch_missingHash_stillMismatches() {
        // Faro sin hash (writeCloudAccountLinked con sub vacío).
        #expect(ProviderMismatchLogic.decide(
            accountExists: false, beaconLinked: true,
            beaconAccountHash: nil, beaconProvider: "google",
            sessionSubHash: "hash-B", sessionProvider: .apple
        ) == .mismatch(Exits(accountProvider: .google, signInWith: .google, createWith: .apple)))
    }

    /// Faro linked sin provider (residual raro): la regla 4 no aplica (nil != sesión), cae a la 5. El copy
    /// será el GENÉRICO y el botón de entrar ofrece el OTRO método —la hipótesis de la regla es «usaste el
    /// otro»—, nunca el mismo que acaba de fallar.
    @Test("faro sin método ⇒ copy genérico, y «entrar» ofrece el OTRO método")
    func mismatch_beaconProviderNil_genericCopy_signInWithTheOther() {
        #expect(ProviderMismatchLogic.decide(
            accountExists: false, beaconLinked: true,
            beaconAccountHash: "hash-OWNER", beaconProvider: nil,
            sessionSubHash: "hash-B", sessionProvider: .google
        ) == .mismatch(Exits(accountProvider: nil, signInWith: .apple, createWith: .google)))
    }

    /// Un rawValue que esta versión no conoce se trata como «el faro no lo sabe»: jamás llega a la UI.
    @Test("faro con un método desconocido ⇒ igual que sin método, sin interpolar el wire")
    func mismatch_unknownBeaconProvider_isTreatedAsUnknown() {
        #expect(ProviderMismatchLogic.decide(
            accountExists: false, beaconLinked: true,
            beaconAccountHash: "hash-OWNER", beaconProvider: "microsoft",
            sessionSubHash: "hash-B", sessionProvider: .apple
        ) == .mismatch(Exits(accountProvider: nil, signInWith: .google, createWith: .apple)))
    }

    /// **El invariante del paso 6, sobre toda la tabla**: cuando sale mismatch, las dos salidas ofrecen
    /// métodos DISTINTOS (si no, «entrar» y «crear» serían el mismo botón con dos verbos), «crear» es SIEMPRE
    /// el método que la persona acaba de usar, y «entrar» es el del faro cuando el faro lo sabe.
    @Test("en TODA la tabla: salidas con métodos distintos, crear = el usado, entrar = el del faro")
    func mismatch_exitsInvariant_overTheWholeTable() {
        var mismatches = 0
        for beaconProvider in ["apple", "google", nil, "microsoft"] as [String?] {
            for session in [CloudSignInProvider.apple, .google] {
                for beaconHash in ["hash-OWNER", nil] as [String?] {
                    let verdict = ProviderMismatchLogic.decide(
                        accountExists: false, beaconLinked: true,
                        beaconAccountHash: beaconHash, beaconProvider: beaconProvider,
                        sessionSubHash: "hash-B", sessionProvider: session)
                    guard case .mismatch(let exits) = verdict else { continue }
                    mismatches += 1
                    #expect(exits.signInWith != exits.createWith, "\(beaconProvider ?? "nil")/\(session)")
                    #expect(exits.createWith == session)
                    if let known = beaconProvider.flatMap(CloudSignInProvider.init(rawValue:)) {
                        #expect(exits.accountProvider == known)
                        #expect(exits.signInWith == known)
                    } else {
                        #expect(exits.accountProvider == nil)
                    }
                }
            }
        }
        // Control: el barrido tiene que haber producido mismatches de verdad — con 0, las aserciones de
        // arriba se cumplirían sin mirar nada. Son 12: los 16 casos menos los 4 de «mismo método».
        #expect(mismatches == 12, "el barrido produjo \(mismatches) mismatches")
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
