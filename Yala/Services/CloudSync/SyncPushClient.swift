//
//  SyncPushClient.swift
//  Yala
//
//  Sube el outbox del Modo Nube al Worker (POST /sync/push) — incremento I8e. Es el PRIMER código que
//  ESCRIBE datos al backend real: cierra el ciclo del productor (drain → outbox → HTTP). DARK: el ciclo
//  de vida (cuándo/cada-cuánto pushear, backoff, wiring runtime) es I9; aquí vive el componente + su e2e.
//
//  CONTRATO DE WIRE (gateway/src/sync/types.ts, §d): el cuerpo es `{ deltas: [SyncDelta] }`; la respuesta
//  `{ results: [SyncDeltaResult] }` con status por-delta `applied | noop | rejected`. `push` SIEMPRE recibe
//  200 mientras la AUTH pase (el rechazo por-delta viaja DENTRO de results, no como status HTTP).
//
//  INVARIANTES (§d.5):
//    - **HLC FIJO, NUNCA regenerado**: el delta lleva el `hlc` de la FILA de outbox tal cual (la verdad
//      temporal de la mutación). Reenviar = misma fila, mismo HLC → idempotencia/orden total aguas abajo.
//    - **Idempotencia**: el `client_mutation_id` de la fila viaja en el delta; el Worker lo ecoa para
//      correlación. Re-pushear el MISMO delta (mismo syncID+hlc) → el RPC lo resuelve `noop` por HLC.
//    - **RawJSON crudo**: `fields`/`field_hlcs` se EMBEBEN VERBATIM desde `fieldsJSON`/`fieldHlcsJSON` (ya
//      son la salida del codec canónico c1). NUNCA se re-parsean/re-serializan → cero riesgo de tocar la
//      canonicalización (strings de dinero, orden de keys, formato de ints, JSONB anidado). Ver `wireBody`.
//    - **Cero silencios**: cada delta rejected → dead-letter (`SyncOutbox.rejectedReason`) + canario; los
//      errores de red/HTTP → un `PushOutcome` estructurado (nunca un `try?` que traga).
//
//  SEPARACIÓN I8e/I9: `push` NO llama `confirmUploaded` (permite un e2e sin engine). El purgado de las
//  filas subidas con éxito lo hace `applyResults`, que sí toca el engine.
//

import Foundation
import SwiftData

// MARK: - Wire mirror (types.ts)

/// Delta de wire (espeja `SyncDelta` de types.ts). Los payloads `fields`/`field_hlcs` van como JSON CRUDO
/// (ya serializado por el codec c1) para preservar la canonicalización byte-a-byte — por eso este struct
/// NO usa `Codable` sintetizado (que re-serializaría): se emite vía `SyncPushClient.wireBody`.
struct SyncDelta: Equatable {
    /// NOMBRE DE TABLA Postgres (key del manifest, ej. `tx_items`) — NO el nombre de clase.
    let entityType: String
    let syncID: UUID
    let op: SyncOutboxOp
    /// JSON crudo del `fields` (dominio limpio, canon c1). `nil` en `tombstone`.
    let fieldsRawJSON: String?
    /// JSON crudo del `field_hlcs` (`{unit:hlc}`). `nil` en `tombstone`.
    let fieldHlcsRawJSON: String?
    /// HLC de FILA (46 chars) — el de la fila de outbox, NUNCA regenerado (§d.5).
    let hlc: String
    let clientMutationID: UUID
    let schemaVersion: Int
}

/// Resultado por-delta que devuelve el Worker (espeja `SyncDeltaResult` de types.ts). `outcome` (telemetría
/// opaca del RPC) se ignora en el cliente.
struct SyncDeltaResult: Decodable, Equatable {
    enum Status: String, Decodable { case applied, noop, rejected }

    let syncID: String
    let clientMutationID: String?
    let status: Status
    let reason: String?

    enum CodingKeys: String, CodingKey {
        case syncID = "sync_id"
        case clientMutationID = "client_mutation_id"
        case status
        case reason
    }
}

