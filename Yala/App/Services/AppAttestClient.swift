//
//  AppAttestClient.swift
//  Yala
//
//  Cliente de App Attest: prueba que el request viene de la app legítima en un device genuino,
//  obtiene un token de sesión corto del gateway y lo refresca. El token se adjunta como Bearer en
//  cada llamada al proxy (ProxyClientFactory). Reemplaza la API key embebida en el cliente.
//
//  - actor: serializa el refresh (single-flight) → una sola assertion en vuelo (el counter de App
//    Attest debe crecer monotónicamente; varias en paralelo se rechazarían).
//  - Caché NEGATIVA (`AttestRefreshBackoffLogic`): el single-flight colapsa lo SIMULTÁNEO, no lo
//    SUCESIVO. Sin recordar el último fallo, los ~6 llamadores independientes del token producían la
//    tormenta medida en producción el 2026-07-31 — 17 `POST /v1/attest/challenge` en 3 segundos.
//  - Recuperación: si la key guardada ya no sirve, se descarta y se re-registra. Cubre las DOS formas,
//    que no son la misma (medido en device el 2026-07-31): el gateway no la reconoce (`unknownKey`) O
//    `generateAssertion` la rechaza LOCALMENTE porque la key murió con la instalación anterior mientras
//    su keyId sobrevivía en el Keychain. Quién decide: `AttestKeyRecoveryLogic`.
//  - Simulador / DEBUG: App Attest no corre en simulador → usa el bypass de dev (staging) si está
//    configurado el secret; si no, la IA queda deshabilitada (degradación, sin crash).
//

import CryptoKit
import DeviceCheck
import Foundation

enum AppAttestError: Error {
    case unavailable // App Attest no soportado y sin bypass configurado
    case unknownKey // el gateway no reconoce la key → re-registrar
    case server(String) // error tipado del gateway (error.type)
    case network(Error)
}

@MainActor
final class AppAttestClient {
    static let shared = AppAttestClient()
    private init() {}

    private static let keyIdKeychainKey = "appattest.keyId"
    /// Key ACUÑADA pero todavía no canjeada por sesión. Slot APARTE de `keyIdKeychainKey` a propósito:
    /// ese lo lee `performRefresh` para decidir assert-vs-register, así que dejar ahí una key sin atestar
    /// mandaría el próximo refresh al assert, fallaría con `DCErrorInvalidKey` y la descartaría —
    /// quemándola igual, que es justo lo que este slot evita. Ver `runRegister`.
    private static let pendingKeyIdKeychainKey = "appattest.pendingKeyId"
    /// Margen para refrescar antes de la expiración real del token.
    private static let refreshMargin: TimeInterval = 30

    private var cached: (token: String, expiry: Date)?
    private var refreshTask: Task<String, Error>?
    /// Caché NEGATIVA: el último fallo del refresh y su racha. La política (cuánto callar, cuándo volver
    /// a intentar) vive entera en `AttestRefreshBackoffLogic`; aquí solo se guarda el estado y el error.
    private var lastFailure: (error: Error, state: AttestRefreshBackoffLogic.FailureState)?

    // MARK: - API pública

