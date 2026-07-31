//
//  AttestKeyRecoveryLogic.swift
//  Yala
//
//  Qué hacer cuando el ASSERT de App Attest falla: ¿el keyId guardado ya no sirve (bórralo y
//  re-registra) o es transitorio (propaga y reintenta luego con la MISMA key)?
//
//  POR QUÉ EXISTE, medido en device el 2026-07-31. `AppAttestClient` guardaba el keyId en el Keychain
//  y solo re-registraba al recibir `AppAttestError.unknownKey`, que se lanza EXCLUSIVAMENTE al leer una
//  respuesta del gateway. Pero la key de App Attest vive en el Secure Enclave atada a la INSTALACIÓN de
//  la app, mientras el string del keyId SOBREVIVE en el Keychain al borrado de la app. ⇒ tras reinstalar,
//  `generateAssertion` falla con un `DCError` LOCAL —nunca llega al servidor, así que nunca hay
//  `unknownKey`—, el error propaga, el `try?` de `AttestSessionProvider` lo vuelve `nil`, el request sale
//  sin `X-Yala-Attest-Session` y el gateway responde 401 `yala_attest_required`. Y no se cura JAMÁS: nada
//  borraba el keyId, así que cada intento releía el mismo y fallaba igual. Con `ENFORCE = "enforce"` en
//  producción eso deja al device sin Grupos, sin IA y sin proxy de tipos de cambio, en silencio.
//
//  Sonda del device (build Debug contra producción): `keyIdLen=44 challengeLen=76 hashLen=32` — todos los
//  inputs BIEN formados — y aun así `Error Domain=com.apple.devicecheck.error Code=2`, que el header del
//  SDK define como `DCErrorInvalidInput` («datos que no están correctamente formateados»). Es decir: el
//  keyId tiene forma válida pero no designa ninguna key de esta instalación.
//
//  POR QUÉ LA DECISIÓN ES ACOTADA Y NO UN `catch` GENÉRICO. `DCError.h` es explícito con
//  `DCErrorServerUnavailable`: «try the attestation again later using the SAME key and the same value for
//  the clientDataHash — retrying with the same inputs helps to preserve the risk metric for a given
//  device». Un `catch` que descartara la key ante cualquier error quemaría una key nueva en cada fallo de
//  red y degradaría esa métrica de riesgo. ⇒ solo se descarta cuando el error dice que la key NO SIRVE.
//

import DeviceCheck
import Foundation

enum AttestKeyRecoveryLogic {

    enum Decision: Equatable {
        /// El keyId no designa una key usable: borrarlo del Keychain y re-registrar UNA vez.
        case discardKeyAndRegister
        /// Fallo transitorio o ajeno a la key: propagar. Se reintenta más tarde con la MISMA key.
        case propagate
    }

    /// Decide a partir del error que lanzó el assert.
    ///
    /// `unknownKey` entra aquí para que exista UN SOLO punto de decisión: antes vivía como un `catch`
    /// aparte en `performRefresh` y esa separación es justo lo que dejó el camino local sin cubrir.
    static func decide(assertError: Error) -> Decision {
        if case AppAttestError.unknownKey = assertError { return .discardKeyAndRegister }

        let ns = assertError as NSError
        guard ns.domain == DCErrorDomain else { return .propagate }

        // Se compara por `rawValue` y no capturando `DCError` para no depender del puente
        // `_BridgedStoredNSError`: el error llega desde una API Objective-C y así el test puede
        // construir el caso con un `NSError` normal.
        switch DCError.Code(rawValue: ns.code) {
        case .invalidInput, .invalidKey:
            // `invalidKey` es el caso documentado de «generateAssertion con una key sin atestar».
            // `invalidInput` es el que devuelve DE VERDAD el device cuando el keyId no existe en esta
            // instalación (medido: inputs bien formados, Code=2).
            return .discardKeyAndRegister
        default:
            // `serverUnavailable` y `unknownSystemFailure` son transitorios; un `rawValue` que no casa
            // ningún caso conocido (un código nuevo de un iOS futuro) también propaga, que es la opción
            // conservadora: perder un refresh es recuperable, quemar keys no.
            return .propagate
        }
    }
}
