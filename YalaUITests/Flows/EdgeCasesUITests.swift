//
//  EdgeCasesUITests.swift
//  YalaUITests
//
//  Cobertura XCUITest del área `edge-cases-logic` (14.1 empty states + 14.3 montos
//  extremos): la app monta sin crash con 0 datos (empty state) y guarda montos
//  en los límites (0.01). Los otros escenarios del área (14.4 límites de texto,
//  14.5 muchas entidades) son validación de formato/volumen → unit/perf.
//  Convenciones: ver CLAUDE.md (sin sleeps, scheme Yala Dev).
//

import XCTest

final class EdgeCasesUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// 14.1: con 0 datos (reset + sin seed) la app llega al Panel sin crash.
    func test_emptyStateMountsWithoutCrash() {
        let app = XCUIApplication()
        app.launchForUITest(seed: nil)  // reset + skip onboarding, sin sembrar nada
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap no completó con 0 datos.")

        // El Panel monta (el avatar del toolbar está siempre presente) sin crashear.
        XCTAssertTrue(
            app.buttons["profile_avatar"].waitForExistence(timeout: 10),
            "El Panel no montó con 0 datos (profile_avatar ausente)."
        )
        // Config de secciones también disponible (Panel funcional aun vacío).
        XCTAssertTrue(
            app.buttons["panel_sections_config"].exists,
            "panel_sections_config ausente — el Panel no renderizó su chrome con 0 datos."
        )
    }

    /// 14.3: un monto mínimo (0.01) se guarda sin romper el flujo de creación.
    func test_extremeMinimumAmountSaves() {
        let app = XCUIApplication()
        app.launchForUITest()  // seed minimal (cuentas + subcategorías)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        // El MENÚ del FAB (manual/voz/imagen) sigue siendo cosa del flotante: la
        // fila del hero lleva a cada entrada directamente, sin desplegar. Así que
        // aquí se baja hasta el FAB en vez de cambiar de camino, que perdería
        // justo lo que este test cubre.
        let fabMenu = app.buttons["fab_new_transaction"]
        var intentos = 0
        while !fabMenu.isHittable && intentos < 14 {
            app.swipeUp()
            intentos += 1
        }
        XCTAssertTrue(fabMenu.waitForExistence(timeout: 10), "No apareció el FAB tras bajar por el Panel.")
        fabMenu.tap()
        let manual = app.buttons["fab_manual"]
        XCTAssertTrue(manual.waitForExistence(timeout: 5), "No se expandió el menú del FAB (fab_manual).")
        manual.tap()

        let amountField = app.textFields["new_transaction_amount"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 5), "No apareció new_transaction_amount.")
        amountField.tap()
        amountField.typeText("0.01")

        app.buttons["new_transaction_account_chip"].tap()
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "account_selector_row_"))
            .firstMatch.tap()

        let subcatChip = app.buttons["new_transaction_subcategory_chip"]
        XCTAssertTrue(subcatChip.waitForExistence(timeout: 5), "No volvió al formulario tras elegir cuenta.")
        subcatChip.tap()
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "subcategory_selector_row_"))
            .firstMatch.tap()

        let saveButton = app.buttons["new_transaction_save"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "No apareció new_transaction_save.")
        XCTAssertTrue(saveButton.isEnabled, "El botón guardar está deshabilitado con monto 0.01.")
        saveButton.tap()

        // El monto mínimo se guarda y el flujo vuelve al Panel sin romperse.
        // La pantalla de éxito vive dentro del mismo sheet y solo se cierra con
        // «Aceptar»: sin cerrarla, el Panel de fondo sigue en el árbol y la aserción
        // de abajo pasaría en verde con el sheet aún puesto.
        app.dismissTransactionSuccess()

        // Misma red del 2026-08-04: afirmar el regreso al Panel con el sheet aún
        // puesto daba verde en falso. El testigo sigue siendo el FLOTANTE y no la
        // fila del hero — medido el 2026-09-02: al cerrar el éxito el Panel NO
        // rebobina, se queda donde lo dejó el scroll de arriba, así que la fila
        // está fuera de pantalla (existe en el árbol pero no es hittable) y el
        // flotante sí se ve. La primera versión de este arreglo dio por hecho lo
        // contrario y puso el test en rojo.
        let fab = app.buttons["fab_new_transaction"]
        XCTAssertTrue(
            fab.waitForExistence(timeout: 10),
            "Tras guardar 0.01 no se volvió al Panel — el monto extremo rompió el guardado."
        )
        XCTAssertTrue(
            fab.waitForHittable(timeout: 5),
            "El Panel existe pero sigue tapado — el sheet de la transacción no se desmontó."
        )
    }
}
