//
//  GroupsMembershipClient.swift
//  Yala
//
//  Cliente TIPADO de los RPCs de membresía del canal Grupos → backend (incremento G3, DARK). CLASE NUEVA,
//  PARALELA al camino CloudKit vigente (`GroupService`/`InviteLinkService` + CKSyncEngine) — NO lo reemplaza
//  ni añade call-sites de UI. Habla con el gateway (`POST /groups/rpc/{fn}`), que reenvía el JWT verbatim al
//  RPC SECURITY DEFINER de Postgres (`supabase-groups-staging.ddl`) y sanitiza los errores a un envelope
//  `{error:{message, type:"yala_rpc_error", code}}`.
//
//  Molde de red de `GroupsSyncClient` (init inyectable: baseURL/tokenProvider/attestProvider/urlSession).
//  CERO logging de tokens/PII; logs bajo `#if DEBUG`.
//

import Foundation
import OSLog

// MARK: - Errores tipados

/// Error del canal de membresía. Mapea el envelope de error del gateway (`error.code`, con FALLBACK a
/// `error.message` — ambos llevan el código `yala_*`) a un caso semántico. Un 400 con un código `yala_*`
/// desconocido → `.permanentRejected` (NUNCA `.transient`: un 400 permanente reintentado sería loop, A5).
enum GroupsRPCError: Error, Equatable {
    case sessionExpired          // 401, o token nil (sin request)
    case notAuthorized           // yala_not_authorized
    case invalidInvite           // yala_invalid_invite
    case badInput                // yala_bad_input
    case groupExists             // yala_group_exists
    case invalidGroupID          // yala_invalid_group_id
    case memberNotFound          // yala_member_not_found
    case cannotRemoveOwner       // yala_cannot_remove_owner
    case ownerCannotLeave        // yala_owner_cannot_leave
    /// HTTP 400 con un `yala_*` fuera de los 8 conocidos (A5) — rechazo PERMANENTE, jamás reintentable.
    case permanentRejected(code: String)
    /// 5xx / no-yala / transporte / respuesta no-HTTP. `status == -1` = error de transporte/no-HTTP.
    case transient(status: Int)
    /// 200 pero el body no decodifica al struct esperado.
    case decoding

    /// Traduce un código `yala_*` del DDL a su caso. `nil` si no es uno de los 8 conocidos.
    init?(yalaCode: String) {
        switch yalaCode {
        case "yala_not_authorized":     self = .notAuthorized
        case "yala_invalid_invite":     self = .invalidInvite
        case "yala_bad_input":          self = .badInput
        case "yala_group_exists":       self = .groupExists
        case "yala_invalid_group_id":   self = .invalidGroupID
        case "yala_member_not_found":   self = .memberNotFound
        case "yala_cannot_remove_owner": self = .cannotRemoveOwner
        case "yala_owner_cannot_leave": self = .ownerCannotLeave
        default: return nil
        }
    }
}

// MARK: - Structs de resultado (shape del DDL, snake_case)

struct CreateGroupResult: Decodable, Equatable {
    let groupID: String
    let memberKey: String
    enum CodingKeys: String, CodingKey {
        case groupID = "group_id"
        case memberKey = "member_key"
    }
}

struct JoinGroupResult: Decodable, Equatable {
    let groupID: String
    let memberKey: String
    let status: String
    let rebound: Bool
    enum CodingKeys: String, CodingKey {
        case groupID = "group_id"
        case memberKey = "member_key"
        case status
        case rebound
    }
}

struct MemberActionResult: Decodable, Equatable {
    let groupID: String
    let memberKey: String
    let status: String
    enum CodingKeys: String, CodingKey {
        case groupID = "group_id"
        case memberKey = "member_key"
        case status
    }
}

struct UpdateDisplayNameResult: Decodable, Equatable {
    let groupID: String
    let memberKey: String
    let displayName: String
    enum CodingKeys: String, CodingKey {
        case groupID = "group_id"
        case memberKey = "member_key"
        case displayName = "display_name"
    }
}

