//
//  ListDetailOverlayLogicTests.swift
//  YalaTests
//
//  La lista tapa el detalle cuando el detalle mide el split entero con la lista a la vista (el split la
//  superpone porque no caben las dos). Lado a lado, el detalle mide el split menos la lista; con la lista
//  retirada no hay nada que retirar. Anchos medidos: iPad mini en vertical (744) y iPad Pro 13 (1032).
//

import CoreGraphics
import Testing

@testable import Yala

struct ListDetailOverlayLogicTests {
    private typealias Logic = ListDetailOverlayLogic

    @Test func overlaid_listCoversDetail() {
        #expect(Logic.listCoversDetail(splitWidth: 744, detailWidth: 744, listIsShown: true))
    }

    @Test func sideBySide_listDoesNotCoverDetail() {
        #expect(!Logic.listCoversDetail(splitWidth: 1032, detailWidth: 632, listIsShown: true))
    }

    /// Con la lista retirada el detalle también mide el split entero: no es una superposición.
    @Test func listRetired_nothingToRetire() {
        #expect(!Logic.listCoversDetail(splitWidth: 744, detailWidth: 744, listIsShown: false))
    }

    /// Antes de la primera medida (anchos a cero) no se decide nada.
    @Test func unmeasured_neverCovers() {
        #expect(!Logic.listCoversDetail(splitWidth: 0, detailWidth: 0, listIsShown: true))
        #expect(!Logic.listCoversDetail(splitWidth: 744, detailWidth: 0, listIsShown: true))
    }

    /// Redondeos de medio punto no convierten un lado a lado en superposición, ni al revés.
    @Test func halfPointRounding_isTolerated() {
        #expect(Logic.listCoversDetail(splitWidth: 744, detailWidth: 743.5, listIsShown: true))
        #expect(!Logic.listCoversDetail(splitWidth: 744, detailWidth: 742, listIsShown: true))
    }

    // MARK: - La lista se aparta cuando no cabe legible junto a lo abierto

    private func yields(_ split: CGFloat, regular: Bool = true, empty: Bool = false) -> Bool {
        Logic.listYieldsToDetail(
            splitWidth: split, minimumColumnWidth: 375, isRegularWidth: regular, detailIsEmpty: empty)
    }

    /// iPad Pro 13 en vertical con Yala IA al lado (1024 − 375 = 649) y un registro abierto.
    @Test func narrowSplitWithSomethingOpen_listYields() {
        #expect(yields(649))
    }

    /// Los dos vecinos del umbral: dos anchos de iPhone SE (750) caben; uno menos, no.
    @Test func threshold_neighbours() {
        #expect(!yields(750))
        #expect(yields(749))
    }

    /// iPad Pro 13 a pantalla completa en vertical, sin chat: caben las dos.
    @Test func wideSplit_listStays() {
        #expect(!yields(1024))
    }

    /// Con «Elige un…» en el detalle la lista no se aparta: sería una pantalla sin salida.
    @Test func emptyDetail_listStays() {
        #expect(!yields(649, empty: true))
    }

    /// Plegado (iPhone, ventana compacta) el split enseña una sola columna: no aplica.
    @Test func compact_neverYields() {
        #expect(!yields(402, regular: false))
    }

    /// Antes de la primera medida no se decide nada.
    @Test func unmeasured_neverYields() {
        #expect(!yields(0))
    }

    // MARK: - Con texto de accesibilidad la columna es más ancha, y el umbral para apartarse crece con ella

    private func yieldsWithText(_ splitWidth: CGFloat, accessibility: Bool) -> Bool {
        Logic.listYieldsToDetail(
            splitWidth: splitWidth,
            minimumColumnWidth: DS.Adaptive.listColumnWidths(isAccessibilityText: accessibility).min,
            isRegularWidth: true,
            detailIsEmpty: false)
    }

