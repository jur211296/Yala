//
//  CompartidoAltaPersonaTransporteTests.swift
//  YalaTests
//
//  Lote 3 de Compartido: `GroupsMembershipClient.createPersonGroup` es un método NUEVO en un cliente ya cableado, y el
//  escáner de `AttestWiringTests` cuenta el `attestProvider:` del init, no los métodos (`gateway-attest.md`). Su par de
//  transporte: con el proveedor vivo el header de App Attest viaja; sin él, no. Y el cuerpo lleva lo que el Worker deja
//  pasar (`create_person_group` en su lista blanca), sin `p_key`, que la inyecta el Worker.
//

import Foundation
import Testing
@testable import Yala

@Suite("Compartido · alta de persona: transporte con App Attest")
@MainActor
struct CompartidoAltaPersonaTransporteTests {

    private let header = "X-Yala-Attest-Session"

    private func client(attest: String?) -> (GroupsMembershipClient, GroupsSyncClientTests.StubHTTPSession) {
        let session = GroupsSyncClientTests.StubHTTPSession(
            responseData: Data(#"{"group_id":"SplitGroup-P","member_key":"sub-1","person_member_key":"seat-1"}"#.utf8),
            statusCode: 200)
        let client = GroupsMembershipClient(
            baseURL: URL(string: "https://gw.test")!, tokenProvider: { "jwt" },
            attestProvider: { attest }, urlSession: session)
        client.sleeper = { _ in }
        return (client, session)
    }

    private func create(_ client: GroupsMembershipClient) async throws -> CreateGroupResult {
        try await client.createPersonGroup(
            groupID: "SplitGroup-P", name: "Marta", currencyCode: "PEN", iconName: "person.fill",
            colorHex: "#14B8A6", displayName: "Jürgen", personMemberKey: "seat-1")
    }

    @Test func sendsAttest_whenProviderIsLive() async throws {
        let (client, session) = client(attest: "attest-tok")
        let result = try await create(client)
        #expect(result.groupID == "SplitGroup-P")
        #expect(session.lastRequest?.value(forHTTPHeaderField: header) == "Bearer attest-tok")
        #expect(session.lastRequest?.url?.path == "/groups/rpc/create_person_group")
    }

    @Test func omitsAttest_whenProviderIsNil() async throws {
        let (client, session) = client(attest: nil)
        _ = try await create(client)
        #expect(session.lastRequest?.value(forHTTPHeaderField: header) == nil)
    }

    @Test func body_carriesTheSeatKey_andNeverTheEncryptionKey() async throws {
        let (client, session) = client(attest: "attest-tok")
        _ = try await create(client)
        let body = try #require(session.lastRequest?.httpBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["p_person_member_key"] as? String == "seat-1")
        #expect(json["p_name"] as? String == "Marta")
        #expect(json["p_key"] == nil)
    }
}