struct ForgetResult: Decodable, Equatable {
    let groupsTransferred: Int
    let groupsTombstoned: Int
    let membershipsAnonymized: Int
    enum CodingKeys: String, CodingKey {
        case groupsTransferred = "groups_transferred"
        case groupsTombstoned = "groups_tombstoned"
        case membershipsAnonymized = "memberships_anonymized"
    }
}

// MARK: - Cliente

@MainActor
final class GroupsMembershipClient {

    private let baseURL: URL
    private let tokenProvider: @MainActor () async -> String?
    private let attestProvider: @MainActor () async -> String?
    private let urlSession: SyncHTTPSession
    private let logger = Logger(subsystem: "com.yala.app", category: "GroupsRPC")

    /// Sleep INYECTABLE del retry (default `Task.sleep`) — los tests inyectan uno que no duerme (regla:
    /// jamás `Task.sleep > 0.5s` en tests).
    var sleeper: (TimeInterval) async -> Void = { seconds in
        try? await Task.sleep(for: .seconds(seconds))
    }

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

    // MARK: - Retry de transitorios (B2 [R5], residual A9)

    /// Delays fijos cortos entre reintentos: hasta `maxAttempts = delays.count + 1 = 3` intentos totales.
    private static let retryDelays: [TimeInterval] = [1, 3]

    /// TABLA DE IDEMPOTENCIA POR RPC ([R5] + MEDIUM-1 del review adversarial): ¿el RPC es seguro de
    /// reintentar tras CUALQUIER `.transient`? La ambigüedad ack-perdido-post-COMMIT NO es solo del
    /// transporte del device (`status: -1`): el salto gateway↔PostgREST la tiene IGUAL — un 500/502
    /// respondido al gateway DESPUÉS del COMMIT de PostgREST significa que el RPC SÍ aplicó aunque el
    /// cliente vea un transitorio. Por eso los one-shots creadores se excluyen de TODO retry `.transient`,
    /// no solo del -1 (son acciones user-facing: no reintentar es aceptable; el usuario re-tapea).
    ///
    ///   RPC                          | retry .transient | racional
    ///   -----------------------------|------------------|---------------------------------------------------
    ///   create_group_invite          | NUNCA            | genera token NUEVO en cada llamada (gen_random_bytes
    ///                                |                  | + INSERT, DDL:383-385) → un retry tras ack perdido
    ///                                |                  | post-COMMIT deja un token HUÉRFANO VÁLIDO (credencial
    ///                                |                  | de unión no intencionada). EL peligro real.
    ///   create_group                 | NUNCA            | el server lo hace seguro por sí mismo (unique_violation
    ///                                |                  | → yala_group_exists, 400 no-reintentable) — se excluye
    ///                                |                  | por SIMETRÍA CONSERVADORA (one-shot user-facing).
    ///   join_group                   | SÍ               | ya-member → mismo member_key (idempotente)
    ///   approve_member               | SÍ               | status ya active → no-op server-side
    ///   remove_member                | SÍ               | ya removed → no-op / mismo estado
    ///   leave_group                  | SÍ               | ya left → no-op / mismo estado
    ///   revoke_invite                | SÍ               | ya revocado → no-op
    ///   update_member_display_name   | SÍ               | last-write del mismo valor
    ///   groups_forget_user           | SÍ               | destructivo pero convergente (re-aplicable)
    private static let neverRetryTransient: Set<String> = ["create_group", "create_group_invite"]

