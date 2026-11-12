//
//  GroupAdminPermissionLogicTests.swift
//  YalaTests
//
//  Card 0vbn (2026-11-03) · en un grupo migrado, el menú de un miembro ofrece las acciones de admin que el servidor
//  acepta. El servidor decide con `is_group_admin` (cualquier fila con mi `user_id`, activa y `admin`; medido en el DDL:
//  `approve_member`, `remove_member`, `set_member_role`, `revoke_invite` y la política de UPDATE de `split_groups`), y la
//  sonda de staging de hfhs (`qa/cloud/g29_01-staging-probe.sh`, casos 9 y 10) midió las dos filas del grupo migrado.
//

import Foundation
import Testing

@testable import Yala

@Suite("Grupos · ¿soy admin? como el servidor (0vbn)")
@MainActor
struct GroupAdminPermissionLogicTests {

    private let me = "8F0E1C2A-1111-4222-8333-944455556666"
    typealias Row = GroupAdminPermissionLogic.MemberRow

    private func decide(owner: Bool = false, backend: Bool = true, session: String?, rows: [Row],
                        canonical: (isActive: Bool, isAdmin: Bool)?) -> Bool {
        GroupAdminPermissionLogic.isAdmin(
            groupIsOwner: owner, isBackendGroup: backend, currentUserID: session, members: rows, canonical: canonical)
    }