    /// Sin texto de accesibilidad, los anchos de siempre: nada cambia para quien no los usa.
    @Test func defaultText_keepsTheIPhoneWidths() {
        let widths = DS.Adaptive.listColumnWidths(isAccessibilityText: false)
        #expect(widths == DS.Adaptive.ListColumnWidths(min: 375, ideal: 400, max: 480))
    }

    /// Con AX5, «Este mes» y el chip «Presupuestos» caben en los 408 pt de contenido del Pro Max vertical y no en el
    /// SE; la columna lleva además sus márgenes (2 × 16). El margen de la isla lo suma el split. Medido el 2026-10-01.
    @Test func accessibilityText_columnFitsWhatAProMaxPortraitFits() {
        let widths = DS.Adaptive.listColumnWidths(isAccessibilityText: true)
        #expect(widths.min - 32 >= 408)
        #expect(widths.min <= widths.ideal && widths.ideal <= widths.max)
        #expect(widths.min > DS.Adaptive.listColumnMinWidth)
    }

    /// iPad Pro 13 junto a la barra lateral (1096) y en vertical (1032): con AX caben lista y algo abierto. Medido el
    /// 2026-10-01: restando además los márgenes que el proxy reporta (280), salía 816 y la lista se apartaba.
    @Test func iPadPro13_listStaysWithAccessibilityText() {
        #expect(!yieldsWithText(1096, accessibility: true))
        #expect(!yieldsWithText(1032, accessibility: true))
    }

    /// Yala IA al lado en el iPad Pro 13 vertical (649): con AX la lista se aparta, igual que sin AX.
    @Test func chatBeside_listYieldsWithAccessibilityText() {
        #expect(yieldsWithText(649, accessibility: true))
    }

    /// Los dos vecinos del umbral AX: dos columnas mínimas caben; un punto menos, no.
    @Test func accessibilityThreshold_neighbours() {
        let min = DS.Adaptive.listColumnWidths(isAccessibilityText: true).min
        #expect(!yieldsWithText(2 * min, accessibility: true))
        #expect(yieldsWithText(2 * min - 1, accessibility: true))
    }

    // MARK: - Con texto de accesibilidad y sin sitio para dos columnas, la página se pliega a la pila

    private func folds(_ pageWidth: CGFloat, accessibility: Bool = true, regular: Bool = true) -> Bool {
        Logic.foldsForAccessibilityText(
            pageWidth: pageWidth,
            minimumColumnWidth: DS.Adaptive.listColumnWidths(isAccessibilityText: true).min,
            isAccessibilityText: accessibility,
            isRegularWidth: regular)
    }

    /// El Pro Max girado con AX5: 832 pt de página no dan para dos columnas de 440, y el split superponía la lista.
    /// El iPad mini tampoco: 744 en vertical y 853 en horizontal, junto a la barra lateral (medidos el 2026-10-01).
    @Test func narrowRegularPagesWithAccessibilityText_fold() {
        #expect(folds(832))
        #expect(folds(744))
        #expect(folds(853))
    }

    /// Con texto de siempre, nunca: la columna del iPhone cabe al lado (Pro Max girado, igual que antes).
    @Test func defaultText_neverFolds() {
        #expect(!folds(832, accessibility: false))
        #expect(!folds(375, accessibility: false))
    }

    /// En el iPad Pro 13 caben dos columnas AX: sigue en split, con la lista más ancha (1032 vertical, 1096 girado).
    @Test func iPadPro13_staysSplit() {
        #expect(!folds(1032))
        #expect(!folds(1096))
    }

    /// Compacta ya es la pila; antes de medir, no se decide nada.
    @Test func compactOrUnmeasured_neverFolds() {
        #expect(!folds(832, regular: false))
        #expect(!folds(0))
    }

    /// Los dos vecinos del umbral: dos columnas AX mínimas caben; un punto menos, no.
    @Test func foldThreshold_neighbours() {
        let min = DS.Adaptive.listColumnWidths(isAccessibilityText: true).min
        #expect(!folds(2 * min))
        #expect(folds(2 * min - 1))
    }
}
