//
//  SettingsListLayoutTests.swift
//  YalaTests
//
//  El ancho de la lista agrupada de ajustes (`YalaSettingsList`): en una ventana estrecha, el margen
//  adaptativo de siempre; en una ancha, el contenido no pasa de `readableWidth` y queda centrado. Decide
//  el ancho medido, no el aparato: un iPad en una ventana estrecha se comporta como un iPhone.
//

import SwiftUI
import Testing

@testable import Yala

struct SettingsListLayoutTests {

    private func contentWidth(_ container: CGFloat, _ sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        container - 2 * DS.Adaptive.readableListMargin(containerWidth: container, sizeClass: sizeClass)
    }

    // MARK: - Ventana estrecha: el margen de siempre

    /// iPhone SE, 17 Pro y Pro Max en vertical: el margen de 16 que ya llevaba Personalización.
    @Test(arguments: [CGFloat(375), 402, 440])
    func compactWindow_keepsCompactMargin(width: CGFloat) {
        #expect(DS.Adaptive.readableListMargin(containerWidth: width, sizeClass: .compact) == DS.Spacing.lg)
    }

    /// Sin ancho medido todavía (primer pase de layout) no hay nada que centrar.
    @Test(arguments: [UserInterfaceSizeClass?.none, .compact, .regular])
    func unmeasuredWidth_usesAdaptiveMargin(sizeClass: UserInterfaceSizeClass?) {
        #expect(
            DS.Adaptive.readableListMargin(containerWidth: 0, sizeClass: sizeClass)
                == DS.Adaptive.horizontalPadding(sizeClass)
        )
    }

    /// En regular pero sin sitio para pasar de 700, el margen adaptativo de regular (32), no menos.
    @Test func regularWindow_narrowerThanReadable_keepsRegularMargin() {
        #expect(DS.Adaptive.readableListMargin(containerWidth: 700, sizeClass: .regular) == DS.Spacing.xxxl)
    }

    // MARK: - Ventana ancha: tope legible y centrado

    /// iPad en vertical y en horizontal, iPad Pro 13: el contenido se queda en 700.
    @Test(arguments: [CGFloat(820), 1024, 1180, 1366])
    func wideWindow_capsContentAtReadableWidth(width: CGFloat) {
        let content = contentWidth(width, .regular)
        #expect(content <= DS.Adaptive.readableWidth)
        #expect(content >= DS.Adaptive.readableWidth - 1)
    }

    /// El tope no depende del size class: una columna ancha que se declare compacta (la columna de detalle
    /// de un split puede serlo) tampoco pasa de 700.
    @Test func wideButCompactSizeClass_stillCapsAtReadableWidth() {
        #expect(contentWidth(1024, .compact) <= DS.Adaptive.readableWidth)
    }

    /// Justo en el umbral: el margen adaptativo y el del tope coinciden, sin salto.
    @Test func atThreshold_marginsMeet() {
        let threshold = DS.Adaptive.readableWidth + 2 * DS.Spacing.xxxl
        #expect(DS.Adaptive.readableListMargin(containerWidth: threshold, sizeClass: .regular) == DS.Spacing.xxxl)
        #expect(DS.Adaptive.readableListMargin(containerWidth: threshold + 2, sizeClass: .regular) == DS.Spacing.xxxl + 1)
    }
}
