//
//  GroupInviteLinkCreationLogicTests.swift
//  YalaTests
//
//  Pieza 4 de `invite-link-five-causes-one-message`: el botón de generar enlace culpaba a la conexión
//  cuando el fallo era permanente. Las dos superficies que acuñan invitación gateaban por el mismo
//  `if groupsBackendEnabled && isBackendGroup` y su `else` mostraba `groups.errors.inviteFailed`
//  («Revisa tu conexión e inténtalo de nuevo») para DOS causas de naturaleza opuesta, ninguna de ellas
//  la conexión.
//
//  Tabla completa 2×2 + el scan de que las dos superficies —no una— consumen el clasificador. Que fueran
//  DOS fue la corrección de la primera pasada del ticket, y por eso el scan las nombra a las dos.
//

import Foundation
import Testing

@testable import Yala

@Suite("GroupInviteLinkCreationLogic · por qué no se puede emitir el enlace")
struct GroupInviteLinkCreationLogicTests {

    @Test func backendGroupWithChannelOn_hasNoBlocker() {
        #expect(GroupInviteLinkCreationLogic.blocker(
            backendEnabled: true, isBackendGroup: true) == nil)
    }

    @Test func backendGroupWithChannelOff_isTransient() {
        #expect(GroupInviteLinkCreationLogic.blocker(
            backendEnabled: false, isBackendGroup: true) == .channelOff)
    }

    @Test func legacyGroupWithChannelOn_isPermanent() {
        #expect(GroupInviteLinkCreationLogic.blocker(
            backendEnabled: true, isBackendGroup: false) == .legacyGroup)
    }

    /// La celda que decide el criterio: con las dos condiciones caídas gana el motivo PERMANENTE.
    /// Si el canal vuelve mañana, ese grupo sigue sin poder emitir enlace — prometerle «inténtalo más
    /// tarde» sería el mismo consejo imposible por otra puerta.
    @Test func legacyGroupWithChannelOff_permanentWins() {
        #expect(GroupInviteLinkCreationLogic.blocker(
            backendEnabled: false, isBackendGroup: false) == .legacyGroup)
    }

    /// El clasificador es la NEGACIÓN EXACTA del guard de las dos superficies. Si dejan de ser el mismo
    /// predicado, una rama del `else` se quedaría sin motivo y caería al copy de red.
    @Test func blockerIsExactNegationOfTheProductionGuard() {
        for backendEnabled in [true, false] {
            for isBackendGroup in [true, false] {
                let canEmit = backendEnabled && isBackendGroup
                let blocker = GroupInviteLinkCreationLogic.blocker(
                    backendEnabled: backendEnabled, isBackendGroup: isBackendGroup)
                #expect((blocker == nil) == canEmit,
                        "Descuadre en (\(backendEnabled), \(isBackendGroup))")
            }
        }
    }
}

/// Cableado de producción (source-scan). Las dos superficies necesitan un `SplitGroup` y un flag global
/// para ejercitarse de verdad; el scan fija lo que importa y es barato: que **las dos** consuman el
/// clasificador y que las tres claves de copy sigan repartidas por causa.
@Suite("Copy por causa del enlace · cableado de producción (source-scan)")
struct GroupInviteLinkCreationWiringTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
    }

    /// Las DOS superficies. Que fueran dos y no una fue la corrección de la primera pasada del ticket:
    /// arreglar solo `GroupMembersView` dejaba a `GroupDetailView` culpando a la conexión.
    private static let surfaces = [
        "Yala/App/Views/Groups/GroupMembersView.swift",
        "Yala/App/ViewModels/GroupDetailViewModel.swift",
    ]

    @Test func bothSurfaces_classifyByCause() throws {
        for path in Self.surfaces {
            let src = try Self.source(path)
            #expect(src.contains("GroupInviteLinkCreationLogic.blocker("),
                    "\(path) no clasifica la causa del bloqueo.")
            #expect(src.contains("L10n.Groups.Errors.inviteLegacyGroup"),
                    "\(path) no tiene copy para el grupo de la era CloudKit (permanente).")
            #expect(src.contains("L10n.Groups.Errors.inviteChannelOff"),
                    "\(path) no tiene copy para el canal apagado (transitorio).")
        }
    }

    /// `inviteFailed` («revisa tu conexión») sobrevive SOLO donde es cierto: el `catch` del RPC.
    ///
    /// **Comprueba DÓNDE aparece, no cuántas veces.** La primera versión de este test contaba usos
    /// (`== 2`) y la MUTACIÓN la refutó: devolver el `else` a `surfaceActionError(inviteFailed)` deja
    /// exactamente 2 usos igual, así que pasaba en verde con el bug puesto — el fallo que su propio
    /// nombre promete detectar. Ahora aísla el bloque del `else` y exige que la única línea que nombre
    /// el copy de red ahí dentro sea el `case nil` inalcanzable del clasificador.
    @Test func networkCopyStaysInTheCatchOnly() throws {
        for path in Self.surfaces {
            let src = try Self.source(path)
            let afterGuard = try #require(
                src.components(separatedBy: "if CloudSyncFlags.groupsBackendEnabled && group.isBackendGroup {")
                    .dropFirst().first,
                "\(path): el guard cambió de forma — re-ancla este scan.")
            let elseBlock = try #require(
                afterGuard.components(separatedBy: "} else {").dropFirst().first,
                "\(path): el `else` del guard desapareció.")
            // Hasta el `catch`, que es donde el copy de red SÍ es correcto.
            let elseBody = elseBlock.components(separatedBy: "} catch").first ?? elseBlock

            for line in elseBody.split(separator: "\n")
            where line.contains("L10n.Groups.Errors.inviteFailed") {
                #expect(line.contains("case nil"),
                        """
                        \(path): el `else` vuelve a culpar a la conexión fuera del `case nil`. \
                        Línea: \(line.trimmingCharacters(in: .whitespaces))
                        """)
            }
            // Control positivo: si el aislamiento fallara y `elseBody` saliera vacío, el bucle de arriba
            // no iteraría y el test pasaría sin mirar nada.
            #expect(elseBody.contains("GroupInviteLinkCreationLogic.blocker("),
                    "\(path): el bloque aislado no es el `else` esperado — el scan mide en vacío.")
        }
    }
}
