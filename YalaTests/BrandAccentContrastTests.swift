//
//  BrandAccentContrastTests.swift
//  YalaTests
//
//  Decisión de Jürgen del 2026-10-17: oscurecer un poco el acento de marca para que el texto blanco encima pase AA.
//  Los botones rellenos con el acento («Nuevo registro» del Panel, «Aplicar» de Filtros, `YalaPrimaryButton`…) llevan
//  texto blanco, y con #6366F1 medían 4,47:1. El acento pasó a #6063F1 (4,61:1): mismo tono, solo menos luminosidad.
//
//  Este test resuelve el acento REAL de cada tema índigo (no un hex copiado) y mide el contraste con el blanco, con
//  margen sobre 4,5. Mide también los dos usos del acento como texto que eran o pasaban a ser AA (sobre la tarjeta
//  blanca del tema Claro y sobre el negro del Oscuro), y que las copias del hex fuera del token no se desvíen.
//
//  Fuera, a propósito: Rosa, Turquesa y Minimalista tienen otro acento y el blanco encima queda muy por debajo de AA
//  (ticket `white-text-on-the-rosa-teal-and-minimal-accents-is-below-aa`). Y el acento como texto pequeño sobre las
//  superficies oscuras no puede pasar AA con el mismo color que deja AA al blanco encima (ticket
//  `indigo-accent-as-small-text-on-dark-themes-is-below-aa`).
//

import Foundation
import SwiftUI
import Testing
import UIKit
@testable import Yala

struct BrandAccentContrastTests {

    /// Los temas cuyo acento es el índigo de marca.
    static let indigoThemes: [(name: String, theme: YalaTheme)] = [
        ("Claro", .light), ("Oscuro", .dark), ("Índigo", .indigo), ("Traslúcido", .translucent),
        ("Liquid Glass", .liquidGlass),
    ]

    /// Margen sobre AA: el objetivo era ~4,6:1, así que un acento que vuelva a rozar 4,5 ya no vale.
    static let whiteOnAccentMinimum = 4.55

    /// `(r, g, b)` de 0 a 1 de un `Color`, resuelto en la apariencia del tema.
    static func rgb(_ color: Color, scheme: ColorScheme) throws -> [Double] {
        let traits = UITraitCollection(userInterfaceStyle: scheme == .dark ? .dark : .light)
        let resolved = UIColor(color).resolvedColor(with: traits)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        try #require(resolved.getRed(&r, green: &g, blue: &b, alpha: &a), "El color no se resuelve a RGB")
        #expect(a == 1, "El acento tiene que ser opaco para medirlo así")
        return [Double(r), Double(g), Double(b)]
    }

    static func luminance(_ rgb: [Double]) -> Double {
        let lin = rgb.map { v in v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        return 0.2126 * lin[0] + 0.7152 * lin[1] + 0.0722 * lin[2]
    }

    static func contrast(_ a: [Double], _ b: [Double]) -> Double {
        let la = luminance(a), lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    @Test(arguments: 0..<indigoThemes.count)
    func whiteTextOnTheAccent_passesAAWithMargin(index: Int) throws {
        let (name, theme) = Self.indigoThemes[index]
        let accent = try Self.rgb(theme.accent, scheme: theme.baseColorScheme)
        let ratio = Self.contrast([1, 1, 1], accent)
        #expect(ratio >= Self.whiteOnAccentMinimum, "\(name): blanco sobre el acento da \(ratio):1")
    }

    /// El acento como texto sobre la tarjeta blanca del tema Claro (enlaces, «Ver todo»): con #6366F1 daba 4,47.
    @Test func accentAsText_onTheLightCard_passesAA() throws {
        let theme = YalaTheme.light
        let accent = try Self.rgb(theme.accent, scheme: .light)
        let card = try Self.rgb(theme.card, scheme: .light)
        let ratio = Self.contrast(accent, card)
        #expect(ratio >= 4.5, "Acento sobre tarjeta blanca: \(ratio):1")
    }

    /// El acento como texto sobre el negro del tema Oscuro era AA (4,70) y tiene que seguirlo siendo: oscurecerlo de
    /// más lo bajaría de 4,5.
    @Test func accentAsText_onTheDarkBackground_staysAA() throws {
        let theme = YalaTheme.dark
        let accent = try Self.rgb(theme.accent, scheme: .dark)
        let background = try Self.rgb(theme.background, scheme: .dark)
        let ratio = Self.contrast(accent, background)
        #expect(ratio >= 4.5, "Acento sobre fondo negro: \(ratio):1")
    }

    /// Los sitios que copian el hex del acento porque no pueden leer `Color.electricIndigo`: el catálogo (lo usa la
    /// alerta del sistema), el fondo de arranque (empalma con el splash, que pinta el token), los widgets (otro target)
    /// y el color «disponible» del Sankey (un hex de datos).
    @Test func copiesOfTheBrandHex_matchTheToken() throws {
        let token = try AlertActionIndigoParityTests.tokenRGB("electricIndigo")
        let root = AlertActionIndigoParityTests.repoRoot

        let accent = try AlertActionIndigoParityTests.assetRGB(colorset: "AccentColor")
        #expect(accent["any"] == token, "AccentColor claro \(accent["any"] ?? []) ≠ electricIndigo \(token)")

        let launch = try AlertActionIndigoParityTests.assetRGB(colorset: "LaunchBackground")
        #expect(!launch.isEmpty)
        for (appearance, rgb) in launch {
            #expect(rgb == token, "LaunchBackground \(appearance) \(rgb) ≠ electricIndigo \(token)")
        }

        let widgets = try String(
            contentsOf: root.appendingPathComponent("YalaWidgets/Theme/WidgetColors.swift"), encoding: .utf8)
        #expect(try Self.hexRGB(in: widgets, pattern: #"static let primary = Color\(hex: "([0-9A-Fa-f]{6})"\)"#) == token)

        let sankey = try String(
            contentsOf: root.appendingPathComponent("Yala/App/Logic/Calculators/SankeyFlowCalculator.swift"),
            encoding: .utf8)
        #expect(try Self.hexRGB(in: sankey, pattern: ##"availableColor = "#([0-9A-Fa-f]{6})""##) == token)
    }

    static func hexRGB(in source: String, pattern: String) throws -> [Int] {
        let regex = try Regex(pattern)
        let match = try #require(source.firstMatch(of: regex), "No encuentro \(pattern)")
        let hex = try #require(match.output[1].substring)
        let value = try #require(Int(String(hex), radix: 16))
        return [(value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF]
    }
}
