//
//  GroupsMembershipClientTests.swift
//  YalaTests / CloudSync
//
//  Cliente TIPADO de los RPCs de membresía del canal Grupos → backend (incremento G3, DARK). Cliente PURO
//  de red → sin `ModelContext` (no usa `makeTestContext`, no necesita `.serialized`): stub HTTP inyectado,
//  aserción del REQUEST enviado (URL exacta {base}/groups/rpc/{fn}, body campo a campo — lección d49d2e47 —,
//  Authorization), decode de los structs de resultado y mapeo de errores.
//
//  Reusa `GroupsSyncClientTests.StubHTTPSession` (captura lastRequest + status/data configurable).
//

import Foundation
import Testing

@testable import Yala

@Suite("GroupsMembershipClient · RPCs de membresía (DARK)")
@MainActor
struct GroupsMembershipClientTests {

    private let base = URL(string: "https://gw.test")!

    private func stub(_ json: String, status: Int = 200) -> GroupsSyncClientTests.StubHTTPSession {
        GroupsSyncClientTests.StubHTTPSession(responseData: Data(json.utf8), statusCode: status)
    }

    private func client(
        _ session: GroupsSyncClientTests.StubHTTPSession, token: String? = "jwt-token"
    ) -> GroupsMembershipClient {
        let client = GroupsMembershipClient(baseURL: base, tokenProvider: { token }, urlSession: session)
        // B2: el retry de transitorios ([R5]) duerme 1s/3s con el sleeper real — aquí se anula (regla:
        // jamás sleeps reales en tests). Los outcomes finales de estos tests no cambian (el retry agota
        // contra el mismo stub); el comportamiento del retry se cubre en GroupsSyncHardeningTests.
        client.sleeper = { _ in }
        return client
    }

