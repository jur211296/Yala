//
//  SignOutBackendGroupRowsTests.swift
//  YalaTests / CloudSync
//
//  Paso 9 del rediseño de sesiones: la privada sin sesión (C) OLVIDA los grupos del canal backend al cerrar
//  —una sesión de grupos que caducó—, y su hoja lo dice. `CloudSessionSignOut.hasBackendGroupRows` decide qué
//  filas cuentan como del canal. La review adversarial lo encontró sin ningún test: invertir el predicado
//  dejaba grupos ajenos a la vista de la persona siguiente, o borraba los de la era CloudKit que no tienen de
//  dónde volver.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Cierre privado · ¿guarda filas del canal de grupos?", .serialized)
@MainActor
struct SignOutBackendGroupRowsTests {

    @Test("sin grupos, no")
    func noGroups_isFalse() throws {
        let context = try makeTestContext()
        #expect(!CloudSessionSignOut.hasBackendGroupRows(context: context))
    }

    /// La era CloudKit que nunca migró no tiene de dónde volver: se queda en el dispositivo.
    @Test("un grupo solo de CloudKit, sin migrar, no cuenta")
    func legacyCloudKitGroup_isFalse() throws {
        let context = try makeTestContext()
        context.insert(SplitGroup(name: "Viaje"))
        try context.save()
        #expect(!CloudSessionSignOut.hasBackendGroupRows(context: context))
    }

    @Test("un grupo del canal backend cuenta")
    func backendGroup_isTrue() throws {
        let context = try makeTestContext()
        let group = SplitGroup(name: "Piso")
        group.isBackendGroup = true
        context.insert(group)
        try context.save()
        #expect(CloudSessionSignOut.hasBackendGroupRows(context: context))
    }

    /// El flip de canal marca solo una fila de las que comparten zona: la que ya se movió cuenta aunque no
    /// lleve `isBackendGroup`, igual que en el resto de guards del canal.
    @Test("un grupo que ya se movió al backend cuenta aunque no esté marcado")
    func movedToBackend_isTrue() throws {
        let context = try makeTestContext()
        let group = SplitGroup(name: "Oficina")
        group.movedToBackendAt = Date(timeIntervalSince1970: 1_700_000_000)
        context.insert(group)
        try context.save()
        #expect(CloudSessionSignOut.hasBackendGroupRows(context: context))
    }
}
