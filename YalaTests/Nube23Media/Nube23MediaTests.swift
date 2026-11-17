//
//  Nube23MediaTests.swift
//  YalaTests
//
//  Encargo «Nube 2.3: los cinco bugs de prioridad media» (2026-11-16). Tres de los cinco cambian la app:
//   · volver a pasar a la nube con la misma cuenta: el claim de «Migrar» pide el re-cutover (`recutover`), y la hoja de
//     volver a iCloud deja de decir «Hoy no se puede»;
//   · modo iCloud: la salida se llama «Cerrar sesión» y su hoja nombra el botón de la bienvenida de hoy;
//   · el aviso del Panel «Tus datos ya están en tu cuenta» solo sale con el marcador de la cuenta del faro.
//  Lo del servidor lo prueba el banco de `qa/cloud/g31_01_claim_recutover_after_return_to_icloud.sql`.
//

import Foundation
import Testing
@testable import Yala

/// Stub HTTP que guarda el cuerpo del último POST.
private final class RecutoverStubHTTP: SyncHTTPSession, @unchecked Sendable {
    private(set) var lastBody: [String: Any]?

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastBody = (try? JSONSerialization.jsonObject(with: request.httpBody ?? Data())) as? [String: Any]
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (Data(#"{"state":"created","kind":"complete","recutover":true,"has_personal_writes":true}"#.utf8), response)
    }
}

@Suite("Nube 2.3 media · volver a la nube con la misma cuenta")
@MainActor
struct Nube23MediaRecutoverTests {

    private let base = URL(string: "https://gw.local/v1")!

    @Test("el cliente manda recutover solo cuando se pide, y nunca como false")
    func client_sendsRecutoverOnlyWhenAsked() async {
        let stub = RecutoverStubHTTP()
        let client = CloudAccountClient(baseURL: base, urlSession: stub)

        let asked = await client.claimReportingPersonalWrites(
            jwt: "j", deviceID: "d", provider: "google", migration: true, recutover: true)
        #expect(asked.outcome == .success(.created), "control: la respuesta del re-cutover se lee como un `created`")
        #expect(stub.lastBody?["recutover"] as? Bool == true)

        _ = await client.claimReportingPersonalWrites(jwt: "j", deviceID: "d", provider: "google", migration: true)
        #expect(stub.lastBody?["recutover"] == nil, "sin pedirlo no viaja la clave: un Worker viejo no la conoce")
        #expect(stub.lastBody?["migration"] as? Bool == true, "control: el cuerpo es el del claim de siempre")

        _ = await client.claim(jwt: "j", deviceID: "d", provider: "apple")
        #expect(stub.lastBody?["recutover"] == nil, "el alta born-cloud nunca lo pide")
    }

    @Test("la hoja de volver a iCloud ya no dice que hoy no se puede volver")
    func revertSheet_saysYouCanComeBack() throws {
        let src = try Nube23MediaSource.read("Yala/App/Views/Settings/ReturnToICloudSheet.swift")
        #expect(src.contains("detail: L10n.Nube23Media.revertCloudAgainDetail"))
        #expect(!src.contains("L10n.Storage.Revert.Sheet.cloudAgainDetail"))
        #expect(!L10n.Nube23Media.revertCloudAgainDetail.isEmpty)
        #expect(L10n.Nube23Media.revertCloudAgainDetail != "nube23media.revert.cloudAgainDetail", "la clave existe")
    }
}

@Suite("Nube 2.3 media · modo iCloud: «Cerrar sesión»")
@MainActor
struct Nube23MediaSignOutICloudTests {

    @Test("la hoja sin cuenta de Yala usa el título y el botón del cierre de siempre")
    func sheet_usesTheSignOutTitleAndButton() {
        for operation in [DestructiveScopeLogic.Operation.signOutPrivate, .signOutPrivateWithGroups] {
            let config = DestructiveScopeSheet.Config.make(operation: operation, cloudLabel: .icloud, onConfirm: {})
            #expect(config.title == L10n.Settings.signOutConfirmTitle, "\(operation)")
            #expect(config.confirmLabel == L10n.Settings.signOutConfirmAction, "\(operation)")
            #expect(config.title != L10n.UXCS.removeDeviceDataSheetTitle, "control: no es el título de antes")
        }
    }

