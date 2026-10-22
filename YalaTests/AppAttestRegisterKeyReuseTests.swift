//
//  AppAttestRegisterKeyReuseTests.swift
//  YalaTests
//
//  Una key de App Attest por INSTALACIÓN, no una por intento fallido.
//
//  POR QUÉ ESTE FICHERO EXISTE. `runRegister` llamaba a `service.generateKey()` en CADA intento y solo
//  persistía el keyId tras un register EXITOSO ⇒ todo fallo intermedio —`fetchChallenge`, `attestKey`,
//  el `POST /v1/attest/register`— huerfanaba una key recién acuñada en el Secure Enclave. Con la
//  tormenta medida el 2026-07-31 en producción (~17 intentos en 3 s) eso son ~17 keys quemadas en tres
//  segundos, contra lo que dice explícitamente `DCAppAttestService.h`: «retry attestation again using
//  the same key and client data hash later to avoid unnecessarily generating new keys. Retrying with
//  the same inputs helps to preserve the risk metric for a given device».
//
//  POR QUÉ ES SOURCE-SCAN Y NO COMPORTAMIENTO. Lo que hay que pinnear es un ORDEN de efectos sobre
//  `DCAppAttestService.shared` y el Keychain del proceso: el singleton de DeviceCheck no es inyectable
//  y ejercitarlo de verdad llamaría al App Attest REAL (red, y en simulador ni siquiera está soportado).
//  El repo ya usa este molde donde el invariante es estructural — `AttestWiringTests`,
//  `HandoverGroupsWiringTests`, `GroupPullRescueParityTests`. La contrapartida de un escáner es que
//  puede pasar en verde sin comprobar nada, así que cada aserción de orden va precedida de la de
//  PRESENCIA del marcador que compara.
//

import Foundation
import Testing

@testable import Yala

@Suite("App Attest · la key del register se reusa, no se re-acuña por intento")
struct AppAttestRegisterKeyReuseTests {

    private static var clientSource: String {
        get throws {
            let url = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()  // YalaTests/
                .deletingLastPathComponent()  // repo root
                .appendingPathComponent("Yala/App/Services/AppAttestClient.swift")
            return try String(contentsOf: url, encoding: .utf8)
        }
    }

    /// Cuerpo de `runRegister`, de su firma hasta la siguiente declaración del fichero.
    private static func runRegisterBody() throws -> String {
        let source = try clientSource
        guard let start = source.range(of: "private func runRegister(") else {
            Issue.record("No se encontró `runRegister` en AppAttestClient.swift: el escáner está roto.")
            return ""
        }
        let rest = source[start.lowerBound...]
        guard let end = rest.range(of: "private func runAssert(") else {
            Issue.record("No se encontró el final de `runRegister`: el escáner está roto.")
            return String(rest)
        }
        return String(rest[..<end.lowerBound])
    }

    private func index(of needle: String, in body: String, _ what: String) -> String.Index? {
        guard let r = body.range(of: needle) else {
            Issue.record("`runRegister` ya no contiene \(what) (`\(needle)`).")
            return nil
        }
        return r.lowerBound
    }

    // MARK: - El orden que evita quemar keys

