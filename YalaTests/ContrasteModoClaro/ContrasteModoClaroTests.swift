//
//  ContrasteModoClaroTests.swift
//  YalaTests
//
//  Modo claro: los campos y botones blancos se despegan del fondo (Jürgen, 19-nov-2026, con capturas de Nuevo registro
//  y Yala IA). Fija lo que decide el tema, no la pintura: el fondo claro es un gris neutro y no el casi-blanco de antes,
//  las superficies del tema claro llevan contorno y los temas oscuros no, «Aumentar contraste» marca más las dos cosas,
//  y el texto de color sigue en AA sobre el gris nuevo.
//

import SwiftUI
import Testing
import UIKit
@testable import Yala

@Suite("Contraste en modo claro: fondo gris y superficies con contorno")
struct ContrasteModoClaroTests {

    private struct RGB: Equatable { let r, g, b: Double }

    private static func rgb(_ color: Color, contrast: UIAccessibilityContrast = .normal, dark: Bool = false) -> RGB {
        let traits = UITraitCollection { mutable in
            mutable.userInterfaceStyle = dark ? .dark : .light
            mutable.accessibilityContrast = contrast
        }
        let ui = UIColor(color).resolvedColor(with: traits)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return RGB(r: Double(r), g: Double(g), b: Double(b))
    }

    private static func alpha(_ color: Color, contrast: UIAccessibilityContrast = .normal) -> Double {
        let traits = UITraitCollection { $0.userInterfaceStyle = .light; $0.accessibilityContrast = contrast }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).resolvedColor(with: traits).getRed(&r, green: &g, blue: &b, alpha: &a)
        return Double(a)
    }

    private static func luminance(_ c: RGB) -> Double {
        func lin(_ v: Double) -> Double { v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b)
    }

    private static func ratio(_ a: RGB, _ b: RGB) -> Double {
        let la = luminance(a), lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    private static let white = RGB(r: 1, g: 1, b: 1)

    // MARK: - Fondo

    @Test("El fondo claro ya no es casi blanco: la tarjeta blanca se separa de él")
    func lightBackground_separatesFromTheWhiteCard() {
        let bg = Self.rgb(YalaTheme.light.background)
        let card = Self.rgb(YalaTheme.light.card)
        #expect(card == Self.white, "La tarjeta del claro sigue siendo blanca")
        // El #FAFBFF de antes daba 1,03:1 contra el blanco: no se veía el contorno de nada.
        #expect(Self.ratio(card, bg) >= 1.08, "tarjeta contra fondo: \(Self.ratio(card, bg))")
    }

    @Test("El gris del fondo es neutro, no lavanda")
    func lightBackground_isNeutral() {
        let bg = Self.rgb(YalaTheme.light.background)
        #expect(abs(bg.r - bg.g) <= 0.01)
        #expect(abs(bg.b - bg.r) <= 0.02, "el azul no domina: \(bg)")
    }

    @Test("Con «Aumentar contraste» el fondo baja un punto más")
    func lightBackground_isDarkerWithIncreasedContrast() {
        let normal = Self.luminance(Self.rgb(YalaTheme.light.background))
        let high = Self.luminance(Self.rgb(YalaTheme.light.background, contrast: .high))
        #expect(high < normal)
    }

    // MARK: - Contorno de las superficies

    @Test("El tema claro trae contorno para sus superficies; ningún tema oscuro lo trae")
    func surfaceEdge_onlyInLightThemes() {
        #expect(YalaTheme.light.surfaceEdge != nil)
        let darkThemes: [YalaTheme] = [
            .dark, .indigo, .rosa, .teal, .minimalist, .translucent, .translucentRosa, .translucentTeal, .liquidGlass,
        ]
        for theme in darkThemes {
            #expect(theme.baseColorScheme == .dark)
            #expect(theme.surfaceEdge == nil)
        }
    }

    @Test("La línea del contorno se ve, y con «Aumentar contraste» se marca más")
    func surfaceEdge_lineIsVisible_andStrongerWithIncreasedContrast() throws {
        let edge = try #require(YalaTheme.light.surfaceEdge)
        let normal = Self.alpha(edge.line)
        let high = Self.alpha(edge.line, contrast: .high)
        #expect(normal >= 0.08, "línea casi invisible: \(normal)")
        #expect(high > normal)
        #expect(edge.lineRadius <= 1, "la línea es un borde finísimo, no una sombra")
        #expect(edge.softRadius > edge.lineRadius)
    }

    @Test("El borde de las tarjetas se marca más con «Aumentar contraste»")
    func cardBorder_strongerWithIncreasedContrast() {
        #expect(Self.alpha(YalaTheme.light.cardBorder, contrast: .high) > Self.alpha(YalaTheme.light.cardBorder))
    }

    // MARK: - Texto sobre el gris nuevo

    @Test("El índigo como texto llega a AA sobre el fondo gris y sobre la tarjeta blanca")
    func accentText_isAA_onTheNewBackground() {
        let text = Self.rgb(YalaTheme.light.accentText)
        let bg = Self.rgb(YalaTheme.light.background)
        #expect(Self.ratio(text, bg) >= 4.5, "sobre el fondo: \(Self.ratio(text, bg))")
        #expect(Self.ratio(text, Self.white) >= 4.5)
    }

    @Test("Los montos de color siguen en AA sobre el fondo gris")
    func coloredAmounts_areAA_onTheNewBackground() {
        let bg = Self.rgb(YalaTheme.light.background)
        for (name, color) in [("ingreso", Color.incomeAmount), ("debes", .groupOweAmount), ("te deben", .groupOwedAmount)] {
            let value = Self.ratio(Self.rgb(color), bg)
            #expect(value >= 4.5, "\(name): \(value)")
        }
    }

    // MARK: - Los oscuros no cambian

    @Test("El modo oscuro conserva su fondo negro y su tarjeta")
    func darkTheme_isUnchanged() {
        #expect(Self.rgb(YalaTheme.dark.background, dark: true) == RGB(r: 0, g: 0, b: 0))
        let card = Self.rgb(YalaTheme.dark.card, dark: true)
        #expect(abs(card.r - 0.11) < 0.005 && abs(card.g - 0.11) < 0.005 && abs(card.b - 0.12) < 0.005)
    }
}