    /// Token de sesión vigente (refresca si expiró).
    ///
    /// Dos mecanismos, y hacen falta LOS DOS: **single-flight** (`refreshTask`) colapsa las llamadas
    /// simultáneas en una sola assertion, y **caché negativa con backoff** evita que los llamadores que
    /// llegan DESPUÉS de un fallo vuelvan a intentarlo cada uno por su cuenta. Sin la segunda, los
    /// consumidores independientes del token —el proxy de IA, los tipos de cambio, el runtime de sync
    /// personal y los clients de Grupos y de push— más los reintentos de cada uno produjeron 17
    /// challenges en 3 s en producción. La política vive en `AttestRefreshBackoffLogic`.
    ///
    /// - Parameter ignoringBackoff: salta SOLO la supresión por backoff. Ni el token cacheado ni el
    ///   single-flight se saltan nunca: dos assertions en paralelo romperían la monotonía del counter de
    ///   App Attest. Lo usa el panel de diagnóstico, cuyo trabajo es precisamente intentarlo AHORA y
    ///   contar qué pasó — un error de hace 40 s ahí sería una respuesta falsa.
    func currentSessionToken(ignoringBackoff: Bool = false) async throws -> String {
        if let cached, cached.expiry > Date.now.addingTimeInterval(Self.refreshMargin) {
            return cached.token
        }
        if let refreshTask {
            return try await refreshTask.value
        }
        if !ignoringBackoff, let lastFailure,
            case .suppress(let retryAfter) = AttestRefreshBackoffLogic.decide(
                lastFailure: lastFailure.state, now: .now)
        {
            #if DEBUG
            print(
                "AppAttestClient: refresh suprimido, reintento en \(Int(retryAfter.rounded()))s "
                    + "(racha \(lastFailure.state.consecutiveCount))")
            #endif
            // Se re-lanza el error ORIGINAL y no uno nuevo: los consumidores clasifican por
            // `AppAttestError` (`AttestSyncGate.classify` → transient/terminal, banner y canario), y un
            // tipo nuevo cambiaría ese veredicto sin que nadie lo pidiera. Una llamada suprimida tiene
            // que ser indistinguible de la que la suprimió, salvo por no tocar la red.
            throw lastFailure.error
        }
        let previousFailure = lastFailure?.state
        let task = Task<String, Error> { try await self.performRefresh() }
        refreshTask = task
        do {
            let token = try await task.value
            refreshTask = nil
            lastFailure = nil
            return token
        } catch {
            refreshTask = nil
            lastFailure = (error, AttestRefreshBackoffLogic.record(previous: previousFailure, now: .now))
            throw error
        }
    }

    /// Calienta el token en background (tras el consent de IA / al launch si ya hay Pro), para que
    /// el primer uso no pague la latencia de attestación. Errores se tragan (best-effort).
    func ensureRegistered() async {
        do {
            _ = try await currentSessionToken()
        } catch {
            #if DEBUG
            print("AppAttestClient: ensureRegistered falló: \(error)")
            #endif
        }
    }

    // MARK: - Refresh

    private func performRefresh() async throws -> String {
        let service = DCAppAttestService.shared
        guard service.isSupported else {
            return try await devTokenOrThrow()
        }
        // `!isEmpty`: `KeychainService.getString` devuelve `String(data:encoding:)`, que para un ítem de
        // cero bytes da "" y NO nil ⇒ un `if let` pelado dejaría pasar un keyId vacío al assert.
        if let keyId = KeychainService.getString(forKey: Self.keyIdKeychainKey), !keyId.isEmpty {
            do {
                return try await runAssert(service: service, keyId: keyId)
            } catch {
                // UN solo punto de decisión, en `AttestKeyRecoveryLogic`: el fallo del assert puede venir
                // del gateway (`unknownKey`) o ser un `DCError` LOCAL de que el keyId ya no designa una
                // key de esta instalación (reinstall). Antes solo se cubría el primero y el segundo dejaba
                // el device sin attest PARA SIEMPRE — ver el docblock de esa lógica.
                switch AttestKeyRecoveryLogic.decide(assertError: error) {
                case .propagate:
                    throw error
                case .discardKeyAndRegister:
                    KeychainService.delete(forKey: Self.keyIdKeychainKey)
                    // Descartar la key las descarta LAS DOS. El slot pendiente puede traer la misma key
                    // rancia (un register que murió entre persistir el keyId y borrar el pendiente), y
                    // reusarla aquí sería reintentar con exactamente la que se acaba de declarar muerta.
                    KeychainService.delete(forKey: Self.pendingKeyIdKeychainKey)
                    // Canario FUERA de `#if DEBUG` a propósito: este fallo era invisible en producción
                    // (el `try?` de `AttestSessionProvider` más logs solo en Debug). Sin PII: el detalle
                    // es el código de error, no el keyId.
                    MetricsService.canary(
                        .attestKeyDiscardedAfterAssertFailure,
                        detail: "\((error as NSError).domain)#\((error as NSError).code)")
                    return try await runRegister(service: service)
                }
            }
        }
        return try await runRegister(service: service)
    }

