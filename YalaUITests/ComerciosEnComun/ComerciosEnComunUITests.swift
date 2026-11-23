//
//  ComerciosEnComunUITests.swift
//  YalaUITests
//
//  «Comercios en común» (2.3, 2026-11-22):
//  - Con la lista común sembrada (`-uitest-comercios-comun-lista`), una foto de un comercio que nunca apuntaste trae la
//    categoría puesta y la línea «Así suele categorizarse… · Cambiar», que abre el selector de categoría.
//  - Control: sin la lista, la misma foto llega sin categoría y sin línea.
//  - Perfil › Comercios en común: la fila y el interruptor «Aportar comercios», encendido por defecto.
//  Scheme Yala Dev, seed `minimal`, la app en español (`launchForUITest`): el comercio de la foto fingida es
//  «Restaurante El Buen Gusto».
//

import XCTest

final class ComerciosEnComunUITests: XCTestCase {

    private static let lista = "RESTAURANTE EL BUEN GUSTO=restaurant"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func openAndRead(conLista: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        var extra = ["-uitest-image-result", "incomplete", "-uitest-image-autoclose-seconds", "30"]
        if conLista { extra += ["-uitest-comercios-comun-lista", Self.lista] }
        app.launchForUITest(pro: true, aiConsent: true, extraArguments: extra)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        if UIDevice.current.userInterfaceIdiom == .pad {
            let image = app.buttons["panel_action_image"]
            XCTAssertTrue(image.waitForHittable(timeout: 10), "Falta la acción de imagen del Panel.")
            image.tap()
        } else {
            app.revealPanelFAB().tap()
            let image = app.buttons["fab_image"]
            XCTAssertTrue(image.waitForExistence(timeout: 5), "El menú del FAB no ofreció imagen (fab_image).")
            image.tap()
        }
        let photos = app.buttons["image_source_photos"]
        XCTAssertTrue(photos.waitForExistence(timeout: 15), "La hoja no abrió eligiendo (image_source_photos).")
        photos.tap()
        XCTAssertTrue(app.staticTexts["image_review_title"].waitForExistence(timeout: 20), "No apareció lo leído.")
        return app
    }

    func test_conLaListaComun_laCategoriaVienePuesta_conSuLinea_yCambiarAbreElSelector() {
        let app = openAndRead(conLista: true)
        XCTAssertTrue(app.buttons["esto_lei_subcategory"].waitForExistence(timeout: 10),
                      "La lista común tenía que proponer la categoría del restaurante.")
        let linea = app.descendants(matching: .any)["comercios_comun_linea"].firstMatch
        XCTAssertTrue(linea.waitForExistence(timeout: 5), "Falta la línea «Así suele categorizarse…».")
        capture(app, "despues-1-esto-lei-con-lista-comun")
        let cambiar = app.buttons["comercios_comun_cambiar"]
        XCTAssertTrue(cambiar.waitForHittable(timeout: 5), "Falta «Cambiar».")
        cambiar.tap()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "subcategory_selector_row_")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "«Cambiar» no abrió el selector de categoría.")
    }

    func test_sinLaListaComun_laMismaFotoLlegaSinCategoria_niLinea() {
        let app = openAndRead(conLista: false)
        XCTAssertTrue(app.buttons["voice_draft_chip_subcategory"].waitForExistence(timeout: 10),
                      "Sin lista común, la categoría falta, como antes.")
        XCTAssertFalse(app.descendants(matching: .any)["comercios_comun_linea"].firstMatch.exists,
                       "Sin lista común no hay línea.")
        capture(app, "antes-1-esto-lei-sin-lista-comun")
    }

    func test_perfil_tieneLaFila_yAportarVieneEncendido() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        app.openProfile()
        let row = app.buttons["profile_comercios_comun"]
        var swipes = 0
        while !(row.exists && row.isHittable) && swipes < 8 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(row.exists, "Falta la fila «Comercios en común» en Perfil.")
        row.tap()
        let toggle = app.switches["comercios_comun_aportar"].firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 10), "Falta «Aportar comercios».")
        XCTAssertEqual(toggle.value as? String, "1", "Aportar viene encendido por defecto (aviso + salida).")
        capture(app, "despues-2-perfil-comercios-en-comun")
        toggle.switches.firstMatch.tap()
        XCTAssertEqual(toggle.value as? String, "0", "Se apaga desde aquí.")
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