/// Respuesta de `/sync/push` (espeja `SyncPushResponse`).
private struct SyncPushResponse: Decodable {
    let results: [SyncDeltaResult]
}

/// Envelope de error del gateway (shape OpenAI-compatible, `gateway/src/errors.ts`) — solo el `type`
/// discriminante. Se usa para distinguir el 409 `yala_account_reverting` (freeze de la reversa §h.1)
/// tanto aquí como en `PrefsSyncClient` (mismo enforcement en `/prefs/push`).
struct GatewayErrorEnvelope: Decodable {
    struct Inner: Decodable { let type: String? }
    let error: Inner?

    /// Código del 403 del kill-switch server-side de Grupos (`gateway/src/groups/killSwitch.ts`): el
    /// canal está apagado A PROPÓSITO porque `GROUPS_BACKEND_ROLLOUT_PERCENT` está en 0. UN solo literal
    /// en todo el cliente — el gateway tiene el suyo y son las dos mitades del mismo contrato de wire.
    static let groupsDisabledType = "yala_groups_disabled"

    /// `true` si el body es el 403 del kill-switch de Grupos. Existe para que el canal apagado no se
    /// confunda con «cuenta suspendida» (el otro 403 que estas rutas pueden devolver) ni con un fallo
    /// transitorio: sin distinguirlo, la app dice «inténtalo en unos minutos» sobre un veredicto que
    /// ningún reintento cambia, y nadie sabe que es un apagado deliberado — la clase de bug que costó el
    /// 2026-07-31. Molde de `isAccountReverting`.
    static func isGroupsChannelDisabled(_ data: Data) -> Bool {
        decodedType(data) == groupsDisabledType
    }

    /// `true` si el body es el 409 del freeze de la reversa (§h.1).
    static func isAccountReverting(_ data: Data) -> Bool {
        decodedType(data) == "yala_account_reverting"
    }

    /// El `error.type` del envelope, o `nil` si el body no es uno del gateway (body ajeno → el caller decide).
    private static func decodedType(_ data: Data) -> String? {
        do {
            return try JSONDecoder().decode(GatewayErrorEnvelope.self, from: data).error?.type
        } catch {
            return nil
        }
    }
}

// MARK: - PushOutcome

/// Resultado ESTRUCTURADO de una subida (cero silencios). El orquestador I9 lo consume para decidir
/// backoff/re-login; aquí no se cablea a `SessionExpiryPolicy`/`AttestSyncGate` (I7b) — solo se mapean los
/// códigos HTTP a sus señales.
enum PushOutcome: Equatable {
    /// 200 OK: el Worker procesó el batch. Los resultados por-delta (applied/noop/rejected) van adentro.
    case completed([SyncDeltaResult])
    /// 401: JWT ausente/inválido/expirado (o attest requerido). NO se purga NADA ni se marca dead-letter —
    /// los deltas se reintentan tras re-login. `pending` = cuántos deltas quedaron sin subir.
    case sessionExpired(pending: Int)
    /// 403 (cuenta suspendida/deshabilitada) o 409 `yala_account_reverting` (freeze de la reversa §h.1:
    /// el backend dejó de ser fuente de verdad — device rezagado durante/tras una reversa). En ambos la
    /// cadencia hace STOP sin loop (`SyncCadencePolicy` → `stopUntilRelaunch`). NO se purga ni dead-letter:
    /// los deltas sobreviven en el outbox para la reversa/adopción de ESTE device.
    case accountUnavailable
    /// 5xx / error de red / respuesta no decodificable / 4xx inesperado → reintentar con backoff (I9). NO
    /// se marca dead-letter (el rechazo definitivo es SOLO un delta con status `rejected`).
    case transient
}

// MARK: - HTTP session (inyectable)

/// Abstracción mínima de `URLSession.data(for:)` para inyectar un stub en tests (sin red).
protocol SyncHTTPSession: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: SyncHTTPSession {}