    /// Decodifica el body enviado a `[String: Any]` para aserción campo a campo.
    private func sentBody(_ session: GroupsSyncClientTests.StubHTTPSession) throws -> [String: Any] {
        let data = try #require(session.lastRequest?.httpBody)
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    // MARK: - create_group

    @Test func createGroup_sendsAllParams_decodesResult() async throws {
        let session = stub(#"{"group_id":"SplitGroup-Z","member_key":"sub-1"}"#)
        let result = try await client(session).createGroup(
            groupID: "SplitGroup-Z", name: "Trip", currencyCode: "USD", iconName: "car.fill",
            colorHex: "#112233", displayName: "Alice", defaultSplitType: "equal",
            simplifyDebts: true, showDebtsInSingleCurrency: false, membersCanInvite: true)

        #expect(result == CreateGroupResult(groupID: "SplitGroup-Z", memberKey: "sub-1"))

        let req = try #require(session.lastRequest)
        #expect(req.httpMethod == "POST")
        #expect(req.url?.absoluteString == "https://gw.test/groups/rpc/create_group")
        #expect(req.value(forHTTPHeaderField: "Authorization") == "Bearer jwt-token")

        let body = try sentBody(session)
        #expect(body["p_group_id"] as? String == "SplitGroup-Z")
        #expect(body["p_name"] as? String == "Trip")
        #expect(body["p_currency_code"] as? String == "USD")
        #expect(body["p_icon_name"] as? String == "car.fill")
        #expect(body["p_color_hex"] as? String == "#112233")
        #expect(body["p_display_name"] as? String == "Alice")
        #expect(body["p_default_split_type"] as? String == "equal")
        #expect(body["p_simplify_debts"] as? Bool == true)
        #expect(body["p_show_debts_in_single_currency"] as? Bool == false)
        #expect(body["p_members_can_invite"] as? Bool == true)
    }

    // MARK: - create_group_invite (A6: JSON-string escalar)

    @Test func createInvite_decodesJSONStringToken_omitsNilMaxUses() async throws {
        let session = stub(#""tok-abc123""#)
        let token = try await client(session).createInvite(groupID: "g-1", ttlSeconds: 3600, maxUses: nil)
        #expect(token == "tok-abc123")

        #expect(session.lastRequest?.url?.absoluteString == "https://gw.test/groups/rpc/create_group_invite")
        let body = try sentBody(session)
        #expect(body["p_group_id"] as? String == "g-1")
        #expect(body["p_ttl_seconds"] as? Int == 3600)
        #expect(body["p_max_uses"] == nil)   // nil omitido → PostgREST usa su default
    }

    @Test func createInvite_includesMaxUses_whenPresent() async throws {
        let session = stub(#""tok-xyz""#)
        _ = try await client(session).createInvite(groupID: "g-1", ttlSeconds: 60, maxUses: 5)
        let body = try sentBody(session)
        #expect(body["p_max_uses"] as? Int == 5)
    }

    // MARK: - join_group

    @Test func joinGroup_sendsParams_decodesResult() async throws {
        let session = stub(#"{"group_id":"g-1","member_key":"sub-2","status":"pendingApproval","rebound":false}"#)
        let result = try await client(session).joinGroup(
            token: "tok-1", displayName: "Bob", legacyMemberKey: "rec-legacy")

        #expect(result == JoinGroupResult(
            groupID: "g-1", memberKey: "sub-2", status: "pendingApproval", rebound: false))
        #expect(session.lastRequest?.url?.absoluteString == "https://gw.test/groups/rpc/join_group")
        let body = try sentBody(session)
        #expect(body["p_token"] as? String == "tok-1")
        #expect(body["p_display_name"] as? String == "Bob")
        #expect(body["p_legacy_member_key"] as? String == "rec-legacy")
    }

    @Test func joinGroup_omitsNilLegacyMemberKey() async throws {
        let session = stub(#"{"group_id":"g","member_key":"m","status":"active","rebound":true}"#)
        _ = try await client(session).joinGroup(token: "t", displayName: "C", legacyMemberKey: nil)
        let body = try sentBody(session)
        #expect(body["p_legacy_member_key"] == nil)
    }

    // MARK: - approve / remove / leave

    @Test func approveMember_decodesResult() async throws {
        let session = stub(#"{"group_id":"g-1","member_key":"m-1","status":"active"}"#)
        let result = try await client(session).approveMember(groupID: "g-1", memberKey: "m-1")
        #expect(result == MemberActionResult(groupID: "g-1", memberKey: "m-1", status: "active"))
        #expect(session.lastRequest?.url?.absoluteString == "https://gw.test/groups/rpc/approve_member")
        let body = try sentBody(session)
        #expect(body["p_group_id"] as? String == "g-1")
        #expect(body["p_member_key"] as? String == "m-1")
    }

    @Test func removeMember_decodesResult() async throws {
        let session = stub(#"{"group_id":"g-1","member_key":"m-1","status":"removed"}"#)
        let result = try await client(session).removeMember(groupID: "g-1", memberKey: "m-1")
        #expect(result.status == "removed")
        #expect(session.lastRequest?.url?.absoluteString == "https://gw.test/groups/rpc/remove_member")
    }

    @Test func leaveGroup_decodesResult() async throws {
        let session = stub(#"{"group_id":"g-1","member_key":"m-1","status":"left"}"#)
        let result = try await client(session).leaveGroup(groupID: "g-1")
        #expect(result.status == "left")
        #expect(session.lastRequest?.url?.absoluteString == "https://gw.test/groups/rpc/leave_group")
        let body = try sentBody(session)
        #expect(body["p_group_id"] as? String == "g-1")
    }

    // MARK: - revoke_invite / update_member_display_name / groups_forget_user

    @Test func revokeInvite_succeedsOn200() async throws {
        let session = stub(#"{"revoked":true}"#)
        try await client(session).revokeInvite(token: "tok-1")
        #expect(session.lastRequest?.url?.absoluteString == "https://gw.test/groups/rpc/revoke_invite")
        let body = try sentBody(session)
        #expect(body["p_token"] as? String == "tok-1")
    }

    @Test func updateDisplayName_decodesResult() async throws {
        let session = stub(#"{"group_id":"g-1","member_key":"m-1","display_name":"New Name"}"#)
        let result = try await client(session).updateMemberDisplayName(groupID: "g-1", displayName: "New Name")
        #expect(result == UpdateDisplayNameResult(groupID: "g-1", memberKey: "m-1", displayName: "New Name"))
        let body = try sentBody(session)
        #expect(body["p_group_id"] as? String == "g-1")
        #expect(body["p_display_name"] as? String == "New Name")
    }

    @Test func forgetUser_decodesCounts_sendsEmptyBody() async throws {
        let session = stub(#"{"groups_transferred":2,"groups_tombstoned":1,"memberships_anonymized":3}"#)
        let result = try await client(session).forgetUser()
        #expect(result == ForgetResult(groupsTransferred: 2, groupsTombstoned: 1, membershipsAnonymized: 3))
        #expect(session.lastRequest?.url?.absoluteString == "https://gw.test/groups/rpc/groups_forget_user")
        #expect(try sentBody(session).isEmpty)
    }

    // MARK: - Mapeo de errores

    @Test func error_400_yalaCode_mapsToTypedCase() async throws {
        let session = stub(#"{"error":{"message":"yala_invalid_invite","type":"yala_rpc_error","code":"yala_invalid_invite"}}"#,
                           status: 400)
        await #expect(throws: GroupsRPCError.invalidInvite) {
            _ = try await self.client(session).joinGroup(token: "bad", displayName: "X", legacyMemberKey: nil)
        }
    }

    @Test func error_400_fallsBackToMessage_whenCodeAbsent() async throws {
        let session = stub(#"{"error":{"message":"yala_group_exists","type":"yala_rpc_error"}}"#, status: 400)
        await #expect(throws: GroupsRPCError.groupExists) {
            _ = try await self.client(session).createGroup(
                groupID: "SplitGroup-Z", name: "T", currencyCode: "USD", iconName: "i",
                colorHex: "#000000", displayName: "A", defaultSplitType: "equal",
                simplifyDebts: false, showDebtsInSingleCurrency: false, membersCanInvite: false)
        }
    }

    @Test func error_400_unknownYalaCode_isPermanentRejected() async throws {
        let session = stub(#"{"error":{"code":"yala_something_new","type":"yala_rpc_error"}}"#, status: 400)
        await #expect(throws: GroupsRPCError.permanentRejected(code: "yala_something_new")) {
            _ = try await self.client(session).approveMember(groupID: "g", memberKey: "m")
        }
    }

    @Test func error_400_noYalaCode_isTransient() async throws {
        // 400 sin código `yala_*` (ni en `code` ni en `message`) → transitorio, NO permanentRejected:
        // no es un rechazo de dominio, así que el reintento es correcto.
        let session = stub(#"{"error":{"message":"malformed request body"}}"#, status: 400)
        await #expect(throws: GroupsRPCError.transient(status: 400)) {
            _ = try await self.client(session).approveMember(groupID: "g", memberKey: "m")
        }
    }

    @Test func error_401_isSessionExpired() async throws {
        let session = stub(#"{"error":{"message":"unauthorized"}}"#, status: 401)
        await #expect(throws: GroupsRPCError.sessionExpired) {
            _ = try await self.client(session).leaveGroup(groupID: "g")
        }
    }

    @Test func error_500_isTransient() async throws {
        let session = stub(#"{"error":{"message":"boom"}}"#, status: 500)
        await #expect(throws: GroupsRPCError.transient(status: 500)) {
            _ = try await self.client(session).forgetUser()
        }
    }

    // MARK: - Kill-switch del canal (403 yala_groups_disabled)

    /// El caso que motiva todo: el device tiene el percent viejo cacheado (hasta 6 h de
    /// `RemoteFlagDecisionLogic.refreshMinInterval`), así que CREE que el canal está encendido y el
    /// servidor ya dice que no. Tiene que salir un error TIPADO, no un transitorio.
    @Test func error_403_groupsDisabled_isChannelDisabled() async throws {
        let session = stub(
            #"{"error":{"message":"Canal de Grupos apagado por configuración","type":"yala_groups_disabled","code":"yala_groups_disabled"}}"#,
            status: 403)
        await #expect(throws: GroupsRPCError.channelDisabled) {
            _ = try await self.client(session).joinGroup(token: "t", displayName: "X", legacyMemberKey: nil)
        }
    }

    /// La aserción que carga el peso del requisito «no reintentable»: `join_group` SÍ reintenta
    /// transitorios (no está en `neverRetryTransient`), así que un `callCount == 1` solo puede venir de
    /// que `channelDisabled` NO entra en el retry. Si alguien lo mapeara a `.transient`, esto daría 3.
    @Test func channelDisabled_isNotRetried_singleRequest() async throws {
        let session = stub(#"{"error":{"type":"yala_groups_disabled"}}"#, status: 403)
        await #expect(throws: GroupsRPCError.channelDisabled) {
            _ = try await self.client(session).approveMember(groupID: "g", memberKey: "m")
        }
        #expect(session.callCount == 1)
    }

    /// Contraprueba del mapeo: se discrimina por el CÓDIGO del envelope, no por el status 403 a secas, y un
    /// 403 de OTRA procedencia conserva su comportamiento de hoy — transitorio, CON retry (3 intentos).
    /// El caso usa `yala_pro_required` porque es el otro 403 que el gateway sabe emitir, **aunque en estas
    /// rutas no sea alcanzable** (`limitsFor` da límites de `sync` a los dos tiers: «Modo Nube es GRATIS»,
    /// `gateway/src/policy.ts`). Lo que el test fija es el contrato defensivo: si mañana algo por delante
    /// del Worker —un proxy, un WAF, un guard nuevo— devuelve 403, no se convierte en «canal apagado»
    /// permanente. Un `case 403:` pelado en el cliente sí lo habría convertido.
    @Test func error_403_otherCode_staysTransient_andRetries() async throws {
        let session = stub(#"{"error":{"message":"Esta función requiere Yala Pro.","type":"yala_pro_required"}}"#,
                           status: 403)
        await #expect(throws: GroupsRPCError.transient(status: 403)) {
            _ = try await self.client(session).approveMember(groupID: "g", memberKey: "m")
        }
        #expect(session.callCount == 3)   // 1 + los 2 reintentos de `retryDelays`
    }

    /// 403 con un body que no es un envelope del gateway (proxy, WAF, HTML) → transitorio, como antes:
    /// no se puede afirmar que sea el kill, y equivocarse hacia «transitorio» solo cuesta un reintento.
    @Test func error_403_nonGatewayBody_staysTransient() async throws {
        let session = stub("<html>403 Forbidden</html>", status: 403)
        await #expect(throws: GroupsRPCError.transient(status: 403)) {
            _ = try await self.client(session).leaveGroup(groupID: "g")
        }
    }

    /// El literal del wire vive en UN solo sitio del cliente y tiene que ser EXACTAMENTE el que emite el
    /// gateway: el `"yala_groups_disabled"` que `groupsChannelKilled` pasa a `jsonError`
    /// (`gateway/src/groups/killSwitch.ts`) y que `YalaErrorType` declara en `gateway/src/errors.ts`. Un
    /// typo en cualquiera de las dos mitades convierte el kill en un transitorio silencioso, que es el bug
    /// que esto cierra. No hay forma de compartir el literal entre TS y Swift: el pin es este test.
    @Test func groupsDisabledType_matchesGatewayWireContract() {
        #expect(GatewayErrorEnvelope.groupsDisabledType == "yala_groups_disabled")
        #expect(GatewayErrorEnvelope.isGroupsChannelDisabled(
            Data(#"{"error":{"type":"yala_groups_disabled"}}"#.utf8)))
        #expect(!GatewayErrorEnvelope.isGroupsChannelDisabled(
            Data(#"{"error":{"type":"yala_account_reverting"}}"#.utf8)))
        #expect(!GatewayErrorEnvelope.isGroupsChannelDisabled(Data("no soy json".utf8)))
    }

    @Test func nilToken_isSessionExpired_withoutRequest() async throws {
        let session = stub(#"{}"#)
        await #expect(throws: GroupsRPCError.sessionExpired) {
            _ = try await self.client(session, token: nil).leaveGroup(groupID: "g")
        }
        #expect(session.callCount == 0)   // NUNCA se emitió el request sin token
    }
}
