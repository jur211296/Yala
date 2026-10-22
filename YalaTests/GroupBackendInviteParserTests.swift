//
//  GroupBackendInviteParserTests.swift
//  YalaTests
//
//  Contrato C1 (G4-invites, DARK): builder + parser del link backend (`g`+`t`+`s`). Verifica que un
//  link CKShare actual devuelve nil (camino vigente intacto) y que el round-trip build→extract preserva
//  group_id/token por los DOS caminos (universal directo + custom-scheme vía `s`).
//

import Foundation
import Testing

@testable import Yala

/// `.serialized`: desde D-R1 paso 2 el fichero togglea el override estático de
/// `CloudSyncFlags.groupsBackendEnabled` (antes leía el default en crudo).
@MainActor
@Suite(.serialized)
struct GroupBackendInviteParserTests {

    private static func b64u(_ s: String) -> String {
        Data(s.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    // MARK: - extractBackendInvite

    @Test func directGT_returnsPair() {
        let url = URL(string: "https://yala-app.pe/invite?g=SplitGroup-ABC&t=deadbeef&s=xyz")!
        let pair = InviteLinkService.extractBackendInvite(from: url)
        #expect(pair?.groupID == "SplitGroup-ABC")
        #expect(pair?.token == "deadbeef")
    }

    @Test func fallbackDecodesInnerS_whenNoTopLevelGT() {
        // invite.astro re-emite SOLO `s` por el custom scheme; el interior porta g+t.
        let inner = "https://yala-app.pe/invite?g=SplitGroup-XYZ&t=cafe01"
        let url = URL(string: "yala://invite?s=\(Self.b64u(inner))")!
        let pair = InviteLinkService.extractBackendInvite(from: url)
        #expect(pair?.groupID == "SplitGroup-XYZ")
        #expect(pair?.token == "cafe01")
    }

    @Test func ckShareLink_returnsNil() {
        // Link CKShare actual: `s` = CKShare URL, sin g/t ni al top ni en el interior.
        let share = "https://www.icloud.com/share/0ABCdef"
        let url = URL(string: "https://yala-app.pe/invite?s=\(Self.b64u(share))")!
        #expect(InviteLinkService.extractBackendInvite(from: url) == nil)
    }

    @Test func alternateHost_directGT_returnsPair() {
        let url = URL(string: "https://yala-pe.com/invite?g=SplitGroup-1&t=aa11")!
        let pair = InviteLinkService.extractBackendInvite(from: url)
        #expect(pair?.groupID == "SplitGroup-1")
        #expect(pair?.token == "aa11")
    }

    @Test func foreignHost_returnsNil() {
        let url = URL(string: "https://attacker.com/invite?g=SplitGroup-1&t=aa11")!
        #expect(InviteLinkService.extractBackendInvite(from: url) == nil)
    }

    @Test func wrongPath_returnsNil() {
        let url = URL(string: "https://yala-app.pe/random?g=SplitGroup-1&t=aa11")!
        #expect(InviteLinkService.extractBackendInvite(from: url) == nil)
    }

    @Test func emptyGorT_returnsNil() {
        #expect(InviteLinkService.extractBackendInvite(
            from: URL(string: "https://yala-app.pe/invite?g=&t=aa")!) == nil)
        #expect(InviteLinkService.extractBackendInvite(
            from: URL(string: "https://yala-app.pe/invite?g=SplitGroup-1&t=")!) == nil)
    }

    @Test func customSchemeDirectGT_returnsPair() {
        let url = URL(string: "yaladev://invite?g=SplitGroup-2&t=bb22")!
        let pair = InviteLinkService.extractBackendInvite(from: url)
        #expect(pair?.groupID == "SplitGroup-2")
        #expect(pair?.token == "bb22")
    }

    // MARK: - build → extract round-trip

    @Test func roundTrip_universalLink_preservesGT() {
        let group = SplitGroup(name: "Viaje", iconName: "airplane", colorHex: "#112233", currencyCode: "PEN")
        let url = InviteLinkService.buildBackendInviteURL(
            groupID: group.cloudKitZoneID, token: "abc123",
            group: group, members: [], inviterName: "Alice")
        #expect(url != nil)
        let pair = InviteLinkService.extractBackendInvite(from: url!)
        #expect(pair?.groupID == group.cloudKitZoneID)
        #expect(pair?.token == "abc123")
        // Cosméticos presentes + `s` presente (AASA lo exige).
        let items = URLComponents(url: url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(items.contains { $0.name == "s" && !($0.value ?? "").isEmpty })
        #expect(items.first { $0.name == "n" }?.value == "Viaje")
    }

    // MARK: - C2 gate: el enrutado al canal backend exige link parseable Y canal encendido

    /// Antes leía el default en crudo y afirmaba `groupsBackendEnabled == false`. Tras el flip de D-R1
    /// paso 2 eso divergía por scheme (rojo bajo `Yala Dev`, verde bajo `Yala` por el fail-closed remoto,
    /// o sea verde por una razón distinta de la que el test decía probar). Lo que el test quiere afirmar
    /// es el GATE, no el valor del default: ahora lo fija con override explícito. El caso sigue vivo
    /// después del flip — es lo que ocurre con el kill remoto activo.
    @Test func flagOff_backendLinkParsesButDoesNotRoute() {
        CloudSyncFlags.groupsBackendEnabled = false
        defer { CloudSyncFlags._testResetGroupsBackendEnabledOverride() }
        let url = URL(string: "https://yala-app.pe/invite?g=SplitGroup-A&t=tok01")!
        let parsed = InviteLinkService.extractBackendInvite(from: url) != nil
        #expect(parsed)  // el link ES un invite backend parseable…
        // …pero con el canal apagado la rama C2 no se evalúa → handler NO invocado.
        #expect(GroupBackendInviteEntryLogic.routesToBackend(
            flagEnabled: CloudSyncFlags.groupsBackendEnabled, backendInviteParsed: parsed) == false)
    }

    /// Control POSITIVO de la rama que el encendido vuelve alcanzable y que hasta ahora no tenía test:
    /// sin él, el gate solo estaba probado por su lado negativo.
    @Test func flagOn_backendLinkRoutesToBackend() {
        CloudSyncFlags.groupsBackendEnabled = true
        defer { CloudSyncFlags._testResetGroupsBackendEnabledOverride() }
        let url = URL(string: "https://yala-app.pe/invite?g=SplitGroup-A&t=tok01")!
        let parsed = InviteLinkService.extractBackendInvite(from: url) != nil
        #expect(parsed)
        #expect(GroupBackendInviteEntryLogic.routesToBackend(
            flagEnabled: CloudSyncFlags.groupsBackendEnabled, backendInviteParsed: parsed))
    }

    @Test func roundTrip_viaSonly_preservesGT() {
        // Simula el camino custom-scheme: descarta g/t del top y re-emite solo `s`.
        let group = SplitGroup(name: "Casa", currencyCode: "USD")
        let full = InviteLinkService.buildBackendInviteURL(
            groupID: group.cloudKitZoneID, token: "tok777",
            group: group, members: [], inviterName: "Bob")!
        let sValue = URLComponents(url: full, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "s" }?.value
        #expect(sValue != nil)
        let customScheme = URL(string: "yala://invite?s=\(sValue!)")!
        let pair = InviteLinkService.extractBackendInvite(from: customScheme)
        #expect(pair?.groupID == group.cloudKitZoneID)
        #expect(pair?.token == "tok777")
    }
}