// MARK: - SyncPushClient

@MainActor
final class SyncPushClient {

    private let baseURL: URL
    private let tokenProvider: () async -> String?
    private let attestProvider: () async -> String?
    private let urlSession: SyncHTTPSession

    /// - Parameters:
    ///   - baseURL: gateway (default `ProxyConfig.baseURL`).
    ///   - tokenProvider: JWT de Supabase (DARK stub aquí; el real es I7c). `nil` = sin sesión → 401-like.
    ///   - attestProvider: token de sesión de App Attest (DARK stub; opcional — el header solo va si != nil).
    ///   - urlSession: inyectable para tests.
    init(
        baseURL: URL = ProxyConfig.baseURL,
        tokenProvider: @escaping () async -> String?,
        attestProvider: @escaping () async -> String? = { nil },
        urlSession: SyncHTTPSession = URLSession.shared,
        pushChunkSize: Int = 50
    ) {
        self.baseURL = baseURL
        self.tokenProvider = tokenProvider
        self.attestProvider = attestProvider
        self.urlSession = urlSession
        self.pushChunkSize = max(1, pushChunkSize)
    }

    /// Máximo de deltas por REQUEST (I14-H2, corrida device 2026-07-12): el Worker aplica los
    /// `apply_delta` SECUENCIALMENTE (~300ms c/u) → un batch sin cap (p.ej. el backlog de ~800 filas sin
    /// confirmar que deja un kill a mitad del snapshot) excede el timeout del URLSession (`-1001` a ~60s)
    /// con ~200 aplicadas server-side → `.transient` → `applyResults` nunca corre → nada se purga → el
    /// próximo intento re-manda el MISMO backlog en el mismo orden = re-upserts idempotentes en LOOP sin
    /// progreso (heartbeat congelado, cursor clavado). 50 deltas ≈ 15s de Worker (margen 4× bajo el
    /// timeout). El progreso es INCREMENTAL por chunk (ver `push`).
    private let pushChunkSize: Int

    // MARK: buildDelta

    /// Traduce UNA fila de outbox a su `SyncDelta` de wire. `entity_type` = la TABLA Postgres (no la clase).
    /// - Throws: `SyncPushError.unknownEntity` si la clase de la fila no está cableada al wire (no debe
    ///   ocurrir — el drain solo produce las 6 syncables; canario aguas arriba).
    func buildDelta(from row: SyncOutbox) throws -> SyncDelta {
        guard let table = EntityEmissionMap.table(forClass: row.entityType) else {
            throw SyncPushError.unknownEntity(row.entityType)
        }
        let op = SyncOutboxOp(rawValue: row.opRaw) ?? .upsert
        // Tombstone: SIN fields/field_hlcs (el borrado no lleva payload; el árbitro es `hlc`/`deleted_hlc`).
        let isTombstone = (op == .tombstone)
        return SyncDelta(
            entityType: table,
            syncID: row.syncID,
            op: op,
            fieldsRawJSON: isTombstone ? nil : row.fieldsJSON,
            fieldHlcsRawJSON: isTombstone ? nil : row.fieldHlcsJSON,
            hlc: row.hlc,
            clientMutationID: row.clientMutationID,
            schemaVersion: row.schemaVersion
        )
    }

    // MARK: partitionBuildable (DIFERIDOS #26 — aislar poison rows ANTES de push)

    /// Una fila de outbox que NO se pudo traducir a delta de wire (clase no cableada) — poison. Se
    /// dead-letterea en el store (`rejectedReason = reason`) SIN subirse, y el resto del batch sí sube.
    struct PoisonRow: Equatable {
        let row: SyncOutbox
        /// Motivo canónico del dead-letter: `"unbuildable:<clase>"` (§d.5 cero-silencios).
        let reason: String
    }

