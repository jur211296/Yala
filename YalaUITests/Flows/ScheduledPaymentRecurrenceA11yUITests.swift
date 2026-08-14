//
//  ScheduledPaymentRecurrenceA11yUITests.swift
//  YalaUITests
//
//  Pin de los DOS identificadores del bloque de Recurrencia del editor de pagos planificados.
//
//  POR QUÉ EXISTE. El QA visual de `qa_pagos-planificados-notifs` se quedó a medias el 2026-08-14
//  porque el selector «Una sola vez / Repetición» y el de «Día del mes» no eran alcanzables desde
//  automatización, y sin tocarlos no se puede crear un pago que venza HOY: el editor abre en
//  repetición mensual con `dayOfMonth = 1`, así que el primer vencimiento cae el día 1 del mes
//  SIGUIENTE (la propia pantalla lo lista en «Próximas fechas»). Con la recurrencia por defecto, la
//  comprobación de que NO llega aviso con el interruptor apagado sale verde por la razón
//  equivocada, y la de que SÍ llega al encenderlo sale roja sin que haya ningún fallo.
//
//  Y ESTE TEST ES LA MEDICIÓN, no un adorno: `snapshot_ui` (el árbol rs/1 de XcodeBuildMCP) **NO**
//  enumera estos dos controles ni siquiera con el identificador puesto — se comprobó con el
//  segmentado VISIBLE en pantalla. O sea que los ids no desbloquean esa herramienta; lo que
//  desbloquean es XCUITest, que los alcanza por otra API (`segmentedControls[...]`). Esa
//  diferencia es justo lo que este archivo prueba, y por eso no vale con dar el cableado por bueno.
//

import XCTest

final class ScheduledPaymentRecurrenceA11yUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Los dos controles del bloque Recurrencia son alcanzables por identificador, y tocarlos SURTE
    /// EFECTO. La aserción que carga el peso es la segunda: que exista un elemento no prueba que el
    /// tap llegue, y el modo de fallo que importa es justamente un control que se ve y no responde.
    func test_recurrenceControlsAreReachableByIdentifier() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        app.openProfile()
        app.openSettingsSection("profile_planned")

        let addButton = app.buttons["scheduled_add_button"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "No apareció scheduled_add_button.")
        addButton.tap()

        XCTAssertTrue(
            app.textFields["scheduled_name_field"].waitForExistence(timeout: 5),
            "No se montó el editor de pago planificado."
        )

        // El editor abre en repetición mensual ⇒ el picker de día del mes está montado. Es el
        // control CONDICIONAL, así que su presencia aquí es también la precondición del test.
        let dayOfMonth = app.descendants(matching: .any)
            .matching(identifier: "scheduled_day_of_month_picker").firstMatch
        XCTAssertTrue(
            dayOfMonth.waitForExistence(timeout: 5),
            "scheduled_day_of_month_picker no existe: o el editor no abre en mensual, o el id se perdió."
        )

        let recurrence = app.segmentedControls["scheduled_recurrence_picker"]
        XCTAssertTrue(
            recurrence.waitForExistence(timeout: 5),
            "scheduled_recurrence_picker no existe — sin él, crear un pago que venza HOY no es automatizable."
        )

        // Segmento 0 = «Una sola vez». Por índice y no por rótulo: el texto está localizado y la
        // suite corre en cualquier idioma.
        let oneTime = recurrence.buttons.element(boundBy: 0)
        XCTAssertTrue(oneTime.exists, "El segmentado no expone sus dos segmentos.")
        oneTime.tap()

        // EL EFECTO: en «Una sola vez» el bloque mensual se desmonta. Si el tap no hubiera llegado,
        // el picker seguiría ahí y esta aserción caería — que es exactamente lo que la distingue de
        // un test que solo comprueba que el control se dibuja.
        XCTAssertTrue(
            dayOfMonth.waitForNonExistence(timeout: 5),
            "Tras elegir «Una sola vez» el día del mes sigue montado: el tap no surtió efecto."
        )
    }
}