    /// El grupo migrado de la card: la heredada de la era CloudKit (lleva `isCurrentUser`, sin `user_id` en el servidor) y
    /// la mía nacida en el backend. La canónica es la heredada.
    private func migratedPair(legacyRole: String, mineRole: String) throws -> (canonical: SplitMember, rows: [Row]) {
        let zone = "SplitGroup-Migrado"
        let legacy = SplitMember(groupZoneID: zone, displayName: "B", cloudKitUserRecordID: "_ckB", role: legacyRole,
                                 isCurrentUser: true)
        legacy.joinedAt = Date(timeIntervalSince1970: 1_000)
        let mine = SplitMember(groupZoneID: zone, displayName: "B", role: mineRole)
        mine.userID = me.lowercased()
        mine.joinedAt = Date(timeIntervalSince1970: 2_000)
        let canonical = try #require(GroupExpenseService.selectCurrentUserMember(
            from: [legacy, mine], cachedRecordName: "_ckB", currentUserID: me))
        #expect(canonical.id == legacy.id, "la canónica es la heredada: es la que decidía el menú")
        let rows = [legacy, mine].map { Row(userID: $0.userID, isActive: $0.isActive, role: $0.role) }
        return (canonical, rows)
    }

    @Test("heredada SIN reclamar `member` y la mía `admin`: el servidor acepta, y ahora el menú también")
    func unclaimedMemberLegacy_withMyAdminRow_offersAdminActions() throws {
        let pair = try migratedPair(legacyRole: "member", mineRole: "admin")
        // La decisión vieja (solo la canónica) decía que no: el menú escondía lo que el servidor deja hacer.
        #expect(!(pair.canonical.isActive && pair.canonical.isAdmin))
        #expect(decide(session: me, rows: pair.rows,
                       canonical: (pair.canonical.isActive, pair.canonical.isAdmin)))
    }

    @Test("heredada SIN reclamar `admin` y la mía `member`: el servidor rechaza, y ahora el menú no lo ofrece")
    func unclaimedAdminLegacy_withMyMemberRow_hidesAdminActions() throws {
        let pair = try migratedPair(legacyRole: "admin", mineRole: "member")
        // La vieja decía que sí: el menú ofrecía lo que el servidor rechaza (`yala_not_authorized`).
        #expect(pair.canonical.isActive && pair.canonical.isAdmin)
        #expect(!decide(session: me, rows: pair.rows,
                        canonical: (pair.canonical.isActive, pair.canonical.isAdmin)))
    }

    @Test("heredada RECLAMADA (lleva mi user_id) y admin: admin, como el caso 10 de la sonda")
    func claimedLegacyAdmin_isAdmin() {
        let claimed = Row(userID: me.lowercased(), isActive: true, role: "admin")
        #expect(decide(session: me, rows: [claimed], canonical: (true, true)))
        // Sin distinguir mayúsculas: la sesión y el `user_id` del pull no tienen por qué coincidir.
        #expect(decide(session: me.lowercased(), rows: [Row(userID: me, isActive: true, role: "admin")],
                       canonical: (true, false)))
    }

    @Test("la tabla: admin que se fue, otro admin, dueño sin fila, sin sesión y grupo que no es del backend")
    func table() {
        let mineMember = Row(userID: me.lowercased(), isActive: true, role: "member")
        let mineAdminLeft = Row(userID: me.lowercased(), isActive: false, role: "admin")
        let otherAdmin = Row(userID: "11111111-2222-3333-4444-555555555555", isActive: true, role: "admin")
        let legacyUnclaimedAdmin = Row(userID: nil, isActive: true, role: "admin")

        // Un admin que se fue no administra aunque la fila siga.
        #expect(!decide(session: me, rows: [mineAdminLeft], canonical: (false, true)))
        // Otro admin no me hace admin.
        #expect(!decide(session: me, rows: [otherAdmin, mineMember], canonical: (true, false)))
        // El dueño con una fila mía `member`: manda la fila (el servidor no tiene atajo de dueño para estas acciones).
        #expect(!decide(owner: true, session: me, rows: [mineMember], canonical: (true, true)))
        // El dueño sin ninguna fila mía bajada todavía (grupo recién creado): conserva el admin.
        #expect(decide(owner: true, session: me, rows: [otherAdmin], canonical: nil))
        #expect(!decide(owner: false, session: me, rows: [otherAdmin], canonical: nil))
        // Sin sesión, o fuera del backend: la fila canónica de siempre.
        #expect(decide(session: nil, rows: [legacyUnclaimedAdmin, mineMember], canonical: (true, true)))
        #expect(decide(backend: false, session: me, rows: [legacyUnclaimedAdmin, mineMember], canonical: (true, true)))
        #expect(!decide(backend: false, session: me, rows: [mineAdminLeft], canonical: (false, true)))
        // Sin canónica fuera del backend: el respaldo del dueño que ya tenía el guardado.
        #expect(decide(backend: false, session: nil, rows: [], canonical: nil) == false)
        #expect(decide(owner: true, backend: false, session: nil, rows: [], canonical: nil))
    }

    @Test("el menú y el guardado pasan por la MISMA decisión (cableado)")
    func menuAndSaveUseTheSameDecision() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let vm = try String(contentsOf: root.appendingPathComponent("Yala/App/ViewModels/GroupDetailViewModel.swift"),
                            encoding: .utf8)
        let service = try String(contentsOf: root.appendingPathComponent("Yala/Services/Groups/GroupService.swift"),
                                 encoding: .utf8)
        #expect(vm.contains("GroupAdminPermissionLogic.isAdmin(group: group, members: members)"))
        #expect(service.contains("if GroupAdminPermissionLogic.isAdmin(group: group, members: members) { return }"))
        // Ninguno decide ya con la fila canónica sola.
        #expect(!vm.contains("guard let me = currentUserMember, me.isActive else { return false }"))
        #expect(!service.contains("guard current.role == \"admin\" else { throw GroupServiceError.adminRequired }"))
    }

    @Test("ninguna fila mía lleva acciones de admin sobre mí: tampoco la reclamada que no es la canónica (review)")
    func myOtherRows_neverGetTheAdminMenu() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let view = try String(contentsOf: root.appendingPathComponent("Yala/App/Views/Groups/GroupMembersView.swift"),
                              encoding: .utf8)
        // Con el admin decidido por cualquier fila mía, mi fila reclamada `admin` (sin flag hasta relanzar, no canónica)
        // ve el menú: sin este término, «quitar» salía sobre mí y el servidor deja quitarse a uno mismo.
        #expect(view.contains("|| myMemberIDs.contains(member.id),"))
        #expect(view.contains("GroupExpenseService.resolveAllCurrentUserMembers(from: viewModel.members)"))
    }
}