    /// Particiona `rows` en construibles (subibles) y poison (no traducibles a delta) ANTES de `push`,
    /// preservando el ORDEN (los construibles conservan su orden relativo → `applyResults` correlaciona
    /// por `client_mutation_id`, no por posición, así que el orden es informativo pero se respeta). NO
    /// lanza: un `buildDelta` que falla clasifica la fila como poison. La entidad de la fila
    /// (`row.entityType`) ES el nombre de clase → el motivo se arma sin depender del tipo de error.
    func partitionBuildable(_ rows: [SyncOutbox]) -> (buildable: [SyncOutbox], poison: [PoisonRow]) {
        var buildable: [SyncOutbox] = []
        var poison: [PoisonRow] = []
        for row in rows {
            do {
                _ = try buildDelta(from: row)
                buildable.append(row)
            } catch {
                poison.append(PoisonRow(row: row, reason: "unbuildable:\(row.entityType)"))
            }
        }
        return (buildable, poison)
    }

    // MARK: push

    /// Sube `rows` a `POST /sync/push` en CHUNKS de `pushChunkSize` (I14-H2). NO purga nada (eso es
    /// `applyResults`). Nunca lanza por un fallo de red/HTTP (se mapea a `.transient`).
    ///
    /// **Progreso incremental (I14-H2):** si un chunk falla tras chunks ya confirmados, devuelve
    /// `.completed(resultadosParciales)` — el caller (`applyResults`) purga LO CONFIRMADO y el próximo
    /// intento re-emite solo el resto (el criterio "outbox vacío" del uploader clasifica el intento como
    /// transient y reintenta con backlog MENOR → converge). Un outcome TERMINAL (401/403/409-reverting)
    /// en un chunk tardío resurfacea en el PRIMER chunk del próximo intento — la semántica de STOP se
    /// conserva con un ciclo de retraso, sin perder el progreso ya aplicado.
    func push(_ rows: [SyncOutbox]) async -> PushOutcome {
        guard !rows.isEmpty else { return .completed([]) }

        // Sin sesión → no se puede subir. Breadcrumb + sessionExpired (los datos están a salvo local).
        guard let token = await tokenProvider(), !token.isEmpty else {
            CloudSyncBreadcrumb.pushBlockedNoSession(pending: rows.count)
            MetricsService.cloudSyncBlockedByExpiredSession(pending: rows.count)
            return .sessionExpired(pending: rows.count)
        }

        let deltas: [SyncDelta]
        do {
            deltas = try rows.map { try buildDelta(from: $0) }
        } catch {
            // Una fila referencia una clase no cableada (no debe ocurrir). Canario y NO subimos el batch;
            // no es transitorio (reintentar no ayuda) pero tampoco un rechazo del backend → transient para
            // que I9 lo re-evalúe (la fila problemática la delata el drain aguas arriba).
            CloudSyncBreadcrumb.pushBuildFailed(reason: "\(error)")
            return .transient
        }

        // Attest UNA vez para todos los chunks (TTL de sesión ≫ duración del push).
        let attest = await attestProvider()

        var confirmed: [SyncDeltaResult] = []
        var index = 0
        while index < deltas.count {
            let upper = min(index + pushChunkSize, deltas.count)
            let outcome = await pushBatch(
                Array(deltas[index..<upper]), token: token, attest: attest, totalPending: rows.count)
            switch outcome {
            case .completed(let results):
                confirmed.append(contentsOf: results)
                index = upper
            case .sessionExpired, .accountUnavailable, .transient:
                // Progreso parcial: lo confirmado se entrega para purgarse; sin nada confirmado, el
                // outcome del chunk fallido sube tal cual (conserva la clasificación 401/403/transient).
                return confirmed.isEmpty ? outcome : .completed(confirmed)
            }
        }
        return .completed(confirmed)
    }

