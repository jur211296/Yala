//
//  CloudAccountClient.swift
//  Yala
//
//  Cliente del gate de identidad del Modo Nube (§f.1): `POST /account/claim` (reserva ATÓMICA de la
//  cuenta) + `GET /account/exists` (hint barato de encaminamiento). Corre INMEDIATAMENTE tras un
//  `signInWithIdToken` exitoso y ANTES de cualquier `save()` de onboarding — REGLA C4 (el consumidor
//  UI real es I14; aquí lo ejercita el panel DEBUG).
//
//  WIRE REAL (anclado a `gateway/src/sync/account.ts` + `gateway/test/account.goldens.test.ts`):
//   - Request:  `POST /account/claim`  body `{ "device_id": <string>, "provider": <string> }`.
//   - Response: `200 { "state": "created" | "existing_stable" | "claiming_in_progress", "profile"?: {…} }`.
//   - Auth: SOLO el JWT de usuario (`Authorization: Bearer <supabase jwt>`). `/account/*` NO exige App
//     Attest (precede al `/attest/bind` — el device aún no vinculó su keyId). Confirmado en el handler.
//   - Errores: envelope OpenAI-compatible `{ "error": { message, type, param, code } }` con status
//     (401 JWT ausente/inválido, 400 body inválido, 502 upstream). El panel los muestra EN CLARO.
//
//  Cero silencios: la red se traduce a un `ClaimOutcome` estructurado (estilo `PushOutcome`); NUNCA
//  lanza por red. Sin PII en logs (jamás el JWT ni el body de perfil).
//

import Foundation

/// Resultado ESTRUCTURADO de `POST /account/claim`. `detail` en los casos de error lleva `status + body`
/// del Worker (para el panel DEBUG) — nunca el JWT.
enum ClaimOutcome: Equatable {
    /// 200 OK con un `state` válido → decodificado a `ClaimState`.
    case success(AccountClaimDecision.ClaimState)
    /// 401: JWT ausente/inválido/expirado → re-firmar.
    case sessionExpired(detail: String)
    /// 403: autenticado pero prohibido (cuenta suspendida) — defensivo (`/account/*` no lo emite hoy).
    case accountUnavailable(detail: String)
    /// 5xx / red caída / respuesta no decodificable / status inesperado → reintentar.
    case transient(detail: String)
}

/// Resultado de `GET /account/exists`.
enum ExistsOutcome: Equatable {
    case exists(Bool)
    case sessionExpired(detail: String)
    case transient(detail: String)
}

/// Resultado ESTRUCTURADO de `POST /account/delete` (G5-D1 — borrado GDPR del corpus personal). Solo
/// interesa éxito/no-éxito: los counts por tabla del RPC NO se consumen client-side (la cuenta muere).
/// NUNCA lanza — traduce todo a este enum (estilo `ClaimOutcome`).
enum DeleteOutcome: Equatable {
    /// 200 OK → el HARD DELETE server-side se aplicó.
    case success
    /// 401: JWT o token de attest ausente/inválido/expirado → la sesión no está viva → re-firmar.
    case sessionExpired(detail: String)
    /// 5xx / red caída / 400 yala_* / respuesta no-HTTP → reintentable (los teardowns son idempotentes).
    case transient(detail: String)
}

/// Resultado ESTRUCTURADO de `POST /account/siwa/exchange` (B1, 5.1.1(v)). El `refreshToken` es el de
/// APPLE (no el de Supabase) — el Worker es stateless y lo devuelve para custodia en el Keychain del
/// cliente. NUNCA lanza; el token JAMÁS aparece en `detail` (los errores traen solo el envelope del Worker).
enum SiwaExchangeOutcome: Equatable {
    /// 200 `{ refresh_token }` → custodiar el PAR (token, appleUserID) en el Keychain.
    case success(refreshToken: String)
    /// 401: JWT ausente/inválido/expirado.
    case sessionExpired(detail: String)
    /// 5xx / 503 no-configurado / 400 shape / red caída / respuesta no decodificable → best-effort, sin token.
    case transient(detail: String)
}

/// Resultado ESTRUCTURADO de `POST /account/siwa/revoke` (B1, 5.1.1(v)). Best-effort por contrato: el
/// borrado de cuenta JAMÁS se bloquea por un fallo aquí.
enum SiwaRevokeOutcome: Equatable {
    /// 200 `{ revoked: true }` → limpiar el PAR del Keychain.
    case success
    case sessionExpired(detail: String)
    case transient(detail: String)
}

