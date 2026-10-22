//
//  BeaconOrphanLogicTests.swift
//  YalaTests
//
//  Paso 6 del rediseño de sesiones: ¿cuándo PRUEBA una respuesta de [I] que la cuenta del faro de
//  iCloud-KV ya no existe? Limpiar el faro es irreversible y cross-device, así que la tabla se fija por
//  las dos caras: lo que prueba, y —con el mismo peso— lo que parece prueba y no lo es.
//

import Foundation
import Testing

@testable import Yala

@Suite("Paso 6 · el faro huérfano solo se limpia con PRUEBA")
struct BeaconOrphanLogicTests {

    private func proof(
        exists: Bool = false,
        linked: Bool = true,
        beaconHash: String? = "hash-VIEJO",
        beaconProvider: String? = "apple",
        sessionHash: String = "hash-NUEVO",
        sessionProvider: CloudSignInProvider? = .apple
    ) -> BeaconOrphanLogic.Proof? {
        BeaconOrphanLogic.proof(
            accountExists: exists,
            beaconLinked: linked,
            beaconAccountHash: beaconHash,
            beaconProvider: beaconProvider,
            sessionSubHash: sessionHash,
            sessionProvider: sessionProvider)
    }

    // MARK: - Lo que SÍ prueba

    @Test("el faro nombra ESTA identidad y el backend dice que no tiene cuenta ⇒ prueba 1")
    func sameAccount() {
        #expect(proof(beaconHash: "hash-A", beaconProvider: "google",
                      sessionHash: "hash-A", sessionProvider: .google) == .sameAccount)
    }

    /// **El caso que motiva la decisión**: el fresh start borró `auth.users`, así que volver a firmar con
    /// Apple da OTRO uuid y el hash del faro no casa nunca. Lo que prueba es el método: SIWA solo firma con
    /// el Apple ID del teléfono, que es el mismo cuyo iCloud-KV guarda el faro.
    @Test("fresh start: faro de Apple + sesión de Apple + no existe ⇒ prueba 2, aunque el hash no case")
    func appleIdentityHasNoAccount() {
        #expect(proof(beaconHash: "hash-VIEJO", beaconProvider: "apple",
                      sessionHash: "hash-NUEVO", sessionProvider: .apple) == .appleIdentityHasNoAccount)
    }

    @Test("faro de Apple SIN hash + sesión de Apple ⇒ también prueba 2")
    func appleWithoutBeaconHash() {
        #expect(proof(beaconHash: nil, beaconProvider: "apple", sessionProvider: .apple)
                == .appleIdentityHasNoAccount)
    }

    // MARK: - Lo que parece prueba y NO lo es

    /// La persona puede haber firmado con OTRA cuenta de Google, y la del faro seguir viva: limpiarlo le
    /// quitaría el encaminamiento a una cuenta que existe.
    @Test("Google con otro hash NO prueba nada")
    func googleWithAnotherHash_isNotProof() {
        #expect(proof(beaconHash: "hash-VIEJO", beaconProvider: "google",
                      sessionHash: "hash-NUEVO", sessionProvider: .google) == nil)
    }

    @Test("faro de Apple pero firmó con Google ⇒ la identidad Apple no se consultó: no prueba")
    func appleBeacon_googleSession_isNotProof() {
        #expect(proof(beaconProvider: "apple", sessionProvider: .google) == nil)
    }

    @Test("faro de Google pero firmó con Apple ⇒ no prueba")
    func googleBeacon_appleSession_isNotProof() {
        #expect(proof(beaconProvider: "google", sessionProvider: .apple) == nil)
    }

    @Test("método de sesión desconocido ⇒ solo vale la prueba 1")
    func unknownSessionProvider_onlySameAccountCounts() {
        #expect(proof(beaconProvider: "apple", sessionProvider: nil) == nil)
        #expect(proof(beaconHash: "hash-A", beaconProvider: "apple",
                      sessionHash: "hash-A", sessionProvider: nil) == .sameAccount)
    }

    @Test("dos hashes VACÍOS no son «la misma cuenta»")
    func emptyHashes_areNotTheSameAccount() {
        #expect(proof(beaconHash: "", beaconProvider: "google", sessionHash: "", sessionProvider: .google) == nil)
    }

    // MARK: - Los dos guards de entrada, con su control

    /// Cada caso lleva su control positivo: el MISMO input con el guard levantado sí prueba. Sin eso, un
    /// `nil` constante pasaría estos tests.
    @Test("la cuenta EXISTE ⇒ jamás, aunque todo lo demás case")
    func accountExists_neverProves() {
        #expect(proof(exists: true, beaconHash: "hash-A", sessionHash: "hash-A") == nil)
        #expect(proof(exists: false, beaconHash: "hash-A", sessionHash: "hash-A") == .sameAccount)
    }

    @Test("sin faro no hay nada que limpiar")
    func noBeacon_nothingToClear() {
        #expect(proof(linked: false, beaconHash: "hash-A", sessionHash: "hash-A") == nil)
        #expect(proof(linked: true, beaconHash: "hash-A", sessionHash: "hash-A") == .sameAccount)
    }
}
