//
//  RestoreICloudDriveOffTests.swift
//  YalaTests
//
//  Card 6a12 (ticket `restore-with-icloud-drive-off-mounts-without-mirror`): con la sesión de iCloud abierta y iCloud
//  Drive apagado, Restaurar decía «Activa iCloud» porque preguntaba por el token de Drive. Ahora pregunta por la cuenta
//  de CloudKit y, si CloudKit no contestó todavía, le pregunta antes de decidir. La lógica es pura y se prueba de
//  frente; el cableado de las dos vistas se fija con escáneres acotados al cuerpo que importa.
//

import CloudKit
import Foundation
import Testing

@testable import Yala

@MainActor
@Suite("Restaurar con iCloud Drive apagado (card 6a12)")
struct RestoreICloudDriveOffTests {

    // MARK: - La decisión

    @Test("Drive apagado y CloudKit con cuenta: hay cuenta y se busca")
    func driveOff_cloudKitAvailable_isPresent() {
        #expect(WelcomeRestoreRelaunchLogic.accountCheck(
            tokenPresent: false, cloudKitStatus: .available, alreadyAsked: false) == .present)
        #expect(WelcomeRestoreRelaunchLogic.accountCheck(
            tokenPresent: false, cloudKitStatus: .available, alreadyAsked: true) == .present)
    }

    @Test("Con el token de Drive hay cuenta, diga lo que diga CloudKit")
    func token_isPresent() {
        let statuses: [CKAccountStatus?] = [nil, .available, .noAccount, .couldNotDetermine, .restricted]
        for status in statuses {
            #expect(WelcomeRestoreRelaunchLogic.accountCheck(
                tokenPresent: true, cloudKitStatus: status, alreadyAsked: false) == .present)
        }
    }

    @Test("Sin token y sin respuesta de CloudKit: se pregunta UNA vez antes de decir «Activa iCloud»")
    func noToken_unanswered_asksOnce() {
        #expect(WelcomeRestoreRelaunchLogic.accountCheck(
            tokenPresent: false, cloudKitStatus: nil, alreadyAsked: false) == .askCloudKit)
        #expect(WelcomeRestoreRelaunchLogic.accountCheck(
            tokenPresent: false, cloudKitStatus: nil, alreadyAsked: true) == .absent,
                "tras preguntar, sin respuesta no se vuelve a preguntar: la pantalla no puede quedarse colgada")
    }

    @Test("Sin cuenta sigue diciendo «Activa iCloud»")
    func noAccount_isAbsent() {
        let statuses: [CKAccountStatus] = [.noAccount, .restricted, .couldNotDetermine, .temporarilyUnavailable]
        for status in statuses {
            #expect(WelcomeRestoreRelaunchLogic.accountCheck(
                tokenPresent: false, cloudKitStatus: status, alreadyAsked: false) == .absent, "\(status.rawValue)")
        }
    }

    @Test("Con cuenta, se reabre desde el store neutro; tras reabrir con Drive apagado, no hay bucle")
    func relaunchOnlyFromTheNeutralMount() {
        #expect(WelcomeRestoreRelaunchLogic.needsRelaunchToSearch(
            iCloudAccountPresent: true, mountedDecision: .neutralNoMirror))
        #expect(!WelcomeRestoreRelaunchLogic.needsRelaunchToSearch(
            iCloudAccountPresent: true, mountedDecision: .localNoMirror),
                "el mount de Drive apagado ya trae el espejo: pedir reabrir otra vez sería el bucle")
        #expect(WelcomeRestoreRelaunchLogic.skipsRelaunch(destination: .restoreICloud, iCloudAccountPresent: false))
        #expect(!WelcomeRestoreRelaunchLogic.skipsRelaunch(destination: .restoreICloud, iCloudAccountPresent: true))
    }

    @Test("Tras reabrir con Drive apagado, la tabla monta el espejo y no el neutro")
    func mountAfterRelaunch_driveOff_attachesTheMirror() {
        // El relanzamiento marca el chooser (ContentView), así que ni el neutro de instalación nueva ni el durable valen.
        let decision = SwiftDataConfiguration.personalStoreDecision(
            storageMode: .icloud, mirrorOffArmed: false, iCloudAvailable: false,
            freshInstall: false, neutralDurable: false)
        #expect(decision == .localNoMirror)
        #expect(decision.attachesCloudKitMirror)
    }

    // MARK: - El cableado

    @Test("Restaurar decide con la cuenta de CloudKit antes de reabrir, del wipe y de encender la señal")
    func startSearch_decidesWithTheCloudKitAccount() throws {
        let src = try Self.code("Yala/App/Views/Onboarding/WelcomeRestoreView.swift")
        let search = try Self.body(of: "private func startSearch(afterAskingCloudKit: Bool = false) {", in: src)
        #expect(!search.contains("isAccountAvailable else"), "volvió la puerta por el token de iCloud Drive")
        let check = try #require(search.range(of: "WelcomeRestoreRelaunchLogic.accountCheck("))
        #expect(search.contains("tokenPresent: sync.isAccountAvailable"))
        #expect(search.contains("cloudKitStatus: sync.cloudKitAccountStatus"))
        #expect(search.contains("alreadyAsked: afterAskingCloudKit"))
        #expect(search.contains("startSearch(afterAskingCloudKit: true)"), "tras preguntar hay que volver a decidir")
        let relaunch = try #require(search.range(of: "onNeedsMirrorRelaunch()"))
        let wiped = try #require(search.range(of: "RestoreOfferGate.wasWiped("))
        let started = try #require(search.range(of: "ICloudRestoreSessionSignal.noteRestoreStarted("))
        #expect(check.lowerBound < relaunch.lowerBound
                && check.lowerBound < wiped.lowerBound
                && check.lowerBound < started.lowerBound)
    }

    @Test("El Welcome hace la misma pregunta que Restaurar: la cuenta, no el token")
    func welcomePortal_asksTheSameQuestion() throws {
        let src = try Self.code("Yala/App/Views/Onboarding/WelcomeFlowContainer.swift")
        let portal = try Self.body(
            of: "private func leaveWelcome(to destination: WelcomeMirrorRelaunchLogic.Destination,", in: src)
        #expect(portal.contains("iCloudAccountPresent: iCloudSyncService.shared.hasICloudAccount"))
        #expect(!portal.contains("isAccountAvailable"))
    }

    // MARK: - Helpers

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // raíz del repo
    }

    private static func code(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// El cuerpo entre la llave que sigue al marcador y la que la cierra.
    private static func body(of marker: String, in source: String) throws -> String {
        let start = try #require(source.range(of: marker), "marcador no encontrado: \(marker)")
        let chars = Array(source[start.upperBound...])
        var depth = 1, i = 0
        while i < chars.count {
            if chars[i] == "{" { depth += 1 }
            if chars[i] == "}" { depth -= 1; if depth == 0 { break } }
            i += 1
        }
        return String(chars[0..<min(i, chars.count)])
    }
}