/// Resultado ESTRUCTURADO de `POST /account/migration` (I10-wiring w6, cutover §g.4). `ok:true` → `.ok`;
/// `ok:false` con `reason=='other_leader'` → `.otherLeader` (el líder fue usurpado — el runner corta
/// retomable y converge a follower); cualquier otro `ok:false` → `.rejected(reason)`.
enum MigrationProgressOutcome: Equatable {
    /// 200 `{ok:true}` → el avance se aplicó (idempotente).
    case ok
    /// 200 `{ok:false, reason:'other_leader'}` → otro device lidera → cortar retomable → follower.
    case otherLeader
    /// 200 `{ok:false, reason:…}` distinto (no_profile / not_in_progress / bad_action) → stop retomable.
    case rejected(reason: String)
    /// 401: JWT ausente/inválido/expirado → re-firmar.
    case sessionExpired(detail: String)
    /// 5xx / red caída / respuesta no decodificable / status inesperado → reintentar.
    case transient(detail: String)
}

@MainActor
final class CloudAccountClient {

    private let baseURL: URL
    private let urlSession: SyncHTTPSession
    private let attestProvider: @MainActor () async -> String?

    /// - Parameters:
    ///   - baseURL: gateway (default `ProxyConfig.baseURL`, per-scheme).
    ///   - urlSession: inyectable para tests (reusa `SyncHTTPSession` del push client).
    ///   - attestProvider: token de sesión de App Attest. Default `{ nil }` ⇒ claim/exists/migration/
    ///     siwaExchange NO envían attest (asimetría deliberada — el gate de cuenta y el sign-in preceden
    ///     al `/attest/bind`). Lo adjuntan `deleteAccount` (G5-D1) y `siwaRevoke` (B1) — ambos pasos del
    ///     mismo flujo destructivo (`requireUserAndAttest`, molde `/groups/rpc`); en producción se
    ///     inyecta `{ try? await AppAttestClient.shared.currentSessionToken() }`.
    init(
        baseURL: URL = ProxyConfig.baseURL,
        urlSession: SyncHTTPSession = URLSession.shared,
        attestProvider: @escaping @MainActor () async -> String? = { nil }
    ) {
        self.baseURL = baseURL
        self.urlSession = urlSession
        self.attestProvider = attestProvider
    }

    // MARK: - Decoder puro (testeable sin red)

    /// Mapea el `state` del wire (§f.1) a `AccountClaimDecision.ClaimState`. `nil` = string desconocido.
    static func decodeState(_ raw: String) -> AccountClaimDecision.ClaimState? {
        switch raw {
        case "created": return .created
        case "existing_stable": return .existingStable
        case "claiming_in_progress": return .claimingInProgress
        default: return nil
        }
    }

    private struct ClaimResponse: Decodable {
        let state: String?
        /// ADITIVO (Google Sign-In sesión 2): perfil devuelto en `existing_stable`. Solo se
        /// consume `provider` (red post-claim sub-first — breadcrumb, jamás alerta). `ClaimOutcome`
        /// NO cambia de shape.
        let profile: ClaimProfile?
    }

    private struct ClaimProfile: Decodable {
        let provider: String?
    }

    private struct ExistsResponse: Decodable {
        let exists: Bool
    }

    private struct MigrationResponse: Decodable {
        let ok: Bool?
        let reason: String?
    }

    // MARK: - POST /account/claim

