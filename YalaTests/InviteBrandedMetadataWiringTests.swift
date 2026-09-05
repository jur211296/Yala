//
//  InviteBrandedMetadataWiringTests.swift
//  YalaTests
//
//  Pieza 2 de `invite-link-five-causes-one-message`: el nombre del grupo viaja en el enlace y la app lo
//  tiraba. `GroupBackendInviteEntryHandler.handle` declaraba `branded:` en su firma y **no lo
//  referenciaba ni una vez** en el cuerpo; el drain de `.presentGroupBackendInviteOnboarding` ponía
//  `pendingInviteMetadata = nil` explícitamente. ⇒ `welcomeWithGroup` («Te invitaron al grupo %@») era
//  código vivo sin camino alcanzable, y el invitado veía un título genérico un segundo después de que la
//  web le enseñara el nombre.
//
//  Dos bloques, y hacen falta los dos:
//    1. Comportamiento — la marca persiste con el intent y sobrevive al re-tap con enlace mínimo.
//    2. Cableado (source-scan) — la marca ENTRA por los call-sites y el drain la LEE. Sin esto, revertir
//       el hunk del handler o del drain dejaría el bloque 1 en verde con el bug de vuelta: el store
//       aceptaría la marca igual, solo que nadie se la daría.
//

import Foundation
import Testing

@testable import Yala

@MainActor
@Suite("Invite · la marca del grupo viaja con el intent", .serialized)
struct InviteBrandedMetadataWiringTests {

    private func makeStore() -> () -> Void {
        let suiteName = "test.invitebranded.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suiteName)!
        PendingJoinStore.defaults = d
        return {
            PendingJoinStore.defaults = .standard
            d.removePersistentDomain(forName: suiteName)
            GroupBackendInviteEntryHandler.clearInviteTapArms()
        }
    }

    private static func branded(
        name: String? = "Viaje a Cusco",
        icon: String? = "airplane",
        color: String? = "FF8800"
    ) -> InviteLinkService.BrandedMetadata {
        .init(name: name, icon: icon, color: color, members: ["Ana", "Beto"])
    }

    // MARK: - hasBranding

    @Test func hasBranding_trueWhenAnyPaintableFieldIsPresent() {
        #expect(Self.branded().hasBranding)
        #expect(Self.branded(name: nil, icon: nil).hasBranding)          // solo color
        #expect(Self.branded(name: nil, color: nil).hasBranding)         // solo icono
    }

    @Test func hasBranding_falseWhenNothingToPaint() {
        #expect(!InviteLinkService.BrandedMetadata.empty.hasBranding)
        #expect(!Self.branded(name: nil, icon: nil, color: nil).hasBranding)
        // Strings vacíos: la vista los descarta igual (`!name.isEmpty`), así que tampoco son marca.
        #expect(!Self.branded(name: "", icon: "", color: "").hasBranding)
    }

    /// El caso que hace que `== .empty` NO sirva como test de vacuidad, y por el que `hasBranding`
    /// existe: `extractMetadata` sobre `…&m=` devuelve `members: []`, distinto de `.empty` y sin
    /// embargo sin una sola cosa que pintar.
    @Test func hasBranding_falseButNotEqualToEmpty_whenOnlyMembersPresent() {
        let onlyMembers = InviteLinkService.BrandedMetadata(
            name: nil, icon: nil, color: nil, members: [])
        #expect(onlyMembers != .empty)
        #expect(!onlyMembers.hasBranding)
    }

    // MARK: - Persistencia (el transporte que cubre el arranque en FRÍO)

    @Test func persistIntent_storesBrandingWithTheIntent() {
        let cleanup = makeStore(); defer { cleanup() }
        let gid = "SplitGroup-\(UUID().uuidString)"

        GroupBackendInviteEntryHandler.persistIntent(
            groupID: gid, token: "tok01", branded: Self.branded())

        let entry = PendingJoinStore.entry(zoneName: gid)
        #expect(entry?.branded?.name == "Viaje a Cusco")
        #expect(entry?.branded?.icon == "airplane")
        #expect(entry?.branded?.color == "FF8800")
    }

