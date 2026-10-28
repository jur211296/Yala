//
//  GroupsListNoticeAlignmentUITests.swift
//  YalaUITests
//
//  **Card rj3b (Jürgen, 2026-10-28).** En la lista de Grupos, la tarjeta «Avisos del grupo» no se podía quitar, y ella y
//  los botones «Nuevo gasto» / «Nuevo grupo» quedaban 16 pt más adentro que las tarjetas de grupo (Jurpi, Matri), que son
//  la referencia: llevaban su propio margen encima del que ya pone el scroll. Medido en píxeles antes del arreglo: 32 pt
//  frente a 16.
//
//  La tarjeta solo sale a quien nunca la vio, y bajo `-uitest` se da por vista (`UITestEphemeralDefaults`, dominio de
//  registro): el argumento `-hasSeenGroupsNotificationPrompt NO` va al dominio de argumentos, que manda sobre ése.
//

import XCTest

final class GroupsListNoticeAlignmentUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_notificationsCard_alignsWithTheGroupCards_andItsXDismissesIt() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "solo-grupos", groupInvite: true,
                            extraArguments: ["-hasSeenGroupsNotificationPrompt", "NO"])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        let card = app.descendants(matching: .any)["group_notifications_card"]
        XCTAssertTrue(card.waitForExistence(timeout: 15), "La tarjeta «Avisos del grupo» no salió en la lista.")
        let groupCard = app.buttons.matching(identifier: "group_card").firstMatch
        let newExpense = app.buttons["groups_action_new_expense"]
        XCTAssertTrue(groupCard.waitForExistence(timeout: 5) && newExpense.exists, "Faltan las tarjetas o los botones.")

        // Las tarjetas de grupo son la referencia: mismo borde izquierdo y derecho para la tarjeta de avisos, y mismo borde
        // izquierdo para la fila de botones. Un punto de tolerancia por el redondeo de los marcos.
        XCTAssertEqual(card.frame.minX, groupCard.frame.minX, accuracy: 1, "La tarjeta de avisos no empieza donde las de grupo.")
        XCTAssertEqual(card.frame.maxX, groupCard.frame.maxX, accuracy: 1, "La tarjeta de avisos no acaba donde las de grupo.")
        XCTAssertEqual(newExpense.frame.minX, groupCard.frame.minX, accuracy: 1, "«Nuevo gasto» no empieza donde las tarjetas.")

        app.buttons["group_notifications_dismiss"].tap()
        XCTAssertTrue(card.waitForNonExistence(timeout: 5), "La X no quitó la tarjeta «Avisos del grupo».")
    }
}
