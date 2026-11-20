//
//  TemasRepintadoUITests.swift
//  YalaUITests
//
//  Al cambiar de tema con Ajustes abierto, la hoja se repinta al instante (Jürgen, 19-nov-2026, build 2.3 (5)): de Claro
//  a Oscuro, Ajustes › Temas y la lista de Ajustes se quedaban con el texto del modo claro —gris oscuro sobre negro—
//  hasta cerrar la hoja y volver a abrirla.
//
//  Mide la pintura, no el estado: en la captura del título «Apariencia» y de la fila «Temas», el texto tiene que
//  separarse del fondo (`legibility`: del píxel sin color más oscuro al más claro). Con el bug, texto y fondo quedan
//  los dos cerca del negro (≈0,14); legible, ≈0,9. Seed `minimal`, scheme Yala Dev, arranca en Claro (`-userTheme 1`).
//

import XCTest

final class TemasRepintadoUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_cambiarAOscuroConAjustesAbierto_repintaTemasYLaLista() {
        let app = XCUIApplication()
        app.launchForUITest(extraArguments: ["-userTheme", "1"])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        app.openProfile()

        let themeRow = scrollTo(app, "profile_theme")
        XCTAssertTrue(themeRow.exists, "No apareció la fila «Temas» en Ajustes.")
        themeRow.tap()
        let title = app.staticTexts["theme_settings_title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10), "No se abrió Ajustes › Temas.")
        XCTAssertGreaterThan(legibility(of: title), 0.5, "En Claro, el título de Temas no se lee (\(legibility(of: title))).")

        // Claro → Oscuro, con la hoja abierta.
        let dark = app.buttons["theme_card_2"]
        XCTAssertTrue(dark.waitForExistence(timeout: 5), "No apareció el tema Oscuro.")
        dark.tap()
        XCTAssertTrue(waitForLegible(title),
                      "Tras elegir Oscuro, el título de Temas sigue oscuro sobre negro (\(legibility(of: title))).")

        // La lista de Ajustes, debajo, también.
        let back = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(back.waitForHittable(timeout: 5), "No apareció «Atrás» en Temas.")
        back.tap()
        XCTAssertTrue(themeRow.waitForHittable(timeout: 5), "«Atrás» no volvió a la lista de Ajustes.")
        XCTAssertTrue(waitForLegible(themeRow, labelOnly: true),
                      "La fila «Temas» de Ajustes sigue con el texto del modo claro (\(legibility(of: themeRow, labelOnly: true))).")

        // Y de vuelta a Claro, igual de al instante.
        themeRow.tap()
        let light = app.buttons["theme_card_1"]
        XCTAssertTrue(light.waitForExistence(timeout: 5), "No apareció el tema Claro.")
        light.tap()
        XCTAssertTrue(waitForLegible(title), "Tras volver a Claro, el título de Temas no se lee (\(legibility(of: title))).")
    }

    /// Cada tema que se ve sin desplazar la rejilla, saliendo cada vez de Claro: el bug solo salía al cambiar de modo
    /// (claro ↔ oscuro). Teal, Minimalista y Traslúcido son oscuros como Índigo y Rosa y pasan por la misma sonda; su
    /// claro u oscuro lo fija `ThemeWindowStyleTests.style_perTheme`. Con Pro para poder elegir los de pago.
    func test_cadaTemaConLaHojaAbierta_seLee() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, extraArguments: ["-userTheme", "1"])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        app.openProfile()
        let themeRow = scrollTo(app, "profile_theme")
        XCTAssertTrue(themeRow.exists, "No apareció la fila «Temas» en Ajustes.")
        themeRow.tap()
        let title = app.staticTexts["theme_settings_title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10), "No se abrió Ajustes › Temas.")

        let light = app.buttons["theme_card_1"]
        let steps: [(card: Int, name: String)] = [(2, "oscuro"), (3, "indigo"), (4, "rosa"), (8, "liquid-glass"), (0, "sistema")]
        for step in steps {
            light.tap()
            XCTAssertTrue(waitForLegible(title), "Al volver a Claro antes de \(step.name), el título no se lee.")
            let card = app.buttons["theme_card_\(step.card)"]
            XCTAssertTrue(card.waitForExistence(timeout: 5), "No apareció el tema \(step.name).")
            card.tap()
            XCTAssertTrue(waitForLegible(title),
                          "Claro → \(step.name) con la hoja abierta: el título no se lee (\(legibility(of: title))).")
            capture(app, "temas-\(step.name)")
        }
    }

    // MARK: - Medida

    /// Adjunta la captura y, con `YALA_CAPTURE_DIR`, la guarda para la evidencia del cierre.
    private func capture(_ app: XCUIApplication, _ name: String) {
        let shot = app.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        guard let dir = ProcessInfo.processInfo.environment["YALA_CAPTURE_DIR"], !dir.isEmpty else { return }
        do {
            try shot.pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("despues-\(name).png"))
        } catch {
            XCTFail("TemasRepintadoUITests: no se pudo guardar la captura \(name): \(error)")
        }
    }

    private func scrollTo(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        let element = app.buttons[identifier]
        var tries = 0
        while !(element.exists && element.isHittable) && tries < 14 {
            app.swipeUp()
            tries += 1
        }
        return element
    }

    /// Espera a que el texto se lea: el cambio de tema se pinta en la vuelta siguiente, no en el toque.
    private func waitForLegible(_ element: XCUIElement, labelOnly: Bool = false) -> Bool {
        let deadline = Date().addingTimeInterval(4)
        repeat {
            if legibility(of: element, labelOnly: labelOnly) > 0.5 { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        } while Date() < deadline
        return false
    }

    /// Cuánto se separa el texto del fondo en la captura del elemento (0…1): del píxel sin color más oscuro al más claro,
    /// con `min(r, g, b)` por píxel para que el color de un icono no cuente como claro. Con `labelOnly`, solo la franja
    /// del texto de una fila (sin el icono, que lleva un símbolo blanco, ni el chevron).
    private func legibility(of element: XCUIElement, labelOnly: Bool = false) -> Double {
        guard let image = element.screenshot().image.cgImage else { return -1 }
        let source: CGImage
        if labelOnly {
            let rect = CGRect(x: Double(image.width) * 0.22, y: 0,
                              width: Double(image.width) * 0.6, height: Double(image.height))
            guard let cropped = image.cropping(to: rect) else { return -1 }
            source = cropped
        } else {
            source = image
        }
        let width = source.width, height = source.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let drawn: Bool = pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return -1 }
        var darkest: UInt8 = 255, brightest: UInt8 = 0
        for index in stride(from: 0, to: pixels.count, by: 4) {
            let value = min(pixels[index], pixels[index + 1], pixels[index + 2])
            darkest = min(darkest, value)
            brightest = max(brightest, value)
        }
        return Double(brightest - darkest) / 255
    }
}
