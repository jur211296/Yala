//
//  GroupLeaveSurfacesWiringTests.swift
//  YalaTests / CloudSync
//
//  Source-scan de CABLEADO, molde `AttestWiringTests`. Existe porque el test de comportamiento no puede
//  ver esto: `GroupLeaveErrorLogicTests` seguiría verde si alguien devolviera `error.localizedDescription`
//  a cualquiera de las dos vistas de salida — la clasificación seguiría siendo correcta y el alert volvería
//  a pintar «(Error de Yala.GroupsRPCError 11.)». Lo que se fija aquí es que las superficies SIGAN
//  cableadas al clasificador, que es la mitad que un verde de unit test no prueba.
//

import Foundation
import Testing

@testable import Yala

@Suite("Salir de un grupo · las superficies no pintan el error crudo (source-scan)")
struct GroupLeaveSurfacesWiringTests {

    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    private func fuente(_ ruta: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(ruta), encoding: .utf8)
    }

    /// Las DOS superficies de salida asignan su mensaje desde `GroupLeaveErrorLogic`, nunca desde el
    /// `localizedDescription` del error.
    @Test(arguments: [
        "Yala/App/Views/Groups/GroupSettingsView.swift",
        "Yala/App/Views/Groups/GroupsContainerView.swift",
    ])
    func leaveSurfaces_areWiredToTheClassifier(ruta: String) throws {
        let src = try fuente(ruta)

        // Control POSITIVO: si el fichero deja de contener la marca, el scan mide otra cosa (fichero
        // movido o renombrado) y hay que arreglar el test, no darlo por bueno.
        #expect(src.contains("leaveErrorMessage"), "\(ruta) ya no tiene el estado del alert de salir")

        #expect(src.contains("GroupLeaveErrorLogic.classify"),
                "\(ruta) debe elegir el copy con GroupLeaveErrorLogic")
        #expect(!src.contains("leaveErrorMessage = error.localizedDescription"),
                "\(ruta) volvió a pintar el discriminante crudo del enum")
    }

    /// La salida del DUEÑO («Transferir y salir») tiene que seguir CABLEADA al offer, no a
    /// `group.isOwner` a pelo.
    ///
    /// Esto un unit test no lo ve: `GroupOwnerExitLogicTests` seguiría verde si la vista volviera a
    /// decidir con el booleano local, y el dueño con deuda volvería al callejón sin salida que este
    /// trabajo cierra — sin que nada se ponga rojo. Es el mismo hueco que motivó el resto del fichero.
    @Test func ownerExit_isWiredToTheOffer_notToTheLocalFlag() throws {
        let src = try fuente("Yala/App/Views/Groups/GroupSettingsView.swift")

        // Control POSITIVO: si desaparece la sección, el scan mide otra cosa y hay que arreglar el
        // test, no darlo por bueno.
        #expect(src.contains("transferAndLeaveSection"),
                "GroupSettingsView ya no tiene la sección de transferir")

        #expect(src.contains("GroupService.shared.ownerExitOffer"),
                "la pantalla debe pedir el offer al servicio")

        // El scan se ACOTA al bloque que elige las secciones de salida. Buscar `group.isOwner` en
        // todo el fichero daría un falso positivo real y medido: la sección de opciones usa
        // `if !group.isOwner` para el hint de «solo el dueño» (moneda única), que no tiene nada que
        // ver con esta decisión y es legítimo.
        // 1000 y no 700: la tercera sección (`showsDelete`) empieza en el carácter 782 del bloque —
        // medido, no estimado. Un prefijo corto dejaría fuera justo la aserción que importa y el
        // test pasaría a fijar dos tercios de lo que dice fijar.
        let bloque = try #require(src.range(of: "// Leave group (non-owner)").map {
            String(src[$0.lowerBound...].prefix(1000))
        })
        // Las tres decisiones de salida salen del offer…
        #expect(bloque.contains("currentOffer.showsLeave"))
        #expect(bloque.contains("currentOffer.showsTransferAndLeave"))
        #expect(bloque.contains("currentOffer.showsDelete"))
        // …y ninguna vuelve al flag device-local, que es lo que dejaba sin salida al dueño.
        #expect(!bloque.contains("group.isOwner"),
                "una sección de salida volvió a decidirse con el flag device-local")
        #expect(!src.contains(".disabled(hasOutstandingDebt || isDeleting)"),
                "«Eliminar» volvió a leer la deuda sin pasar por el offer")
    }

    /// El fallo de la transferencia tampoco puede pintar el discriminante crudo del enum.
    @Test func transferAndLeave_doesNotShowRawErrors() throws {
        let src = try fuente("Yala/App/Views/Groups/GroupSettingsView.swift")
        let cuerpo = try #require(src.range(of: "private func transferAndLeave()").map {
            String(src[$0.lowerBound...].prefix(1800))
        })
        #expect(cuerpo.contains("GroupLeaveErrorLogic.classify"))
        #expect(!cuerpo.contains("actionErrorMessage = error.localizedDescription"))
        // El «no queda heredero» NO es un error: llega como outcome del RPC y tiene copy propio.
        #expect(cuerpo.contains("L10n.Groups.Errors.transferNoHeir"))
    }

    /// Y el destino al que manda el copy de `ownerCannotLeave` («…puedes eliminarlo») tampoco puede
    /// recibir al usuario con una dev-string en inglés de `GroupServiceError`.
    @Test func softDelete_doesNotShowDevStrings() throws {
        let src = try fuente("Yala/App/Views/Groups/GroupSettingsView.swift")
        let cuerpo = try #require(src.range(of: "private func performSoftDelete()").map {
            String(src[$0.lowerBound...].prefix(1400))
        })
        #expect(cuerpo.contains("GroupLeaveErrorLogic.classify"))
        #expect(!cuerpo.contains("actionErrorMessage = error.localizedDescription"))
    }
}
