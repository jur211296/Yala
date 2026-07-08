//
//  SyncPullClient.swift
//  Yala
//
//  Baja los deltas remotos del Worker (GET /sync/pull) — incremento I8f-1. Espeja `SyncPushClient`
//  (mismo `SyncHTTPSession` inyectable, `tokenProvider`/`attestProvider`, headers Authorization Bearer
//  + X-Yala-Attest-Session; AÑADE `X-Yala-Capability-Set: v1`). El apply de estos deltas al store local
//  vive en `SyncApplyEngine` (extensión de `CloudSyncEngine`); este archivo es SOLO el transporte + el
//  decoder del envelope de wire. DARK: el ciclo de vida (cuándo/cada-cuánto pullear) es I9.
//
//  CONTRATO DE WIRE (gateway/src/sync/types.ts `PulledDelta` / `SyncPullResponse`, §d.6):
//    GET /sync/pull?since=<serverSeqCursor>&limit=<n>
//    → { deltas: [PulledDelta], max_server_seq: number }
//  Cada `PulledDelta` es FULL-ROW (D-0): `fields` trae TODAS las columnas del capability-set (nulls
//  incluidos) y `field_hlcs` el mapa por-unidad completo. Un `tombstone` trae `fields:{}`/`field_hlcs:{}`
//  y `hlc = deleted_hlc` (árbitro row-level del borrado).
//
//  CERO SILENCIOS: los códigos HTTP → un `PullOutcome` estructurado (nunca un `try?` que traga). El
//  decode del cuerpo usa `JSONDecoder` con `WireValue` (preserva bool vs número) y re-serializa cada
//  delta de forma determinista para el `rawDelta` de cuarentena.
//

import Foundation

// MARK: - PulledDelta (forma decodificada del wire)

/// Un delta bajado, ya decodificado a tipos Swift (pero con `fields` como árbol `WireValue` crudo — la
/// conversión columna→tipo del `@Model` la hace `EntityApplyMap`). `Equatable` para los tests.
struct PulledDelta: Equatable {
    /// NOMBRE DE TABLA Postgres (`tx_items`, `accounts`, …), NO la clase Swift.
    let entityType: String
    /// Identidad de sync de la fila remota.
    let syncID: UUID
    let op: SyncOutboxOp
    /// PATCH/full-row de dominio (columna Postgres → valor de wire crudo). Vacío en `tombstone`.
    let fields: [String: WireValue]
    /// Mapa unidad-de-coherencia → HLC (46 chars c1). Vacío en `tombstone`.
    let fieldHlcs: [String: String]
    /// HLC de FILA (upsert = `hlc`; tombstone = `deleted_hlc`) — árbitro LWW row-level.
    let hlc: String
    /// Posición en el eje de orden global (`server_seq`) — clave del cursor/dedup de cuarentena.
    let serverSeq: Int64
    let schemaVersion: Int
    /// El delta re-serializado (JSON determinista) para el `rawDelta` de cuarentena (round-trippea).
    let rawDelta: String
}

/// Página del pull (deltas + high-water del server_seq de la página).
struct PulledPage: Equatable {
    let deltas: [PulledDelta]
    let maxServerSeq: Int64
}

// MARK: - PullOutcome

/// Resultado ESTRUCTURADO de un pull (cero silencios), espejo de `PushOutcome`. El orquestador I9
/// decide backoff/re-login.
enum PullOutcome: Equatable {
    /// 200 OK: una página de deltas + el `max_server_seq`.
    case page(PulledPage)
    /// 401: JWT ausente/inválido/expirado (o attest requerido) → reintentar tras re-login.
    case sessionExpired
    /// 403: autenticado pero prohibido (cuenta suspendida/deshabilitada, ≠401).
    case accountUnavailable
    /// 5xx / red / cuerpo no decodificable / 4xx inesperado → reintentar con backoff.
    case transient
}

// MARK: - Envelope de wire (Decodable)

/// Delta crudo tal cual el JSON del wire. `fields` puede venir ausente (tombstone lo trae `{}` pero
/// somos defensivos) → decodifica a `[:]`.
private struct RawPulledDelta: Decodable {
    let entityType: String
    let syncID: String
    let op: String
    let fields: [String: WireValue]?
    let fieldHlcs: [String: String]?
    let hlc: String
    let serverSeq: Int64
    let schemaVersion: Int?

    enum CodingKeys: String, CodingKey {
        case entityType = "entity_type"
        case syncID = "sync_id"
        case op
        case fields
        case fieldHlcs = "field_hlcs"
        case hlc
        case serverSeq = "server_seq"
        case schemaVersion = "schema_version"
    }
}

private struct RawPullResponse: Decodable {
    let deltas: [RawPulledDelta]
    let maxServerSeq: Int64

    enum CodingKeys: String, CodingKey {
        case deltas
        case maxServerSeq = "max_server_seq"
    }
}

// MARK: - SyncPullClient

@MainActor
final class SyncPullClient {

    private let baseURL: URL
    private let tokenProvider: () async -> String?
    private let attestProvider: () async -> String?
    private let urlSession: SyncHTTPSession

    /// Capability-set del cliente (header `X-Yala-Capability-Set`). v1 = las 16 entidades del manifest.
    static let capabilitySet = "v1"

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

    // MARK: pull

