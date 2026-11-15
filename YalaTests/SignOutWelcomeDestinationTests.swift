//
//  SignOutWelcomeDestinationTests.swift
//  YalaTests
//
//  Card 7e60 (iPhone 14, iOS 27.2, 2026-11-05): tras cerrar sesión en la nube, cada apertura de Yala decía «Un último
//  paso: reabre Yala», sin salida. Un destino del Welcome de antes del cierre («Restaurar desde iCloud», que nadie
//  consumió) sobrevivía al borrado; el arranque abría Restaurar sin pasar por el Welcome, Restaurar pedía reabrir para
//  conectar iCloud y, con `hasShownWelcomeChooser` borrado y el neutro armado, el arranque volvía a montar sin espejo.
//  Dos cortes, cada uno con su caso: el cierre decide el destino (retira el viejo) y Restaurar marca la elección.
//  `CloudSessionSignOut` y el encaminamiento de `ContentView` no se pueden conducir hasta el arm en un test, así que el
//  cableado lo fija leer el fuente.
//

import Foundation
import Testing

@testable import Yala

@Suite("Destino del Welcome tras cerrar sesión (source-scan + store)")
struct SignOutWelcomeDestinationTests {

    private static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    /// Líneas de código (sin comentarios ni vacías), recortadas.
    private static func codeLines(_ path: String) throws -> [String] {
        try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("//") && !$0.hasPrefix("///") }
    }

    // MARK: - El store

    @Test("`clear` retira el destino: el arranque siguiente no encamina a ningún sitio")
    func clear_removesThePendingDestination() throws {
        let defaults = try #require(testDefaults(suiteName: "test.\(UUID().uuidString)"))
        WelcomePendingDestinationStore.set(.restoreICloud, defaults: defaults)
        #expect(WelcomePendingDestinationStore.peek(defaults) == .restoreICloud)
        WelcomePendingDestinationStore.clear(defaults)
        #expect(WelcomePendingDestinationStore.peek(defaults) == nil)
    }

    // MARK: - El cierre decide el destino

    @Test("Sin destino propio, el cierre retira el que hubiera")
    func persistDestinationOnArm_clearsWhenTheSignOutHasNone() throws {
        let lines = try Self.codeLines("Yala/Services/CloudSync/CloudSessionSignOut.swift")
        let start = try #require(lines.firstIndex(of: "private func persistDestinationOnArm() {"))
        let body = Array(lines[(start + 1)..<(start + 8)])
        #expect(body == [
            "if let destinationOnArm {",
            "WelcomePendingDestinationStore.set(destinationOnArm)",
            "} else {",
            "WelcomePendingDestinationStore.clear()",
            "}",
            "destinationOnArm = nil",
            "}",
        ])
    }

    @Test("Cada arm del borrado escribe o retira el destino pegado a él; el borrado de cuenta siempre retira")
    func everyArm_decidesTheDestination() throws {
        let lines = try Self.codeLines("Yala/Services/CloudSync/CloudSessionSignOut.swift")
        let arms = lines.indices.filter { lines[$0] == "StorageModePersistence.armSignOutWipe()" }
        // El quinto es «Empezar de cero» en un teléfono en la nube (opción A del 13-nov), que retira como el borrado de cuenta.
        #expect(arms.count == 5)
        var persisted = 0
        var cleared = 0
        for arm in arms {
            // El arm, su rastro y el destino, en ese orden y sin nada en medio que pueda suspender.
            #expect(lines[arm + 1] == "CloudSyncBreadcrumb.signOutWipeArmed()")
            if lines[arm + 2] == "persistDestinationOnArm()" {
                persisted += 1
            } else {
                // El borrado de la cuenta no trae destino, y el que quedara en `destinationOnArm` sería de un cierre
                // anterior que salió sin armar: se retira sin escribirlo.
                #expect(lines[arm + 2] == "destinationOnArm = nil")
                #expect(lines[arm + 3] == "WelcomePendingDestinationStore.clear()")
                cleared += 1
            }
        }
        #expect(persisted == 2)
        #expect(cleared == 3)
    }

    // MARK: - Restaurar marca la elección

    @Test("Restaurar que pide reabrir marca que ya se eligió, antes de escribir el destino")
    func restoreNeedsMirrorRelaunch_marksTheChoice() throws {
        let lines = try Self.codeLines("Yala/App/ContentView.swift")
        let destination = try #require(lines.firstIndex(of: "WelcomePendingDestinationStore.set(.restoreICloud)"))
        // El callback de Restaurar es el único que escribe ese destino a mano.
        #expect(lines.filter { $0 == "WelcomePendingDestinationStore.set(.restoreICloud)" }.count == 1)
        let callbackStart = try #require(lines[..<destination].lastIndex(of: "onNeedsMirrorRelaunch: {"))
        let callback = Array(lines[callbackStart..<destination])
        #expect(callback.contains("hasShownWelcomeChooser = true"))
        #expect(callback.contains("StorageModePersistence.clearGroupsOnlyNeutralMount()"))
    }

    @Test("Con la elección marcada, el neutro armado ya no se monta: el arranque siguiente trae el espejo")
    func markedChoice_unmountsTheArmedNeutral() {
        #expect(SwiftDataConfiguration.shouldMountNeutralDurable(
            neutralMountArmed: true, hasShownWelcomeChooser: false, groupsOnlySessionArmed: false,
            persistedMode: .icloud, mirrorOffArmed: false))
        #expect(!SwiftDataConfiguration.shouldMountNeutralDurable(
            neutralMountArmed: true, hasShownWelcomeChooser: true, groupsOnlySessionArmed: false,
            persistedMode: .icloud, mirrorOffArmed: false))
    }
}
