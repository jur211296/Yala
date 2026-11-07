//
//  AppleOnTheWebSignInTests.swift
//  YalaTests
//
//  Ticket `cloud-sign-in-cannot-choose-another-apple-id` (decisión A de Jürgen, 2026-11-06): «Otra cuenta de Apple» entra
//  por la web de Apple con un Apple ID que puede no ser el del teléfono. Tres piezas que no se ven en pantalla:
//  la URL de vuelta (si no es la del esquema de la app, la hoja no vuelve nunca), que esa sesión no sirva de prueba para
//  limpiar el faro, y el cableado de lo que el inicio web deja distinto del nativo.
//

import Foundation
import Testing

@testable import Yala

@Suite("Otra cuenta de Apple · inicio de sesión web")
struct AppleOnTheWebSignInTests {

    // MARK: - La URL de vuelta

    @Test func redirect_usaElEsquemaDeLaApp_noElDeGoogle() {
        let info: [String: Any] = ["CFBundleURLTypes": [[
            "CFBundleURLSchemes": ["yaladev", "com.googleusercontent.apps.123-abc"],
        ]]]
        #expect(CloudAuthService.appleWebRedirectURL(infoDictionary: info)?.absoluteString == "yaladev://auth-callback")
    }

    /// Control: con el de Google primero, igual sale el de la app.
    @Test func redirect_conGooglePrimero_sigueSaliendoElDeLaApp() {
        let info: [String: Any] = ["CFBundleURLTypes": [[
            "CFBundleURLSchemes": ["com.googleusercontent.apps.123-abc", "yala"],
        ]]]
        #expect(CloudAuthService.appleWebRedirectURL(infoDictionary: info)?.absoluteString == "yala://auth-callback")
    }

    @Test func redirect_sinEsquemaPropio_esNil() {
        let info: [String: Any] = ["CFBundleURLTypes": [["CFBundleURLSchemes": ["com.googleusercontent.apps.1"]]]]
        #expect(CloudAuthService.appleWebRedirectURL(infoDictionary: info) == nil)
        #expect(CloudAuthService.appleWebRedirectURL(infoDictionary: nil) == nil)
    }

    /// El bundle que corre los tests: Yala Dev (`DEV_BUILD`) vuelve a `yaladev://`, que es la que staging tiene permitida
    /// (`uri_allow_list`); Yala, a `yala://`, la que producción tendrá que permitir.
    @Test func redirect_delBundleReal_esElDeSuEntorno() {
        #if DEV_BUILD
        #expect(CloudAuthService.appleWebRedirectURL()?.absoluteString == "yaladev://auth-callback")
        #else
        #expect(CloudAuthService.appleWebRedirectURL()?.absoluteString == "yala://auth-callback")
        #endif
    }

    // MARK: - El faro

