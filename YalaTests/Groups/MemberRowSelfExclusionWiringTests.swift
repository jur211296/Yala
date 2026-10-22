//
//  MemberRowSelfExclusionWiringTests.swift
//  YalaTests
//
//  Identidad de miembro · la fila propia no se reconoce por el flag (source-scan).
//

import Foundation
import Testing

@testable import Yala

/// La condición que oculta las acciones de administración sobre tu propia fila vive dentro de un
/// `body` de SwiftUI, así que ningún unit test puede alcanzarla. Este scan es lo que impide que
/// vuelva a decidirse con el flag crudo.
///
/// **Por qué el cableado importa aquí más que la lógica:** `GroupMemberRow` decidía con
/// `!member.isCurrentUser`. Cuando los consumidores pasaron a resolver identidad (2026-09-04), un
/// admin cuyo member bajó por el pull —2º device, reinstalación, aprobación en vivo— empezó a tener
/// `isCurrentUserAdmin == true` con su fila aún sin marcar ⇒ su PROPIA fila mostraba «cambiar rol»
/// y «quitar». Y esos botones no son mudos: `GroupService.removeMember` llama al RPC ANTES de
/// `removeMemberLocal`, cuyo guard anti-self sigue leyendo el flag (`:345`), así que el servidor te
/// quita y el guard local lanza después — te expulsa de tu propio grupo y la pantalla dice que no
/// puede.
///
/// El scan afirma las dos mitades, porque una sola no basta: que la fila NO lee el flag, y que el
/// call-site le pasa la UNIÓN del flag y la identidad resuelta. La unión, no la igualdad: una zona
/// migrada puede tener DOS filas propias con el flag puesto (`refreshCurrentUserFlags` conserva la
/// legacy y enciende la born-backend) y el resolvedor devuelve UNA, así que comparar solo contra
/// ella dejaría la otra expuesta.
@Suite("Identidad de miembro · la fila propia no se decide por el flag (source-scan)")
struct MemberRowSelfExclusionWiringTests {

    private static func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    /// La condición de las acciones de admin usa `isSelf`, nunca `member.isCurrentUser`.
    @Test func adminActionsCondition_usesIsSelf_notTheRawFlag() throws {
        let src = try Self.source("Yala/App/Views/Groups/GroupMemberRow.swift")
        #expect(
            src.contains("if isCurrentUserAdmin && !isSelf && !member.isGroupOwner {"),
            "La condición de las acciones de admin cambió de forma: debe decidir con `isSelf`.")
        #expect(
            !src.contains("!member.isCurrentUser"),
            "`GroupMemberRow` volvió a decidir con el flag crudo — eso reabre la auto-expulsión.")
    }

    /// El call-site pasa la UNIÓN del flag y la identidad resuelta.
    @Test func callSite_passesUnionOfFlagAndResolvedIdentity() throws {
        let src = try Self.source("Yala/App/Views/Groups/GroupMembersView.swift")
        #expect(
            src.contains("isSelf: member.isCurrentUser"),
            "El call-site dejó de incluir el flag en `isSelf`: con dos filas propias marcadas, la que el resolvedor no devuelve queda expuesta.")
        #expect(
            src.contains("member.id.uuidString == viewModel.currentMemberID"),
            "El call-site dejó de incluir la identidad resuelta en `isSelf`: un admin sin flag volvería a ver acciones sobre su propia fila.")
    }

    /// Los tres controles de admin conservan identificador con el nombre dentro. Sin ellos, la
    /// suite de UI no puede afirmar de QUIÉN es el control — solo contarlos, y contar no distingue
    /// tu fila de la de otro.
    @Test func adminControls_keepPerMemberIdentifiers() throws {
        let src = try Self.source("Yala/App/Views/Groups/GroupMemberRow.swift")
        for id in ["group_member_approve_", "group_member_reject_", "group_member_actions_"] {
            #expect(
                src.contains("accessibilityIdentifier(\"\(id)\\(member.displayName)\")"),
                "Falta el identificador `\(id)<nombre>` — GroupMembersAdminUITests targetea por él.")
        }
    }
}