    /// Reserva atómica de la cuenta. `provider` = "apple" para Sign in with Apple. `migration=true`
    /// arma la reserva de LÍDER (`migration_in_progress` + heartbeat) ATÓMICAMENTE en el INSERT del RPC
    /// (§g.1) — SOLO la rama de migración lo pasa; born-cloud/exists usan `false` (default). NO envía
    /// header de attest (el gate de cuenta no lo exige). NUNCA lanza — traduce todo a `ClaimOutcome`.
    func claim(jwt: String, deviceID: String, provider: String, migration: Bool = false) async -> ClaimOutcome {
        var request = URLRequest(url: baseURL.appendingPathComponent("account/claim"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        do {
            request.httpBody = try JSONSerialization.data(
                withJSONObject: ["device_id": deviceID, "provider": provider, "migration": migration]
            )
        } catch {
            return .transient(detail: "encode failed")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            return .transient(detail: "network: \(error.localizedDescription)")
        }
        guard let http = response as? HTTPURLResponse else {
            return .transient(detail: "non-HTTP response")
        }

        switch http.statusCode {
        case 200:
            guard
                let decoded = try? JSONDecoder().decode(ClaimResponse.self, from: data),
                let rawState = decoded.state,
                let state = Self.decodeState(rawState)
            else {
                return .transient(detail: "HTTP 200 undecodable: \(Self.bodyString(data))")
            }
            // Red post-claim SUB-FIRST (sesión 2, H4): post-claim el sub es EL MISMO por
            // construcción (claim JWT-scoped) ⇒ un `profile.provider` distinto es identity-linking
            // LEGÍTIMO de GoTrue — solo breadcrumb (sin PII), JAMÁS alerta ni canario.
            if let profileProvider = decoded.profile?.provider,
               ProviderMismatchLogic.postClaimLinkedDifferentProvider(
                   profileProvider: profileProvider, sessionProvider: provider) {
                CloudSyncBreadcrumb.claimProfileProviderDiffers(profileProvider: profileProvider)
            }
            return .success(state)
        case 401:
            return .sessionExpired(detail: "HTTP 401: \(Self.bodyString(data))")
        case 403:
            return .accountUnavailable(detail: "HTTP 403: \(Self.bodyString(data))")
        default:
            return .transient(detail: "HTTP \(http.statusCode): \(Self.bodyString(data))")
        }
    }

    // MARK: - GET /account/exists

    /// Hint de encaminamiento barato (§f.1) — NO la garantía anti-doble-siembra (esa la da `claim`).
    func exists(jwt: String) async -> ExistsOutcome {
        var request = URLRequest(url: baseURL.appendingPathComponent("account/exists"))
        request.httpMethod = "GET"
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            return .transient(detail: "network: \(error.localizedDescription)")
        }
        guard let http = response as? HTTPURLResponse else {
            return .transient(detail: "non-HTTP response")
        }
        switch http.statusCode {
        case 200:
            guard let decoded = try? JSONDecoder().decode(ExistsResponse.self, from: data) else {
                return .transient(detail: "HTTP 200 undecodable")
            }
            return .exists(decoded.exists)
        case 401:
            return .sessionExpired(detail: "HTTP 401: \(Self.bodyString(data))")
        default:
            return .transient(detail: "HTTP \(http.statusCode): \(Self.bodyString(data))")
        }
    }

    // MARK: - POST /account/migration

    /// Avance de la migración (§g.4) y de la REVERSA (§h, I11-3). `action` = `"cutover"` (estampa
    /// `migrated_at`) / `"complete"` (`migration_in_progress=false`) / `"reverse_claim"` /
    /// `"reverse_freeze"` / `"reverse_complete"` / `"reverse_abort"`. Guards líder/lease SERVER-side
    /// (toda la semántica vive en el RPC `migration_progress`; este cliente es genérico en el action).
    /// NUNCA lanza — traduce a `MigrationProgressOutcome`. `other_leader` = este device fue usurpado
    /// (lease-takeover).
    func migrationProgress(jwt: String, deviceID: String, action: String) async -> MigrationProgressOutcome {
        var request = URLRequest(url: baseURL.appendingPathComponent("account/migration"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        do {
            request.httpBody = try JSONSerialization.data(
                withJSONObject: ["device_id": deviceID, "action": action]
            )
        } catch {
            return .transient(detail: "encode failed")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            return .transient(detail: "network: \(error.localizedDescription)")
        }
        guard let http = response as? HTTPURLResponse else {
            return .transient(detail: "non-HTTP response")
        }
        switch http.statusCode {
        case 200:
            guard let decoded = try? JSONDecoder().decode(MigrationResponse.self, from: data),
                  let ok = decoded.ok else {
                return .transient(detail: "HTTP 200 undecodable: \(Self.bodyString(data))")
            }
            if ok { return .ok }
            let reason = decoded.reason ?? "unknown"
            return reason == "other_leader" ? .otherLeader : .rejected(reason: reason)
        case 401:
            return .sessionExpired(detail: "HTTP 401: \(Self.bodyString(data))")
        default:
            return .transient(detail: "HTTP \(http.statusCode): \(Self.bodyString(data))")
        }
    }

    // MARK: - POST /account/delete (G5-D1)

    /// `POST /account/delete` — HARD DELETE del corpus personal server-side (`delete_personal_account`,
    /// GDPR). ASIMETRÍA DELIBERADA con el resto de `/account/*`: esta ruta EXIGE App Attest
    /// (`requireUserAndAttest`, molde de `/groups/rpc`) por ser la operación más destructiva del canal —
    /// de ahí el header `X-Yala-Attest-Session` que los hermanos (claim/exists/migration) NO envían. Body
    /// vacío (`{}`; el RPC no toma args, usa `auth.uid()`). NUNCA lanza — traduce a `DeleteOutcome`.
    func deleteAccount(jwt: String) async -> DeleteOutcome {
        var request = URLRequest(url: baseURL.appendingPathComponent("account/delete"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        if let attest = await attestProvider(), !attest.isEmpty {
            request.setValue("Bearer \(attest)", forHTTPHeaderField: "X-Yala-Attest-Session")
        }
        request.httpBody = Data("{}".utf8)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            return .transient(detail: "network: \(error.localizedDescription)")
        }
        guard let http = response as? HTTPURLResponse else {
            return .transient(detail: "non-HTTP response")
        }
        switch http.statusCode {
        case 200:
            return .success
        case 401:
            return .sessionExpired(detail: "HTTP 401: \(Self.bodyString(data))")
        default:
            // 400 yala_* (auth.uid null defensivo) / 502 upstream / cualquier otro → reintentable.
            return .transient(detail: "HTTP \(http.statusCode): \(Self.bodyString(data))")
        }
    }

    // MARK: - POST /account/siwa/exchange (B1)

    /// Canje del `authorization_code` de Apple → refresh token de Apple, vía el Worker (que firma el
    /// `client_secret` con la .p8 — jamás client-side). SIN attest (como claim/exists/migration: el
    /// sign-in PRECEDE al `/attest/bind`). Corre best-effort en el hook post-sign-in — NUNCA lanza.
    /// El refresh token devuelto no se loguea (solo viaja al Keychain).
    func siwaExchange(jwt: String, authorizationCode: String) async -> SiwaExchangeOutcome {
        var request = URLRequest(url: baseURL.appendingPathComponent("account/siwa/exchange"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        do {
            request.httpBody = try JSONSerialization.data(
                withJSONObject: ["authorization_code": authorizationCode]
            )
        } catch {
            return .transient(detail: "encode failed")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            return .transient(detail: "network: \(error.localizedDescription)")
        }
        guard let http = response as? HTTPURLResponse else {
            return .transient(detail: "non-HTTP response")
        }
        switch http.statusCode {
        case 200:
            guard
                let decoded = try? JSONDecoder().decode(SiwaExchangeResponse.self, from: data),
                let token = decoded.refresh_token, !token.isEmpty
            else {
                // NO volcar el body de un 200 (portaría el token si el shape cambió): solo el hecho.
                return .transient(detail: "HTTP 200 undecodable (body omitido — puede portar token)")
            }
            return .success(refreshToken: token)
        case 401:
            return .sessionExpired(detail: "HTTP 401: \(Self.bodyString(data))")
        default:
            // 503 yala_siwa_not_configured / 400 shape / 502 upstream Apple → best-effort, sin token.
            return .transient(detail: "HTTP \(http.statusCode): \(Self.bodyString(data))")
        }
    }

    private struct SiwaExchangeResponse: Decodable {
        let refresh_token: String?
    }

    // MARK: - POST /account/siwa/revoke (B1)

    /// Revocación 5.1.1(v) del refresh token de Apple — paso 4a del borrado de cuenta. CON attest
    /// (`requireUserAndAttest`, coherencia con `/account/delete`: mismo flujo destructivo), de ahí el
    /// header `X-Yala-Attest-Session` vía el `attestProvider` del init. NUNCA lanza.
    func siwaRevoke(jwt: String, refreshToken: String) async -> SiwaRevokeOutcome {
        var request = URLRequest(url: baseURL.appendingPathComponent("account/siwa/revoke"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        if let attest = await attestProvider(), !attest.isEmpty {
            request.setValue("Bearer \(attest)", forHTTPHeaderField: "X-Yala-Attest-Session")
        }
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: ["refresh_token": refreshToken])
        } catch {
            return .transient(detail: "encode failed")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            return .transient(detail: "network: \(error.localizedDescription)")
        }
        guard let http = response as? HTTPURLResponse else {
            return .transient(detail: "non-HTTP response")
        }
        switch http.statusCode {
        case 200:
            return .success
        case 401:
            return .sessionExpired(detail: "HTTP 401: \(Self.bodyString(data))")
        default:
            return .transient(detail: "HTTP \(http.statusCode): \(Self.bodyString(data))")
        }
    }

    // MARK: - Helpers

    /// Cuerpo como string acotado para diagnóstico del panel (el body de error del Worker es el envelope
    /// `{error:{type,message}}`, sin PII). Se recorta para no volcar payloads grandes.
    private static func bodyString(_ data: Data) -> String {
        let s = String(data: data, encoding: .utf8) ?? "<non-utf8>"
        return s.count > 300 ? String(s.prefix(300)) + "…" : s
    }
}