    /// El re-tap sobre la forma MÍNIMA (`?g=..&t=..`, que la pieza 3 acaba de dejar entrar por la puerta)
    /// no debe borrar el nombre que el primer tap sí traía.
    @Test func persistIntent_reTapWithoutBranding_preservesTheOneAlreadyCaptured() {
        let cleanup = makeStore(); defer { cleanup() }
        let gid = "SplitGroup-\(UUID().uuidString)"

        GroupBackendInviteEntryHandler.persistIntent(
            groupID: gid, token: "tok01", branded: Self.branded())
        GroupBackendInviteEntryHandler.persistIntent(
            groupID: gid, token: "tok02", branded: .empty)

        let entry = PendingJoinStore.entry(zoneName: gid)
        #expect(entry?.inviteToken == "tok02", "El token SÍ se refresca — es el del tap nuevo.")
        #expect(entry?.branded?.name == "Viaje a Cusco", "La marca buena no se pisa con una vacía.")
    }

    /// El simétrico: un tap nuevo CON marca sí actualiza (el admin renombró el grupo entre enlaces).
    @Test func persistIntent_reTapWithBranding_overwrites() {
        let cleanup = makeStore(); defer { cleanup() }
        let gid = "SplitGroup-\(UUID().uuidString)"

        GroupBackendInviteEntryHandler.persistIntent(
            groupID: gid, token: "tok01", branded: Self.branded())
        GroupBackendInviteEntryHandler.persistIntent(
            groupID: gid, token: "tok02", branded: Self.branded(name: "Viaje a Puno"))

        #expect(PendingJoinStore.entry(zoneName: gid)?.branded?.name == "Viaje a Puno")
    }

    @Test func persistIntent_withoutBranding_leavesItNil() {
        let cleanup = makeStore(); defer { cleanup() }
        let gid = "SplitGroup-\(UUID().uuidString)"
        GroupBackendInviteEntryHandler.persistIntent(groupID: gid, token: "tok01")
        #expect(PendingJoinStore.entry(zoneName: gid)?.branded == nil)
    }

    // MARK: - Back-compat del JSON persistido

    /// Una entry escrita por la versión ANTERIOR no tiene `branded`. Debe decodificar a `nil` (y la vista
    /// caer a su visual genérico), no reventar el store entero — que dejaría al invitado sin join.
    @Test func decode_legacyJSON_withoutBranded_isNil() throws {
        let cleanup = makeStore(); defer { cleanup() }
        let json = """
        {"SplitGroup-OLD":{"zoneName":"SplitGroup-OLD","zoneOwnerName":"","createdAt":\
        "2026-09-01T12:00:00Z","backendGroupID":"SplitGroup-OLD","inviteToken":"tok"}}
        """
        PendingJoinStore.defaults.set(Data(json.utf8), forKey: PendingJoinStore.userDefaultsKey)

        let entry = try #require(PendingJoinStore.entry(
            zoneName: "SplitGroup-OLD", now: Date(timeIntervalSince1970: 1_756_800_000)))
        #expect(entry.branded == nil)
        #expect(entry.inviteToken == "tok", "El resto de la entry sigue legible.")
    }

    /// `createdAt` va con segundos ENTEROS a propósito (molde `PendingJoinStoreTests.ref`): el store
    /// codifica en ISO8601, que trunca la fracción, así que un `.now` cualquiera vuelve distinto del
    /// original y el `==` sintetizado falla por los decimales — no por la marca, que es lo que se mide
    /// aquí. Se imprimen idénticos: el diagnóstico no está en el mensaje del fallo.
    @Test func brandedSurvivesRoundTripThroughTheStore() {
        let cleanup = makeStore(); defer { cleanup() }
        let ref = Date(timeIntervalSince1970: 1_756_800_000)
        let entry = PendingJoinEntry(
            zoneName: "SplitGroup-RT", zoneOwnerName: "",
            createdAt: ref,
            backendGroupID: "SplitGroup-RT", inviteToken: "tok",
            branded: Self.branded())
        PendingJoinStore.save(entry)
        #expect(PendingJoinStore.entry(zoneName: "SplitGroup-RT", now: ref) == entry)
    }
}

