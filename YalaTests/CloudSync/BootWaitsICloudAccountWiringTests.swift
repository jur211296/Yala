//
//  BootWaitsICloudAccountWiringTests.swift
//  YalaTests
//
//  Cards dtex y jzti (2026-11-05). Las esperas del arranque y la puerta del cierre con grupos deciden «¿hay cuenta?» con
//  `iCloudSyncService.hasICloudAccount` (token de iCloud Drive O CloudKit `.available`), no con el token solo: con Drive
//  apagado y la sesión de iCloud abierta el espejo importa igual, y con el token esas esperas se saltaban y el arranque
//  guardaba en plena importación. Las tablas de las dos decisiones las fijan `MigrationGateLogicTests`,
//  `BootSaveGateLogicTests` y `CloudSignOutFlowLogicTests`; esto fija qué testigo les llega.
//

import CloudKit
import Foundation
import Testing
@testable import Yala

@MainActor
@Suite("Esperas del arranque y del cierre · la cuenta de iCloud, no el token de Drive")
struct BootWaitsICloudAccountWiringTests {

    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private static func normalized(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("//") }
            .joined(separator: " ")
    }

    private static func count(_ needle: String, in haystack: String) -> Int {
        haystack.components(separatedBy: needle).count - 1
    }

    @Test("las tres decisiones del arranque reciben `hasICloudAccount`, tras esperar a CloudKit con techo")
    func bootWaitsReadTheAccountWitness() throws {
        let boot = try Self.normalized("Yala/App/AppBootstrapper.swift")
        #expect(Self.count("isAccountAvailable: iCloudSyncService.shared.isAccountAvailable", in: boot) == 0,
                "una espera del arranque vuelve a leer el token de iCloud Drive: con Drive apagado se salta y guarda en plena importación")
        #expect(Self.count("isAccountAvailable: iCloudSyncService.shared.hasICloudAccount", in: boot) == 3)
        // Una espera en el paso 8.5 y otra al entrar en la de los guardados del arranque, cada una antes de su decisión.
        #expect(Self.count("await iCloudSyncService.shared.awaitCloudKitAccountStatus(timeout: Self.bootAccountStatusTimeout)", in: boot) == 2)
        #expect(boot.contains("await iCloudSyncService.shared.awaitCloudKitAccountStatus(timeout: Self.bootAccountStatusTimeout) let decision = MigrationGateLogic.shouldWaitForCloudKit( isAccountAvailable: iCloudSyncService.shared.hasICloudAccount,"))
        #expect(boot.contains("await iCloudSyncService.shared.awaitCloudKitAccountStatus(timeout: Self.bootAccountStatusTimeout) func gateDecision() -> BootSaveGateLogic.Decision { BootSaveGateLogic.decide( isAccountAvailable: iCloudSyncService.shared.hasICloudAccount,"))
    }

    @Test("la puerta del cierre con grupos lee la cuenta y la salida del store que no importa")
    func groupsSignOutGateReadsTheAccountWitness() throws {
        let signOut = try Self.normalized("Yala/Services/CloudSync/CloudSessionSignOut.swift")
        #expect(signOut.contains("""
            let sync = iCloudSyncService.shared return CloudSignOutFlowLogic.isPersonalSaveSafe( \
            mountAttachesMirror: personalMountAttachesMirror, accountPresent: sync.hasICloudAccount, \
            firstImportCompleted: sync.hasCompletedFirstImport, importQuiescent: sync.isImportQuiescent, \
            observedImportActivity: sync.hasObservedImportActivity, noImportGraceElapsed: sync.noImportGraceElapsed, \
            syncingAnyPhase: sync.status.isSyncing)
            """))
    }

    @Test("sin pregunta a CloudKit en vuelo, la espera con techo vuelve al instante")
    func boundedWaitReturnsWithoutAQuestion() async {
        let sync = iCloudSyncService.shared
        #expect(!sync.isAwaitingCloudKitAccountStatus, "en el host de test no se pregunta a CloudKit")
        let start = ContinuousClock.now
        await sync.awaitCloudKitAccountStatus(timeout: 5)
        #expect(ContinuousClock.now - start < .seconds(1))
    }

    @Test("el testigo: sin respuesta de CloudKit decide el token; con `.available`, hay cuenta sin token")
    func witnessTable() {
        #expect(!ICloudAccountWitness.hasAccount(tokenPresent: false, cloudKitStatus: nil))
        #expect(ICloudAccountWitness.hasAccount(tokenPresent: false, cloudKitStatus: .available), "iCloud Drive apagado")
        #expect(!ICloudAccountWitness.hasAccount(tokenPresent: false, cloudKitStatus: .noAccount), "sin iCloud: nadie espera")
        #expect(ICloudAccountWitness.hasAccount(tokenPresent: true, cloudKitStatus: nil))
    }
}
