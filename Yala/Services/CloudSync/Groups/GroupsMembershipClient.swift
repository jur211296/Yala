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
//  Molde de red de `GroupsSyncClient` (init inyectable: baseURL/tokenProvider/canRenewSession/attestProvider/urlSession).
//  CERO logging de tokens/PII; logs bajo `#if DEBUG`.
//

import Foundation
import OSLog

// MARK: - Errores tipados

/// Error del canal de membresía. Mapea el envelope de error del gateway (`error.code`, con FALLBACK a
/// `error.message` — ambos llevan el código `yala_*`) a un caso semántico. Un 400 con un código `yala_*`
/// desconocido → `.permanentRejected` (NUNCA `.transient`: un 400 permanente reintentado sería loop, A5).
enum GroupsRPCError: Error, Equatable {
    case sessionExpired          // 401 (salvo `yala_attest_required`, que es `.transient`), o token nil con la sesión borrada por el SDK (sin request)
    case notAuthorized           // yala_not_authorized
    case invalidInvite           // yala_invalid_invite
    /// yala_group_deleted (g13_03) — el token era VÁLIDO pero el grupo ya no existe. Se separa de
    /// `.invalidInvite` porque el consejo de aquel copy («pídele al admin que regenere uno») manda a una
    /// acción imposible: no hay grupo ni admin a quien pedírselo.
    case groupDeleted            // yala_group_deleted
    case badInput                // yala_bad_input
    case groupExists             // yala_group_exists
    case invalidGroupID          // yala_invalid_group_id
    case memberNotFound          // yala_member_not_found
    case cannotRemoveOwner       // yala_cannot_remove_owner
    case ownerCannotLeave        // yala_owner_cannot_leave
    /// HTTP 400 con un `yala_*` fuera de los 10 conocidos (A5) — rechazo PERMANENTE, jamás reintentable.
    case permanentRejected(code: String)
    /// 403 `yala_groups_disabled` — el KILL-SWITCH server-side del canal está puesto
    /// (`GROUPS_BACKEND_ROLLOUT_PERCENT = 0`). Apagado DELIBERADO, no un fallo de red: `callWithRetry`
    /// NO lo reintenta (solo reintenta `.transient`), y el caller debe tratarlo como «vuelve más tarde»
    /// CONSERVANDO la intención del usuario — el canal se levantará sin que él haga nada. Este caso
    /// existe porque el device puede tener el percent viejo cacheado hasta 6 h
    /// (`RemoteFlagDecisionLogic.refreshMinInterval`): el cliente cree ON y el servidor ya dice OFF.
    case channelDisabled
    /// 5xx / no-yala / transporte / respuesta no-HTTP. `status == -1` = error de transporte/no-HTTP, y desde el
    /// 2026-09-17 también el token que no llega con la sesión guardada: la renovación falló, casi siempre sin red, y no
    /// se hizo la petición (ver `call`). `status == 401` = App Attest ausente con la sesión buena
    /// (`yala_attest_required`, 2026-09-15): no es sesión caducada.
    case transient(status: Int)
    /// 200 pero el body no decodifica al struct esperado.
    case decoding
    /// yala_group_archived (g13_05) — el enlace es BUENO y el grupo EXISTE: está archivado, y un grupo
    /// archivado no acepta miembros nuevos. Caso propio y no `.invalidInvite` porque aquí no hay nada
    /// roto que arreglar ni enlace que regenerar — es un estado del grupo, reversible por su admin.
    ///
    /// **Declarado AL FINAL a propósito, y no junto a `groupDeleted`, que es su hermano semántico.** El
    /// orden de declaración de este enum se ve FUERA del código: es el número que Foundation imprime al
    /// puentear a `NSError` («Error de Yala.GroupsRPCError 10»), el que llega en un reporte de device y
    /// con el que se diagnostica. Insertarlo en medio habría corrido en uno los ocho casos siguientes y
    /// habría invalidado la lectura de los reportes de los builds ya publicados — el mismo enredo que
    /// `nsErrorCode_perCase_isMeasuredNotInferred` documenta que ya costó un diagnóstico en agosto. La
    /// agrupación semántica se paga con un comentario; la numeración, con una tarde de diagnóstico.
    case groupArchived           // yala_group_archived

