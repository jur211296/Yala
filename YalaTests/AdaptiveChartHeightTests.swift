//
//  AdaptiveChartHeightTests.swift
//  YalaTests
//
//  Las gráficas de tendencia ganan alto con el ancho en los iPhone grandes (ticket
//  `iphone-large-models-use-the-extra-width`). Lo decide el ANCHO medido de la gráfica y solo en ancho compacto: el
//  iPhone pequeño y el iPad no cambian.
//

import SwiftUI
import Testing

@testable import Yala

struct AdaptiveChartHeightTests {

    /// Ancho de la gráfica de tendencia dentro de su tarjeta en un iPhone de 375 pt (SE) y de 440 pt (Pro Max):
    /// 375 − 2 × 16 de margen − 2 × 16 de tarjeta, y lo mismo con 440.
    private let smallPhoneChartWidth: CGFloat = 311
    private let proMaxChartWidth: CGFloat = 376

    @Test func smallPhone_keepsTheBaseHeight() {
        #expect(DS.Adaptive.chartHeight(base: 170, width: smallPhoneChartWidth, sizeClass: .compact) == 170)
    }

    /// El umbral es exclusivo: justo en 320 pt no crece; un punto más, sí.
    @Test func referenceWidth_isTheLastWidthThatKeepsTheBase() {
        #expect(DS.Adaptive.chartHeight(base: 170, width: 320, sizeClass: .compact) == 170)
        #expect(DS.Adaptive.chartHeight(base: 170, width: 321, sizeClass: .compact) > 170)
    }

    /// Conserva la proporción: 170 × 376 / 320 = 199,75 → 200.
    @Test func proMax_growsInProportionToItsWidth() {
        #expect(DS.Adaptive.chartHeight(base: 170, width: proMaxChartWidth, sizeClass: .compact) == 200)
    }

    /// Techo +20 %: una ventana compacta muy ancha (un iPad en Split View ancho) no estira la gráfica sin fin.
    @Test(arguments: [384.0, 500.0, 1000.0])
    func growthIsCappedAtTwentyPercent(width: CGFloat) {
        #expect(DS.Adaptive.chartHeight(base: 170, width: width, sizeClass: .compact) == 204)
    }

    /// En ancho regular la composición es de la fase 2b (iPad, Duo abierto): ahí no cambia nada.
    @Test(arguments: [376.0, 500.0, 800.0])
    func regularWidth_keepsTheBaseHeight(width: CGFloat) {
        #expect(DS.Adaptive.chartHeight(base: 170, width: width, sizeClass: .regular) == 170)
    }

    /// Sin size class conocido, o antes de la primera medida (ancho 0), lo de siempre.
    @Test func unknownSizeClassOrUnmeasuredWidth_keepsTheBaseHeight() {
        #expect(DS.Adaptive.chartHeight(base: 170, width: proMaxChartWidth, sizeClass: nil) == 170)
        #expect(DS.Adaptive.chartHeight(base: 170, width: 0, sizeClass: .compact) == 170)
    }
}
