//
//  NavegadoresConectadosProduccionTests.swift
//  YalaTests
//
//  «Navegadores conectados» en la app publicada (encargo del 22-nov-2026, decisiones 42 y 51: la web es un dispositivo
//  más en modo nube). Hasta ese día la fila solo existía en Yala Dev, porque `ConnectedBrowsersConfig.baseURL` era `nil`
//  fuera de DEV_BUILD. Aquí se fija que cada build hable con la web de SU nube y que esas direcciones sean las que
//  publica `webapp/wrangler.toml`: una web movida de dominio sin tocar la app dejaría la fila apuntando a la nada.
//

import Foundation
import Testing
@testable import Yala

struct NavegadoresConectadosProduccionTests {

    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // NavegadoresConectadosProduccion/
        .deletingLastPathComponent()  // YalaTests/
        .deletingLastPathComponent()  // raíz del repo

    private static func webToml() throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent("webapp/wrangler.toml"), encoding: .utf8)
    }

    /// El bloque de staging (todo lo de antes de la tabla `[env.production]`) o el de `[env.production.vars]` en adelante.
    /// Las cabeceras se buscan a principio de línea: los comentarios del toml también las nombran.
    private static func webBlock(production: Bool) throws -> String {
        let toml = try webToml()
        if production {
            let start = try #require(toml.range(of: "\n[env.production.vars]\n"))
            return String(toml[start.upperBound...])
        }
        let end = try #require(toml.range(of: "\n[env.production]\n"))
        return String(toml[..<end.lowerBound])
    }

    /// `PUBLIC_URL` de un bloque de `webapp/wrangler.toml`.
    private static func webPublicURL(production: Bool) throws -> String {
        let block = try webBlock(production: production)
        let line = try #require(block.split(separator: "\n").first { $0.hasPrefix("PUBLIC_URL") })
        let parts = line.split(separator: "\"")
        try #require(parts.count >= 2)
        return String(parts[1])
    }

    @Test func laAppPublicadaHablaConLaWebDeProduccion() throws {
        let url = try #require(ConnectedBrowsersConfig.baseURL(isDevBuild: false))
        #expect(url.absoluteString == (try Self.webPublicURL(production: true)))
        #expect(url.host == "app.yala-app.pe")
    }

    @Test func yalaDevSigueConLaWebDeStaging() throws {
        let url = try #require(ConnectedBrowsersConfig.baseURL(isDevBuild: true))
        #expect(url.absoluteString == (try Self.webPublicURL(production: false)))
    }

    @Test func laFilaExisteEnLosDosBuilds() {
        #expect(ConnectedBrowsersConfig.baseURL(isDevBuild: false) != nil)
        #expect(ConnectedBrowsersConfig.baseURL(isDevBuild: true) != nil)
        #expect(ConnectedBrowsersConfig.isAvailable)
    }

    /// «Vincular un navegador» pide Face ID (`LinkBrowserModel`, `LAContext.evaluatePolicy`), y sin
    /// `NSFaceIDUsageDescription` en el Info.plist iOS cierra la app al pedirlo. Hasta el 22-nov-2026 la clave solo estaba
    /// en Debug-Dev y Release-Dev (la función era solo de Yala Dev). Ahora la llevan las cuatro configuraciones de la app.
    @Test func lasCuatroConfiguracionesDeLaAppDeclaranFaceID() throws {
        let pbxproj = try String(
            contentsOf: Self.repoRoot.appendingPathComponent("Yala.xcodeproj/project.pbxproj"), encoding: .utf8)
        let blocks = pbxproj.components(separatedBy: "isa = XCBuildConfiguration;").dropFirst()
        let appBlocks = blocks.filter {
            $0.contains("PRODUCT_BUNDLE_IDENTIFIER = com.jurgenschmidt.yala;")
                || $0.contains("PRODUCT_BUNDLE_IDENTIFIER = com.jurgenschmidt.yala.dev;")
        }
        #expect(appBlocks.count == 4)
        for block in appBlocks {
            let name = block.components(separatedBy: "name = ").last?.prefix(20) ?? ""
            #expect(block.contains("INFOPLIST_KEY_NSFaceIDUsageDescription = "), "sin Face ID en \(name)")
        }
    }

    /// La web valida el token del iPhone contra SU Supabase: la de producción con el de producción. Si la app de
    /// producción mandara su token a la web de staging (o al revés), cada llamada daría 401 y la fila diría que la
    /// sesión caducó.
    @Test func cadaWebValidaContraElSupabaseDeSuBuild() throws {
        let production = try Self.webBlock(production: true)
        let staging = try Self.webBlock(production: false)
        #expect(production.contains("SUPABASE_URL = \"https://kefvaiymtgytemwbltlz.supabase.co\""))
        #expect(staging.contains("SUPABASE_URL = \"https://fostjbbwstyuunmmefuk.supabase.co\""))

        let appSource = try String(
            contentsOf: Self.repoRoot.appendingPathComponent("Yala/App/Services/CloudBackendConfig.swift"),
            encoding: .utf8)
        let devBranch = try #require(appSource.range(of: "return URL(string: \"https://fostjbbwstyuunmmefuk.supabase.co\")"))
        let elseBranch = try #require(appSource.range(of: "#else", range: devBranch.upperBound..<appSource.endIndex))
        let afterElse = appSource[elseBranch.upperBound...].prefix(200)
        #expect(afterElse.contains("return URL(string: \"https://kefvaiymtgytemwbltlz.supabase.co\")"))
    }
}