    /// Envuelve `call` con retry SOLO de `.transient` ([R5]): delays fijos `[1s, 3s]` (3 intentos máx).
    /// JAMÁS reintenta `sessionExpired`/`permanentRejected`/los `yala_*` mapeados/`decoding` (reintentar
    /// un rechazo permanente sería loop). Los RPCs de `neverRetryTransient` (one-shots creadores) NO
    /// reintentan NINGÚN `.transient` — ni transporte -1 ni 5xx/502 con respuesta (ambigüedad
    /// ack-perdido-post-COMMIT en ambos saltos; ver la tabla). Un `.transient` que agota el presupuesto
    /// SUBE al call-site tal cual — el caller NO debe loopearlo (los reintentos de nivel superior son
    /// responsabilidad del reconciler/UI, no de este cliente).
    private func callWithRetry(fn: String, args: [String: Any]) async throws -> Data {
        var attempt = 0
        while true {
            do {
                return try await call(fn: fn, args: args)
            } catch let error as GroupsRPCError {
                guard case .transient(let status) = error else { throw error }
                // One-shot creador → NUNCA reintentar un transitorio (token/estado huérfano server-side).
                if Self.neverRetryTransient.contains(fn) { throw error }
                guard attempt < Self.retryDelays.count else { throw error }  // presupuesto agotado
                let delay = Self.retryDelays[attempt]
                attempt += 1
                #if DEBUG
                logger.notice("GroupsRPC: \(fn, privacy: .public) transitorio (status \(status)) — retry \(attempt)/\(Self.retryDelays.count) en \(delay)s")
                #endif
                await sleeper(delay)
            }
        }
    }

    // MARK: - Núcleo de red (POST /groups/rpc/{fn})

    /// Ejecuta UN RPC de membresía. Devuelve el body crudo del RPC (jsonb o JSON-string) con status 200; lanza
    /// un `GroupsRPCError` en cualquier otro caso. NUNCA loguea token/PII.
    private func call(fn: String, args: [String: Any]) async throws -> Data {
        guard let token = await tokenProvider(), !token.isEmpty else {
            throw GroupsRPCError.sessionExpired
        }

        var request = URLRequest(url: baseURL.appendingPathComponent("groups/rpc/\(fn)"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let attest = await attestProvider(), !attest.isEmpty {
            request.setValue("Bearer \(attest)", forHTTPHeaderField: "X-Yala-Attest-Session")
        }
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: args, options: [.sortedKeys])
        } catch {
            #if DEBUG
            logger.error("GroupsRPC: serializar args de \(fn, privacy: .public) falló: \(error)")
            #endif
            throw GroupsRPCError.decoding
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            throw GroupsRPCError.transient(status: -1)
        }
        guard let http = response as? HTTPURLResponse else {
            throw GroupsRPCError.transient(status: -1)
        }

        switch http.statusCode {
        case 200:
            return data
        case 401:
            throw GroupsRPCError.sessionExpired
        case 400:
            // Envelope de error del gateway: `error.code` (fallback `error.message`) lleva el `yala_*` (A4).
            if let code = Self.decodeYalaCode(data) {
                if let mapped = GroupsRPCError(yalaCode: code) { throw mapped }
                throw GroupsRPCError.permanentRejected(code: code)   // 400 yala_* desconocido (A5)
            }
            throw GroupsRPCError.transient(status: 400)   // 400 sin código yala_* → no-yala → transitorio
        default:
            // 404 (fn fuera de allowlist), 5xx, 502 yala_unavailable, y cualquier otro 4xx → transitorio.
            throw GroupsRPCError.transient(status: http.statusCode)
        }
    }

