//
//  OpeningBalanceServerAdminParityTests.swift
//  YalaTests
//
//  Card hfhs (2026-11-02) · en un grupo migrado, la app y el servidor tienen que elegir la MISMA fila de miembro para
//  decidir quién gestiona los saldos iniciales.
//
//  La medición, en dos mitades:
//   · SERVIDOR (staging, `qa/cloud/g29_01-staging-probe.sh`, casos 9 y 10): con la fila heredada de B admin y sin
//     reclamar (`user_id` NULL) y la suya `member`, `is_group_admin` da false y su saldo se rechaza
//     (`yala_opening_balance_not_admin`). Reclamando la heredada, da true y se aplica.
//   · APP (aquí, `divergence_isReal_withTheCanonicalRow`): en ese mismo estado la fila canónica es la HEREDADA —lleva
//     `isCurrentUser` de la era CloudKit y gana a la del backend—, y con ella la decisión vieja decía «sí».
//  ⇒ divergían. Desde la card, en un grupo del backend la app decide como `is_group_admin`.
//

import Foundation
import Testing

@testable import Yala

@Suite("Saldos iniciales · la app decide quién los gestiona como el servidor (hfhs)")
@MainActor
struct OpeningBalanceServerAdminParityTests {

    private let me = "8F0E1C2A-1111-4222-8333-944455556666"
    typealias Row = OpeningBalancePermissionLogic.MemberRow

    private func decide(owner: Bool = false, backend: Bool = true, session: String?, rows: [Row],
                        canonicalActive: Bool = true, canonicalAdmin: Bool) -> Bool {
        OpeningBalancePermissionLogic.canManage(
            groupIsOwner: owner, isBackendGroup: backend, currentUserID: session, members: rows,
            canonicalIsActive: canonicalActive, canonicalIsAdmin: canonicalAdmin)
    }

    @Test("la divergencia existía: en el grupo migrado sin reclamar, la fila canónica es la heredada admin")
    func divergence_isReal_withTheCanonicalRow() throws {
        let zone = "SplitGroup-Migrado"
        let legacy = SplitMember(groupZoneID: zone, displayName: "B", cloudKitUserRecordID: "_ckB", role: "admin",
                                 isCurrentUser: true)
        legacy.joinedAt = Date(timeIntervalSince1970: 1_000)
        let mine = SplitMember(groupZoneID: zone, displayName: "B", role: "member")
        mine.userID = me.lowercased()
        mine.joinedAt = Date(timeIntervalSince1970: 2_000)

        let canonical = try #require(GroupExpenseService.selectCurrentUserMember(
            from: [legacy, mine], cachedRecordName: "_ckB", currentUserID: me))
        #expect(canonical.id == legacy.id, "la canónica es la heredada: es la que pintaba el botón")
        // La decisión vieja, con esa fila: «sí». El servidor (sonda, caso 9): «no».
        #expect(OpeningBalancePermissionLogic.canManage(
            groupIsOwner: false, currentMemberIsActive: canonical.isActive, currentMemberIsAdmin: canonical.isAdmin))
        // La nueva, con las filas tal como las ve el servidor: «no», como el servidor.
        let rows = [legacy, mine].map { Row(userID: $0.userID, isActive: $0.isActive, role: $0.role) }
        #expect(!decide(session: me, rows: rows, canonicalAdmin: canonical.isAdmin))
    }

    @Test("la tabla: dueño, fila mía admin (reclamada), sin sesión y grupo que no es del backend")
    func table() {
        let legacyUnclaimed = Row(userID: nil, isActive: true, role: "admin")
        let mineMember = Row(userID: me.lowercased(), isActive: true, role: "member")
        let mineAdmin = Row(userID: me.lowercased(), isActive: true, role: "admin")
        let mineAdminLeft = Row(userID: me.lowercased(), isActive: false, role: "admin")
        let otherAdmin = Row(userID: "11111111-2222-3333-4444-555555555555", isActive: true, role: "admin")

        // Caso 10 de la sonda: la heredada reclamada (lleva mi user_id) y admin → sí.
        #expect(decide(session: me, rows: [mineAdmin], canonicalAdmin: true))
        // Comparación sin mayúsculas: `CloudAuthService.currentUserID` y el `user_id` del pull no tienen por qué coincidir.
        #expect(decide(session: me.lowercased(), rows: [Row(userID: me, isActive: true, role: "admin")], canonicalAdmin: false))
        // Caso 9: la heredada sin reclamar no es mía para el servidor.
        #expect(!decide(session: me, rows: [legacyUnclaimed, mineMember], canonicalAdmin: true))
        // Un admin que se fue no gestiona, aunque la fila siga.
        #expect(!decide(session: me, rows: [mineAdminLeft], canonicalAdmin: true))
        // Otro admin no me hace admin.
        #expect(!decide(session: me, rows: [otherAdmin, mineMember], canonicalAdmin: false))
        // El dueño siempre (lo decide `owner_user_id`, no las filas).
        #expect(decide(owner: true, session: me, rows: [mineMember], canonicalAdmin: false))
        // Sin sesión, o fuera del backend, la decisión de siempre con la fila canónica.
        #expect(decide(session: nil, rows: [legacyUnclaimed, mineMember], canonicalAdmin: true))
        #expect(decide(backend: false, session: me, rows: [legacyUnclaimed, mineMember], canonicalAdmin: true))
        #expect(!decide(backend: false, session: me, rows: [mineAdmin], canonicalAdmin: false))
    }

    @Test("el botón y el guardado pasan por la MISMA decisión (cableado)")
    func bothSidesUseTheSameDecision() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let vm = try String(contentsOf: root.appendingPathComponent("Yala/App/ViewModels/GroupDetailViewModel.swift"),
                            encoding: .utf8)
        let service = try String(contentsOf: root.appendingPathComponent("Yala/Services/Groups/GroupExpenseService.swift"),
                                 encoding: .utf8)
        #expect(vm.contains("OpeningBalancePermissionLogic.canManage(group: group, members: members)"))
        #expect(service.contains("OpeningBalancePermissionLogic.canManage(\n            group: group, members: try GroupService.shared.fetchMembers(for: group)"))
        // Ninguno de los dos sigue con la forma vieja (fila canónica sola).
        #expect(!vm.contains("currentMemberIsAdmin: currentUserMember?.isAdmin"))
        #expect(!service.contains("currentMemberIsAdmin: current?.isAdmin"))
    }
}
