//
//  GroupsPushKindContractTests.swift
//  YalaTests
//
//  Lote 12.7 · card `tablero-tocar-una-notificacion-de-grupo-no-abre-x6p9` (ticket `push-client-ignores-yala-kind`).
//  Tres cosas que tienen que seguir siendo verdad para que tocar un aviso de grupo abra el grupo y un push sin
//  nada que bajar no dispare un ciclo de sync:
//  1. los `kind` que el gateway emite (`GROUP_PUSH_KINDS`) son los que la app conoce (`GroupsPushKind`);
//  2. el `deepLink` del push (`groups/SplitGroup-<uuid>`) abre el grupo aunque su `id` local sea otro;
//  3. el delegado solo sincroniza por un kind conocido.
//

import Foundation
import Testing

@testable import Yala

@MainActor
@Suite("Push de Grupos · kind y enlace")
struct GroupsPushKindContractTests {

    // MARK: - 1. Contrato de kinds con el gateway

    @Test func gatewayKindsMatchTheAppEnum() throws {
        let ts = try Self.source("gateway/src/groups/routes.ts")
        let start = try #require(ts.range(of: "export const GROUP_PUSH_KINDS = ["))
        let rest = ts[start.upperBound...]
        let end = try #require(rest.range(of: "]"))
        let gatewayKinds = Set(rest[..<end.lowerBound]
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " \"\n")) }
            .filter { !$0.isEmpty })
        #expect(gatewayKinds == Set(GroupsPushKind.allCases.map(\.rawValue)))
        #expect(gatewayKinds.count == 2, "el escáner no leyó el bloque: \(gatewayKinds)")
    }

    @Test func onlyKnownKindsTriggerAGroupsSync() {
        #expect(GroupsPushKind.triggersGroupsSync(kind: "groups-sync"))
        #expect(GroupsPushKind.triggersGroupsSync(kind: "groups-membership"))
        #expect(!GroupsPushKind.triggersGroupsSync(kind: "g0-spike"))
        #expect(!GroupsPushKind.triggersGroupsSync(kind: "otro-de-una-version-futura"))
        #expect(!GroupsPushKind.triggersGroupsSync(kind: nil))
    }

    // MARK: - 2. El enlace del push abre el grupo

    @Test func serverGroupIDMatchesByZone_evenWhenTheLocalIDDiffers() {
        // Un grupo que llegó por el canal backend: `id` local nuevo, `cloudKitZoneID` = group_id del servidor.
        let localID = UUID()
        let serverUUID = UUID()
        let zone = "SplitGroup-\(serverUUID.uuidString)"
        #expect(GroupDeepLinkMatch.matches(pendingID: zone, groupID: localID, zoneID: zone))
        // Pelar el prefijo y buscar por id NO lo encontraría: es justo lo que el gateway no hace.
        #expect(!GroupDeepLinkMatch.matches(pendingID: serverUUID.uuidString, groupID: localID, zoneID: zone))
    }

    @Test func localIDStillMatchesById() {
        let id = UUID()
        #expect(GroupDeepLinkMatch.matches(pendingID: id.uuidString, groupID: id, zoneID: "SplitGroup-\(id.uuidString)"))
        #expect(!GroupDeepLinkMatch.matches(pendingID: UUID().uuidString, groupID: id, zoneID: "SplitGroup-\(id.uuidString)"))
    }

    @Test func emptyZoneNeverMatches() {
        #expect(!GroupDeepLinkMatch.matches(pendingID: "", groupID: UUID(), zoneID: ""))
    }

    @Test func notificationParsesTheServerGroupLink() {
        #expect(NotificationService.parseDestination("groups/SplitGroup-ABC") == .groupDetail(groupID: "SplitGroup-ABC"))
    }

    // MARK: - 3. Cableado

    @Test func groupsTabResolvesThePendingGroupWithTheMatcher() throws {
        let src = try Self.source("Yala/App/Views/Groups/GroupsContainerView.swift")
        let start = try #require(src.range(of: "private func openPendingGroupIfAvailable() {"))
        let body = src[start.upperBound...].prefix(600)
        #expect(body.contains("GroupDeepLinkMatch.matches(pendingID: groupID, groupID: $0.id, zoneID: $0.cloudKitZoneID)"))
        #expect(!body.contains("UUID(uuidString: groupID)"))
    }

    @Test func appDelegateSyncsOnlyForAKnownKind() throws {
        let src = try Self.source("Yala/App/YalaAppDelegate.swift")
        let guardRange = try #require(src.range(of: "guard GroupsPushKind.triggersGroupsSync(kind: kind) else {"))
        let syncRange = try #require(src.range(of: "GroupsSyncClient.shared.syncNowFromPush("))
        #expect(guardRange.lowerBound < syncRange.lowerBound, "el guard tiene que ir antes del ciclo")
    }

    private static func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }
}
