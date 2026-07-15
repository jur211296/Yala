//
//  GroupsMerkleClient.swift
//  Yala
//
//  Transporte del snapshot Merkle del canal de GRUPOS (GET /groups/merkle?group_id=…) — endurecimiento
//  pre-flag B1. Espeja `SyncMerkleClient` (personal) pero contra el wire REAL de Grupos, que DIFIERE del
//  personal en dos cosas (routes.ts:329 / types.ts):
//    - la query lleva `group_id` (el Merkle de Grupos es POR-GRUPO, no global);
//    - la respuesta trae `channel2_root` NO-OPCIONAL y **SIN `capability_set`** (el canal de Grupos no
//      declara capability-set en este endpoint) → el request NO manda `X-Yala-Capability-Set`.
//  La comparación local↔remoto vive en `GroupsSyncClient.verifyGroupIntegrity`; aquí SOLO el fetch + decode.
//  DARK: solo corre con `CloudSyncFlags.groupsBackendEnabled` (el cableado de cadencia vive en el cliente).
//

import Foundation

// MARK: - RemoteGroupMerkle (wire)

/// Snapshot Merkle del backend para UN grupo (respuesta de `GET /groups/merkle`, `GroupMerkleResponse`
/// del gateway). A diferencia del personal: `group_id` explícito, `channel2_root` no-opcional, sin
/// `capability_set`.
struct RemoteGroupMerkle: Equatable, Decodable {
    struct Entity: Equatable, Decodable {
        let count: Int
        let hash: String
    }

    let canonVersion: String
    let groupID: String
    /// Root del Canal 1 (las 5 tablas de grupos, orden UTF-8 asc; tabla vacía = sha256("")).
    let root: String
    /// tabla Postgres → (count de filas VIVAS del Canal 1, entityHash hex).
    let entities: [String: Entity]
    /// Root del Canal 2 (interno del Worker, full-row incl. deleted). INFORMATIVO: el cliente NO lo
    /// recomputa. NO-opcional en el wire de Grupos (difiere del personal).
    let channel2Root: String

    enum CodingKeys: String, CodingKey {
        case canonVersion = "canon_version"
        case groupID = "group_id"
        case root
        case entities
        case channel2Root = "channel2_root"
    }
}

// MARK: - GroupMerkleFetchOutcome

/// Resultado ESTRUCTURADO del fetch (cero silencios), espejo de `MerkleFetchOutcome` del personal.
enum GroupMerkleFetchOutcome: Equatable {
    case snapshot(RemoteGroupMerkle)
    case sessionExpired
    case accountUnavailable
    case transient
}

// MARK: - GroupsMerkleClient

@MainActor
final class GroupsMerkleClient {

    private let baseURL: URL
    // Providers `@MainActor` (leen `CloudAuthService`, main-actor-isolado) — igual que `GroupsSyncClient`.
    private let tokenProvider: @MainActor () async -> String?
    private let attestProvider: @MainActor () async -> String?
    private let urlSession: SyncHTTPSession

    init(
        baseURL: URL = ProxyConfig.baseURL,
        tokenProvider: @escaping @MainActor () async -> String? = { await CloudAuthService.shared.accessToken() },
        attestProvider: @escaping @MainActor () async -> String? = { nil },
        urlSession: SyncHTTPSession = URLSession.shared
    ) {
        self.baseURL = baseURL
        self.tokenProvider = tokenProvider
        self.attestProvider = attestProvider
        self.urlSession = urlSession
    }

    /// GET `/groups/merkle?group_id=<gid>`. Nunca lanza por red/HTTP (→ `.transient`). NO envía
    /// `X-Yala-Capability-Set` (el wire de Grupos no lo declara — divergiría del server que lo ignora).
    func fetchMerkle(groupID: String) async -> GroupMerkleFetchOutcome {
        guard let token = await tokenProvider(), !token.isEmpty else {
            GroupsSyncBreadcrumb.groupsMerkleSkipped(reason: "no-session")
            return .sessionExpired
        }
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent("groups/merkle"), resolvingAgainstBaseURL: false) else {
            return .transient
        }
        components.queryItems = [URLQueryItem(name: "group_id", value: groupID)]
        guard let url = components.url else { return .transient }

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
            GroupsSyncBreadcrumb.groupsMerkleFetchFailed(reason: "transport")
            return .transient
        }
        guard let http = response as? HTTPURLResponse else {
            GroupsSyncBreadcrumb.groupsMerkleFetchFailed(reason: "non-http")
            return .transient
        }
        switch http.statusCode {
        case 200:
            do {
                return .snapshot(try JSONDecoder().decode(RemoteGroupMerkle.self, from: data))
            } catch {
                GroupsSyncBreadcrumb.groupsMerkleFetchFailed(reason: "decode-200")
                return .transient
            }
        case 401:
            GroupsSyncBreadcrumb.groupsMerkleSkipped(reason: "http-401")
            return .sessionExpired
        case 403:
            GroupsSyncBreadcrumb.groupsMerkleSkipped(reason: "http-403")
            return .accountUnavailable
        default:
            GroupsSyncBreadcrumb.groupsMerkleFetchFailed(reason: "http-\(http.statusCode)")
            return .transient
        }
    }
}
