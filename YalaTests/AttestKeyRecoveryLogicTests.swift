//
//  AttestKeyRecoveryLogicTests.swift
//  YalaTests
//
//  La decisión de descartar (o no) el keyId de App Attest cuando el assert falla.
//
//  El caso que dio origen a todo esto está medido en device: `Code=2` (`DCErrorInvalidInput`) con TODOS
//  los inputs bien formados (`keyIdLen=44 challengeLen=76 hashLen=32`), porque el keyId sobrevivió en el
//  Keychain a una reinstalación pero su key murió con la instalación anterior. Antes del fix eso no
//  disparaba re-registro y el device se quedaba sin attest —y por tanto sin Grupos, sin IA y sin proxy—
//  de forma PERMANENTE y silenciosa.
//
//  El test que de verdad protege algo es `serverUnavailable_propaga`: es la única barrera contra
//  «simplificar» este `catch` a uno genérico, que quemaría una key de App Attest en cada fallo de red
//  contra lo que dice explícitamente `DCError.h` (reintentar con la MISMA key preserva la risk metric
//  del device).
//

import DeviceCheck
import Foundation
import Testing

@testable import Yala

@Suite("App Attest · recuperación del keyId cuando el assert falla")
struct AttestKeyRecoveryLogicTests {

    private func dcError(_ code: Int) -> NSError {
        NSError(domain: DCErrorDomain, code: code, userInfo: nil)
    }

    // MARK: - Descartar: la key no sirve

    @Test func invalidInput_descartaYReregistra() {
        // El caso REAL medido en device el 2026-07-31.
        #expect(
            AttestKeyRecoveryLogic.decide(assertError: dcError(DCError.Code.invalidInput.rawValue))
                == .discardKeyAndRegister)
    }

    @Test func invalidKey_descartaYReregistra() {
        // El caso que documenta Apple para «generateAssertion con una key sin atestar».
        #expect(
            AttestKeyRecoveryLogic.decide(assertError: dcError(DCError.Code.invalidKey.rawValue))
                == .discardKeyAndRegister)
    }

    @Test func unknownKeyDelGateway_descartaYReregistra() {
        // El único camino que cubría el código ANTES del fix. Sigue cubierto, ahora en el mismo sitio.
        #expect(
            AttestKeyRecoveryLogic.decide(assertError: AppAttestError.unknownKey)
                == .discardKeyAndRegister)
    }

    // MARK: - Propagar: transitorio, se reintenta con la MISMA key

    @Test func serverUnavailable_propaga() {
        // LOAD-BEARING. `DCError.h`: «try the attestation again later using the SAME key … retrying with
        // the same inputs helps to preserve the risk metric for a given device». Descartar la key aquí
        // quemaría una key nueva en cada fallo de red.
        #expect(
            AttestKeyRecoveryLogic.decide(assertError: dcError(DCError.Code.serverUnavailable.rawValue))
                == .propagate,
            "serverUnavailable es transitorio: descartar la key aquí quema una key por cada fallo de red.")
    }

    @Test func unknownSystemFailure_propaga() {
        #expect(
            AttestKeyRecoveryLogic.decide(assertError: dcError(DCError.Code.unknownSystemFailure.rawValue))
                == .propagate)
    }

    @Test func featureUnsupported_propaga() {
        // No dice nada de la key: el device no soporta App Attest. Descartarla no arregla nada.
        #expect(
            AttestKeyRecoveryLogic.decide(assertError: dcError(DCError.Code.featureUnsupported.rawValue))
                == .propagate)
    }

    @Test func codigoDesconocidoDeUnIOSFuturo_propaga() {
        // Conservador a propósito: perder un refresh es recuperable, quemar keys no.
        #expect(AttestKeyRecoveryLogic.decide(assertError: dcError(9_999)) == .propagate)
    }

    @Test func errorAjenoADeviceCheck_propaga() {
        // El assert también hace red (`fetchChallenge`, `postJSON`): un fallo de transporte NO es un
        // veredicto sobre la key.
        #expect(
            AttestKeyRecoveryLogic.decide(assertError: URLError(.notConnectedToInternet)) == .propagate)
        #expect(
            AttestKeyRecoveryLogic.decide(assertError: AppAttestError.server("yala_rate_limited"))
                == .propagate)
    }

    // MARK: - El dominio importa, no solo el número

    @Test func mismoCodigoEnOtroDominio_propaga() {
        // Un `code == 2` de cualquier otro dominio no es `DCErrorInvalidInput`. Sin el guard de dominio
        // este test se pone rojo, y con él se documenta por qué el guard existe.
        #expect(
            AttestKeyRecoveryLogic.decide(
                assertError: NSError(domain: "com.yala.otro", code: 2, userInfo: nil)) == .propagate)
    }
}