    /// Una sesión de Apple abierta por la web NO prueba que la cuenta del faro (la del Apple ID de ESTE teléfono) no
    /// exista: puede ser otro Apple ID. Limpiar el faro es irreversible y viaja a todos los dispositivos.
    @Test func faro_unaSesionDeAppleWeb_noEsPrueba() {
        let provider = CloudAuthService.providerProvingThisDevicesAppleID(stored: "apple", appleOnTheWeb: true)
        #expect(provider == nil)
        #expect(BeaconOrphanLogic.proof(
            accountExists: false, beaconLinked: true, beaconAccountHash: "hashFaro", beaconProvider: "apple",
            sessionSubHash: "hashSesion", sessionProvider: provider.flatMap(CloudSignInProvider.init(rawValue:))) == nil)
    }

    /// Control: la misma situación con la sesión NATIVA sí es la prueba 2 (sin esto, el de arriba no discrimina).
    @Test func faro_unaSesionDeAppleNativa_sigueSiendoPrueba() {
        let provider = CloudAuthService.providerProvingThisDevicesAppleID(stored: "apple", appleOnTheWeb: false)
        #expect(provider == "apple")
        #expect(BeaconOrphanLogic.proof(
            accountExists: false, beaconLinked: true, beaconAccountHash: "hashFaro", beaconProvider: "apple",
            sessionSubHash: "hashSesion", sessionProvider: provider.flatMap(CloudSignInProvider.init(rawValue:)))
                == .appleIdentityHasNoAccount)
    }

    /// La prueba 1 (mismo hash) no depende del método y sigue valiendo con la sesión web.
    @Test func faro_mismoHash_sigueSiendoPruebaConLaWeb() {
        let provider = CloudAuthService.providerProvingThisDevicesAppleID(stored: "apple", appleOnTheWeb: true)
        #expect(BeaconOrphanLogic.proof(
            accountExists: false, beaconLinked: true, beaconAccountHash: "mismo", beaconProvider: "apple",
            sessionSubHash: "mismo", sessionProvider: provider.flatMap(CloudSignInProvider.init(rawValue:)))
                == .sameAccount)
    }

    // MARK: - Cableado (source-scan)

    private func source(_ relative: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
    }

    private func body(of signature: String, in text: String) throws -> String {
        let start = try #require(text.range(of: signature))
        var depth = 0
        var opened = false
        var index = start.upperBound
        while index < text.endIndex {
            let c = text[index]
            if c == "{" { depth += 1; opened = true }
            if c == "}" { depth -= 1; if opened && depth == 0 { return String(text[start.lowerBound...index]) } }
            index = text.index(after: index)
        }
        Issue.record("sin cierre para \(signature)")
        return ""
    }

    /// Lo que el inicio web deja distinto del nativo, y por qué cada línea importa:
    /// · sin `keyAppleUserID` (lo borra `clearCapturedProfile`): con el de otro Apple ID, `refreshCredentialStateIfNeeded`
    ///   cerraría la sesión en el siguiente primer plano (`.notFound`);
    /// · la marca web, que apaga la prueba 2 del faro;
    /// · la sesión efímera: sin ella la página de Apple reusa la cookie de Safari y vuelve al mismo Apple ID.
    @Test func elInicioWeb_dejaLaMarca_borraElAppleUserID_yVaSinCookies() throws {
        let text = try source("Yala/Services/CloudSync/CloudAuthService.swift")
        let web = try body(of: "func signInWithAppleOnTheWeb() async throws", in: text)
        #expect(web.contains("session.prefersEphemeralWebBrowserSession = true"))
        #expect(web.contains("writeProfileString(\"1\", forKey: Self.keyAppleOnTheWeb)"))
        #expect(web.contains("clearCapturedProfile()"))
        #expect(!web.contains("keyAppleUserID"), "El inicio web no puede guardar un appleUserID: no es el del teléfono.")
        #expect(!web.contains("SIWAExchangeCapture"))
    }

    /// Todo otro inicio de sesión y el cierre retiran la marca: si no, una sesión NATIVA posterior perdería la prueba 2.
    @Test func losOtrosIniciosYElCierre_retiranLaMarca() throws {
        let text = try source("Yala/Services/CloudSync/CloudAuthService.swift")
        #expect(text.components(separatedBy: "clearAppleOnTheWebMark()").count - 1 == 4,
                "La definición, y los tres que la retiran: nativo de Apple, Google y el cierre de sesión.")
    }

    /// El descubrimiento de identidad lee, por defecto, el proveedor que PRUEBA el Apple ID del teléfono.
    @Test func elDescubrimiento_leeElProveedorQuePrueba() throws {
        let text = try source("Yala/Services/CloudSync/CloudIdentityDiscovery.swift")
        #expect(text.contains("sessionProviderName ?? { CloudAuthService.shared.storedProviderProvingThisDevicesAppleID() }"))
        #expect(!text.contains("CloudAuthService.shared.storedProvider() }"))
    }
}
