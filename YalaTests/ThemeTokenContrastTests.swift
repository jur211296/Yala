//
//  ThemeTokenContrastTests.swift
//  YalaTests
//
//  Lote 12.3 · contraste en los tokens del tema, medido con la fórmula WCAG 2.x (AA = 4,5:1 para texto normal):
//  - card lbcr: el texto sobre el relleno del acento (`onAccent`) en los ocho temas.
//  - card 1c9w: el acento como texto (`accentText`) sobre el fondo y la tarjeta de cada tema oscuro.
//  - card elwl: el importe de un ingreso (`Color.incomeAmount`) en claro y en oscuro, y su relleno fijo con blanco.
//
//  Si un tema nuevo entra en `allThemes` sin pasar, o alguien devuelve un token al color de antes, cae aquí.
//

import SwiftUI
import Testing
import UIKit
@testable import Yala

@Suite("Lote 12.3 · contraste AA de los tokens del tema")
struct ThemeTokenContrastTests {

    private struct RGB { let r: Double, g: Double, b: Double }

    /// Los temas que se pueden elegir (Claro, Oscuro, Índigo, Rosa, Teal, Minimalista, Traslúcido en sus tres acentos y
    /// Liquid Glass), con su nombre para el mensaje.
    private static let allThemes: [(String, YalaTheme)] = [
        ("Claro", .light), ("Oscuro", .dark), ("Índigo", .indigo), ("Rosa", .rosa), ("Teal", .teal),
        ("Minimalista", .minimalist), ("Traslúcido", .translucent), ("Traslúcido Rosa", .translucentRosa),
        ("Traslúcido Teal", .translucentTeal), ("Liquid Glass", .liquidGlass),
    ]

    private static var darkThemes: [(String, YalaTheme)] { allThemes.filter { $0.1.baseColorScheme == .dark } }

    // MARK: - Medida

    /// Resuelve un `Color` (también los adaptativos) en el modo dado y lo compone sobre `over` si tiene transparencia.
    private static func rgb(_ color: Color, dark: Bool, over base: RGB? = nil) -> RGB {
        let ui = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: dark ? .dark : .light))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        guard let base, a < 1 else { return RGB(r: Double(r), g: Double(g), b: Double(b)) }
        let al = Double(a)
        return RGB(r: Double(r) * al + base.r * (1 - al), g: Double(g) * al + base.g * (1 - al), b: Double(b) * al + base.b * (1 - al))
    }

    private static func luminance(_ c: RGB) -> Double {
        func lin(_ v: Double) -> Double {
            let v = min(max(v, 0), 1)
            return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b)
    }

    private static func ratio(_ a: RGB, _ b: RGB) -> Double {
        let la = luminance(a), lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    /// Fondo y tarjeta del tema (la tarjeta compuesta sobre el fondo cuando es translúcida).
    private static func surfaces(of theme: YalaTheme) -> [(String, RGB)] {
        let dark = theme.baseColorScheme == .dark
        let bg = rgb(theme.background, dark: dark)
        return [("fondo", bg), ("tarjeta", rgb(theme.card, dark: dark, over: bg))]
    }

    // MARK: - Sanidad del instrumento

    @Test("El medidor da los valores de referencia de WCAG")
    func meter_matchesKnownRatios() {
        let white = RGB(r: 1, g: 1, b: 1), black = RGB(r: 0, g: 0, b: 0)
        #expect(abs(Self.ratio(white, black) - 21) < 0.01)
        // #6063F1 con blanco: 4,61 (el valor que fijó el pulido del 17-oct).
        #expect(abs(Self.ratio(Self.rgb(.electricIndigo, dark: false), white) - 4.61) < 0.02)
    }

    // MARK: - lbcr · texto sobre el acento

    @Test("El texto sobre el relleno del acento llega a AA en todos los temas", arguments: allThemes.map(\.0))
    func onAccent_overAccent_isAA(name: String) throws {
        let theme = try #require(Self.allThemes.first { $0.0 == name }?.1)
        let dark = theme.baseColorScheme == .dark
        let value = Self.ratio(Self.rgb(theme.onAccent, dark: dark), Self.rgb(theme.accent, dark: dark))
        #expect(value >= 4.5, "\(name): \(String(format: "%.2f", value)):1 sobre el acento")
    }

    @Test("Teal, Rosa y Minimalista llevan texto negro; los índigo, blanco")
    func onAccent_choice() {
        for theme in [YalaTheme.teal, .rosa, .minimalist, .translucentTeal, .translucentRosa] {
            #expect(theme.onAccent == .black)
        }
        for theme in [YalaTheme.light, .dark, .indigo, .translucent, .liquidGlass] {
            #expect(theme.onAccent == .white)
        }
    }

    @Test("onFill: sobre el acento devuelve onAccent; sobre otro color, el contraste de siempre")
    func onFill_routesTheAccent() {
        #expect(YalaTheme.teal.onFill(YalaTheme.teal.accent) == .black)
        #expect(YalaTheme.indigo.onFill(YalaTheme.indigo.accent) == .white)
        #expect(YalaTheme.teal.onFill(Color.selectedIndigoFill) == Color.contrastingText(for: .selectedIndigoFill))
    }

    // MARK: - 1c9w · el acento como texto

    @Test("El acento como texto llega a AA sobre fondo y tarjeta de cada tema oscuro", arguments: darkThemes.map(\.0))
    func accentText_onDarkSurfaces_isAA(name: String) throws {
        let theme = try #require(Self.allThemes.first { $0.0 == name }?.1)
        for (surface, color) in Self.surfaces(of: theme) {
            let value = Self.ratio(Self.rgb(theme.accentText, dark: true), color)
            #expect(value >= 4.5, "\(name), \(surface): \(String(format: "%.2f", value)):1")
        }
    }

    @Test("En el Claro, el texto índigo sobre la tarjeta blanca sigue en AA")
    func accentText_light_onWhiteCard() {
        let value = Self.ratio(Self.rgb(YalaTheme.light.accentText, dark: false), Self.rgb(.white, dark: false))
        #expect(value >= 4.5, "\(value)")
    }

    // MARK: - elwl · el importe de un ingreso

    @Test("El importe de un ingreso llega a AA en claro sobre blanco y en oscuro sobre cada superficie oscura")
    func incomeAmount_isAA_inBothModes() {
        let light = Self.ratio(Self.rgb(.incomeAmount, dark: false), Self.rgb(.white, dark: false))
        #expect(light >= 4.5, "claro: \(light)")
        for (name, theme) in Self.darkThemes {
            for (surface, color) in Self.surfaces(of: theme) {
                let value = Self.ratio(Self.rgb(.incomeAmount, dark: true), color)
                #expect(value >= 4.5, "\(name), \(surface): \(String(format: "%.2f", value)):1")
            }
        }
    }

    @Test("En oscuro el ingreso ya no es el turquesa apagado de antes")
    func incomeAmount_dark_isNotTheOldFixedTone() {
        let old = Self.rgb(Color(hex: "0F7A80"), dark: true)
        let now = Self.rgb(.incomeAmount, dark: true)
        #expect(abs(old.g - now.g) > 0.1, "Color.incomeAmount en oscuro sigue siendo #0F7A80")
    }

    @Test("El relleno turquesa con blanco encima sigue en AA (no cambia con el modo)")
    func incomeFill_withWhite_isAA() {
        for dark in [false, true] {
            let value = Self.ratio(Self.rgb(.incomeFill, dark: dark), Self.rgb(.white, dark: dark))
            #expect(value >= 4.5, "\(dark ? "oscuro" : "claro"): \(value)")
        }
    }
}