    /// UN request `POST /sync/push` con un chunk de deltas. Extraído de `push` (I14-H2) sin cambios de
    /// mapeo: la clasificación de status es EXACTAMENTE la previa.
    private func pushBatch(
        _ deltas: [SyncDelta], token: String, attest: String?, totalPending: Int
    ) async -> PushOutcome {
        let body = wireBody(deltas)
        var request = URLRequest(url: baseURL.appendingPathComponent("sync/push"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let attest, !attest.isEmpty {
            request.setValue("Bearer \(attest)", forHTTPHeaderField: "X-Yala-Attest-Session")
        }
        request.httpBody = body

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            // Red caída / timeout → reintentar. Sin PII.
            CloudSyncBreadcrumb.pushTransport(reason: "\(error)")
            return .transient
        }

        guard let http = response as? HTTPURLResponse else {
            CloudSyncBreadcrumb.pushTransport(reason: "non-http-response")
            return .transient
        }

        switch http.statusCode {
        case 200:
            do {
                let decoded = try JSONDecoder().decode(SyncPushResponse.self, from: data)
                return .completed(decoded.results)
            } catch {
                // 200 pero cuerpo ilegible → no podemos confirmar nada; reintentar (no perdemos deltas).
                CloudSyncBreadcrumb.pushTransport(reason: "decode-200:\(error)")
                return .transient
            }
        case 401:
            CloudSyncBreadcrumb.pushBlockedNoSession(pending: totalPending)
            MetricsService.cloudSyncBlockedByExpiredSession(pending: totalPending)
            return .sessionExpired(pending: totalPending)
        case 403:
            CloudSyncBreadcrumb.pushAccountUnavailable()
            MetricsService.cloudAccountUnavailable()
            return .accountUnavailable
        case 409:
            // Enforcement del freeze de la reversa (§h.1): `reverse_frozen_at` estampado → el backend ya
            // no es fuente de verdad. Mismo trato de STOP que el 403 (breadcrumb/telemetría propios para
            // distinguirlo en diagnóstico). Un 409 SIN ese type conserva el trato previo (transient).
            if GatewayErrorEnvelope.isAccountReverting(data) {
                CloudSyncBreadcrumb.pushAccountReverting()
                MetricsService.cloudAccountReverting()
                return .accountUnavailable
            }
            CloudSyncBreadcrumb.pushHTTP(status: http.statusCode)
            return .transient
        default:
            // 5xx (retry), 429 (rate-limit → retry), y 4xx inesperados. Ninguno es un rechazo DEFINITIVO
            // de datos (esos son per-delta) → transient. No dead-letter: no perdemos deltas. I9 acota los
            // reintentos con backoff.
            CloudSyncBreadcrumb.pushHTTP(status: http.statusCode)
            return .transient
        }
    }

    // MARK: applyResults

    /// Aplica los resultados de un `push` a las filas de outbox (cero silencios):
    ///   - `applied`/`noop` → `engine.confirmUploaded` (purga la fila + su espejo; desbloquea el corte de
    ///     `deleteHistory`).
    ///   - `rejected` → dead-letter (`rejectedReason`/`rejectedAt`) + canario `cloudSyncMutationRejected`.
    ///     La fila NO se purga (queda para el panel DEBUG I12; un rechazo repetido re-escribe el motivo).
    /// Correlación por `client_mutation_id` (unívoco por mutación; `sync_id` puede repetirse entre ediciones
    /// sucesivas de la misma fila con distinto HLC).
    func applyResults(
        _ results: [SyncDeltaResult],
        rows: [SyncOutbox],
        engine: CloudSyncEngine,
        context: ModelContext
    ) async {
        guard !results.isEmpty else { return }

        // Correlación por `client_mutation_id` normalizado a lowercase: el wire emite el UUID canónico en
        // minúsculas (§d), pero `UUID.uuidString` de Foundation es MAYÚSCULAS → hay que igualar el caso o
        // el match falla silenciosamente (dejando la fila sin purgar Y sin dead-letter).
        var rowsByMutation: [String: SyncOutbox] = [:]
        for row in rows { rowsByMutation[row.clientMutationID.uuidString.lowercased()] = row }

        for result in results {
            guard let mutationID = result.clientMutationID,
                  let row = rowsByMutation[mutationID.lowercased()] else {
                // El Worker siempre ecoa el client_mutation_id; si falta, no correlacionamos a ciegas.
                CloudSyncBreadcrumb.applyResultUnmatched(syncID: result.syncID)
                continue
            }
            switch result.status {
            case .applied, .noop:
                engine.confirmUploaded(syncID: row.syncID, hlc: row.hlc, context: context)
            case .rejected:
                let reason = result.reason ?? "rejected"
                // Un `rejected` con reason `upstream_*` NO es un rechazo DEFINITIVO del delta (forma/
                // coherencia/schema, §d.5) sino un error de infraestructura TRANSITORIO del Worker
                // (Postgres caído, timeout, deadlock). NO dead-letterear ni disparar el canario
                // "debe-ser-0": la fila NO se purga y el próximo ciclo (I9) la reintenta → auto-sana.
                if reason.hasPrefix("upstream_") {
                    CloudSyncBreadcrumb.pushTransientUpstream(syncID: row.syncID.uuidString, reason: reason)
                } else {
                    markRejected(row, reason: reason, context: context)
                }
            }
        }
    }

    /// Marca una fila como dead-letter (§d.5). NO purga: el delta queda con su motivo para el panel DEBUG.
    private func markRejected(_ row: SyncOutbox, reason: String, context: ModelContext) {
        row.rejectedReason = reason
        row.rejectedAt = .now
        do {
            try context.save()
        } catch {
            #if DEBUG
            print("SyncPushClient: guardar dead-letter falló: \(error)")
            #endif
        }
        MetricsService.cloudSyncMutationRejected(reason: reason)
    }

    // MARK: - Wire body (RawJSON crudo)

    /// Ensambla `{ "deltas": [ ... ] }` con `fields`/`field_hlcs` EMBEBIDOS VERBATIM. NO usa `JSONEncoder`
    /// para el envelope de campos precisamente para no re-serializar el canon c1 (los escalares SÍ se
    /// escapan como JSON strings válidos). Byte-identidad garantizada para el payload de dominio.
    private func wireBody(_ deltas: [SyncDelta]) -> Data {
        let joined = deltas.map(Self.encodeDelta).joined(separator: ",")
        return Data("{\"deltas\":[\(joined)]}".utf8)
    }

    /// Un delta → fragmento JSON. `fields`/`field_hlcs` se insertan crudos (o se OMITEN en tombstone).
    static func encodeDelta(_ d: SyncDelta) -> String {
        var parts: [String] = [
            "\"entity_type\":\(jsonString(d.entityType))",
            "\"sync_id\":\(jsonString(d.syncID.uuidString.lowercased()))",
            "\"op\":\(jsonString(d.op.rawValue))",
        ]
        if let fields = d.fieldsRawJSON {
            parts.append("\"fields\":\(fields)")           // VERBATIM (canon c1)
        }
        if let fieldHlcs = d.fieldHlcsRawJSON {
            parts.append("\"field_hlcs\":\(fieldHlcs)")    // VERBATIM
        }
        parts.append("\"hlc\":\(jsonString(d.hlc))")
        parts.append("\"client_mutation_id\":\(jsonString(d.clientMutationID.uuidString.lowercased()))")
        parts.append("\"schema_version\":\(d.schemaVersion)")
        return "{\(parts.joined(separator: ","))}"
    }

    /// Escapa un String como literal JSON (comillas incluidas). RFC-8259: `"`, `\`, control chars < 0x20.
    static func jsonString(_ s: String) -> String {
        var out = "\""
        for scalar in s.unicodeScalars {
            switch scalar {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            default:
                if scalar.value < 0x20 {
                    out += String(format: "\\u%04x", scalar.value)
                } else {
                    out.unicodeScalars.append(scalar)
                }
            }
        }
        out += "\""
        return out
    }
}

// MARK: - Errores

nonisolated enum SyncPushError: Error, Equatable {
    /// La fila de outbox referencia una clase que no está cableada al wire (`EntityEmissionMap.table` → nil).
    case unknownEntity(String)
}
