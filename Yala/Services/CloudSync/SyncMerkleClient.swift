//
//  SyncMerkleClient.swift
//  Yala
//
//  Transporte del snapshot Merkle del backend (GET /sync/merkle) — incremento I8f-3. Espeja
//  `SyncPullClient` (mismo `SyncHTTPSession` inyectable, `tokenProvider`/`attestProvider`, headers
//  Authorization Bearer + X-Yala-Attest-Session + X-Yala-Capability-Set). La comparación local↔remoto
//  vive en `SyncMerkle`/`verifyIntegrity`; aquí SOLO el fetch + decode. DARK: la cadencia es I9.
//

import Foundation

// MARK: - RemoteMerkle (wire)

/// Snapshot Merkle del backend (respuesta de `/sync/merkle`, regla A-1: buckets por entidad).
struct RemoteMerkle: Equatable, Decodable {
    struct Entity: Equatable, Decodable {
        let count: Int
        let hash: String
    }

    let canonVersion: String
    let capabilitySet: String
    /// Root del Canal 1 (16 tablas, orden UTF-8 asc; tabla vacía = sha256("")).
    let root: String
    /// tabla Postgres → (count de filas VIVAS del Canal 1, entityHash hex).
    let entities: [String: Entity]
    /// Root del Canal 2 (interno del Worker, full-row incl. deleted). INFORMATIVO: el cliente NO lo
    /// recomputa en v1.
    let channel2Root: String?

    enum CodingKeys: String, CodingKey {
        case canonVersion = "canon_version"
        case capabilitySet = "capability_set"
        case root
        case entities
        case channel2Root = "channel2_root"
    }
}

// MARK: - MerkleFetchOutcome

/// Resultado ESTRUCTURADO del fetch (cero silencios), espejo de `PullOutcome`.
enum MerkleFetchOutcome: Equatable {
    case snapshot(RemoteMerkle)
    case sessionExpired
    case accountUnavailable
    case transient
}

// MARK: - SyncMerkleClient

@MainActor
final class SyncMerkleClient {

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

    /// GET /sync/merkle con el capability-set v1. Nunca lanza por red/HTTP (→ `.transient`).
    func fetchMerkle() async -> MerkleFetchOutcome {
        guard let token = await tokenProvider(), !token.isEmpty else {
            CloudSyncBreadcrumb.pullBlockedNoSession()
            return .sessionExpired
        }
        var request = URLRequest(url: baseURL.appendingPathComponent("sync/merkle"))
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(SyncPullClient.capabilitySet, forHTTPHeaderField: "X-Yala-Capability-Set")
        if let attest = await attestProvider(), !attest.isEmpty {
            request.setValue("Bearer \(attest)", forHTTPHeaderField: "X-Yala-Attest-Session")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            CloudSyncBreadcrumb.pullTransport(reason: "merkle:\(error)")
            return .transient
        }
        guard let http = response as? HTTPURLResponse else {
            CloudSyncBreadcrumb.pullTransport(reason: "merkle:non-http-response")
            return .transient
        }
        switch http.statusCode {
        case 200:
            do {
                return .snapshot(try JSONDecoder().decode(RemoteMerkle.self, from: data))
            } catch {
                CloudSyncBreadcrumb.pullTransport(reason: "merkle:decode-200:\(error)")
                return .transient
            }
        case 401:
            CloudSyncBreadcrumb.pullBlockedNoSession()
            return .sessionExpired
        case 403:
            CloudSyncBreadcrumb.pullAccountUnavailable()
            return .accountUnavailable
        default:
            CloudSyncBreadcrumb.pullHTTP(status: http.statusCode)
            return .transient
        }
    }
}
