//
//  SettingsReturnOpeningTests.swift
//  YalaTests
//
//  L16-5 · card 6d71: la reapertura de Ajustes tras cambiar el idioma espera a que la ventana se libere de las hojas de
//  antes del cambio, comprueba que la hoja nueva llegó a UIKit y, si no llegó, deja el botón de Ajustes vivo.
//

import Testing
@testable import Yala

@MainActor
@Suite("L16-5 · reabrir Ajustes tras cambiar el idioma sin dejar el botón muerto")
struct SettingsReturnOpeningTests {

    /// Una ventana de mentira: `busyPolls` vueltas con las hojas viejas cerrándose, y después lo que haga la hoja pedida.
    final class FakeWindow {
        var busyPolls: Int
        /// Cuántas peticiones se descartan antes de que una llegue a presentarse (`Int.max` = ninguna llega).
        var dropsBeforeTaking: Int
        var flag = false
        var presented = false
        var opens = 0
        var releases = 0
        var openedWhileBusy = false

        init(busyPolls: Int, dropsBeforeTaking: Int = 0) {
            self.busyPolls = busyPolls
            self.dropsBeforeTaking = dropsBeforeTaking
        }

        var isPresenting: Bool { busyPolls > 0 || presented }

        func open() {
            opens += 1
            if busyPolls > 0 { openedWhileBusy = true }
            flag = true
            if dropsBeforeTaking > 0 { dropsBeforeTaking -= 1 } else { presented = true }
        }

        func release() {
            releases += 1
            flag = false
        }

        func pause() {
            if busyPolls > 0 { busyPolls -= 1 }
        }
    }

    private func run(_ window: FakeWindow) async -> SettingsReturnOpening.Outcome {
        await SettingsReturnOpening.run(
            isWindowPresenting: { window.isPresenting },
            open: { window.open() },
            release: { window.release() },
            pause: { window.pause() })
    }

    @Test("Con las hojas de antes cerrándose, la pide solo cuando la ventana queda libre")
    func waitsForTheOldSheetsToClose() async {
        let window = FakeWindow(busyPolls: 8)
        #expect(await run(window) == .presented)
        #expect(window.opens == 1)
        #expect(!window.openedWhileBusy, "pedir la hoja con el cierre en curso es el bug: UIKit la descarta")
        #expect(window.flag && window.presented)
    }

    @Test("Con la ventana ya libre, la pide en el acto")
    func opensRightAwayWhenFree() async {
        let window = FakeWindow(busyPolls: 0)
        #expect(await run(window) == .presented)
        #expect(window.opens == 1 && window.releases == 0)
    }

    @Test("Si la hoja pedida no llega, baja el flag y la vuelve a pedir")
    func retriesWhenThePresentationIsDropped() async {
        let window = FakeWindow(busyPolls: 0, dropsBeforeTaking: 1)
        #expect(await run(window) == .presented)
        #expect(window.opens == 2)
        #expect(window.releases == 1)
        #expect(window.flag && window.presented)
    }

    @Test("Si nunca llega, el flag queda en false: el botón de Ajustes sigue abriendo")
    func neverLeavesTheFlagStuck() async {
        let window = FakeWindow(busyPolls: 0, dropsBeforeTaking: .max)
        #expect(await run(window) == .neverTook)
        #expect(window.opens == SettingsReturnOpening.maxAttempts)
        #expect(!window.flag, "con el flag en true y sin hoja, tocar el avatar no hace nada")
    }

    @Test("Si la ventana no se libera, no pide nada y no toca el flag")
    func givesUpWithoutOpeningWhenTheWindowStaysBusy() async {
        let window = FakeWindow(busyPolls: .max)
        #expect(await run(window) == .slotNeverFreed)
        #expect(window.opens == 0)
        #expect(!window.flag)
    }
}