    /// Extrae el código `yala_*` del envelope de error del gateway. Prefiere `error.code`, cae a
    /// `error.message` (A4 — ambos llevan el código). `nil` si el body no trae un código `yala_*`.
    private static func decodeYalaCode(_ data: Data) -> String? {
        struct Envelope: Decodable {
            struct Inner: Decodable { let message: String?; let code: String? }
            let error: Inner?
        }
        guard let decoded = try? JSONDecoder().decode(Envelope.self, from: data) else { return nil }
        let candidate = decoded.error?.code ?? decoded.error?.message
        guard let candidate, candidate.hasPrefix("yala_") else { return nil }
        return candidate
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            #if DEBUG
            logger.error("GroupsRPC: decode de \(String(describing: T.self), privacy: .public) falló: \(error)")
            #endif
            throw GroupsRPCError.decoding
        }
    }

    // MARK: - Métodos tipados (9)

    func createGroup(
        groupID: String,
        name: String,
        currencyCode: String,
        iconName: String,
        colorHex: String,
        displayName: String,
        defaultSplitType: String,
        simplifyDebts: Bool,
        showDebtsInSingleCurrency: Bool,
        membersCanInvite: Bool
    ) async throws -> CreateGroupResult {
        let data = try await callWithRetry(fn: "create_group", args: [
            "p_group_id": groupID,
            "p_name": name,
            "p_currency_code": currencyCode,
            "p_icon_name": iconName,
            "p_color_hex": colorHex,
            "p_display_name": displayName,
            "p_default_split_type": defaultSplitType,
            "p_simplify_debts": simplifyDebts,
            "p_show_debts_in_single_currency": showDebtsInSingleCurrency,
            "p_members_can_invite": membersCanInvite,
        ])
        return try decode(CreateGroupResult.self, from: data)
    }

    /// PostgREST devuelve el escalar `text` como JSON-string (`"tok..."`), no texto crudo → decodificar
    /// `String.self` (A6).
    func createInvite(groupID: String, ttlSeconds: Int, maxUses: Int?) async throws -> String {
        var args: [String: Any] = [
            "p_group_id": groupID,
            "p_ttl_seconds": ttlSeconds,
        ]
        if let maxUses { args["p_max_uses"] = maxUses }
        let data = try await callWithRetry(fn: "create_group_invite", args: args)
        return try decode(String.self, from: data)
    }

    func joinGroup(token: String, displayName: String, legacyMemberKey: String?) async throws -> JoinGroupResult {
        var args: [String: Any] = [
            "p_token": token,
            "p_display_name": displayName,
        ]
        if let legacyMemberKey { args["p_legacy_member_key"] = legacyMemberKey }
        let data = try await callWithRetry(fn: "join_group", args: args)
        return try decode(JoinGroupResult.self, from: data)
    }

    func approveMember(groupID: String, memberKey: String) async throws -> MemberActionResult {
        let data = try await callWithRetry(fn: "approve_member", args: [
            "p_group_id": groupID, "p_member_key": memberKey,
        ])
        return try decode(MemberActionResult.self, from: data)
    }

    func removeMember(groupID: String, memberKey: String) async throws -> MemberActionResult {
        let data = try await callWithRetry(fn: "remove_member", args: [
            "p_group_id": groupID, "p_member_key": memberKey,
        ])
        return try decode(MemberActionResult.self, from: data)
    }

    func leaveGroup(groupID: String) async throws -> MemberActionResult {
        let data = try await callWithRetry(fn: "leave_group", args: ["p_group_id": groupID])
        return try decode(MemberActionResult.self, from: data)
    }

    /// `revoke_invite` devuelve `{revoked: true}`; sin oráculo de existencia (un token inexistente o de un
    /// no-admin → `yala_invalid_invite`). Solo interesa el éxito → `Void` (200 = revocado).
    func revokeInvite(token: String) async throws {
        _ = try await callWithRetry(fn: "revoke_invite", args: ["p_token": token])
    }

    func updateMemberDisplayName(groupID: String, displayName: String) async throws -> UpdateDisplayNameResult {
        let data = try await callWithRetry(fn: "update_member_display_name", args: [
            "p_group_id": groupID, "p_display_name": displayName,
        ])
        return try decode(UpdateDisplayNameResult.self, from: data)
    }

    func forgetUser() async throws -> ForgetResult {
        let data = try await callWithRetry(fn: "groups_forget_user", args: [:])
        return try decode(ForgetResult.self, from: data)
    }
}
