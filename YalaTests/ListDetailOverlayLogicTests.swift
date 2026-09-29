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
}
