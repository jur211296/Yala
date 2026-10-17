//
//  AlertActionIndigoParityTests.swift
//  YalaTests
//
//  El botón «Activar» del aviso de voz y foto es la acción destacada de una alerta del sistema. La alerta toma su
//  RELLENO del `AccentColor` del catálogo y su TEXTO del tinte de quien la presenta; si el tinte coincide con el relleno,
//  el texto sale negro (medido en píxeles el 2026-10-17). `alertActionTint` es blanco en oscuro y `electricIndigo` en
//  claro, así que el catálogo tiene que valer `alertActionIndigo` en oscuro (blanco encima, AA) y `electricIndigo` en
//  claro (coincide con el tinte: negro encima, 4,70:1, AA). Si divergen, el texto sale del color del tinte sobre un
//  relleno casi igual, y no se lee.
//

import Foundation
import Testing

struct AlertActionIndigoParityTests {

    static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // raíz del repo
    }

    /// `(r, g, b)` de 0 a 255 del hex de `static let <name> = Color(hex: "……")` en `UIHelpers.swift`.
    static func tokenRGB(_ name: String) throws -> [Int] {
        let url = repoRoot.appendingPathComponent("Yala/App/Views/Shared/UIHelpers.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        let pattern = try Regex("static let \(name) = Color\\(hex: \"([0-9A-Fa-f]{6})\"\\)")
        let match = try #require(source.firstMatch(of: pattern), "No encuentro \(name)")
        let hex = try #require(match.output[1].substring)
        let value = try #require(Int(String(hex), radix: 16))
        return [(value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF]
    }

    /// `(r, g, b)` de 0 a 255 de cada variante del `AccentColor.colorset`, por apariencia (`any` o `dark`). Xcode escribe
    /// los canales en hex («0x58») o en fracción («0.345»).
    static func assetRGB() throws -> [String: [Int]] {
        let url = repoRoot.appendingPathComponent("Yala/Resources/Assets.xcassets/AccentColor.colorset/Contents.json")
        let data = try Data(contentsOf: url)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let colors = try #require(json["colors"] as? [[String: Any]])
        var result: [String: [Int]] = [:]
        for entry in colors {
            let appearances = entry["appearances"] as? [[String: String]] ?? []
            let key = appearances.first { $0["appearance"] == "luminosity" }?["value"] ?? "any"
            let color = try #require(entry["color"] as? [String: Any])
            #expect(color["color-space"] as? String == "srgb")
            let components = try #require(color["components"] as? [String: String])
            result[key] = try ["red", "green", "blue"].map { channel in
                let raw = try #require(components[channel])
                if raw.hasPrefix("0x") { return try #require(Int(raw.dropFirst(2), radix: 16)) }
                return Int((try #require(Double(raw)) * 255).rounded())
            }
        }
        return result
    }

    static func luminance(_ rgb: [Int]) -> Double {
        let lin = rgb.map { c -> Double in
            let v = Double(c) / 255
            return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * lin[0] + 0.7152 * lin[1] + 0.0722 * lin[2]
    }

    @Test func accentColorAsset_matchesTheTintInEachMode() throws {
        let asset = try Self.assetRGB()
        #expect(Set(asset.keys) == ["any", "dark"], "Variantes del AccentColor: \(asset.keys.sorted())")
        let dark = try Self.tokenRGB("alertActionIndigo")
        let light = try Self.tokenRGB("electricIndigo")
        #expect(asset["dark"] == dark, "AccentColor oscuro \(asset["dark"] ?? []) ≠ alertActionIndigo \(dark)")
        #expect(asset["any"] == light, "AccentColor claro \(asset["any"] ?? []) ≠ electricIndigo \(light)")
    }

    @Test func darkFill_keepsWhiteTextAboveAA() throws {
        let l = Self.luminance(try Self.tokenRGB("alertActionIndigo"))
        let white = 1.05 / (l + 0.05)
        #expect(white >= 4.5, "Blanco sobre el relleno oscuro: \(white):1, por debajo de AA")
    }

    @Test func lightFill_keepsBlackTextAboveAA() throws {
        let l = Self.luminance(try Self.tokenRGB("electricIndigo"))
        let black = (l + 0.05) / 0.05
        #expect(black >= 4.5, "Negro sobre el relleno claro: \(black):1, por debajo de AA")
    }

    /// El tinte vale blanco en oscuro y `electricIndigo` en claro: si el claro dejara de ser el relleno, el texto saldría
    /// en ese otro color en vez de negro.
    @Test func alertActionTint_isWhiteInDarkAndTheFillInLight() throws {
        let url = Self.repoRoot.appendingPathComponent("Yala/App/Views/Shared/UIHelpers.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        #expect(source.contains("traits.userInterfaceStyle == .dark ? .white : UIColor(Color.electricIndigo)"))
    }

    /// El aviso de voz y foto presenta la alerta con `alertActionTint` desde su ancla.
    @Test func aiConsentAlert_isTintedWithTheToken() throws {
        let url = Self.repoRoot.appendingPathComponent("Yala/App/Theme/ViewModifiers.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        let body = try #require(AIConsentProviderNameTests.structBody(named: "AIConsentAlertModifier", in: source))
        #expect(body.contains(".tint(Color.alertActionTint)"))
        #expect(body.contains(".keyboardShortcut(.defaultAction)"))
    }
}