    /// Acuña la key (o REUSA la del intento anterior), la atesta contra Apple y la canja por sesión.
    ///
    /// **La key se persiste ANTES de `attestKey`.** Antes se llamaba a `generateKey()` en CADA intento y
    /// el keyId solo se guardaba tras un register EXITOSO ⇒ todo fallo —de red, del gateway o de Apple—
    /// huerfanaba una key recién acuñada en el Secure Enclave, y Apple espera UNA key por instalación.
    /// `DCAppAttestService.h` lo dice explícitamente para `serverUnavailable`: «retry attestation again
    /// using the same key and client data hash later **to avoid unnecessarily generating new keys**.
    /// Retrying with the same inputs helps to preserve the risk metric for a given device».
    ///
    /// Persistir (y no solo recordar en memoria) es lo que hace que un kill del proceso en la ventana
    /// tampoco queme la key. Y el slot pendiente sobrevive a una reinstalación igual que el definitivo:
    /// esa key sí está muerta, pero cae en `.discardKeyAndRegister` y se cura en un intento.
    ///
    /// Lo que NO se reusa es el `clientDataHash`, y es a conciencia: Apple pide reintentar «with the
    /// same inputs», pero el challenge lo emite el gateway y es de un solo uso, así que replicarlo daría
    /// `yala_attest_invalid` («challenge inválido o expirado») en cada reintento. De las dos mitades de
    /// esa frase, la que protege la risk metric —y la única que el gateway nos deja cumplir— es la key.
    private func runRegister(service: DCAppAttestService) async throws -> String {
        // `!isEmpty` por el mismo motivo que en `performRefresh`: `getString` devuelve "" y NO nil para
        // un ítem de cero bytes, y un keyId vacío también es `DCErrorInvalidInput`.
        let keyId: String
        if let pending = KeychainService.getString(forKey: Self.pendingKeyIdKeychainKey), !pending.isEmpty
        {
            keyId = pending
        } else {
            keyId = try await service.generateKey()
            KeychainService.setString(keyId, forKey: Self.pendingKeyIdKeychainKey)
        }

        do {
            let challenge = try await fetchChallenge()
            let clientDataHash = Data(SHA256.hash(data: Data(challenge.utf8)))
            let attestation = try await service.attestKey(keyId, clientDataHash: clientDataHash)
            let storeKitJWS = await StoreKitManager.shared.fetchActiveTransactionJWS()
            let resp: SessionResponse = try await postJSON(
                "v1/attest/register",
                body: [
                    "keyId": keyId,
                    "attestation": attestation.base64EncodedString(),
                    "challenge": challenge,
                    "storeKitJWS": storeKitJWS,
                    "userJWT": await Self.cloudUserJWT(),
                ],
            )
            KeychainService.setString(keyId, forKey: Self.keyIdKeychainKey)
            KeychainService.delete(forKey: Self.pendingKeyIdKeychainKey)
            return cache(resp)
        } catch {
            // MISMA pregunta que en el assert —«¿este error dice que la key NO SIRVE?»— ⇒ MISMO punto de
            // decisión, reusado tal cual y sin tocarlo: duplicar aquí su tabla de `DCError` es cómo los
            // dos criterios divergen. Lo que hay que evitar es justo lo que esa lógica ya acota —
            // descartar ante `serverUnavailable`, ante un 5xx o ante un decode fallido quemaría una key
            // por cada fallo de red, que es el defecto que esta función arregla.
            //
            // Matiz frente a Apple, deliberado. `DCAppAttestService.h` dice «if your server fails to
            // verify the attestation object, discard the key identifier», pero el ÚNICO error tipado que
            // este endpoint devuelve es `yala_attest_invalid` (`gateway/src/attest/routes.ts:107` y
            // `:119`), y cubre dos casos donde una key NUEVA no ayuda: el challenge caducado
            // (transitorio — el siguiente intento trae otro) y la atestación rechazada por AAGUID,
            // permanente por diseño en un build firmado en desarrollo. Ahí descartar solo quema keys. Lo
            // que sí descarta es el veredicto LOCAL de DeviceCheck sobre la key
            // (`invalidInput`/`invalidKey`) — el caso de la key rancia que sobrevivió a una reinstalación.
            if AttestKeyRecoveryLogic.decide(assertError: error) == .discardKeyAndRegister {
                KeychainService.delete(forKey: Self.pendingKeyIdKeychainKey)
            }
            throw error
        }
    }

