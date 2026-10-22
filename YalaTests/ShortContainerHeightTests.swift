//
//  ShortContainerHeightTests.swift
//  YalaTests
//
//  Con poco alto (un iPhone girado) la cabecera de Registros y de Estadísticas › Resumen va en banda (ticket
//  `iphone-landscape-headers-fill-the-short-screen`). Lo decide el ALTO medido del contenedor, nunca la orientación:
//  aquí se fija dónde cae el umbral respecto a los contenedores que se midieron.
//

import SwiftUI
import Testing

@testable import Yala

struct ShortContainerHeightTests {

    /// Girados, con las barras: Estadísticas en un SE (~320), Registros en un SE (375) y en un Pro Max (440).
    @Test(arguments: [320.0, 375.0, 440.0])
    func landscapePhoneContainers_areShort(height: CGFloat) {
        #expect(DS.Adaptive.isShortContainer(height: height))
    }

    /// En vertical, del más bajo (Estadísticas en un SE, bajo su barra de chips: ~615) a un iPad mini girado (744) y
    /// un iPad Pro.
    @Test(arguments: [615.0, 667.0, 744.0, 1366.0])
    func portraitAndTabletContainers_areNotShort(height: CGFloat) {
        #expect(!DS.Adaptive.isShortContainer(height: height))
    }

    /// El umbral es exclusivo: justo en él, alto suficiente; un punto menos, poco alto.
    @Test func threshold_isExclusive() {
        let limit = DS.Adaptive.shortContainerMaxHeight
        #expect(!DS.Adaptive.isShortContainer(height: limit))
        #expect(DS.Adaptive.isShortContainer(height: limit - 1))
    }

    /// Antes de la primera medida el alto es 0: no se compacta (la cabecera de siempre hasta saber el alto).
    @Test func unmeasuredContainer_isNotShort() {
        #expect(!DS.Adaptive.isShortContainer(height: 0))
    }
}
