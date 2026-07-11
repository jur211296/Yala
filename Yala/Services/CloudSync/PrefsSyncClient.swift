//
//  PrefsSyncClient.swift
//  Yala
//
//  Transporte de las preferencias del Modo Nube al/del Worker (I13). Espejo mínimo de `SyncPushClient`/
//  `SyncPullClient`: mismo `SyncHTTPSession` inyectable, `tokenProvider`/`attestProvider`, headers
//  Authorization Bearer + X-Yala-Attest-Session, y `Outcome` estructurado (cero silencios). El lado
//  servidor YA EXISTE (I6): `POST /prefs/push` (RPC `apply_pref`, LWW por key server-side) y
//  `GET /prefs/pull?since=<server_seq>` (cursor). Ambos exigen `requireUserAndAttest` (en staging con
//  `ENFORCE != "enforce"` el JWT basta — igual que `/sync/*`).
//
//  CONTRATO DE WIRE (gateway/src/sync/types.ts):
//    push req  { prefs: [{ key, value: string|null, hlc }] }
//    push resp { results: [{ key, status: "applied"|"noop", reason? }] }
//    pull resp { prefs: [{ key, value: string|null, hlc, server_seq }], max_server_seq }
//
//  DARK: el orquestador (`CloudSyncRuntime`) decide cuándo/cada-cuánto. Aquí vive SOLO el transporte +
//  el decode. A diferencia del dominio (`SyncPushClient`), los values de prefs son strings planos → se
//  serializan con `JSONEncoder` (no hay canon c1 que preservar verbatim).
//

import Foundation

// MARK: - Wire types

/// Una preferencia a subir (espeja `PrefsPushRequest.prefs[]`).
struct WirePref: Equatable {
    let key: String
    let value: String?
    let hlc: String
}

/// Resultado por-key del push (espeja `PrefsPushResponse.results[]`).
struct PrefPushResult: Decodable, Equatable {
    enum Status: String, Decodable { case applied, noop }
    let key: String
    let status: Status
    let reason: String?
}

/// Una preferencia bajada (espeja `PrefsPullResponse.prefs[]`).
struct PulledPref: Decodable, Equatable {
    let key: String
    let value: String?
    let hlc: String
    let serverSeq: Int64

    enum CodingKeys: String, CodingKey {
        case key, value, hlc
        case serverSeq = "server_seq"
    }
}

/// Página del pull de prefs.
struct PrefsPulledPage: Equatable {
    let prefs: [PulledPref]
    let maxServerSeq: Int64
}

// MARK: - Outcomes

/// Resultado ESTRUCTURADO de un push de prefs (cero silencios), espejo de `PushOutcome`.
enum PrefsPushOutcome: Equatable {
    case completed([PrefPushResult])
    case sessionExpired
    /// 403 (cuenta suspendida) o 409 `yala_account_reverting` (freeze de la reversa §h.1 — el gateway
    /// también gatea `/prefs/push`). El runtime NO purga el outbox de prefs (solo purga en `completed`)
    /// → nada se pierde; el stop del ciclo lo impone el push de dominio del mismo ciclo.
    case accountUnavailable
    case transient
}

/// Resultado ESTRUCTURADO de un pull de prefs, espejo de `PullOutcome`.
enum PrefsPullOutcome: Equatable {
    case page(PrefsPulledPage)
    case sessionExpired
    case accountUnavailable
    case transient
}

// MARK: - PrefsSyncClient

@MainActor
final class PrefsSyncClient {

    private let baseURL: URL
    private let tokenProvider: () async -> String?
    private let attestProvider: () async -> String?
    private let urlSession: SyncHTTPSession

    init(
        baseURL: URL = ProxyConfig.baseURL,
        tokenProvider: @escaping () async -> String?,
        attestProvider: @escaping () async -> String? = { nil },
        urlSession: SyncHTTPSession = URLSession.shared
    ) {
        self.baseURL = baseURL
        self.tokenProvider = tokenProvider
        self.attestProvider = attestProvider
        self.urlSession = urlSession
    }

    // MARK: push

