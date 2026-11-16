//
//  RecordsVoiceOver23UITests.swift
//  YalaUITests
//
//  Lote de Registros 2.3 (decisiones 77 y 78 de la discusión del 9-nov), la parte que se ve:
//  - 77: con la lista vacía desaparecía el selector Lista/Calendario. Ahora se queda, también en modo calendario.
//  - 78: un fallo al leer los movimientos se veía como «Sin registros». Ahora sale el error con «Reintentar».
//    `-uitest-records-load-fails` finge el almacén que no se deja leer; qué enseña la lista lo decide la app.
//  Los casos de la fecha en VoiceOver, la pista de las etiquetas y la tarjeta de Siri van en `RecordsVoiceOver23Tests`.
//

import XCTest

final class RecordsVoiceOver23UITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Captura para la evidencia del PR (se exporta del `.xcresult`).
    private func attach(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// Sin semilla: Registros sin un solo movimiento, «Sin registros en este periodo».
    func test_emptyList_keepsTheListCalendarSelector() {
        let app = XCUIApplication()
        app.launchForUITest(seed: nil, deeplink: "records")
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap no completó.")

        let listMode = app.buttons["records_view_mode_list"]
        let calendarMode = app.buttons["records_view_mode_calendar"]
        XCTAssertTrue(listMode.waitForExistence(timeout: 10), "Con la lista vacía no está el selector Lista/Calendario.")
        XCTAssertTrue(calendarMode.exists, "Con la lista vacía falta «Calendario» en el selector.")
        XCTAssertFalse(app.buttons.matching(identifier: "record_row").firstMatch.exists,
                       "El escenario no discrimina: la lista tiene filas.")
        attach("despues-1-lista-vacia")

        calendarMode.tap()
        XCTAssertTrue(calendarMode.waitForExistence(timeout: 5), "Al pasar a Calendario el selector desapareció.")
        XCTAssertTrue(calendarMode.isSelected, "El toque no eligió Calendario.")
        XCTAssertTrue(listMode.exists, "En modo Calendario con la lista vacía falta «Lista».")
        attach("despues-2-calendario-vacio")
    }

    func test_loadFailure_showsTheError_notTheEmptyList() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal", deeplink: "records", extraArguments: ["-uitest-records-load-fails"])
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")

        let retry = app.buttons["records_load_error_retry"]
        XCTAssertTrue(retry.waitForExistence(timeout: 10),
                      "Con la lectura de los movimientos fallando no sale el error con «Reintentar».")
        XCTAssertFalse(app.buttons["records_view_mode_list"].exists,
                       "Con el error se pinta el selector Lista/Calendario, como si la lista estuviera vacía.")
        attach("despues-3-error-de-carga")

        // Reintentar vuelve a leer; con la lectura aún fallando, el error sigue (no pasa a «Sin registros»).
        retry.tap()
        XCTAssertTrue(retry.waitForExistence(timeout: 5), "Tras «Reintentar» el error desapareció sin datos que enseñar.")
    }
}