    @Test func consultaElSlotPendiente_antesDeAcunarUnaKeyNueva() throws {
        let body = try Self.runRegisterBody()
        guard
            let lee = index(
                of: "KeychainService.getString(forKey: Self.pendingKeyIdKeychainKey)", in: body,
                "la lectura del slot pendiente"),
            let acuna = index(of: "service.generateKey()", in: body, "la acuñación de la key")
        else { return }

        #expect(
            lee < acuna,
            """
            `runRegister` acuña una key ANTES de mirar si ya hay una del intento anterior. Eso es el \
            defecto original: cada fallo de red deja una key huérfana en el Secure Enclave.
            """)
    }

    @Test func persisteLaKey_antesDeAtestarla() throws {
        let body = try Self.runRegisterBody()
        guard
            let persiste = index(
                of: "KeychainService.setString(keyId, forKey: Self.pendingKeyIdKeychainKey)", in: body,
                "la persistencia del slot pendiente"),
            let atesta = index(of: "service.attestKey(", in: body, "la atestación")
        else { return }

        #expect(
            persiste < atesta,
            """
            La key se persiste DESPUÉS de `attestKey`. Si el intento falla ahí —o el proceso muere— la \
            key acuñada se pierde y el siguiente intento acuña otra: exactamente lo que `DCError.h` \
            pide no hacer («retry … using the same key … to preserve the risk metric»).
            """)
    }

    @Test func soloHayUnaAcunacionEnTodoElCliente() throws {
        let source = try Self.clientSource
        let veces = source.components(separatedBy: "service.generateKey()").count - 1
        #expect(
            veces == 1,
            """
            `service.generateKey()` aparece \(veces) veces en AppAttestClient.swift (se esperaba 1). \
            Una segunda acuñación fuera del camino guardado por el slot pendiente reabre el defecto.
            """)
    }

    @Test func elSlotPendienteSeLimpia_alCanjearLaKeyPorSesion() throws {
        let body = try Self.runRegisterBody()
        guard
            let registra = index(
                of: "KeychainService.setString(keyId, forKey: Self.keyIdKeychainKey)", in: body,
                "la promoción del keyId al slot definitivo"),
            let limpia = index(
                of: "KeychainService.delete(forKey: Self.pendingKeyIdKeychainKey)", in: body,
                "el borrado del slot pendiente")
        else { return }

        #expect(
            registra < limpia,
            """
            El slot pendiente se limpia ANTES de promover el keyId al definitivo. Si el proceso muere \
            entre las dos, la key queda acuñada y atestada pero sin dueño en ningún slot.
            """)
    }

    // MARK: - El descarte es ACOTADO (lo que no se puede simplificar)

    @Test func elDescarteDelPendiente_pasaPorLaLogicaDeRecuperacion() throws {
        let body = try Self.runRegisterBody()
        #expect(
            body.contains("AttestKeyRecoveryLogic.decide(assertError: error)"),
            """
            LOAD-BEARING. El `catch` de `runRegister` tiene que preguntar a `AttestKeyRecoveryLogic` \
            antes de descartar la key pendiente. Un descarte incondicional ahí quema una key en CADA \
            fallo de red o 5xx del gateway, que es literalmente el defecto que esta función arregla; y \
            duplicar aquí su tabla de `DCError` es como los dos criterios divergen.
            """)
    }

    /// Descartar la key definitiva y dejar viva la pendiente haría que el re-registro reintentase con
    /// la MISMA key que se acaba de declarar muerta (pueden coincidir si un register murió entre
    /// promover el keyId y limpiar el slot).
    @Test func descartarLaKey_lasDescartaLasDos() throws {
        let source = try Self.clientSource
        guard let start = source.range(of: "case .discardKeyAndRegister:"),
            let end = source[start.upperBound...].range(of: "return try await runRegister(")
        else {
            Issue.record("No se encontró la rama `.discardKeyAndRegister` de `performRefresh`.")
            return
        }
        let rama = String(source[start.upperBound..<end.lowerBound])

        #expect(rama.contains("KeychainService.delete(forKey: Self.keyIdKeychainKey)"))
        #expect(
            rama.contains("KeychainService.delete(forKey: Self.pendingKeyIdKeychainKey)"),
            """
            La rama que descarta la key del assert no borra el slot pendiente. Si ahí quedó la misma \
            key rancia, `runRegister` la reusaría y el re-registro fallaría igual, en bucle.
            """)
    }

    // MARK: - Los dos slots son distintos

    @Test func elSlotPendienteNoEsElDefinitivo() throws {
        let source = try Self.clientSource
        #expect(source.contains(#"keyIdKeychainKey = "appattest.keyId""#))
        #expect(
            source.contains(#"pendingKeyIdKeychainKey = "appattest.pendingKeyId""#),
            """
            Los dos slots tienen que ser claves distintas del Keychain. Guardar la key sin atestar en \
            `appattest.keyId` mandaría el siguiente refresh al ASSERT, que fallaría con \
            `DCErrorInvalidKey` y la descartaría — quemándola igual.
            """)
    }
}
