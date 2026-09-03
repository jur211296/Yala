//
//  RejectedMemberExitWiringTests.swift
//  YalaTests
//
//  `guest-decline-has-no-screen` · el rechazado tiene salida, y es local.
//

import Foundation
import Testing

@testable import Yala

/// El botón del banner de rechazo vive en una `View` y llama a un método `private`, así que no hay forma
/// de alcanzarlo desde un unit test. Este scan es lo que impide que vuelva a quedarse sin hacer nada —
/// molde de `NeutralMountWiringTests`, que existe por la misma razón.
///
/// **Y aquí el cableado es más que una conexión: sin él, el arreglo empeora el producto.** Mostrar el
/// aviso de rechazo hace que el grupo deje de desaparecer de la lista; si además el botón no lo quita,
/// el grupo se queda PEGADO para siempre con un cartel y sin salida. Peor que la desaparición silenciosa
/// que se venía a arreglar. Por eso el scan afirma las dos mitades: que llama a la limpieza, y que ya no
/// abre Ajustes.
@Suite("Rechazo en Grupos · cableado de la salida (source-scan)")
struct RejectedMemberExitWiringTests {

    private static func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    @Test("El botón del banner de rechazo quita el grupo del teléfono")
    func rejectedBannerButton_discardsTheGroupLocally() throws {
        let src = try Self.source("Yala/App/Views/Groups/GroupDetailView.swift")

        #expect(src.contains("PendingApprovalBanner(state: .rejected, onLeave: { discardRejectedGroup() })"), """
            El banner de rechazo tiene que llamar a la salida local.
            """)
        #expect(src.contains("GroupService.shared.performRemovedSelfCleanup("), """
            La salida es la limpieza local que ya existe, no una implementación nueva: es idempotente y
            es la misma que usa el pull cuando ve desaparecer una zona.
            """)
    }

    /// La versión anterior abría los Ajustes del grupo, donde el botón «salir del grupo» tampoco habría
    /// funcionado: `leave_group` exige `status in ('active','pendingApproval')` y a un `rejected` le
    /// responde `yala_member_not_found`. Mandar ahí a alguien es un callejón sin salida con dos pasos.
    @Test("La salida del rechazado NO pasa por Ajustes, que es un callejón sin salida")
    func rejectedBannerButton_doesNotOpenSettings() throws {
        let src = try Self.source("Yala/App/Views/Groups/GroupDetailView.swift")
        #expect(!src.contains("PendingApprovalBanner(state: .rejected, onLeave: {\n                        viewModel.activeSheet = .settings"), """
            Volver a mandar al rechazado a Ajustes le deja sin salida: el RPC de salir no acepta su
            estado. Si algún día `leave_group` lo acepta, esta aserción es el sitio donde consta.
            """)
    }

    /// El pull del gateway tiene que seguir entregando la membresía rechazada. Si alguien devuelve el
    /// filtro a `(active,pendingApproval)`, el estado no llega al teléfono, el banner no se pinta y el
    /// grupo vuelve a esfumarse en silencio — con la policy de la BD ya aplicada y sin que nada avise.
    @Test("El pull del gateway sigue pidiendo las membresías rechazadas")
    func gatewayPull_stillAsksForRejectedMemberships() throws {
        let src = try Self.source("gateway/src/groups/routes.ts")
        #expect(src.contains("status=in.(active,pendingApproval,rejected)"), """
            Sin `rejected` en el filtro, el paso 1 del pull no descubre el grupo y el paso 2 no pide sus
            deltas: la policy `g13_02` queda inerte y no cambia una sola pantalla.
            """)
    }
}
