//
//  BandejaUnirAlLlegarUITests.swift
//  YalaUITests
//
//  Bandeja sin duplicados, lote 2: el mismo café por Apple Pay y por el correo del banco es UN pendiente, y «Separar» en el
//  borrador lo devuelve a dos. Con `-uitest-inbox-joined-draft` la semilla une los dos por el camino de producción
//  (`InboxArrivalJoin`). Deja capturas para el entregable.
//

import XCTest

final class BandejaUnirAlLlegarUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func attachScreenshot(_ name: String, of app: XCUIApplication) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    func test_joinedDraft_showsItsSources_andSeparateBringsBothBack() {
        let app = XCUIApplication()
        app.launchForUITest(extraArguments: ["-uitest-inbox-joined-draft"])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        let inboxButton = app.buttons["panel_inbox_button"]
        XCTAssertTrue(inboxButton.waitForExistence(timeout: 10), "No apareció el botón de la Bandeja en el Panel.")
        inboxButton.tap()

        let joined = app.buttons["inbox_draft_row_Starbucks"]
        XCTAssertTrue(joined.waitForExistence(timeout: 5), "La Bandeja no mostró el café unido.")
        XCTAssertFalse(app.buttons["inbox_draft_row_STARBUCKS MIRAFLORES"].exists,
                       "El correo del mismo pago sigue como pendiente aparte: no se unió.")
        attachScreenshot("bandeja-un-pendiente", of: app)

        joined.tap()
        let sources = app.descendants(matching: .any)["inbox_joined_sources"]
        XCTAssertTrue(sources.waitForExistence(timeout: 5), "El borrador unido no dice de qué fuentes viene.")
        attachScreenshot("borrador-unido-con-separar", of: app)

        let separate = app.buttons["inbox_joined_separate"]
        XCTAssertTrue(separate.waitForExistence(timeout: 5), "No hay «Separar».")
        separate.tap()

        XCTAssertTrue(app.buttons["inbox_draft_row_STARBUCKS MIRAFLORES"].waitForExistence(timeout: 10),
                      "Tras «Separar» el correo no volvió como pendiente aparte.")
        XCTAssertTrue(app.buttons["inbox_draft_row_Starbucks"].exists, "Tras «Separar» desapareció el de Apple Pay.")
        attachScreenshot("bandeja-tras-separar", of: app)
    }
}
