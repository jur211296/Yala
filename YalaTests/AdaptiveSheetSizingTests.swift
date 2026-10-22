//
//  AdaptiveSheetSizingTests.swift
//  YalaTests
//
//  La decisión de hojas grandes sale del espacio de la VENTANA (size class horizontal), no del
//  tipo de aparato: un iPhone Duo abierto (regular) las quiere grandes, y un iPad en una ventana
//  estrecha (compact), las de iPhone. En Mac, siempre grandes.
//

import SwiftUI
import Testing

@testable import Yala

struct AdaptiveSheetSizingTests {

    // MARK: - usesLargeSheets

    @Test func compactWindow_usesPhoneSheets() {
        #expect(DS.Adaptive.usesLargeSheets(windowHorizontalSizeClass: .compact, isiOSAppOnMac: false) == false)
    }

    @Test func regularWindow_usesLargeSheets() {
        #expect(DS.Adaptive.usesLargeSheets(windowHorizontalSizeClass: .regular, isiOSAppOnMac: false) == true)
    }

    /// Sin size class conocido (previews, una vista fuera de la raíz) manda el comportamiento de iPhone.
    @Test func unknownWindow_usesPhoneSheets() {
        #expect(DS.Adaptive.usesLargeSheets(windowHorizontalSizeClass: nil, isiOSAppOnMac: false) == false)
    }

    @Test(arguments: [UserInterfaceSizeClass?.none, .compact, .regular])
    func mac_alwaysUsesLargeSheets(sizeClass: UserInterfaceSizeClass?) {
        #expect(DS.Adaptive.usesLargeSheets(windowHorizontalSizeClass: sizeClass, isiOSAppOnMac: true) == true)
    }

    // MARK: - sheetDetents

    @Test func phoneSheets_keepTheirDetents() {
        let detents: Set<PresentationDetent> = [.medium, .height(280)]
        #expect(DS.Adaptive.sheetDetents(detents, usesLargeSheets: false) == detents)
    }

    @Test func largeSheets_forceLarge() {
        #expect(DS.Adaptive.sheetDetents([.medium, .height(280)], usesLargeSheets: true) == [.large])
    }

    // MARK: - De la ventana a los detents, de punta a punta

    @Test func compactWindow_keepsMediumDetent() {
        let large = DS.Adaptive.usesLargeSheets(windowHorizontalSizeClass: .compact, isiOSAppOnMac: false)
        #expect(DS.Adaptive.sheetDetents([.medium], usesLargeSheets: large) == [.medium])
    }

    @Test func regularWindow_forcesLargeDetent() {
        let large = DS.Adaptive.usesLargeSheets(windowHorizontalSizeClass: .regular, isiOSAppOnMac: false)
        #expect(DS.Adaptive.sheetDetents([.medium], usesLargeSheets: large) == [.large])
    }
}