    private func runAssert(service: DCAppAttestService, keyId: String) async throws -> String {
        let challenge = try await fetchChallenge()
        let clientDataHash = Data(SHA256.hash(data: Data(challenge.utf8)))
        let assertion = try await service.generateAssertion(keyId, clientDataHash: clientDataHash)
        let storeKitJWS = await StoreKitManager.shared.fetchActiveTransactionJWS()
        let resp: SessionResponse = try await postJSON(
            "v1/attest/assert",
            body: [
                "keyId": keyId,
                "assertion": assertion.base64EncodedString(),
                "challenge": challenge,
                "storeKitJWS": storeKitJWS,
                "userJWT": await Self.cloudUserJWT(),
            ],
        )
        return cache(resp)
    }

    /// C-8: el JWT de la cuenta de nube, para que el gateway resuelva el tier también por CUENTA y
    /// no solo por la suscripción del Apple ID de este device.
    ///
    /// Sin esto, el device donde C-8 devuelve Pro (otro Apple ID, misma cuenta de Yala) tendría la
    /// UI de chat e insights desbloqueada y el proxy respondiéndole 403 `yala_pro_required`: la
    /// incoherencia más visible posible. `nil` sin sesión — el contrato del gateway lo trata como
    /// «solo device», byte-idéntico a antes.
    private static func cloudUserJWT() async -> String? {
        guard CloudBackendConfig.isConfigured, CloudAuthService.shared.hasSession else { return nil }
        return await CloudAuthService.shared.accessToken()
    }

    private func devTokenOrThrow() async throws -> String {
        #if DEBUG
        let secret = ProxyConfig.devSharedSecret
        guard !secret.isEmpty else { throw AppAttestError.unavailable }
        let resp: SessionResponse = try await postJSON(
            "v1/attest/dev",
            body: [:],
            headers: ["X-Yala-Dev-Secret": secret, "X-Yala-Dev-Tier": "pro"],
        )
        return cache(resp)
        #else
        throw AppAttestError.unavailable
        #endif
    }

    private func fetchChallenge() async throws -> String {
        let resp: ChallengeResponse = try await postJSON("v1/attest/challenge", body: [:])
        return resp.challenge
    }

    private func cache(_ resp: SessionResponse) -> String {
        cached = (resp.sessionToken, Date(timeIntervalSince1970: resp.expMs / 1000))
        return resp.sessionToken
    }

    // MARK: - Red

    private func postJSON<T: Decodable>(
        _ path: String,
        body: [String: String?],
        headers: [String: String] = [:],
    ) async throws -> T {
        var request = URLRequest(url: ProxyConfig.baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
        do {
            request.httpBody = try JSONEncoder().encode(body.compactMapValues { $0 })
        } catch {
            throw AppAttestError.server("encode")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AppAttestError.network(error)
        }

        guard let http = response as? HTTPURLResponse else { throw AppAttestError.unavailable }
        guard http.statusCode == 200 else {
            // Best-effort: leer el `error.type` del envelope OpenAI-compatible del gateway.
            let type = (try? JSONDecoder().decode(ErrorEnvelope.self, from: data))?.error.type
            if type == "yala_attest_unknown_key" { throw AppAttestError.unknownKey }
            throw AppAttestError.server(type ?? "http_\(http.statusCode)")
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw AppAttestError.server("decode")
        }
    }
}

// MARK: - Modelos de respuesta

private struct SessionResponse: Decodable {
    let sessionToken: String
    let expMs: Double
    let tier: String
}

private struct ChallengeResponse: Decodable {
    let challenge: String
}

private struct ErrorEnvelope: Decodable {
    struct Payload: Decodable {
        let type: String
        let message: String
    }
    let error: Payload
}
