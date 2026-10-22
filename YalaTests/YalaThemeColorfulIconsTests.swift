//
//  YalaThemeColorfulIconsTests.swift
//  YalaTests
//
//  Tests puros para la lógica de iconos coloridos del tema (commit 44fad0f2:
//  "el toggle Iconos coloridos también pinta Más, y Liquid Glass/Traslúcido
//  dejan de forzar monocromo").
//
//  Cubre:
//   (1) `YalaTheme.forcesMonochromeIcons` por tema — API pública real. Solo
//       Minimalista fuerza monocromo (mapsColorsToGrayscale=true); Liquid Glass,
//       Traslúcido, Light/Dark y los PRO (indigo/rosa/teal) NO.
//   (2) La decisión pura `effectiveColorfulIcons` (toggle × tema) y el color
//       resuelto (`iconColor`). Estos helpers viven `private` dentro de las
//       structs `MoreView`/`ProfileView` y NO son extraíbles/accesibles desde
//       tests; se replica su lógica exacta como oráculo independiente (mismo
//       patrón que DateAlignmentHelperTests replica su pipeline). El primitivo
//       real (`forcesMonochromeIcons`) SÍ se testea directo abajo.
//
//  Sin SwiftData ni ModelContext → NO requiere @Suite(.serialized).
//
//  NOTA (fuera de cobertura): `MoreView.effectiveColorfulIcons`,
//  `MoreView.iconColor(_:)`, `ProfileView.effectiveColorfulIcons` y el render
//  condicional de `ProfileView.settingsRowContent` son `private` en Views y no
//  se pueden invocar desde el test target. Se cubre su LÓGICA vía réplica.
//

import Foundation
import SwiftUI
import Testing

@testable import Yala

struct YalaThemeColorfulIconsTests {

    // MARK: - Oráculo replicado (lógica exacta de las Views)

    /// Réplica INDEPENDIENTE de `MoreView.effectiveColorfulIcons` /
    /// `ProfileView.effectiveColorfulIcons`:
    /// `theme.forcesMonochromeIcons ? false : colorfulIconsToggle`.
    private func effectiveColorfulIcons(theme: YalaTheme, toggle: Bool) -> Bool {
        theme.forcesMonochromeIcons ? false : toggle
    }

    /// Réplica de `MoreView.iconColor(_:)`: el color propio si están activos los
    /// iconos coloridos efectivos, si no `.primary`.
    private func resolvedIconColor(theme: YalaTheme, toggle: Bool, own: Color) -> Color {
        effectiveColorfulIcons(theme: theme, toggle: toggle) ? own : .primary
    }

    // MARK: - (1) forcesMonochromeIcons por tema (API real)

    @Test
    func minimalist_theme_forcesMonochromeIcons() {
        #expect(YalaTheme.minimalist.forcesMonochromeIcons == true)
    }

    @Test
    func liquidGlass_theme_doesNotForceMonochromeIcons() {
        #expect(YalaTheme.liquidGlass.forcesMonochromeIcons == false)
    }

    @Test
    func translucent_theme_doesNotForceMonochromeIcons() {
        #expect(YalaTheme.translucent.forcesMonochromeIcons == false)
    }

    @Test
    func translucentRosa_theme_doesNotForceMonochromeIcons() {
        #expect(YalaTheme.translucentRosa.forcesMonochromeIcons == false)
    }

    @Test
    func translucentTeal_theme_doesNotForceMonochromeIcons() {
        #expect(YalaTheme.translucentTeal.forcesMonochromeIcons == false)
    }

    @Test
    func light_theme_doesNotForceMonochromeIcons() {
        #expect(YalaTheme.light.forcesMonochromeIcons == false)
    }

    @Test
    func dark_theme_doesNotForceMonochromeIcons() {
        #expect(YalaTheme.dark.forcesMonochromeIcons == false)
    }

    @Test
    func indigo_pro_theme_doesNotForceMonochromeIcons() {
        #expect(YalaTheme.indigo.forcesMonochromeIcons == false)
    }

    @Test
    func rosa_pro_theme_doesNotForceMonochromeIcons() {
        #expect(YalaTheme.rosa.forcesMonochromeIcons == false)
    }

    @Test
    func teal_pro_theme_doesNotForceMonochromeIcons() {
        #expect(YalaTheme.teal.forcesMonochromeIcons == false)
    }

    /// `forcesMonochromeIcons` es exactamente el espejo de `mapsColorsToGrayscale`.
    @Test
    func forcesMonochromeIcons_mirrorsMapsColorsToGrayscale() {
        #expect(YalaTheme.minimalist.forcesMonochromeIcons == YalaTheme.minimalist.mapsColorsToGrayscale)
        #expect(YalaTheme.liquidGlass.forcesMonochromeIcons == YalaTheme.liquidGlass.mapsColorsToGrayscale)
    }

    /// El único tema que fuerza monocromo entre todos los reales es Minimalista.
    @Test
    func onlyMinimalist_forcesMonochrome_amongAllThemes() {
        let all: [YalaTheme] = [
            .light, .dark, .indigo, .rosa, .teal,
            .minimalist, .translucent, .translucentRosa, .translucentTeal, .liquidGlass,
        ]
        let forcing = all.filter { $0.forcesMonochromeIcons }
        #expect(forcing.count == 1)
        #expect(forcing.first == .minimalist)
    }

    // MARK: - (2) effectiveColorfulIcons: toggle × tema

    @Test
    func effectiveColorful_minimalist_alwaysFalse_evenWithToggleOn() {
        #expect(effectiveColorfulIcons(theme: .minimalist, toggle: true) == false)
    }

    @Test
    func effectiveColorful_minimalist_falseWithToggleOff() {
        #expect(effectiveColorfulIcons(theme: .minimalist, toggle: false) == false)
    }

    @Test
    func effectiveColorful_liquidGlass_followsToggleOn() {
        #expect(effectiveColorfulIcons(theme: .liquidGlass, toggle: true) == true)
    }

    @Test
    func effectiveColorful_liquidGlass_followsToggleOff() {
        #expect(effectiveColorfulIcons(theme: .liquidGlass, toggle: false) == false)
    }

    @Test
    func effectiveColorful_translucent_followsToggleOn() {
        #expect(effectiveColorfulIcons(theme: .translucent, toggle: true) == true)
    }

    @Test
    func effectiveColorful_light_followsToggle() {
        #expect(effectiveColorfulIcons(theme: .light, toggle: true) == true)
        #expect(effectiveColorfulIcons(theme: .light, toggle: false) == false)
    }

    // MARK: - (2b) Color resuelto (iconColor)

    @Test
    func resolvedIconColor_usesOwnColor_whenColorfulEffective() {
        #expect(resolvedIconColor(theme: .liquidGlass, toggle: true, own: .orange) == .orange)
    }

    @Test
    func resolvedIconColor_usesPrimary_whenToggleOff() {
        #expect(resolvedIconColor(theme: .liquidGlass, toggle: false, own: .orange) == .primary)
    }

    @Test
    func resolvedIconColor_usesPrimary_whenThemeForcesMonochrome() {
        // Minimalista fuerza monocromo aunque el toggle esté encendido.
        #expect(resolvedIconColor(theme: .minimalist, toggle: true, own: .orange) == .primary)
    }
}