    @Test("la nota de la hoja nombra el botón de la bienvenida de hoy, leído del propio botón")
    func conservationNote_namesTodaysWelcomeButton() {
        let button = L10n.Showcase.enterWithICloud
        let cases: [(DestructiveScopeLogic.Operation, String)] = [
            (.signOutPrivate, L10n.Nube23Media.signOutICloudConservation),
            (.signOutPrivateWithGroups, L10n.Nube23Media.signOutICloudConservationWithGroups),
        ]
        for (operation, note) in cases {
            #expect(note.contains(button), "\(operation): «\(note)» no nombra «\(button)»")
            #expect(!note.contains("%@"), "\(operation): el hueco se rellena")
            #expect(!note.contains(L10n.Welcome.Existing.restoreTitle), "\(operation): ya no nombra un botón que no está")
            let config = DestructiveScopeSheet.Config.make(operation: operation, cloudLabel: .icloud, onConfirm: {})
            if let shown = config.conservationNote { #expect(shown == note, "\(operation)") }
        }
    }

    @Test("los 16 idiomas traen las tres claves, y las dos notas con un solo hueco para el botón")
    func everyLanguage_hasTheKeys() throws {
        let languages = ["es", "es-419", "es-AR", "es-ES", "en", "en-GB", "de", "fr", "it", "ja", "zh-Hans", "nl", "pl",
                         "pt", "pt-BR", "pt-PT"]
        for language in languages {
            let strings = try Nube23MediaSource.read("Yala/Resources/\(language).lproj/Localizable.strings")
            let lines = strings.split(separator: "\n")
            for key in ["nube23media.signOutICloud.conservation", "nube23media.signOutICloud.conservationWithGroups"] {
                let line = try #require(lines.first { $0.hasPrefix("\"\(key)\" = ") }, "\(language) · \(key)")
                #expect(line.components(separatedBy: "%@").count == 2, "\(language) · \(key)")
            }
            #expect(strings.contains("\"nube23media.revert.cloudAgainDetail\" = "), "\(language)")
        }
    }

    @Test("la fila de Ajustes se llama «Cerrar sesión» también sin cuenta de Yala, en su tarjeta de siempre")
    func row_isCalledSignOut() throws {
        let src = try Nube23MediaSource.read("Yala/App/Views/Profile/ProfileView.swift")
        #expect(src.contains("title: L10n.Settings.signOut,"))
        #expect(!src.contains("L10n.UXCS.removeDeviceDataRow"))
        #expect(src.contains("if signOutRowRemovesDeviceData {\n                                removeDeviceDataSection"),
                "la fila no se mueve: sigue en su tarjeta del final")
    }
}

@Suite("Nube 2.3 media · el aviso del Panel solo con el marcador de la cuenta del faro")
@MainActor
struct Nube23MediaAdoptOfferTests {

    // Hashes fijos (los de `CloudBeacon.hash` son de 16 hex): la lógica compara cadenas, no los calcula.
    private let hashA = "0123456789abcdef"
    private let hashB = "fedcba9876543210"

    @Test("el marcador tiene que ser de la cuenta del faro")
    func markerMustNameTheBeaconAccount() {
        #expect(CloudAdoptOfferLogic.markerNamesLinkedAccount(
            markerAccountHashes: [hashA], beaconLinked: true, beaconAccountHash: hashA), "control: misma cuenta")
        #expect(CloudAdoptOfferLogic.markerNamesLinkedAccount(
            markerAccountHashes: [hashB, hashA], beaconLinked: true, beaconAccountHash: hashA), "uno de varios basta")
        // El caso de la card: el marcador viejo es de otra cuenta y el faro, de la que acaba de entrar (vacía).
        #expect(!CloudAdoptOfferLogic.markerNamesLinkedAccount(
            markerAccountHashes: [hashB], beaconLinked: true, beaconAccountHash: hashA))
        #expect(!CloudAdoptOfferLogic.markerNamesLinkedAccount(
            markerAccountHashes: [hashA], beaconLinked: false, beaconAccountHash: hashA),
                "faro apagado: cuenta borrada o vuelta a iCloud")
        #expect(!CloudAdoptOfferLogic.markerNamesLinkedAccount(
            markerAccountHashes: [hashA], beaconLinked: true, beaconAccountHash: nil), "faro sin hash no nombra a nadie")
        #expect(!CloudAdoptOfferLogic.markerNamesLinkedAccount(
            markerAccountHashes: [""], beaconLinked: true, beaconAccountHash: ""), "dos vacíos no son la misma cuenta")
        #expect(!CloudAdoptOfferLogic.markerNamesLinkedAccount(
            markerAccountHashes: [], beaconLinked: true, beaconAccountHash: hashA), "sin marcador, nada")
    }

    @Test("el Panel lee la comprobación nueva, y «Dónde viven tus datos» sigue eligiendo el camino con el marcador a secas")
    func wiring() throws {
        let panel = try Nube23MediaSource.read("Yala/App/Views/Panel/PanelView.swift")
        #expect(panel.contains("CloudMigrationController.shared?.adoptOfferMarkerPresent() ?? false"))
        #expect(!panel.contains("markerDecision() == .secondaryDeviceCloudLogin"))

        let controller = try Nube23MediaSource.read("Yala/Services/CloudSync/CloudMigrationController.swift")
        let body = try #require(Nube23MediaSource.functionBody("func adoptOfferMarkerPresent() -> Bool", in: controller))
        #expect(body.contains("guard markerDecision() == .secondaryDeviceCloudLogin else { return false }"))
        #expect(body.contains("CloudAdoptOfferLogic.markerNamesLinkedAccount("))
        #expect(body.contains("beaconLinked: beacon.isCloudAccountLinked"))
        #expect(body.contains("beaconAccountHash: beacon.accountHash"))

        let storage = try Nube23MediaSource.read("Yala/App/Views/Settings/StorageSettingsView.swift")
        #expect(storage.contains("controller.markerDecision() == .secondaryDeviceCloudLogin"),
                "la tarjeta de «Dónde viven tus datos» no cambia: allí el marcador elige adopt o «Migrar»")
    }
}

/// Lectura del código fuente para los scans de cableado.
enum Nube23MediaSource {
    static func read(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }

    /// El cuerpo de una función desde su firma hasta la llave que la cierra (por conteo de llaves).
    static func functionBody(_ signature: String, in source: String) -> String? {
        guard let start = source.range(of: signature) else { return nil }
        var depth = 0
        var opened = false
        var index = start.upperBound
        while index < source.endIndex {
            let char = source[index]
            if char == "{" { depth += 1; opened = true }
            if char == "}" {
                depth -= 1
                if opened && depth == 0 { return String(source[start.lowerBound...index]) }
            }
            index = source.index(after: index)
        }
        return nil
    }
}
