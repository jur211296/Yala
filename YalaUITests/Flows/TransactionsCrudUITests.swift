//
//  TransactionsCrudUITests.swift
//  YalaUITests
//
//  Cobertura XCUITest del área `transactions-core-crud` (escenarios 5.x): el
//  flujo central de crear una transacción vía FAB. Establece el patrón de
//  SELECTORES (AccountSelectorSheet + SubcategorySelectorSheet, sheets compartidos).
//  Las filas se targetean por prefijo de ID (BEGINSWITH) para no acoplar al seed.
//  Seed `minimal`. Convenciones: ver CLAUDE.md (sin sleeps, scheme Yala Dev).
//

import XCTest

final class TransactionsCrudUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Smoke: el FAB abre el formulario de nueva transacción.
    func test_opensNewTransactionForm() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        let fab = app.revealPanelFAB()
        fab.tap()
        // El FAB "+" expande un menú (voz/imagen/manual); "manual" abre el form.
        let manual = app.buttons["fab_manual"]
        XCTAssertTrue(manual.waitForExistence(timeout: 5), "No se expandió el menú del FAB (fab_manual).")
        manual.tap()

        XCTAssertTrue(
            app.textFields["new_transaction_amount"].waitForExistence(timeout: 5),
            "No se montó NewTransactionView (new_transaction_amount)."
        )
    }

    /// CRUD — crear una transacción (monto + cuenta + subcategoría) vía los
    /// selectores y verificar que el flujo completa y vuelve al Panel.
    /// Cubre el patrón de selectores (Account/Subcategory sheets) end-to-end.
    func test_createTransaction() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        app.revealPanelFAB().tap()
        let manual = app.buttons["fab_manual"]
        XCTAssertTrue(manual.waitForExistence(timeout: 5), "No se expandió el menú del FAB (fab_manual).")
        manual.tap()

        // Monto
        let amountField = app.textFields["new_transaction_amount"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 5), "No apareció new_transaction_amount.")
        amountField.tap()
        amountField.typeText("50")

        // Cuenta — abrir selector y elegir la primera fila (sin acoplar al nombre del seed). El helper
        // espera a que el teclado termine de entrar: en iOS 27.0 el toque inmediato se perdía.
        app.chooseFirstSelectorRow(chip: "new_transaction_account_chip", rowPrefix: "account_selector_row_")

        // Subcategoría — ídem.
        XCTAssertTrue(
            app.buttons["new_transaction_subcategory_chip"].waitForExistence(timeout: 5),
            "No volvió al formulario tras elegir cuenta."
        )
        app.chooseFirstSelectorRow(chip: "new_transaction_subcategory_chip", rowPrefix: "subcategory_selector_row_")

        // Guardar → pantalla de éxito.
        let saveButton = app.buttons["new_transaction_save"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "No apareció new_transaction_save.")
        XCTAssertTrue(saveButton.isEnabled, "El botón guardar está deshabilitado (canSave=false: monto/cuenta/subcategoría).")
        saveButton.tap()

        // Tras guardar, el flujo confirma con la pantalla de éxito. NO es transitoria:
        // vive dentro del mismo sheet y solo se cierra con «Aceptar». Cerrarla es parte
        // del flujo que este test cubre, y además lo que hace REAL la aserción de abajo:
        // con el sheet puesto, el Panel de fondo sigue en el árbol y `fab_new_transaction`
        // existe igual ⇒ afirmarlo a secas pasaba en verde sin probar el regreso.
        app.dismissTransactionSuccess()

        let fab = app.buttons["fab_new_transaction"]
        XCTAssertTrue(
            fab.waitForExistence(timeout: 10),
            "Tras guardar no se volvió al Panel — el flujo de creación de transacción no completó."
        )
        XCTAssertTrue(
            fab.waitForHittable(timeout: 5),
            "El Panel existe pero sigue tapado — el sheet de la transacción no se desmontó."
        )
        XCTAssertFalse(
            app.textFields["new_transaction_amount"].exists,
            "El formulario sigue abierto — el guardado no procesó."
        )
    }

    /// Los selectores de cuenta, subcategoría y etiquetas abren a MEDIA altura desde Nuevo registro
    /// (ticket `record-selectors-open-at-medium-detent`) y se estiran a grande con el gesto. Se mide por el marco
    /// de la primera fila: a media altura cae por debajo del 40 % de la ventana; a pantalla completa queda arriba
    /// (~20 %). Volver a `.large` pone rojo la primera aserción de cada selector.
    func test_recordSelectorsOpenAtMediumDetent() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        app.revealPanelFAB().tap()
        let manual = app.buttons["fab_manual"]
        XCTAssertTrue(manual.waitForExistence(timeout: 5), "No se expandió el menú del FAB (fab_manual).")
        manual.tap()
        XCTAssertTrue(
            app.textFields["new_transaction_amount"].waitForExistence(timeout: 5),
            "No se montó NewTransactionView (new_transaction_amount)."
        )
        let windowHeight = app.windows.firstMatch.frame.height

        // Cómo se cierra cada uno sin tocar el formulario: cuenta y subcategoría se cierran al elegir una fila;
        // etiquetas, con su «Guardar».
        let selectors: [(chip: String, rowPrefix: String, closesOnRowTap: Bool)] = [
            ("new_transaction_account_chip", "account_selector_row_", true),
            ("new_transaction_subcategory_chip", "subcategory_selector_row_", true),
            ("new_transaction_tags_chip", "tag_selector_row_", false),
        ]
        for selector in selectors {
            let firstRow = app.openSelectorFirstRow(chip: selector.chip, rowPrefix: selector.rowPrefix)
            XCTAssertGreaterThan(
                firstRow.frame.minY, windowHeight * 0.4,
                "El selector de \(selector.chip) abrió a pantalla completa, no a media altura."
            )
            // Estirar: un deslizamiento rápido hacia arriba dentro de la hoja la sube a grande. Desde la mitad baja de
            // la ventana, que a media altura es hoja; arrastrar desde la fila no movía la hoja (medido).
            let window = app.windows.firstMatch
            window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9)).press(
                forDuration: 0.05,
                thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)),
                withVelocity: .fast,
                thenHoldForDuration: 0
            )
            // `frame` no se puede leer por predicado (no es KVC): se sondea el marco hasta 5 s.
            let deadline = Date().addingTimeInterval(5)
            while firstRow.frame.minY >= windowHeight * 0.4, Date() < deadline {
                RunLoop.current.run(until: Date().addingTimeInterval(0.2))
            }
            XCTAssertLessThan(
                firstRow.frame.minY, windowHeight * 0.4,
                "El selector de \(selector.chip) no se estiró a grande."
            )
            if selector.closesOnRowTap {
                firstRow.tap()
            } else {
                app.buttons["toolbar_save_button"].tap()
            }
            XCTAssertTrue(
                app.buttons[selector.chip].waitForHittable(timeout: 5),
                "El selector de \(selector.chip) no se cerró."
            )
        }
    }
}