    /// Sube `prefs` a `POST /prefs/push`. Devuelve un `PrefsPushOutcome` estructurado (nunca lanza).
    func push(_ prefs: [WirePref]) async -> PrefsPushOutcome {
        guard !prefs.isEmpty else { return .completed([]) }
        guard let token = await tokenProvider(), !token.isEmpty else {
            return .sessionExpired
        }

        let body: Data
        do {
            body = try encodePushBody(prefs)
        } catch {
            #if DEBUG
            print("PrefsSyncClient: encode push body failed: \(error)")
            #endif
            return .transient
        }

        var request = URLRequest(url: baseURL.appendingPathComponent("prefs/push"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let attest = await attestProvider(), !attest.isEmpty {
            request.setValue("Bearer \(attest)", forHTTPHeaderField: "X-Yala-Attest-Session")
        }
        request.httpBody = body

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            return .transient
        }
        guard let http = response as? HTTPURLResponse else { return .transient }

        switch http.statusCode {
        case 200:
            do {
                let decoded = try JSONDecoder().decode(PushResponse.self, from: data)
                return .completed(decoded.results)
            } catch {
                return .transient
            }
        case 401: return .sessionExpired
        case 403: return .accountUnavailable
        case 409:
            // Freeze de la reversa (§h.1): mismo trato de STOP que el 403 (el outbox no se purga). Un
            // 409 ajeno conserva el trato previo (transient). Espejo de la rama 409 de SyncPushClient.
            return GatewayErrorEnvelope.isAccountReverting(data) ? .accountUnavailable : .transient
        default: return .transient
        }
    }

    // MARK: pull

    /// Baja las prefs desde `since` (= cursor `server_seq`). Devuelve un `PrefsPullOutcome` estructurado.
    func pull(since: Int64) async -> PrefsPullOutcome {
        guard let token = await tokenProvider(), !token.isEmpty else {
            return .sessionExpired
        }

        var components = URLComponents(url: baseURL.appendingPathComponent("prefs/pull"),
                                       resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "since", value: String(since))]
        guard let url = components?.url else { return .transient }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let attest = await attestProvider(), !attest.isEmpty {
            request.setValue("Bearer \(attest)", forHTTPHeaderField: "X-Yala-Attest-Session")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            return .transient
        }
        guard let http = response as? HTTPURLResponse else { return .transient }

        switch http.statusCode {
        case 200:
            do {
                let page = try Self.decodePage(data)
                return .page(page)
            } catch {
                return .transient
            }
        case 401: return .sessionExpired
        case 403: return .accountUnavailable
        default: return .transient
        }
    }

    // MARK: - Encode / Decode

    private struct PushResponse: Decodable { let results: [PrefPushResult] }

    private struct RawPullResponse: Decodable {
        let prefs: [PulledPref]
        let maxServerSeq: Int64
        enum CodingKeys: String, CodingKey {
            case prefs
            case maxServerSeq = "max_server_seq"
        }
    }

    /// Ensambla `{ "prefs": [ { key, value, hlc } ] }`. `value: null` cuando la entry no lleva valor.
    private func encodePushBody(_ prefs: [WirePref]) throws -> Data {
        struct WireEnvelope: Encodable {
            struct Item: Encodable { let key: String; let value: String?; let hlc: String }
            let prefs: [Item]
        }
        let envelope = WireEnvelope(prefs: prefs.map { .init(key: $0.key, value: $0.value, hlc: $0.hlc) })
        // `value == nil` se OMITE (Encodable sintetizado usa `encodeIfPresent` para opcionales); el
        // Worker lee `p.value ?? null` → key ausente == null. Hoy `set()` siempre aporta un value, así
        // que el caso nil es teórico. Sin config extra (JSON compacto).
        return try JSONEncoder().encode(envelope)
    }

    /// Decodifica el envelope de `/prefs/pull` a `PrefsPulledPage`.
    static func decodePage(_ data: Data) throws -> PrefsPulledPage {
        let decoded = try JSONDecoder().decode(RawPullResponse.self, from: data)
        return PrefsPulledPage(prefs: decoded.prefs, maxServerSeq: decoded.maxServerSeq)
    }
}
