//
//  DeletedGroupInviteWiringTests.swift
//  YalaTests
//
//  `invite-link-five-causes-one-message` pieza 1 · el grupo borrado deja de dar un consejo imposible.
//

import Foundation
import Testing

@testable import Yala

/// El mensaje se elige dentro de un `switch` en un servicio con dependencias de router y métricas, así
/// que un unit test tendría que montar media app para llegar. El source-scan cubre lo que importa: que
/// el caso nuevo NO caiga en el copy viejo.
///
/// **Por qué merece red propia.** El defecto del ticket no era que faltara un mensaje: era que el que
/// había terminaba en «pídele al admin que regenere uno», y para un grupo borrado eso manda a una acción
/// imposible — no hay grupo ni admin a quien pedírselo. Si alguien colapsa el caso nuevo otra vez en
/// `.invalidInvite`, todo compila, todo pasa, y el usuario vuelve a perseguir un enlace que nadie puede
/// darle.
@Suite("Invitación a grupo borrado · cableado del mensaje (source-scan)")
struct DeletedGroupInviteWiringTests {

    private static func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    @Test("El grupo borrado tiene su propio mensaje, y NO el del enlace inválido")
    func deletedGroup_usesItsOwnCopy() throws {
        let src = try Self.source("Yala/App/Services/GroupBackendInviteEntryHandler.swift")

        #expect(src.contains("if kind == .groupDeleted {"), """
            El caso tiene que ramificar ANTES que `.invalidInvite`: si cae en el mismo `if`, hereda el
            copy con el consejo imposible.
            """)
        #expect(src.contains("groups.reconnect.deletedForAll.body"), """
            El copy reutilizado dice exactamente el hecho («Este grupo fue eliminado por su creador») y
            ya está traducido a los 16 idiomas. Si alguien lo cambia por una clave nueva, que sea una
            decisión consciente y no un descuido.
            """)
    }

    /// El servidor tiene que seguir distinguiendo los dos casos. Si la migración se revierte o alguien
    /// devuelve el `raise` a `yala_invalid_invite`, el cliente queda correcto y el usuario vuelve a ver
    /// el consejo imposible — sin que nada se ponga rojo salvo esto.
    @Test("El DDL distingue el grupo borrado, y NO rompe el no-oráculo de las otras cuatro causas")
    func ddl_separatesDeletedGroupWithoutBreakingTheNonOracle() throws {
        let sql = try Self.source("qa/cloud/g13_03_join_group_distinguishes_deleted.sql")

        #expect(sql.contains("raise exception 'yala_group_deleted'"), """
            La quinta causa (grupo borrado) necesita su propio código.
            """)
        #expect(sql.contains("raise exception 'yala_invalid_invite'"), """
            Y las otras CUATRO tienen que seguir colapsadas: distinguirlas sí sería un oráculo, porque
            permitiría sondear qué tokens existen. El golden `3-quater` lo comprueba contra la BD.
            """)
    }
}
