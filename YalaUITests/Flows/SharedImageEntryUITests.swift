//
//  SharedImageEntryUITests.swift
//  YalaUITests
//
//  Compartir una foto a Yala desde otra app arranca la lectura (ticket
//  share-image-reading-does-not-always-start). La extensión de compartir es otro proceso y XCUITest no la conduce:
//  el seam `uitest-stage=readable` de `<scheme>://shared-image` deja el recibo de ejemplo en `PendingImages/` como lo
//  haría la extensión, y la URL sigue por el camino real (`onOpenURL` → `handleIncomingURL` → router → Panel).
//  «Arranca la lectura» = la hoja enseña lo leído (`image_review_title`, con `-uitest-image-result one`).
//  Convenciones: ver CLAUDE.md (sin sleeps, scheme Yala Dev).
//

import XCTest

final class SharedImageEntryUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// El scheme del build que corre los XCUITest (`Yala Dev`): `handleIncomingURL` descarta cualquier otro.
    /// Se abre con `XCUIDevice.shared.system.open`, como lo abriría la extensión: `XCUIApplication.open(_:)` RELANZA la
    /// app (medido el 2026-10-10: «Launch com.jurgenschmidt.yala.dev»), y eso es un arranque en frío, no el caso caliente.
    private let shareURL = URL(string: "yaladev://shared-image?uitest-stage=readable")!

    /// Abre la URL del share por el sistema. Si SpringBoard pregunta «¿Abrir en …?», se acepta.
    private func openShare() {
        XCUIDevice.shared.system.open(shareURL)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let open = springboard.alerts.buttons.element(boundBy: 1)
        if springboard.alerts.firstMatch.waitForExistence(timeout: 3), open.exists { open.tap() }
    }

    private func launch(_ extra: [String] = [], inboxAlert: Bool = false, deeplinkURL: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(
            pro: true, deeplinkURL: deeplinkURL, inboxAlert: inboxAlert, aiConsent: true,
            extraArguments: ["-uitest-image-result", "one"] + extra)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        return app
    }

    private func assertReadingStarts(
        _ app: XCUIApplication, timeout: TimeInterval = 30, _ message: String,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertTrue(app.staticTexts["image_review_title"].waitForExistence(timeout: timeout), message,
                      file: file, line: line)
    }

    /// a) En frío: la URL entra antes de que el arranque termine.
    func test_coldLaunch_sharedImage_startsReading() {
        let app = launch(deeplinkURL: "yala://shared-image?uitest-stage=readable")
        assertReadingStarts(app, "En frío, la foto compartida tenía que leerse (image_review_title).")
    }

    /// b) Con la app delante.
    func test_foreground_sharedImage_startsReading() {
        let app = launch()
        openShare()
        assertReadingStarts(app, "Con Yala delante, la foto compartida tenía que leerse (image_review_title).")
    }

    /// b) Con la app en segundo plano, que es el caso de compartir desde Fotos.
    func test_background_sharedImage_startsReading() {
        let app = launch()
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 15), "Yala no pasó a segundo plano.")
        openShare()
        assertReadingStarts(app, "Desde segundo plano, la foto compartida tenía que leerse (image_review_title).")
    }

    /// Dos veces seguidas desde segundo plano: la segunda no puede quedarse esperando a la primera.
    func test_background_twice_bothStartReading() {
        let app = launch()
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 15), "Yala no pasó a segundo plano.")
        openShare()
        assertReadingStarts(app, "La primera foto compartida tenía que leerse.")

        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 15), "Yala no pasó a segundo plano la segunda vez.")
        openShare()
        // La hoja de la primera sigue abierta: la segunda espera a que se cierre (no se consume tapada).
        let close = app.buttons["image_close"]
        XCTAssertTrue(close.waitForExistence(timeout: 10), "Falta la X de la hoja de lectura (image_close).")
        close.tap()
        // No se aserta que «Esto leí» desaparezca: la segunda foto se presenta y se lee en cuanto se cierra la primera,
        // a veces antes de que XCUITest vea el hueco (medido el 2026-10-10). Si la segunda se quedara retenida, el
        // título desaparecería y la espera de abajo fallaría.
        assertReadingStarts(app, "La segunda foto compartida tenía que leerse al cerrar la primera.")
    }

    /// c) Con la Bandeja abierta: la lectura espera a que se cierre y arranca sola al cerrarla.
    func test_inboxOpen_sharedImage_startsReadingWhenInboxCloses() {
        let app = launch()
        let inboxButton = app.buttons["panel_inbox_button"]
        XCTAssertTrue(inboxButton.waitForExistence(timeout: 10), "Falta el botón de la Bandeja (panel_inbox_button).")
        inboxButton.tap()
        let close = app.buttons["inbox_close"]
        XCTAssertTrue(close.waitForExistence(timeout: 10), "La Bandeja no se abrió (inbox_close).")

        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 15), "Yala no pasó a segundo plano.")
        openShare()
        XCTAssertTrue(close.waitForExistence(timeout: 10), "La Bandeja tenía que seguir abierta al volver.")

        close.tap()
        assertReadingStarts(app, "Al cerrar la Bandeja, la foto compartida tenía que leerse.")
    }

    /// c) Con una hoja de OTRA pestaña abierta (el detalle de un registro en Estadísticas › Registros). Hasta el
    /// 2026-10-11 la lectura se presentaba encima y tumbaba esa hoja; ahora espera a que se cierre, como con las hojas
    /// del Panel (ticket entry-to-panel-closes-sheets-of-other-tabs; el formulario a medias, en
    /// `ExternalEntryForeignSheetUITests`).
    func test_foreignSheetOpen_sharedImage_startsReadingWhenItCloses() {
        let app = launch()
        app.tabBars.buttons.element(boundBy: 1).tap()
        let recordsChip = app.buttons["detail_chip_registros"]
        XCTAssertTrue(recordsChip.waitForExistence(timeout: 10), "No apareció el chip Registros en Estadísticas.")
        let chipsBar = app.scrollViews.containing(.button, identifier: "detail_chip_insights").firstMatch
        if chipsBar.exists { chipsBar.swipeLeft() }
        recordsChip.tap()
        let firstRow = app.buttons.matching(identifier: "record_row").element(boundBy: 0)
        XCTAssertTrue(firstRow.waitForExistence(timeout: 10), "No hay filas de registro (record_row).")
        firstRow.tap()
        let detailClose = app.buttons["transaction_detail_close"]
        XCTAssertTrue(detailClose.waitForExistence(timeout: 10), "No se abrió el detalle del registro.")

        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 15), "Yala no pasó a segundo plano.")
        openShare()
        // El detalle no se puede cerrar solo: se espera a que desaparezca y lo correcto es agotar la espera.
        let closes = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: detailClose)
        XCTAssertEqual(XCTWaiter().wait(for: [closes], timeout: 10), .timedOut,
                       "La foto compartida cerró el detalle del registro abierto en Estadísticas.")

        detailClose.tap()
        assertReadingStarts(app, "Al cerrar el detalle del registro, la foto compartida tenía que leerse.")
    }

    /// c) Con una hoja del Panel que ningún flag publica (el «?» de un widget): la lectura se pide con esa hoja arriba
    /// y sale al cerrarla. Medido el 2026-10-10: pasa igual sin comprobar la ventana en el Panel (el mutante que la
    /// apagaba sobrevivió), así que esa comprobación no se añadió; este caso queda como red del escenario.
    func test_unpublishedPanelSheetOpen_sharedImage_startsReadingWhenItCloses() {
        let app = launch()
        let info = app.buttons["widget_info_trend"]
        XCTAssertTrue(info.waitForExistence(timeout: 10), "Falta el «?» del widget de tendencia (widget_info_trend).")
        info.tap()
        let close = app.buttons["widget_info_close"]
        XCTAssertTrue(close.waitForExistence(timeout: 10), "No se abrió la hoja de información del widget.")

        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 15), "Yala no pasó a segundo plano.")
        openShare()
        XCTAssertTrue(close.waitForExistence(timeout: 10), "La hoja de información tenía que seguir abierta al volver.")

        close.tap()
        assertReadingStarts(app, "Al cerrar la hoja de información, la foto compartida tenía que leerse.")
    }

    /// c) Con un aviso de arranque delante (el de la Bandeja): la lectura espera a que se conteste.
    func test_startupNoticeOpen_sharedImage_startsReadingWhenAnswered() {
        let app = launch(inboxAlert: true)
        let dismiss = app.buttons["inbox_alert_dismiss"]
        XCTAssertTrue(dismiss.waitForExistence(timeout: 20), "No salió el aviso de la Bandeja.")

        openShare()
        XCTAssertTrue(dismiss.waitForExistence(timeout: 10), "El aviso tenía que seguir delante.")
        dismiss.tap()
        assertReadingStarts(app, "Al contestar el aviso de arranque, la foto compartida tenía que leerse.")
    }
}
