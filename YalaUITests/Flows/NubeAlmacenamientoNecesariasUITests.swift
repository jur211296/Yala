//
//  NubeAlmacenamientoNecesariasUITests.swift
//  YalaUITests
//
//  Revisión por vistas 2.3, zona 41 («Dónde viven tus datos»), punto 1 del lote 11 de mejoras necesarias: con texto de
//  accesibilidad (AX3) la tarjeta de estado apila el icono encima del texto, y la hoja «Antes de activar la nube» lleva
//  los botones de entrar dentro de lo que se desplaza en vez de en un pie fijo que ocupaba casi media pantalla.
//
//  Cada caso tiene su control a tamaño normal, donde nada cambia: la fila de siempre y el pie fijo.
//
//  **Scheme `Yala Dev`** (con `Yala` la fila «¿Dónde viven tus datos?» no existe bajo `-uitest`) y App Attest fingido
//  (sin él la tarjeta de la nube no sale en el simulador).
//

import XCTest

final class NubeAlmacenamientoNecesariasUITests: XCTestCase {

    /// AX3: `UICTContentSizeCategoryAccessibilityXL` (AX1 = M, AX2 = L, AX3 = XL).
    private static let ax3 = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL"]

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    private func attach(_ name: String, _ app: XCUIApplication) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// Arrastre corto y lento: sin inercia, para que lo medido no se mueva al leerlo.
    private func drag(_ app: XCUIApplication, by fraction: CGFloat = 0.3) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7 - fraction))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.3)
    }

    /// Baja hasta que el elemento queda entero en la franja central de la ventana.
    private func scrollUntilVisible(_ target: XCUIElement, in app: XCUIApplication, maxDrags: Int = 20) {
        let window = app.windows.firstMatch.frame
        var drags = 0
        while drags < maxDrags {
            if target.exists, !target.frame.isEmpty,
               target.frame.minY > window.minY + 100, target.frame.maxY < window.maxY - 100 { return }
            drag(app)
            drags += 1
        }
    }

    /// Lanza, abre Ajustes y «¿Dónde viven tus datos?», y espera la tarjeta de estado.
    private func openStorage(largeText: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal", fakeAttestSupport: true, extraArguments: largeText ? Self.ax3 : [])
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap no completó.")
        app.openProfile()
        let row = app.buttons["storage_settings_row"]
        scrollUntilVisible(row, in: app, maxDrags: 30)
        XCTAssertTrue(row.waitForExistence(timeout: 5), """
            No aparece la fila «¿Dónde viven tus datos?» en Ajustes. Si la corrida usa el scheme `Yala`, es el kill de la \
            nube bajo `-uitest` y no este cambio: estos casos van con `Yala Dev`.
            """)
        row.tap()
        XCTAssertTrue(element(app, "storage_status_card").waitForExistence(timeout: 10), "La tarjeta de estado no montó.")
        return app
    }

    // MARK: - La tarjeta de estado

    // El id de la tarjeta va en el contenedor y pisa el de sus hijos (`testing.md`): el icono es su imagen y el título su
    // primer texto.

    func test_ax3_statusCard_stacksTheIconAboveTheText() {
        let app = openStorage(largeText: true)
        let icon = app.images.matching(identifier: "storage_status_card").firstMatch
        let title = app.staticTexts.matching(identifier: "storage_status_card").firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 5), "No se encontró el título de la tarjeta de estado.")
        attach("ax3-estado", app)
        XCTAssertLessThanOrEqual(icon.frame.maxY, title.frame.minY + 1, """
            Con AX3 el icono sigue al lado del texto (icono \(icon.frame), título \(title.frame)): el texto se aprieta en \
            media columna.
            """)
    }

    /// Control: a tamaño normal, la fila de siempre (icono a la izquierda del texto).
    func test_defaultSize_statusCard_keepsTheIconBesideTheText() {
        let app = openStorage(largeText: false)
        let icon = app.images.matching(identifier: "storage_status_card").firstMatch
        let title = app.staticTexts.matching(identifier: "storage_status_card").firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 5), "No se encontró el título de la tarjeta de estado.")
        attach("normal-estado", app)
        XCTAssertLessThanOrEqual(icon.frame.maxX, title.frame.minX + 1, "A tamaño normal el icono ya no va al lado del texto.")
        XCTAssertGreaterThan(icon.frame.maxY, title.frame.minY, "A tamaño normal el icono quedó encima del texto.")
    }

    // MARK: - La hoja de activar

    /// Abre la hoja «Antes de activar la nube» desde «Activar la nube».
    private func openActivationSheet(_ app: XCUIApplication) -> XCUIElement {
        let migrate = element(app, "storage_migrate_button")
        scrollUntilVisible(migrate, in: app)
        XCTAssertTrue(migrate.waitForExistence(timeout: 5), "La tarjeta de la nube no salió con App Attest fingido.")
        migrate.tap()
        let title = app.staticTexts["storage_activation_sheet"]
        XCTAssertTrue(title.waitForExistence(timeout: 10), "«Activar la nube» no abrió la hoja de activar.")
        let apple = app.buttons["storage_activation_apple"]
        XCTAssertTrue(apple.waitForExistence(timeout: 5), "La hoja no ofrece «Continuar con Apple».")
        return apple
    }

    func test_ax3_activationSheet_buttonsScrollWithTheText() {
        let app = openStorage(largeText: true)
        let apple = openActivationSheet(app)
        attach("ax3-hoja-arriba", app)
        let window = app.windows.firstMatch.frame
        let before = apple.frame
        // Con el pie fijo, el botón está siempre a la vista y no se mueve al desplazar. Dentro del desplazamiento, con AX3
        // queda abajo y sube con el texto.
        drag(app, by: 0.4)
        let after = apple.frame
        attach("ax3-hoja-desplazada", app)
        XCTAssertLessThan(after.minY, before.minY - 20, """
            Con AX3 «Continuar con Apple» no se movió al desplazar la hoja (\(before.minY) → \(after.minY)): sigue en un \
            pie fijo.
            """)
        scrollUntilVisible(app.buttons["storage_activation_cancel"], in: app)
        XCTAssertTrue(app.buttons["storage_activation_cancel"].isHittable, "«Cancelar» no se alcanza al final de la hoja.")
        XCTAssertLessThan(app.buttons["storage_activation_cancel"].frame.maxY, window.maxY, "«Cancelar» quedó fuera.")
    }

    /// Control: a tamaño normal el pie sigue fijo (el botón no se mueve al arrastrar).
    func test_defaultSize_activationSheet_keepsThePinnedFooter() {
        let app = openStorage(largeText: false)
        let apple = openActivationSheet(app)
        attach("normal-hoja", app)
        XCTAssertTrue(apple.isHittable, "A tamaño normal «Continuar con Apple» no está a la vista al abrir.")
        let before = apple.frame
        drag(app, by: 0.2)
        XCTAssertEqual(apple.frame.minY, before.minY, accuracy: 2, "A tamaño normal el pie dejó de estar fijo.")
    }
}
