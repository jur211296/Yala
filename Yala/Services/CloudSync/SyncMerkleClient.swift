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
    /// ¿Conserva el SDK la sesión guardada? Ver `SyncPushClient.canRenewSession`: mismo contrato y mismo default de
    /// test `{ false }`.
    ///
    /// **Llegó aquí el 2026-09-22, con el ticket `reverse-verify-network-bucket-hides-a-definitive-server-no`.**
    /// Hasta ese día este cliente era el único de los tres sin él, y no se notaba porque `SyncMerkle` aplanaba su
    /// `.sessionExpired` en un `fetch-failed` que se leía como red: daba igual acertar. Desde que el desenlace sale
    /// tipado y enciende el aviso de «vuelve a entrar» de la vuelta a iCloud, acertar es justo lo que importa — sin
    /// este testigo, un token que no llega **sin cobertura** le pediría firmar otra vez a quien tiene la sesión
    /// intacta, que es el falso positivo que cerró `personal-sync-reads-an-offline-token-refresh-as-a-session-expiry`.
    private let canRenewSession: @MainActor () -> Bool

    init(
        baseURL: URL = ProxyConfig.baseURL,
        tokenProvider: @escaping () async -> String?,
        attestProvider: @escaping () async -> String? = { nil },
        urlSession: SyncHTTPSession = URLSession.shared,
        canRenewSession: @escaping @MainActor () -> Bool = { false }
    ) {
        self.baseURL = baseURL
        self.tokenProvider = tokenProvider
        self.attestProvider = attestProvider
        self.urlSession = urlSession
        self.canRenewSession = canRenewSession
    }

    /// GET /sync/merkle con el capability-set v1. Nunca lanza por red/HTTP (→ `.transient`).
    func fetchMerkle() async -> MerkleFetchOutcome {
        // Sin token: caducada solo si el SDK borró la sesión; si la conserva, la renovación no volvió y es pasajero.
        // Ver `SyncPullClient.pull`.
        guard let token = await tokenProvider(), !token.isEmpty else {
            guard canRenewSession() else {
                CloudSyncBreadcrumb.pullBlockedNoSession()
                return .sessionExpired
            }
            CloudSyncBreadcrumb.pullTokenUnavailable()
            return .transient
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
        case 401 where GatewayErrorEnvelope.isAttestRequired(data):
            // El JWT vale y el gateway no acepta el token de App Attest: pasajero, y NO es una sesión que renovar —
            // «vuelve a entrar» ahí manda a un gesto que no arregla nada. Es la misma lectura que el push y el pull
            // hacen desde el 2026-09-16 (`.claude/rules/gateway-attest.md`, «Los dos 401 de la guard»), y el Merkle
            // la necesita desde que su 401 enciende el aviso de la vuelta.
            CloudSyncBreadcrumb.attestRequired(edge: "merkle")
            MetricsService.cloudSyncAttestRequired(edge: "merkle")
            return .transient
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
