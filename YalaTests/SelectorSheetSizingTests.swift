//
//  SelectorSheetSizingTests.swift
//  YalaTests
//
//  Cómo abren los selectores de registro (cuenta, etiquetas, subcategoría): a media altura desde un registro nuevo,
//  como siempre en el resto (ticket `record-selectors-open-at-medium-detent`).
//

import SwiftUI
import Testing

@testable import Yala

struct SelectorSheetSizingTests {

    // MARK: - detents

    @Test func large_declaresNoDetent() {
        #expect(SelectorSheetSizing.large.detents(dynamicTypeSize: .large).isEmpty)
    }

    @Test func mediumFirst_opensAtMediumAndStretchesToLarge() {
        #expect(SelectorSheetSizing.mediumFirst.detents(dynamicTypeSize: .large) == [.medium, .large])
    }

    /// A media altura con texto de accesibilidad solo caben una o dos filas: abre grande.
    @Test(arguments: [DynamicTypeSize.accessibility1, .accessibility5])
    func mediumFirst_accessibilityText_opensLarge(size: DynamicTypeSize) {
        #expect(SelectorSheetSizing.mediumFirst.detents(dynamicTypeSize: size) == [.large])
    }

    // MARK: - background

    @Test func mediumFirst_atMedium_isTransparent() {
        let background = SelectorSheetSizing.mediumFirst.background(
            selectedDetent: .medium, usesLargeSheets: false, dynamicTypeSize: .large
        )
        #expect(background == .transparent)
    }

    @Test func mediumFirst_stretched_isSubtle() {
        let background = SelectorSheetSizing.mediumFirst.background(
            selectedDetent: .large, usesLargeSheets: false, dynamicTypeSize: .large
        )
        #expect(background == .subtle)
    }

    /// En ventana ancha `.yalaSheetDetents` presenta `[.large]` aunque el detent elegido siga en `.medium`.
    @Test func mediumFirst_wideWindow_isSubtle() {
        let background = SelectorSheetSizing.mediumFirst.background(
            selectedDetent: .medium, usesLargeSheets: true, dynamicTypeSize: .large
        )
        #expect(background == .subtle)
    }

    @Test func mediumFirst_accessibilityText_isSubtle() {
        let background = SelectorSheetSizing.mediumFirst.background(
            selectedDetent: .medium, usesLargeSheets: false, dynamicTypeSize: .accessibility3
        )
        #expect(background == .subtle)
    }
}
