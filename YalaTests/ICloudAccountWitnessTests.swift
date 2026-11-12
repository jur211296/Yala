//
//  ICloudAccountWitnessTests.swift
//  YalaTests
//
//  **Con iCloud Drive apagado hay cuenta de iCloud: lo dice CloudKit, no el token de Drive** (cards 90yc, 2taf y n5zw del
//  lote 12.2). El token (`ubiquityIdentityToken`) solo mide Drive; con Drive apagado y la sesión abierta CloudKit
//  funciona y el espejo sincroniza. Tres cosas que esta suite fija:
//
//   · el testigo (`ICloudAccountWitness.hasAccount`) acepta CUALQUIERA de las dos pruebas y, sin respuesta de CloudKit,
//     decide el token como hasta hoy;
//   · el servicio lo usa donde la pregunta es «¿hay cuenta a la que hablar?»: el estado `.noAccount` de la pantalla de
//     iCloud (90yc) y la espera al import de los borrados del Welcome (2taf), que salía `false` al instante;
//   · el mount `.localNoMirror` nombra su contenedor (n5zw): con `.automatic` tomaba el primero de los entitlements, que
//     en `Yala Dev` es el de producción, y vaciaba la copia local al apagar Drive.
//

import CloudKit
import Foundation
import Testing

@testable import Yala

@Suite("Testigo de cuenta de iCloud · lógica pura")
struct ICloudAccountWitnessLogicTests {

    @Test func driveOff_cloudKitAvailable_hasAccount() {
        #expect(ICloudAccountWitness.hasAccount(tokenPresent: false, cloudKitStatus: .available))
    }

    @Test func tokenPresent_hasAccount_whateverCloudKitSays() {
        #expect(ICloudAccountWitness.hasAccount(tokenPresent: true, cloudKitStatus: nil))
        #expect(ICloudAccountWitness.hasAccount(tokenPresent: true, cloudKitStatus: .available))
    }

    /// Sin ninguna de las dos pruebas no hay cuenta: CloudKit sin respuesta decide el token, como antes del testigo.
    @Test func noTokenAndNoCloudKitYes_hasNoAccount() {
        for status: CKAccountStatus? in [nil, .noAccount, .restricted, .couldNotDetermine, .temporarilyUnavailable] {
            #expect(!ICloudAccountWitness.hasAccount(tokenPresent: false, cloudKitStatus: status),
                    "Sin token y con CloudKit en \(String(describing: status)) se leyó cuenta.")
        }
    }
}

@Suite("Testigo de cuenta de iCloud · el servicio", .serialized)
struct ICloudAccountWitnessServiceTests {

    /// El teléfono de las tres cards: Drive apagado (sin token) y CloudKit con lo que se le pase.
    @MainActor
    private func driveOffService(cloudKit status: CKAccountStatus?) -> iCloudSyncService {
        let service = iCloudSyncService.shared
        service._testReset()
        service._testForceAccountAvailable = false
        service._testSetCloudKitAccountStatus(status)
        return service
    }

    /// 90yc: con Drive apagado y CloudKit vivo, el estado no se queda en «iCloud no está activo».
    @MainActor @Test func driveOff_cloudKitAvailable_statusIsNotNoAccount() {
        let service = driveOffService(cloudKit: .available)
        service.checkAccountStatus()
        #expect(service.hasICloudAccount)
        #expect(!service.status.isNoAccount, "Con CloudKit vivo la pantalla diría «iCloud no está activo».")
    }

    /// Control de 90yc: sin cuenta de verdad, el estado sí dice que no la hay.
    @MainActor @Test func driveOff_cloudKitNoAccount_statusIsNoAccount() {
        let service = driveOffService(cloudKit: .noAccount)
        service.checkAccountStatus()
        #expect(!service.hasICloudAccount)
        #expect(service.status.isNoAccount)
    }

    /// 2taf: con Drive apagado y CloudKit vivo, la espera al import espera de verdad. Con el import ya asentado (terminó
    /// hace un minuto) devuelve `true`; con el guard del token salía `false` al instante sin mirar nada.
    @MainActor @Test func driveOff_cloudKitAvailable_waitForImportQuiescence_waits() async {
        let service = driveOffService(cloudKit: .available)
        service.apply(eventType: .importEvent, error: nil, endDate: Date.now.addingTimeInterval(-60))
        #expect(await service.waitForImportQuiescence(timeout: 2))
    }

    /// Control de 2taf: sin cuenta, la espera sigue saliendo `false` al instante (no hay import que esperar), también
    /// con el mismo import asentado: el término que decide es la cuenta.
    @MainActor @Test func driveOff_cloudKitNoAccount_waitForImportQuiescence_doesNotWait() async {
        let service = driveOffService(cloudKit: .noAccount)
        service.apply(eventType: .importEvent, error: nil, endDate: Date.now.addingTimeInterval(-60))
        #expect(await service.waitForImportQuiescence(timeout: 2) == false)
    }
}

@Suite("Testigo de cuenta de iCloud · cableado (source-scan)")
struct ICloudAccountWitnessWiringTests {

    private static func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    /// n5zw: `.localNoMirror` nombra el MISMO contenedor que `.iCloudMirror`. Sin `cloudKitDatabase:` vuelve a
    /// `.automatic`, que en `Yala Dev` sincroniza contra el contenedor de producción al apagar iCloud Drive.
    @Test func localNoMirror_namesItsContainer() throws {
        let code = try Self.source("Yala/Utils/SwiftDataConfiguration.swift")
        let start = try #require(code.range(of: "        case .localNoMirror:\n            // Card n5zw"))
        let tail = code[start.upperBound...]
        let end = try #require(tail.range(of: "\n        }"))
        let branch = tail[..<end.lowerBound]
        #expect(branch.contains("cloudKitDatabase: .private(cloudKitContainerIdentifier)"))
        // Partido a propósito: entero, `ModelConfigurationCloudKitWiringTests` lo leería como una construcción sin
        // `cloudKitDatabase:` dentro de los tests.
        let bareMount = "return Model" + "Configuration(databaseName, schema: personalSchema)\n"
        #expect(!code.contains(bareMount), "Queda un mount del store personal sin `cloudKitDatabase:`: cae en `.automatic`.")
    }

    /// Las cuatro preguntas «¿hay cuenta a la que hablar?» del servicio usan el testigo, no el token de Drive.
    @Test func serviceGuards_useTheAccountWitness() throws {
        let code = try Self.source("Yala/Services/iCloudSyncService.swift")
        for guardLine in [
            "func checkAccountStatus() {\n        if !hasICloudAccount {",
            "func forceFetchAndWait(timeout: TimeInterval = 15) async -> Bool {\n        guard hasICloudAccount else { return false }",
            "guard hasICloudAccount else { return false }\n        let deadline = Date.now.addingTimeInterval(timeout)",
            "func forceSync(modelContext: ModelContext) async -> ManualSyncResult {\n        guard hasICloudAccount else {",
        ] {
            #expect(code.contains(guardLine), "Falta el testigo de cuenta en: \(guardLine)")
        }
    }
}
