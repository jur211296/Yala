//
//  PairedColumnsLogicTests.swift
//  YalaTests
//
//  Rejillas en pares del Panel y Estadísticas en ventana ancha (ticket
//  `ipad-and-duo-panel-and-statistics-use-the-width`). Anchos de referencia: el iPad Pro 13 en horizontal con barra
//  lateral (~990 de contenido), el iPad mini en vertical (680 en el Panel) y el mínimo de columna (320).
//

import CoreGraphics
import Testing

@testable import Yala

struct PairedColumnsLogicTests {
    private typealias Logic = PairedColumnsLogic

    // MARK: - Columnas

    @Test func twoColumnsWhenTwoMinimumColumnsFit() {
        #expect(Logic.columnCount(width: 656, minColumnWidth: 320, columnSpacing: 16) == 2)
        #expect(Logic.columnCount(width: 990, minColumnWidth: 320, columnSpacing: 16) == 2)
    }

    /// Un punto menos y ya no caben: una columna (Yala IA al lado, una ventana regular estrecha).
    @Test func oneColumnWhenTwoDoNotFit() {
        #expect(Logic.columnCount(width: 655, minColumnWidth: 320, columnSpacing: 16) == 1)
        #expect(Logic.columnCount(width: 375, minColumnWidth: 320, columnSpacing: 16) == 1)
    }

    // MARK: - Filas

    @Test func pairsInOrder_oddGoesLeftAlone() {
        #expect(Logic.rows(spans: [false, false, false], columns: 2) == [[0, 1], [2]])
    }

    /// Una cabecera ocupa su fila y cierra la anterior aunque esté a medias.
    @Test func spanningChildClosesHalfRow() {
        #expect(Logic.rows(spans: [false, true, false, false], columns: 2) == [[0], [1], [2, 3]])
    }

    @Test func oneColumn_everyChildAlone() {
        #expect(Logic.rows(spans: [false, true, false], columns: 1) == [[0], [1], [2]])
    }

    // MARK: - Colocación en pares

    @Test func pairedPlacements_rowHeightIsTheTallest_andColumnsSplitTheWidth() {
        let heights: [CGFloat] = [100, 60, 40]
        let result = Logic.pairedPlacements(
            width: 1000, spans: [false, false, false], minColumnWidth: 320, columnSpacing: 20, rowSpacing: 10,
            measure: { i, _ in heights[i] })
        #expect(result.placements[0] == .init(origin: .zero, slotWidth: 490, slotHeight: 100))
        #expect(result.placements[1] == .init(origin: CGPoint(x: 510, y: 0), slotWidth: 490, slotHeight: 100))
        // El impar, en la columna izquierda y a media anchura: no cruza el pliegue.
        #expect(result.placements[2] == .init(origin: CGPoint(x: 0, y: 110), slotWidth: 490, slotHeight: 40))
        #expect(result.height == 150)
    }

    @Test func pairedPlacements_spanningChildTakesTheWholeWidth() {
        let result = Logic.pairedPlacements(
            width: 1000, spans: [true, false], minColumnWidth: 320, columnSpacing: 20, rowSpacing: 10,
            measure: { _, w in w == 1000 ? 30 : 80 })
        #expect(result.placements[0] == .init(origin: .zero, slotWidth: 1000, slotHeight: 30))
        #expect(result.placements[1] == .init(origin: CGPoint(x: 0, y: 40), slotWidth: 490, slotHeight: 80))
    }

    /// Sin sitio para dos, es una pila: cada hijo a todo lo ancho, uno debajo de otro.
    @Test func pairedPlacements_narrow_isAStack() {
        let result = Logic.pairedPlacements(
            width: 600, spans: [false, false], minColumnWidth: 320, columnSpacing: 20, rowSpacing: 10,
            measure: { _, _ in 50 })
        #expect(result.placements[1] == .init(origin: CGPoint(x: 0, y: 60), slotWidth: 600, slotHeight: 50))
        #expect(result.height == 110)
    }

    // MARK: - Banda de cabecera

    /// Aviso de arriba, saldo y acciones a la izquierda, «Tus finanzas» a la derecha, y los avisos de después debajo
    /// de la banda aunque en el orden vayan entre las acciones y «Tus finanzas».
    @Test func band_leadingAndTrailingSideBySide_restBelow() {
        let columns: [HeaderBandColumn?] = [nil, .leading, .leading, nil, .trailing, nil]
        let heights: [CGFloat] = [20, 120, 44, 30, 90, 200]
        let result = Logic.bandPlacements(
            width: 1000, columns: columns, minColumnWidth: 320, columnSpacing: 20, spacing: 16,
            measure: { i, _ in heights[i] })
        let p = result.placements
        #expect(p[0] == .init(origin: .zero, slotWidth: 1000, slotHeight: 20))
        #expect(p[1] == .init(origin: CGPoint(x: 0, y: 36), slotWidth: 490, slotHeight: 120))
        #expect(p[2] == .init(origin: CGPoint(x: 0, y: 172), slotWidth: 490, slotHeight: 44))
        #expect(p[4] == .init(origin: CGPoint(x: 510, y: 36), slotWidth: 490, slotHeight: 90))
        // La banda acaba en la columna más alta (izquierda: 172 + 44 = 216).
        #expect(p[3] == .init(origin: CGPoint(x: 0, y: 232), slotWidth: 1000, slotHeight: 30))
        #expect(p[5] == .init(origin: CGPoint(x: 0, y: 278), slotWidth: 1000, slotHeight: 200))
        #expect(result.height == 478)
    }

    /// Sin «Tus finanzas» (el usuario ocultó cuentas y salud) no hay banda: la pila de siempre.
    @Test func band_withoutTrailing_isTheUsualStack() {
        let result = Logic.bandPlacements(
            width: 1000, columns: [.leading, .leading, nil], minColumnWidth: 320, columnSpacing: 20, spacing: 16,
            measure: { _, _ in 50 })
        #expect(result.placements.map(\.origin.y) == [0, 66, 132])
        #expect(result.placements.allSatisfy { $0.slotWidth == 1000 })
    }

    /// Sin sitio para dos columnas, la pila en el orden original: «Tus finanzas» después de los avisos.
    @Test func band_narrow_keepsTheOriginalOrder() {
        let result = Logic.bandPlacements(
            width: 600, columns: [.leading, nil, .trailing], minColumnWidth: 320, columnSpacing: 20, spacing: 16,
            measure: { _, _ in 50 })
        #expect(result.placements.map(\.origin.y) == [0, 66, 132])
    }
}