    /// Baja UNA página desde `since` (= `serverSeqCursor`). Devuelve un `PullOutcome` estructurado —
    /// nunca lanza por un fallo de red/HTTP (se mapea a `.transient`).
    func pull(since: Int64, limit: Int = 500) async -> PullOutcome {
        guard let token = await tokenProvider(), !token.isEmpty else {
            CloudSyncBreadcrumb.pullBlockedNoSession()
            TelemetryService.cloudSyncBlockedByExpiredSession(pending: 0)
            return .sessionExpired
        }

        var components = URLComponents(url: baseURL.appendingPathComponent("sync/pull"),
                                       resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "since", value: String(since)),
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        guard let url = components?.url else {
            CloudSyncBreadcrumb.pullTransport(reason: "bad-url")
            return .transient
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(Self.capabilitySet, forHTTPHeaderField: "X-Yala-Capability-Set")
        if let attest = await attestProvider(), !attest.isEmpty {
            request.setValue("Bearer \(attest)", forHTTPHeaderField: "X-Yala-Attest-Session")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            CloudSyncBreadcrumb.pullTransport(reason: "\(error)")
            return .transient
        }

        guard let http = response as? HTTPURLResponse else {
            CloudSyncBreadcrumb.pullTransport(reason: "non-http-response")
            return .transient
        }

        switch http.statusCode {
        case 200:
            do {
                let page = try Self.decodePage(data)
                CloudSyncBreadcrumb.pull(count: page.deltas.count, maxSeq: page.maxServerSeq)
                return .page(page)
            } catch {
                CloudSyncBreadcrumb.pullTransport(reason: "decode-200:\(error)")
                return .transient
            }
        case 401:
            CloudSyncBreadcrumb.pullBlockedNoSession()
            TelemetryService.cloudSyncBlockedByExpiredSession(pending: 0)
            return .sessionExpired
        case 403:
            CloudSyncBreadcrumb.pullAccountUnavailable()
            TelemetryService.cloudAccountUnavailable()
            return .accountUnavailable
        default:
            CloudSyncBreadcrumb.pullHTTP(status: http.statusCode)
            return .transient
        }
    }

    // MARK: - Decode

    /// Decodifica el envelope `SyncPullResponse` a `PulledPage`. Cada delta se re-serializa de forma
    /// determinista (keys ordenadas) para el `rawDelta` de cuarentena. Un `sync_id`/`op` malformado NO
    /// aborta la página: el delta se conserva con una identidad sentinela (lo cuarentenará el apply).
    static func decodePage(_ data: Data) throws -> PulledPage {
        let decoded = try JSONDecoder().decode(RawPullResponse.self, from: data)
        let deltas = try decoded.deltas.map { try mapDelta($0) }
        return PulledPage(deltas: deltas, maxServerSeq: decoded.maxServerSeq)
    }

    /// Traduce un `RawPulledDelta` (wire) a `PulledDelta` (dominio). Re-serializa el delta para `rawDelta`.
    private static func mapDelta(_ raw: RawPulledDelta) throws -> PulledDelta {
        // `op` desconocido → tratar como upsert (el apply lo cuarentenará si la entidad no está cableada;
        // si lo está, un op inválido no debe silenciarse — pero el wire solo emite upsert/tombstone).
        let op = SyncOutboxOp(rawValue: raw.op) ?? .upsert
        // `sync_id` malformado (no debe ocurrir desde nuestro server) → identidad sentinela; el delta
        // conserva su `serverSeq` para el cursor/dedup y acaba en cuarentena (identidad no resoluble).
        let syncID = UUID(uuidString: raw.syncID) ?? UUID()
        let rawDelta = try reserialize(raw)
        return PulledDelta(
            entityType: raw.entityType,
            syncID: syncID,
            op: op,
            fields: raw.fields ?? [:],
            fieldHlcs: raw.fieldHlcs ?? [:],
            hlc: raw.hlc,
            serverSeq: raw.serverSeq,
            schemaVersion: raw.schemaVersion ?? 1,
            rawDelta: rawDelta
        )
    }

    /// Re-serialización DETERMINISTA (keys ordenadas) de un delta de wire para el `rawDelta` de
    /// cuarentena. No es byte-verbatim del socket (JSON no preserva layout) pero round-trippea al struct.
    /// F-9: `server_seq`/`schema_version` se SPLICEAN como literales ENTEROS desde el `Int64`/`Int`
    /// preservado — pasar por `Double` corrompería seqs > 2^53. Los subárboles `fields`/`field_hlcs` se
    /// encodean con `.sortedKeys`; el envelope se arma a mano en orden alfabético de keys (mismo orden
    /// que produciría `.sortedKeys`): entity_type < field_hlcs < fields < hlc < op < schema_version <
    /// server_seq < sync_id.
    private static func reserialize(_ raw: RawPulledDelta) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let fieldsData = try encoder.encode(WireValue.object(raw.fields ?? [:]))
        let fieldHlcsData = try encoder.encode(raw.fieldHlcs ?? [:])
        let js = SyncPushClient.jsonString
        let parts: [String] = [
            "\"entity_type\":\(js(raw.entityType))",
            "\"field_hlcs\":\(String(decoding: fieldHlcsData, as: UTF8.self))",
            "\"fields\":\(String(decoding: fieldsData, as: UTF8.self))",
            "\"hlc\":\(js(raw.hlc))",
            "\"op\":\(js(raw.op))",
            "\"schema_version\":\(raw.schemaVersion ?? 1)",
            "\"server_seq\":\(raw.serverSeq)",
            "\"sync_id\":\(js(raw.syncID))",
        ]
        return "{\(parts.joined(separator: ","))}"
    }
}
