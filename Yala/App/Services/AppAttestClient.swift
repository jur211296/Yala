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
//  - Techo de la espera (2026-10-19): un refresh en vuelo que no vuelve en 90 s se abandona y el siguiente llamador
//    arranca otro (`AttestSessionTokenLogic`). Sin él, una tarea colgada dejaba esperando para siempre a todo el que
//    pidiera token: la subida de «Activar la nube» se quedaba al 55 % hasta cerrar Yala. Y un 401 `yala_attest_required`
//    hace olvidar el token que viajó (`discardSessionToken(ifEqualTo:)`), para no reenviarlo hasta que caduque.
//  - Recuperación: si la key guardada ya no sirve, se descarta y se re-registra. Cubre las DOS formas,
//    que no son la misma (medido en device el 2026-07-31): el gateway no la reconoce (`unknownKey`) O
//    `generateAssertion` la rechaza LOCALMENTE porque la key murió con la instalación anterior mientras
//    su keyId sobrevivía en el Keychain. Quién decide: `AttestKeyRecoveryLogic`.
//  - Simulador / DEBUG: App Attest no corre en simulador → usa el bypass de dev (staging) si está
//    configurado el secret; si no, la IA queda deshabilitada (degradación, sin crash).
//  - Observación en producción: el canario `attestKeyDiscardedAfterAssertFailure` (en `performRefresh`,
//    FUERA de `#if DEBUG` a propósito) y el botón «refresh attest» de `CloudSyncDebugView`. **Aquí NO hay
//    un calentador al launch, y no es un olvido.** Lo hubo en la firma —`ensureRegistered()`, sin un solo
//    call-site desde que nació, borrada el 2026-07-31— y su docblock prometía un calentamiento que no
//    ocurría, así que la consola salió muda a quien la usó como punto de observación para diagnosticar el
//    401 de ese día. No se cableó porque no habría ahorrado latencia: `AppBootstrapper.loadExchangeRates`
//    (paso 2 del bootstrap, con `await`) ya pide token en el primer arranque de cada día UTC, así que el
//    caso dominante llega al primer uso con el token en `cached`; y con `SESSION_TTL_SECONDS = 15 * 60` en
//    el gateway, lo que quedaba —relanzar el mismo día y tocar IA dentro de esos 15 min— no compensa
//    gastar la escalera de `AttestRefreshBackoffLogic` en un llamador que no atiende a ningún usuario: un
//    warm-up que falla sube la racha y el toque REAL que llega después se encuentra la ventana ya
//    consumida. Si algún día hace falta de verdad, mídelo primero: desde el 2026-10-12 el Debug del scheme
//    `Yala` declara `appattest-environment = production` y puede atestar contra producción; un build con
//    entorno `development` contra producción da 401 SIEMPRE (ver `.claude/rules/gateway-attest.md`).
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
    /// Cuándo arrancó `refreshTask`, en reloj monotónico: lo lee el techo de la espera (`AttestSessionTokenLogic`).
    private var refreshStartedAt: ContinuousClock.Instant?
    /// En qué paso va el refresh en vuelo. Solo lo lee el canario del abandono: si una espera vence, dice DÓNDE se colgó
    /// (la causa del ticket `cloud-activation-stalls-without-uploading-until-relaunch` quedó inferida, no medida).
    private var refreshStage = "start"
    /// Qué refresh es el single-flight vigente. Una tarea abandonada que sigue corriendo ya no es la vigente, y sus pasos no
    /// pisan `refreshStage` (lo cazó la review: el canario de un segundo abandono habría dicho el paso de la primera).
    private var refreshGeneration = 0
    @TaskLocal private static var runningGeneration = 0

    /// Apunta el paso del refresh en vuelo, solo si quien lo dice es el vigente.
    private func noteStage(_ stage: String) {
        guard Self.runningGeneration == refreshGeneration else { return }
        refreshStage = stage
    }
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
        if let refreshTask, let refreshStartedAt {
            return try await awaitRefresh(refreshTask, startedAt: refreshStartedAt)
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
        refreshStage = "start"
        refreshGeneration += 1
        let generation = refreshGeneration
        let task = Task<String, Error> {
            try await Self.$runningGeneration.withValue(generation) { try await self.performRefresh() }
        }
        let startedAt = ContinuousClock.now
        refreshTask = task
        refreshStartedAt = startedAt
        do {
            let token = try await awaitRefresh(task, startedAt: startedAt)
            clearRefresh(task)
            lastFailure = nil
            return token
        } catch {
            clearRefresh(task)
            lastFailure = (error, AttestRefreshBackoffLogic.record(previous: previousFailure, now: .now))
            throw error
        }
    }

    /// El gateway acaba de rechazar con 401 `yala_attest_required` el token `rejected`. Si es el guardado, se olvida: el
    /// siguiente `currentSessionToken()` pide uno nuevo en vez de reenviar el rechazado hasta que caduque en el reloj del
    /// teléfono. Uno distinto se queda: ya es más nuevo. Decide `AttestSessionTokenLogic.discardsCachedToken`.
    ///
    /// No toca ni el single-flight ni la caché negativa: el reintento lo pone la cadencia de cada llamador.
    func discardSessionToken(ifEqualTo rejected: String?) {
        guard AttestSessionTokenLogic.discardsCachedToken(cached: cached?.token, rejected: rejected) else { return }
        cached = nil
        #if DEBUG
        print("AppAttestClient: token de sesión rechazado por el gateway, se pedirá otro")
        #endif
    }

    /// Espera a `task` como mucho lo que le quede del techo (`AttestSessionTokenLogic.refreshStallCeiling`, contado desde
    /// que arrancó). Vencido, la tarea se ABANDONA —deja de ser el single-flight y el siguiente llamador arranca otra— y se
    /// lanza un error de red: pasajero para todos los consumidores y sin sumar a la racha del teléfono (estar sin respuesta
    /// no habla del attest). El dueño apunta el fallo en la caché negativa, así que lo normal es que el refresh siguiente
    /// espere la primera ventana del backoff (2 s); si un tercer llamador llega justo entre el abandono y ese apunte, arranca
    /// antes. Aceptado: es una ventana de una vuelta del main actor.
    ///
    /// Se espera con una continuación y no con un `TaskGroup`: el grupo espera a TODOS sus hijos al cerrar, y el hijo que
    /// espera a la tarea colgada no responde a la cancelación (`Task.value` espera aunque cancelen a quien espera).
    private func awaitRefresh(_ task: Task<String, Error>, startedAt: ContinuousClock.Instant) async throws -> String {
        let remaining = AttestSessionTokenLogic.remainingRefreshWait(elapsed: ContinuousClock.now - startedAt)
        let outcome: Result<String, Error>? = await withCheckedContinuation { continuation in
            let once = AttestRefreshWaitResume(continuation)
            let timer = Task { @MainActor in
                do {
                    try await Task.sleep(for: remaining)
                } catch {
                    return
                }
                once.resume(nil)
            }
            Task { @MainActor in
                let result = await task.result
                timer.cancel()
                once.resume(result)
            }
        }
        guard let outcome else {
            if refreshTask == task {
                CloudSyncBreadcrumb.attestRefreshAbandoned(stage: refreshStage)
                MetricsService.canary(.attestRefreshAbandoned, detail: refreshStage)
                clearRefresh(task)
            }
            throw AppAttestError.network(URLError(.timedOut))
        }
        return try outcome.get()
    }

    /// Suelta el single-flight solo si sigue siendo `task`: una tarea abandonada que vuelve tarde no puede soltar la nueva.
    private func clearRefresh(_ task: Task<String, Error>) {
        guard refreshTask == task else { return }
        refreshTask = nil
        refreshStartedAt = nil
    }

    /// **¿Puede este teléfono conseguir un token de sesión?** Es la primera decisión de `performRefresh`, en un booleano:
    /// con App Attest (`isSupported`) se va por la key; sin él solo queda el bypass de dev, que existe en DEBUG y
    /// únicamente con `YALA_DEV_SHARED_SECRET` (`devTokenOrThrow`). Sin ninguno de los dos, `performRefresh` lanza
    /// `.unavailable` en cada intento y sin tocar la red: no es un fallo que cure un reintento.
    ///
    /// Lo leen la puerta de «Es mi primera vez» (`WelcomeNewOptionsGate`) y la card de migración de Ajustes
    /// (`StorageSettingsView.offersCloudMigrationEntry`), las dos vía `AttestSyncGate.shouldOfferCloudOnly`, para no
    /// ofrecer la nube a quien no podría subir nada. **Si cambia la primera decisión de `performRefresh`, esto cambia
    /// con ella**: la puerta y el cliente tienen que creer lo mismo. Un source-scan fija el cuerpo
    /// (`WelcomeNewChooserWiringTests`), porque en el host de test el lado `true` es inalcanzable.
    ///
    /// En el simulador vale `false` salvo con el secreto puesto: el simulador no tiene App Attest. Y con el secreto solo
    /// `Yala Dev` consigue token de verdad: con `Yala` el bypass apunta a producción, que no lo sirve (404), así que ahí
    /// dice `true` sin que nada suba — igual que cree el propio cliente, y solo en desarrollo.
    static var canObtainSessionToken: Bool {
        DCAppAttestService.shared.isSupported || !ProxyConfig.devSharedSecret.isEmpty
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
                noteStage("assert")
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
            noteStage("generateKey")
            keyId = try await service.generateKey()
            KeychainService.setString(keyId, forKey: Self.pendingKeyIdKeychainKey)
        }

        do {
            noteStage("register-challenge")
            let challenge = try await fetchChallenge()
            let clientDataHash = Data(SHA256.hash(data: Data(challenge.utf8)))
            noteStage("attestKey")
            let attestation = try await service.attestKey(keyId, clientDataHash: clientDataHash)
            noteStage("register-storekit")
            let storeKitJWS = await StoreKitManager.shared.fetchActiveTransactionJWS()
            noteStage("register-post")
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
            // permanente por diseño en un build cuyo entorno de attest no es el del gateway. Ahí descartar solo quema keys. Lo
            // que sí descarta es el veredicto LOCAL de DeviceCheck sobre la key
            // (`invalidInput`/`invalidKey`) — el caso de la key rancia que sobrevivió a una reinstalación.
            if AttestKeyRecoveryLogic.decide(assertError: error) == .discardKeyAndRegister {
                KeychainService.delete(forKey: Self.pendingKeyIdKeychainKey)
            }
            throw error
        }
    }

    private func runAssert(service: DCAppAttestService, keyId: String) async throws -> String {
        noteStage("assert-challenge")
        let challenge = try await fetchChallenge()
        let clientDataHash = Data(SHA256.hash(data: Data(challenge.utf8)))
        noteStage("generateAssertion")
        let assertion = try await service.generateAssertion(keyId, clientDataHash: clientDataHash)
        noteStage("assert-storekit")
        let storeKitJWS = await StoreKitManager.shared.fetchActiveTransactionJWS()
        noteStage("assert-post")
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

/// Reanuda la espera de `awaitRefresh` UNA vez: la gana el primero de los dos (la tarea o el techo).
@MainActor
private final class AttestRefreshWaitResume {
    private var continuation: CheckedContinuation<Result<String, Error>?, Never>?

    init(_ continuation: CheckedContinuation<Result<String, Error>?, Never>) {
        self.continuation = continuation
    }

    func resume(_ value: Result<String, Error>?) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(returning: value)
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
