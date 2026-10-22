//
//  FabStackClearanceTests.swift
//  YalaTests
//
//  Margen inferior que reserva el contenido de un scroll para que su última fila suba por encima de los botones
//  flotantes (ticket `floating-buttons-cover-row-amounts-on-ipad-landscape`). La pila se pinta con `fabSize`,
//  `Spacing.md` entre botones y `Spacing.xxl` de margen inferior; el margen tiene que pasar de su techo.
//

import SwiftUI
import Testing

@testable import Yala

struct FabStackClearanceTests {

    /// Distancia del techo de la pila plegada al borde del área segura, tal como la pintan `FABStackView`,
    /// `ExpandableFAB` y `CircularPlusFAB` (botones + separación + margen inferior).
    private func stackTop(buttons: Int) -> CGFloat {
        let count = CGFloat(buttons)
        return count * DS.Button.fabSize + (count - 1) * DS.Spacing.md + DS.Spacing.xxl
    }

    @Test(arguments: [1, 2])
    func clearance_leavesAirAboveTheCollapsedStack(buttons: Int) {
        let clearance = DS.Button.fabStackClearance(buttons: buttons)
        #expect(clearance - stackTop(buttons: buttons) == DS.Spacing.lg)
    }

    /// Las cifras que cita el ticket: 96 con un botón, 164 con Yala IA + «+».
    @Test func clearance_values() {
        #expect(DS.Button.fabStackClearance(buttons: 1) == 96)
        #expect(DS.Button.fabStackClearance(buttons: 2) == 164)
    }

    /// Las cuatro pantallas de un botón (Presupuestos, Pagos planificados, Grupos, detalle de grupo) reservan
    /// `Spacing.safeBottom` y no se tocaron: eso solo vale mientras cubra la pila de uno. La de dos no la cubre, y por
    /// eso Registros y el Panel usan el margen de dos.
    @Test func safeBottom_coversOneButton_butNotTwo() {
        #expect(DS.Spacing.safeBottom >= DS.Button.fabStackClearance(buttons: 1))
        #expect(DS.Spacing.safeBottom < stackTop(buttons: 2))
    }

    /// Una cuenta sin sentido no deja el margen en negativo ni en cero.
    @Test func clearance_neverDropsBelowOneButton() {
        #expect(DS.Button.fabStackClearance(buttons: 0) == DS.Button.fabStackClearance(buttons: 1))
    }
}