    /// Traduce un código `yala_*` del DDL a su caso. `nil` si no es uno de los 10 conocidos.
    init?(yalaCode: String) {
        switch yalaCode {
        case "yala_not_authorized":     self = .notAuthorized
        case "yala_invalid_invite":     self = .invalidInvite
        case "yala_group_deleted":      self = .groupDeleted
        case "yala_group_archived":     self = .groupArchived
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

/// D10 (batch "salir de todos mis grupos"): resultado de `transfer_group_ownership`. El jsonb SIEMPRE trae
/// las claves con nulls (shape uniforme) → decode uniforme; el `new_owner_user_id` extra del wire lo ignora
/// Decodable. `transferred=true` → se transfirió al `newOwnerMemberKey`; `alreadyTransferred=true` → ya no
/// era owner (idempotente, seguro para resume); `reason=="no_eligible_owner"` → sin heredero elegible (el
/// caller manda el grupo a "necesitan tu decisión", jamás se tombstonea).
struct TransferOwnershipResult: Decodable, Equatable {
    let transferred: Bool
    let alreadyTransferred: Bool
    let newOwnerMemberKey: String?
    let reason: String?
    enum CodingKeys: String, CodingKey {
        case transferred
        case alreadyTransferred = "already"
        case newOwnerMemberKey = "new_owner_member_key"
        case reason
    }
}

/// C1: estado del consent de Grupos de la CUENTA, tal y como lo devuelven `record_groups_consent` y
/// `groups_consent_state`. Shape uniforme con nulls cuando la cuenta no ha aceptado nunca — el RPC lo
/// garantiza para que aquí no haya dos ramas de decode (que es donde nacen los `try?`).
///
/// `accepted_at` llega como `timestamptz` serializado por PostgREST, cuya precisión fraccionaria VARÍA
/// (`…T18:04:05.123456+00:00`, `…T18:04:05+00:00`). Se decodifica como `String` y se parsea con los dos
/// formatos: un `JSONDecoder` con `.iso8601` a secas rechaza el primero y dejaría la fecha en `nil`
/// exactamente cuando el servidor SÍ la mandó.
struct GroupsConsentStateResult: Decodable, Equatable, Sendable {
    let textVersion: Int?
    let acceptedAt: Date?
    /// `true` solo en la respuesta de `record_groups_consent` cuando la fila se insertó de verdad (en un
    /// re-registro idempotente es `false`). Diagnóstico: el desarme del intent NO depende de esto — un
    /// `do nothing` es un éxito igual de bueno, porque significa que la cuenta ya tiene su registro.
    let inserted: Bool?

    enum CodingKeys: String, CodingKey {
        case textVersion = "text_version"
        case acceptedAt = "accepted_at"
        case inserted
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        textVersion = try c.decodeIfPresent(Int.self, forKey: .textVersion)
        inserted = try c.decodeIfPresent(Bool.self, forKey: .inserted)
        let raw = try c.decodeIfPresent(String.self, forKey: .acceptedAt)
        acceptedAt = raw.flatMap(GroupsConsentStateResult.parseTimestamp)
    }

    init(textVersion: Int?, acceptedAt: Date?, inserted: Bool?) {
        self.textVersion = textVersion
        self.acceptedAt = acceptedAt
        self.inserted = inserted
    }

    /// `nonisolated`: lo llama `init(from:)`, que es un requisito de `Decodable` y corre fuera del
    /// MainActor (este target compila con `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`).
    nonisolated static func parseTimestamp(_ raw: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = withFraction.date(from: raw) { return d }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: raw)
    }

    /// El formato con el que la fecha de ACEPTACIÓN viaja hacia el RPC. UTC explícito y fracciones: el
    /// servidor la castea a `timestamptz`, y una fecha sin zona la interpretaría en la del servidor.
    nonisolated static func wireTimestamp(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f.string(from: date)
    }
}

// MARK: - Cliente

@MainActor
final class GroupsMembershipClient {

    private let baseURL: URL
    private let tokenProvider: @MainActor () async -> String?
    /// ¿Conserva el SDK la sesión guardada? Separa «sin conexión» de «sesión caducada» cuando el token no llega
    /// (`call`). Default = `CloudAuthService.shared.canRenewSession`, el mismo singleton del que sale el token por
    /// defecto, y **no** `hasSession`: aquel lleva el seam `-uitest-fake-cloud-session`, que dice «hay sesión» sin
    /// ninguna guardada. Molde `GroupsSyncClient.canRenewSession`.
    ///
    /// **Trampa de tests:** con el default, un test que pase `tokenProvider: { nil }` lee el Keychain del simulador. Si
    /// alguien firmó allí, el token nulo sale pasajero y el test que esperaba `.sessionExpired` falla. Inyecta el
    /// testigo explícito.
    private let canRenewSession: @MainActor () -> Bool
    private let attestProvider: @MainActor () async -> String?
    private let urlSession: SyncHTTPSession
    private let logger = Logger(subsystem: "com.yala.app", category: "GroupsRPC")

    /// Sleep INYECTABLE del retry (default `Task.sleep`) — los tests inyectan uno que no duerme (regla:
    /// jamás `Task.sleep > 0.5s` en tests).
    var sleeper: (TimeInterval) async -> Void = { seconds in
        try? await Task.sleep(for: .seconds(seconds))
    }

    /// El default `{ nil }` de `attestProvider` es **SOLO PARA TESTS**: TODA ruta de este cliente es
    /// `POST /groups/rpc/{fn}`, que exige App Attest bajo `enforce` (el enforcement está en el guard
    /// `requireUserAndAttest`, `gateway/src/groups/rpc.ts:87-89` — `:81-83` es la validación del JWT de
    /// Supabase, que es otra cosa y a la que apuntaban tres docblocks del repo).
    /// Producción DEBE pasar `AttestSessionProvider.live` — sin él, 401 `yala_attest_required`. No se
    /// invierte el default porque ~20 construcciones de la suite lo usan y llamarían al App Attest REAL
    /// (red) en un unit test. Lo que impide que nazca un call-site de producción sin él es
    /// `AttestWiringTests`, no el compilador.
    init(
        baseURL: URL = ProxyConfig.baseURL,
        tokenProvider: @escaping @MainActor () async -> String? = { await CloudAuthService.shared.accessToken() },
        canRenewSession: @escaping @MainActor () -> Bool = { CloudAuthService.shared.canRenewSession },
        attestProvider: @escaping @MainActor () async -> String? = { nil },
        urlSession: SyncHTTPSession = URLSession.shared
    ) {
        self.baseURL = baseURL
        self.tokenProvider = tokenProvider
        self.canRenewSession = canRenewSession
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
    ///   transfer_group_ownership     | SÍ               | idempotente-suave: 2º call tras 502 → ya no soy
    ///                                |                  | owner → already:true (sin re-transferir a otro heredero)
    ///   record_groups_consent        | SÍ               | PK (user_id, text_version) + ON CONFLICT DO NOTHING
    ///                                |                  | → un ack perdido post-COMMIT no duplica ni re-fecha
    ///   groups_consent_state         | SÍ               | lectura pura
    private static let neverRetryTransient: Set<String> = ["create_group", "create_group_invite"]

    /// Envuelve `call` con retry SOLO de `.transient` ([R5]): delays fijos `[1s, 3s]` (3 intentos máx).
    /// JAMÁS reintenta `sessionExpired`/`permanentRejected`/`channelDisabled`/los `yala_*` mapeados/
    /// `decoding` (reintentar un rechazo permanente sería loop; el kill-switch del canal no se levanta en
    /// 3 s, y girar sobre él solo gastaría batería y llenaría el log del gateway). Los RPCs de `neverRetryTransient` (one-shots creadores) NO
    /// reintentan NINGÚN `.transient` — ni transporte -1 ni 5xx/502 con respuesta (ambigüedad
    /// ack-perdido-post-COMMIT en ambos saltos; ver la tabla). Un `.transient` que agota el presupuesto
    /// SUBE al call-site tal cual — el caller NO debe loopearlo (los reintentos de nivel superior son
    /// responsabilidad del reconciler/UI, no de este cliente). El token que no se renueva con la sesión guardada
    /// tampoco se reintenta, en ningún RPC: ver su `catch`.
    private func callWithRetry(fn: String, args: [String: Any]) async throws -> Data {
        var attempt = 0
        while true {
            do {
                return try await call(fn: fn, args: args)
            } catch is TokenNotRenewed {
                // Sale al momento como pasajero. La renovación ya es una petición al servidor de auth que el SDK reintenta
                // dos veces (supabase-swift 2.50.0: `RetryRequestInterceptor`, con POST añadido en `Auth/Internal/APIClient`),
                // así que reintentarla aquí triplicaba la espera sin apenas opciones de que entrara: unos 7 s sin red en vez
                // de ~1 s, y hasta ~9 min en vez de ~3 con una red que no responde (leído en el SDK, sin ejecutar). Lo cazó la
                // review adversarial del 2026-09-17. Sin red esperar no sube nada: la persona reintenta con el gesto y los
                // llamadores de fondo, con su propia cadencia.
                throw GroupsRPCError.transient(status: -1)
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

    /// El token no llegó y el SDK conserva la sesión (ver `call`). Solo viaja de `call` a `callWithRetry`, que lo
    /// convierte en `.transient(status: -1)` sin reintentar: los llamadores nunca lo ven.
    private struct TokenNotRenewed: Error {}

    /// Ejecuta UN RPC de membresía. Devuelve el body crudo del RPC (jsonb o JSON-string) con status 200; lanza
    /// un `GroupsRPCError` en cualquier otro caso. NUNCA loguea token/PII.
    private func call(fn: String, args: [String: Any]) async throws -> Data {
        guard let token = await tokenProvider(), !token.isEmpty else {
            // Sin token no se hace la petición. `accessToken()` da `nil` por CUALQUIER fallo, y el SDK solo borra la
            // sesión guardada ante un rechazo terminal del servidor de auth, antes de lanzar. Por eso el testigo se lee
            // DESPUÉS de pedir el token: con la sesión guardada la renovación falló por otra cosa, casi siempre la red,
            // y volver a entrar no lo arregla (tampoco se puede sin red). Es pasajero, con `status: -1` porque no hubo
            // respuesta HTTP: salir de un grupo dice «Vuelve a intentarlo en un momento» en vez de «Tu sesión caducó»,
            // y aceptar una invitación deja de abrir el inicio de sesión. Sale SIN el reintento corto (ver el `catch` de
            // `callWithRetry`), y sin petición no hay ambigüedad «quizá se aplicó». Mismo criterio que
            // `GroupsSyncClient.sdkRemovedTheSession` (ticket `groups-actions-read-an-offline-token-refresh-as-a-session-expiry`).
            //
            // **Aceptado a sabiendas, como en el canal de sync:** un rechazo que el SDK no cuenta como terminal (p. ej.
            // `user_banned`) se lee pasajero.
            guard canRenewSession() else { throw GroupsRPCError.sessionExpired }
            throw TokenNotRenewed()
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
            // El attest pasó la guard: la racha de rechazos se acaba (`GroupsAttestStreakStore`).
            GroupsAttestStreakStore.recordAcceptance()
            return data
        case 401 where GatewayErrorEnvelope.isAttestRequired(data):
            // App Attest ausente con el JWT bueno: el mismo criterio que el canal de sync (ver
            // `GroupsSyncClient.pushChunk`). No es sesión caducada: `.transient` con el status del 401, y por tanto
            // con el reintento corto de `callWithRetry`. La guard rechaza antes de llamar al RPC, así que no hay
            // ambigüedad «quizá se aplicó», tampoco para los one-shots. Para la persona: salir de un grupo dice
            // «Vuelve a intentarlo en un momento» en vez de «Tu sesión caducó», y aceptar una invitación deja de
            // abrir el inicio de sesión, que no lo arregla (decisión de Jürgen, 2026-09-15).
            //
            // **Y cuenta en la racha** (`GroupsAttestStreakStore`): en la nube Grupos casi no pide en segundo plano, así
            // que sin la membresía quien solo intenta salir de un grupo no llegaría nunca al aviso terminal.
            GroupsSyncBreadcrumb.groupsAttestRequired(edge: "rpc:\(fn)")
            GroupsAttestStreakStore.recordRejection()
            throw GroupsRPCError.transient(status: 401)
        case 401:
            throw GroupsRPCError.sessionExpired
        case 403 where GatewayErrorEnvelope.isGroupsChannelDisabled(data):
            // Kill-switch del canal (`gateway/src/groups/killSwitch.ts`). Se discrimina por el CÓDIGO del
            // envelope y no por el status a secas, y el porqué NO es «también llega `yala_pro_required`»:
            // eso sería falso — `limitsFor` da límites de `sync` a los DOS tiers (`gateway/src/policy.ts`:
            // «Modo Nube es GRATIS»), así que `gateRequest` nunca devuelve null-limits en estas rutas. La
            // razón es que un 403 puede venir de algo que NO es el kill (un proxy o WAF por delante del
            // Worker, un guard futuro), y ese caso tiene que conservar su comportamiento de HOY —
            // `.transient`, con retry—: un `case 403:` pelado lo habría cambiado de paso, sin que nadie lo
            // pidiera, y habría convertido un fallo de infraestructura en un «canal apagado» permanente.
            #if DEBUG
            logger.notice("GroupsRPC: \(fn, privacy: .public) → canal apagado por kill-switch remoto (403)")
            #endif
            throw GroupsRPCError.channelDisabled
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

    // MARK: - Métodos tipados (11)

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

    /// D10: transfiere el ownership de UN grupo backend al co-member elegible más antiguo (server-side elige
    /// el heredero). Idempotente-suave → seguro reintentar `.transient` (NO está en `neverRetryTransient`).
    func transferOwnership(groupID: String) async throws -> TransferOwnershipResult {
        let data = try await callWithRetry(fn: "transfer_group_ownership", args: ["p_group_id": groupID])
        return try decode(TransferOwnershipResult.self, from: data)
    }

    // MARK: - Consent de Grupos (C1)

    /// Registra el consentimiento contra la CUENTA (`groups_consents`, append-only por grant).
    ///
    /// `acceptedAt` es la hora de la ACEPTACIÓN y viaja del cliente A PROPÓSITO: el registro no puede
    /// quedar fechado en el reintento que consiguió red. El servidor la acota (futuro → clamp a `now()`,
    /// anterior a 2015 → `yala_bad_input`), así que la fecha del cliente no es una firma en blanco.
    ///
    /// Idempotente por la PK `(user_id, text_version)` + `on conflict do nothing` ⇒ **SÍ es seguro
    /// reintentar `.transient`** y por eso NO entra en `neverRetryTransient`: a diferencia de
    /// `create_group_invite`, un ack perdido post-COMMIT no deja nada huérfano — el segundo intento no
    /// duplica la fila ni le cambia la fecha.
    func recordConsent(textVersion: Int, acceptedAt: Date, path: String?) async throws -> GroupsConsentStateResult {
        var args: [String: Any] = [
            "p_text_version": textVersion,
            "p_accepted_at": GroupsConsentStateResult.wireTimestamp(acceptedAt),
        ]
        if let path, !path.isEmpty { args["p_path"] = path }
        let data = try await callWithRetry(fn: "record_groups_consent", args: args)
        return try decode(GroupsConsentStateResult.self, from: data)
    }

    /// El consent vigente de la cuenta (la versión más alta aceptada y cuándo). Es lo que hace que entrar
    /// con tu cuenta en un device nuevo no vuelva a preguntarte — y la razón de que la lectura NO entre por
    /// el canal de prefs: la frontera M1 sigue cerrada y esto es un hecho de la CUENTA, no del device.
    func consentState() async throws -> GroupsConsentStateResult {
        let data = try await callWithRetry(fn: "groups_consent_state", args: [:])
        return try decode(GroupsConsentStateResult.self, from: data)
    }
}
