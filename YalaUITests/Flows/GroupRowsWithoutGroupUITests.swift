//
//  GroupRowsWithoutGroupUITests.swift
//  YalaUITests
//
//  Filas de grupo sin su grupo o sin su cuenta:
//  - un gasto de grupo cuyo grupo no está en este teléfono se quita de la Bandeja SOLO aquí
//    (ticket `prior-icloud-group-records-summed-without-their-group`, seed `gasto-de-grupo-sin-su-grupo`);
//  - la pata real de una cena de grupo pagada desde una cuenta eliminada sale en «Movimientos sin cuenta» y vuelve al
//    saldo (ticket `orphaned-group-records-stay-out-of-the-notice`, seed `pata-de-grupo-sin-cuenta`).
//

import XCTest

final class GroupRowsWithoutGroupUITests: XCTestCase {

    private let foreignDraft = "Cena del viaje (grupo de otro teléfono)"
    private let personalDraft = "Café"
    private let bank = "Banco QA"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func openInbox(_ app: XCUIApplication) {
        let inboxButton = app.buttons["panel_inbox_button"]
        XCTAssertTrue(inboxButton.waitForExistence(timeout: 10), "No apareció el botón de la Bandeja en el Panel.")
        inboxButton.tap()
    }

    /// El gasto de grupo sin su grupo solo ofrece «Quitar de aquí»; al tocarlo sale de la Bandeja, el borrador personal
    /// sigue, y tras relanzar no vuelve (la lista local persiste).
    func test_groupExpenseWithoutItsGroup_isRemovedHere_andStaysRemovedAfterRelaunch() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "gasto-de-grupo-sin-su-grupo")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        openInbox(app)

        let row = app.buttons["inbox_draft_row_\(foreignDraft)"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "La Bandeja no enseña el gasto de grupo sin su grupo.")
        XCTAssertTrue(app.buttons["inbox_draft_row_\(personalDraft)"].exists, "Falta el borrador personal de control.")

        row.swipeLeft()
        let hide = app.buttons["inbox_hide_here"]
        XCTAssertTrue(hide.waitForExistence(timeout: 5), "El gasto de grupo sin su grupo no ofrece «Quitar de aquí».")
        hide.tap()

        XCTAssertTrue(row.waitForNonExistence(timeout: 5), "El gasto de grupo sigue en la Bandeja tras quitarlo.")
        XCTAssertTrue(app.buttons["inbox_draft_row_\(personalDraft)"].exists, "Quitarlo se llevó otro borrador.")

        // Segundo arranque sobre el mismo store: sin reset y sin volver a sembrar (sembrar duplica).
        app.terminate()
        app.launchForUITest(reset: false, seed: nil)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente en el segundo arranque.")
        openInbox(app)
        XCTAssertTrue(app.buttons["inbox_draft_row_\(personalDraft)"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["inbox_draft_row_\(foreignDraft)"].exists,
                       "El gasto de grupo quitado volvió a la Bandeja tras relanzar.")
    }

    /// Un borrador personal no ofrece «Quitar de aquí»: sigue con Eliminar y Rechazar.
    func test_personalDraft_doesNotOfferRemoveHere() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "gasto-de-grupo-sin-su-grupo")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        openInbox(app)

        let row = app.buttons["inbox_draft_row_\(personalDraft)"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.swipeLeft()
        // Ancla de la ausencia: el gesto sí abrió sus acciones de siempre.
        XCTAssertTrue(app.buttons["inbox_swipe_reject"].waitForExistence(timeout: 5),
                      "El deslizamiento no abrió las acciones del borrador personal.")
        XCTAssertFalse(app.buttons["inbox_hide_here"].exists, "Un borrador personal no debía ofrecer «Quitar de aquí».")
    }

    /// La pata real de la cena de grupo (−60) sale en el aviso junto a Taxi y Teléfono, y al moverlos a «Banco QA» el
    /// saldo pasa de 1.000 a 882.
    func test_groupLegWithoutAccount_isInTheNotice_andMovingItRestoresTheBalance() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "pata-de-grupo-sin-cuenta")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        let banner = app.buttons["orphaned_records_banner"]
        XCTAssertTrue(banner.waitForExistence(timeout: 10), "El Panel no avisa de los movimientos sin cuenta.")
        XCTAssertTrue(banner.label.contains("3"), "El aviso debía decir 3 (Taxi, Teléfono y la cena): «\(banner.label)».")
        banner.tap()

        let count = app.descendants(matching: .any)["orphaned_records_count"]
        XCTAssertTrue(count.waitForExistence(timeout: 5), "La hoja no dice cuántos movimientos son.")
        XCTAssertTrue(count.label.hasSuffix(" 3"), "La hoja debía contar 3 y dice «\(count.label)».")

        let destination = app.buttons["orphaned_records_destination_\(bank)"]
        XCTAssertTrue(destination.waitForExistence(timeout: 5), "No aparece «\(bank)» como destino.")
        if !destination.isSelected { destination.tap() }
        let move = app.buttons["orphaned_records_move"]
        XCTAssertTrue(move.waitForHittable(timeout: 5))
        move.tap()

        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: banner)
        wait(for: [gone], timeout: 10)

        app.openProfile()
        app.openSettingsSection("profile_accounts")
        let bankRow = app.buttons["accounts_row_\(bank)"]
        let moved = expectation(for: NSPredicate(format: "label CONTAINS '882'"), evaluatedWith: bankRow)
        wait(for: [moved], timeout: 10)
    }
}
