//
//  StatisticsMissingStepUITests.swift
//  YalaUITests
//
//  Card 7jfp (2026-10-31): la fila bajo el hero de Estadísticas y el botón flotante se quedaban grises sin decir qué
//  faltaba, mientras el Panel ya decía «Crea tu primera cuenta» o «Crear categorías». Con el bug dentro, en Estadísticas
//  no hay `stats_create_*` (la fila sale apagada) y el flotante es un «+» deshabilitado sin `fab_create_*`; con él fuera,
//  los dos dicen qué falta y su toque lo arregla o abre dónde arreglarlo.
//

import XCTest

final class StatisticsMissingStepUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func openStatistics(_ app: XCUIApplication) {
        let tab = app.tabBars.buttons["Estadísticas"]
        XCTAssertTrue(tab.waitForExistence(timeout: 15), "No apareció la pestaña Estadísticas.")
        tab.tap()
    }

    private func attachScreenshot(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// Con cuenta y sin categorías: la fila de Estadísticas ofrece «Crear categorías», y tocarlo devuelve la fila.
    func test_statistics_withoutCategories_saysSoAndCreatesThem() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "sin-categorias")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        openStatistics(app)

        let createCategories = app.buttons["stats_create_categories"]
        let found = createCategories.waitForHittable(timeout: 15)
        attachScreenshot(app, "estadisticas-sin-categorias")
        XCTAssertTrue(found, "Con cuenta y sin categorías, Estadísticas no dijo qué faltaba (fila apagada sin explicación).")
        XCTAssertFalse(app.buttons["stats_action_new"].exists, "La fila apagada siguió ahí junto al botón.")
        XCTAssertFalse(app.buttons["stats_create_first_account"].exists, "Pidió una cuenta que ya existe.")

        createCategories.tap()
        let newRecord = app.buttons["stats_action_new"]
        XCTAssertTrue(newRecord.waitForHittable(timeout: 10), "«Crear categorías» no creó nada: la fila no volvió.")
        XCTAssertTrue(newRecord.isEnabled, "«Nuevo registro» sigue apagado tras crear las categorías.")

        // Hasta el último gesto: el formulario abre y se cierra sin guardar.
        newRecord.tap()
        let amountField = app.textFields["new_transaction_amount"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 5), "«Nuevo registro» no abrió el formulario.")
        app.closeNewTransactionDiscarding()
        XCTAssertTrue(amountField.waitForNonExistence(timeout: 10), "El formulario no se cerró.")
    }

    /// El flotante (aquí, el del Panel al desplazar): sin categorías ya no es un «+» gris mudo, dice qué falta y lo
    /// resuelve. Es el mismo componente que montan Estadísticas y Registros.
    func test_floatingButton_withoutCategories_saysSoAndCreatesThem() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "sin-categorias")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        XCTAssertTrue(app.buttons["panel_create_categories"].waitForExistence(timeout: 15), "El Panel no cargó.")

        // El flotante sale cuando el scroll se lleva la fila del hero.
        let floating = app.buttons["fab_create_categories"]
        // `isHittable`, como `revealPanelFAB`: mientras la fila del hero está a la vista el flotante no existe.
        for _ in 0..<14 where !(floating.exists && floating.isHittable) {
            app.swipeUp()
        }
        let found = floating.waitForHittable(timeout: 5)
        attachScreenshot(app, "flotante-sin-categorias")
        XCTAssertTrue(found, "Sin categorías, el botón flotante no dijo qué faltaba (seguía el «+» gris).")
        XCTAssertFalse(app.buttons["fab_new_transaction"].exists, "El «+» siguió junto a la salida.")

        floating.tap()
        XCTAssertTrue(app.buttons["fab_new_transaction"].waitForHittable(timeout: 10),
                      "«Crear categorías» del flotante no creó nada: el «+» no volvió.")
        XCTAssertFalse(floating.exists, "La salida siguió en pantalla con categorías ya creadas.")
    }

    /// Sin ninguna cuenta: Estadísticas ofrece «Crea tu primera cuenta» y abre el alta de cuenta.
    func test_statistics_withoutAccounts_offersCreatingTheFirstOne() {
        let app = XCUIApplication()
        app.launchForUITest(seed: nil)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap no completó.")
        XCTAssertTrue(app.buttons["panel_create_first_account"].waitForExistence(timeout: 15),
                      "Escenario: sin seed el Panel debería estar sin cuentas.")
        openStatistics(app)

        let createAccount = app.buttons["stats_create_first_account"]
        let found = createAccount.waitForHittable(timeout: 15)
        attachScreenshot(app, "estadisticas-sin-cuentas")
        XCTAssertTrue(found, "Sin cuentas, Estadísticas no ofreció «Crea tu primera cuenta».")
        XCTAssertFalse(app.buttons["stats_action_new"].exists, "La fila apagada siguió ahí junto al botón.")

        createAccount.tap()
        let nameField = app.descendants(matching: .any)["account_name_field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 8), "«Crea tu primera cuenta» no abrió el alta de cuenta.")
    }
}
