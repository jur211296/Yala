//
//  ContrastingTextWCAGTests.swift
//  YalaTests
//
//  Contraste AA del lote de temas (19-nov-2026), medido con la fórmula de WCAG 2.x:
//  - `Color.contrastingText(for:)` elige blanco o negro por contraste WCAG: blanco si llega a 4,5:1 o si queda a menos de
//    medio punto del negro (empate práctico); si no, negro. Con la fórmula de vídeo de antes, el turquesa de marca salía
//    blanco a 2,19:1.
//  - El índigo como texto del tema Claro llega a AA también con «Aumentar contraste», donde el fondo baja a #EAEAEE.
//  - Los rellenos rosa con texto blanco (porcentaje elegido de la calculadora, ahorro del plan de Pro) son el rosa
//    profundo, no `hotPink`.
//

import SwiftUI
import Testing
import UIKit
@testable import Yala

@Suite("Contraste AA: texto sobre colores, índigo con más contraste y rellenos rosa")
struct ContrastingTextWCAGTests {

    private struct RGB { let r, g, b: Double }

    private static func rgb(_ color: Color, contrast: UIAccessibilityContrast = .normal) -> RGB {
        let traits = UITraitCollection { $0.userInterfaceStyle = .light; $0.accessibilityContrast = contrast }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).resolvedColor(with: traits).getRed(&r, green: &g, blue: &b, alpha: &a)
        return RGB(r: Double(r), g: Double(g), b: Double(b))
    }

    private static func luminance(_ c: RGB) -> Double {
        func lin(_ v: Double) -> Double { v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b)
    }

    private static func ratio(_ a: RGB, _ b: RGB) -> Double {
        let la = luminance(a), lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    private static let white = RGB(r: 1, g: 1, b: 1)
    private static let black = RGB(r: 0, g: 0, b: 0)

    // MARK: - contrastingText

    /// Colores medios de etiquetas y cuentas: con la fórmula vieja todos salían con texto blanco por debajo de AA.
    @Test("Sobre colores medios, el texto pasa a negro donde el blanco no llega a AA",
          arguments: ["00C2CB", "F97316", "10B981", "22C55E", "3B82F6", "EC4899", "FF0080", "0891B2", "8B5CF6"])
    func midColors_getBlackText(hex: String) {
        let fill = Color(hex: hex)
        #expect(Color.contrastingText(for: fill) == .black, "#\(hex)")
        let chosen = Self.ratio(Self.rgb(fill), Self.black)
        #expect(chosen >= 4.5, "#\(hex): negro a \(String(format: "%.2f", chosen)):1")
    }

    /// Donde el blanco ya llega a AA no cambia nada: así no se toca el aspecto de lo que ya se leía.
    @Test("Donde el blanco ya llega a AA, sigue blanco", arguments: ["6063F1", "64748B", "D6006B", "0F7A80", "000000", "1E293B"])
    func darkEnoughColors_keepWhiteText(hex: String) {
        let fill = Color(hex: hex)
        #expect(Color.contrastingText(for: fill) == .white, "#\(hex)")
        #expect(Self.ratio(Self.rgb(fill), Self.white) >= 4.5, "#\(hex)")
    }

    @Test("Los extremos: blanco sobre negro, negro sobre blanco y sobre el amarillo")
    func extremes() {
        #expect(Color.contrastingText(for: .white) == .black)
        #expect(Color.contrastingText(for: .black) == .white)
        #expect(Color.contrastingText(for: Color(hex: "F59E0B")) == .black)
    }

    @Test("La regla, sobre componentes: blanco si llega a AA o empata con el negro; si no, negro")
    func rule_onComponents() {
        // #6063F1: blanco 4,61, negro 4,55 → blanco (llega a AA).
        #expect(Color.contrastingTextIsWhite(red: 0x60 / 255.0, green: 0x63 / 255.0, blue: 0xF1 / 255.0))
        // #6366F1, el índigo por defecto de las cuentas: blanco 4,47, negro 4,70 → blanco (empate práctico, marca).
        #expect(Color.contrastingTextIsWhite(red: 0x63 / 255.0, green: 0x66 / 255.0, blue: 0xF1 / 255.0))
        // #8B5CF6: blanco 4,23, negro 4,96 → negro (el negro gana por más de medio punto).
        #expect(!Color.contrastingTextIsWhite(red: 0x8B / 255.0, green: 0x5C / 255.0, blue: 0xF6 / 255.0))
        // #3B82F6: blanco 3,68, negro 5,71 → negro.
        #expect(!Color.contrastingTextIsWhite(red: 0x3B / 255.0, green: 0x82 / 255.0, blue: 0xF6 / 255.0))
    }

    @Test("El índigo por defecto de las cuentas conserva su glifo blanco")
    func defaultAccountIndigo_keepsWhite() {
        #expect(Color.contrastingText(for: Color(hex: "6366F1")) == .white)
    }

    // MARK: - Índigo como texto con «Aumentar contraste»

    @Test("El índigo del Claro como texto llega a AA con «Aumentar contraste», sobre el fondo y la tarjeta")
    func accentText_light_isAA_withIncreasedContrast() {
        for contrast in [UIAccessibilityContrast.normal, .high] {
            let text = Self.rgb(YalaTheme.light.accentText, contrast: contrast)
            let background = Self.rgb(YalaTheme.light.background, contrast: contrast)
            let onBackground = Self.ratio(text, background)
            let onCard = Self.ratio(text, Self.white)
            #expect(onBackground >= 4.5, "\(contrast == .high ? "más contraste" : "normal"): \(onBackground)")
            #expect(onCard >= 4.5)
        }
    }

    @Test("Sin «Aumentar contraste» el índigo como texto sigue siendo #5B5EE4")
    func accentText_light_normal_isUnchanged() {
        let text = Self.rgb(YalaTheme.light.accentText)
        let expected = Self.rgb(Color(hex: "5B5EE4"))
        #expect(abs(text.r - expected.r) < 0.002 && abs(text.g - expected.g) < 0.002 && abs(text.b - expected.b) < 0.002)
    }

    // MARK: - Rellenos rosa con texto blanco

    @Test("El rosa profundo con blanco encima llega a AA; el rosa vivo no")
    func pinkFills() {
        #expect(Self.ratio(Self.rgb(.emphasisPinkFill), Self.white) >= 4.5)
        #expect(Self.ratio(Self.rgb(.hotPink), Self.white) < 4.5)
        #expect(Color.contrastingText(for: .emphasisPinkFill) == .white)
    }

    @Test("El porcentaje elegido de la calculadora y el ahorro del plan elegido van en el rosa profundo")
    func pinkFills_wiring() throws {
        let calculator = try Self.source("Yala/App/Views/Shared/SplitCalculatorSheet.swift")
        #expect(calculator.contains("? Color.emphasisPinkFill  // con blanco encima"))
        #expect(!calculator.contains("? Color.hotPink\n"), "El chip elegido volvió a `hotPink` (3,77:1 con blanco)")
        let purchase = try Self.source("Yala/App/Views/Subscription/ProPurchaseComponents.swift")
        #expect(purchase.contains("theme.onFill(isSelected ? Color.emphasisPinkFill : theme.accent)"))
        #expect(purchase.contains("Capsule().fill(isSelected ? Color.emphasisPinkFill : theme.accent)"))
    }

    private static func source(_ relativePath: String, file: StaticString = #filePath) throws -> String {
        var url = URL(fileURLWithPath: "\(file)")
        while url.pathComponents.count > 1 {
            url.deleteLastPathComponent()
            let candidate = url.appendingPathComponent(relativePath)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return try String(contentsOf: candidate, encoding: .utf8)
            }
        }
        throw CocoaError(.fileNoSuchFile)
    }
}