/// Cableado de producción (source-scan). Los call-sites que meten la marca en el intent —y el drain que
/// la saca— no son alcanzables desde el runner: uno cuelga de un universal link real y el otro de un
/// `fullScreenCover` de SwiftUI. Sin estos scans, revertir cualquiera de esos hunks deja la suite de
/// arriba entera en verde con el bug de vuelta. Mismo patrón que `GroupsPendingBridgeWiringTests`.
@Suite("Invite · marca del grupo · cableado de producción (source-scan)")
struct InviteBrandedMetadataSourceScanTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
    }

    /// El hallazgo original del ticket, convertido en red: la firma prometía `branded` y el cuerpo no lo
    /// nombraba. Este scan exige que el cuerpo de `handle` lo PASE a `persistIntent`.
    @Test func handle_passesBrandedToPersistIntent() throws {
        let src = try Self.source("Yala/App/Services/GroupBackendInviteEntryHandler.swift")
        let handle = try #require(
            src.components(separatedBy: "static func handle(").dropFirst().first,
            "`handle(` ya no existe con ese nombre — re-ancla este scan.")
        let body = handle.components(separatedBy: "\n    /// ").first ?? handle
        #expect(body.contains("persistIntent(groupID: groupID, token: token, branded: branded)"),
                "`handle` volvió a aceptar `branded` sin usarlo — es el bug exacto que esto pinnea.")
    }

    /// El camino FRÍO es el dominante (el invitado llega desde la web con la app cerrada) y era el único
    /// que ni siquiera extraía la marca.
    @Test func bootstrapper_extractsBrandingOnceAndFeedsEveryPersistingBranch() throws {
        let src = try Self.source("Yala/App/AppBootstrapper.swift")
        let routed = try #require(
            src.components(separatedBy: "private func handleInviteLink(_ url: URL, didRefreshFlags: Bool)")
                .dropFirst().first)
        let body = routed.components(separatedBy: "\n    /// ").first ?? routed

        #expect(body.contains("let branded = InviteLinkService.extractMetadata(from: url)"),
                "La marca debe extraerse en el enrutador, no solo en la rama caliente.")
        // Las tres ramas que persisten intención la reciben.
        #expect(body.components(separatedBy: "branded: branded").count - 1 >= 3,
                "Alguna rama que persiste el intent se quedó sin la marca.")

        let enter = try #require(
            src.components(separatedBy: "private func enterBackendInvite(").dropFirst().first)
        let enterBody = enter.components(separatedBy: "\n    /// ").first ?? enter
        #expect(enterBody.contains("persistBackendInviteIntent(groupID: groupID, token: token, branded: branded)"),
                "El camino frío (`!isInitialized`) volvió a persistir sin marca.")
    }

    /// El drain ponía `nil` a propósito, con un comentario que lo justificaba por el tipo. Ahora LEE la
    /// marca del intent persistido; si alguien vuelve a poner `nil`, esto cae.
    @Test func drain_readsBrandingFromThePersistedIntent() throws {
        let src = try Self.source("Yala/App/ContentView.swift")
        let drain = try #require(
            src.components(separatedBy: "case .presentGroupBackendInviteOnboarding(let zone):")
                .dropFirst().first)
        let body = drain.components(separatedBy: "\n        case ").first ?? drain
        #expect(body.contains("pendingInviteMetadata = PendingJoinStore.entry(zoneName: zone)?.branded"),
                "El drain volvió a descartar la marca.")
        #expect(!body.contains("pendingInviteMetadata = nil"),
                "El drain vuelve a poner `nil` — el invitado pierde el nombre del grupo.")
    }

    /// El tipo muerto no debe volver: exigía un `CKShare.Metadata` del canal que la Fase 3 borró, y esa
    /// exigencia era justo lo que dejaba `welcomeWithGroup` inalcanzable.
    @Test func deadInviteMetadataTypeIsGone() throws {
        let src = try Self.source("Yala/App/Models/RouterIntent.swift")
        #expect(!src.contains("struct InviteMetadata"),
                "`InviteMetadata` volvió: si algo necesita marca, el tipo vivo es `BrandedMetadata`.")
    }
}
