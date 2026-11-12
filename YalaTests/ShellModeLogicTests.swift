//
//  ShellModeLogicTests.swift
//  YalaTests
//
//  Pure-logic tests para `ShellModeLogic.effective(hasPrivateSession:)` — el derivador ÚNICO del modo
//  de la shell. Desde el 2026-09-13 la tabla tiene UN solo término, el eje 1 del ADR 2026-09-09: antes
//  eran dos flags (el modo de onboarding y el foco de uso) y ninguno contestaba la pregunta real.
//  Sin SwiftData, sin UI, sin singletons.
//

import Foundation
import Testing

@testable import Yala

struct ShellModeLogicTests {

    @Test func conSesiónPrivada_esFull() {
        #expect(ShellModeLogic.effective(hasPrivateSession: true, prefersGroupsOnlyView: false) == .full)
    }

    @Test func sinSesiónPrivada_esGroupsFocused() {
        // Quien no tiene vida personal en este teléfono ve Yala reducida a Grupos.
        #expect(ShellModeLogic.effective(hasPrivateSession: false, prefersGroupsOnlyView: false) == .groupsFocused)
    }

    @Test func conSesiónPrivada_ySoloGruposElegido_esGroupsFocused() {
        // Card p0iu: «Solo grupos» elegido sobre Yala completo reduce la shell sin apagar la sesión.
        #expect(ShellModeLogic.effective(hasPrivateSession: true, prefersGroupsOnlyView: true) == .groupsFocused)
    }

    /// La tabla entera, que hoy son cuatro celdas. El barrido existe para que añadir un término nuevo al
    /// derivador obligue a declarar su celda aquí en vez de aparecer en silencio.
    @Test func fullTable() {
        let cases: [(Bool, Bool, ShellMode)] = [
            (true, false, .full),
            (true, true, .groupsFocused),
            (false, false, .groupsFocused),
            (false, true, .groupsFocused),
        ]
        for (hasPrivateSession, prefersGroupsOnlyView, expected) in cases {
            #expect(ShellModeLogic.effective(hasPrivateSession: hasPrivateSession,
                                             prefersGroupsOnlyView: prefersGroupsOnlyView) == expected,
                    "hasPrivateSession=\(hasPrivateSession) prefersGroupsOnlyView=\(prefersGroupsOnlyView)")
        }
    }
}
