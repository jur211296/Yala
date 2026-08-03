//
//  GroupExpenseSuccessUITests.swift
//  YalaUITests
//
//  Cobertura XCUITest determinista del área `groups-expense-form`: crear un gasto de
//  grupo desde el detalle muestra la pantalla de éxito (GroupExpenseSuccessView).
//  Reusa el seed `grupos` (grupo "Viaje a Cusco", 3 miembros). Para evitar el requisito
//  de cuenta del Caso A (bridge ON por default), cambia el pagador a otro miembro
//  (Caso B) → canSave solo depende de monto + descripción.
//  Convenciones: ver CLAUDE.md (sin sleeps, scheme Yala Dev, targetear por identifier).
//

import XCTest

final class GroupExpenseSuccessUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Aterriza DIRECTO en el tab Grupos vía `-uitest-deeplink groups`, sin pasar por el dashboard
    /// de "Más" — mismo patrón que `GroupsSmokeUITests.launchOnGroups()`, adoptado aquí por la
    /// misma causa.
    ///
    /// Antes se navegaba por UI: tab "Más" (4º) → scroll → card `more_card_groups`. Eso **no es
    /// alcanzable de forma determinista en iOS 27.0**: la card vive en un `LazyVGrid` que no
    /// materializa la celda hasta scrollearla, y en 27.0 ningún swipe sintético la revela (medido
    /// el 2026-07-29 con el smoke de Grupos: 8/8 verde en iOS 26.4 con UN swipe · 1/8 en 27.0, con
    /// 93 swipes sobre el elemento Aplicación y 81 sobre el `scrollView`). Este test se escribió el
    /// 2026-07-06, cuando 26.x lo absorbía, y quedó fuera de la migración a deeplink del smoke
    /// (`5c84df88`) — de ahí su rojo en `openGroups`, no una regresión de producto. **Ya se probó y
    /// NO funciona** ni subir el contador de swipes ni scrollear-hasta-la-condición en vez de un
    /// `for` fijo: 30 s de scroll con asentamiento entre gestos siguen dando 1/8. Detalle en
    /// `.claude/rules/testing.md` y en la Lista Negra de TESTING-STRATEGY.md.
    ///
    /// Lo que este test verifica es la PANTALLA DE ÉXITO del gasto, no cómo se llega al tab, así
    /// que el deeplink prueba exactamente lo suyo. NO hace falta fingir sesión de nube
    /// (`-uitest-fake-cloud-session`): con grupos sembrados el contenedor pinta las cards sin
    /// sesión, y `GroupExpenseViewModel.save()` es una escritura SwiftData local — ningún gate de
    /// `hasSession` en `canSave` ni en el camino a `GroupExpenseSuccessView`. Los args de sesión y
    /// consent solo los necesita CREAR GRUPO (ver la sección de dos gates en la regla durable).
    private func launchOnGroups() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "grupos", deeplink: "groups")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        return app
    }

    /// groups-expense-form: detalle del grupo → FAB nuevo gasto → llenar → guardar →
    /// aparece GroupExpenseSuccessView.
    func test_createGroupExpenseShowsSuccessScreen() {
        let app = launchOnGroups()

        // Detalle del grupo sembrado ("Viaje a Cusco" ordena primero y tiene 3 miembros →
        // flujo de chips, no la pre-pantalla de 2 personas).
        let card = app.descendants(matching: .any).matching(identifier: "group_card").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10), "No apareció la tarjeta del grupo.")
        card.tap()

        // FAB nuevo gasto → formulario.
        let fab = app.buttons["group_detail_fab_new_expense"]
        XCTAssertTrue(fab.waitForExistence(timeout: 10), "No apareció el FAB de nuevo gasto en el detalle.")
        fab.tap()

        // Descripción.
        let description = app.textFields["group_expense_description"]
        XCTAssertTrue(description.waitForExistence(timeout: 5), "El form no montó (group_expense_description).")
        description.tap()
        description.typeText("Cena de prueba")

        // Monto.
        let amount = app.textFields["group_expense_amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5), "No apareció el campo de monto.")
        amount.tap()
        amount.typeText("120")

        // Cambiar el pagador a otro miembro (Caso B) → evita el requisito de cuenta del Caso A
        // (bridge ON por default). Abrir el picker también cierra el teclado (patrón como en
        // TransactionsCrudUITests: tras escribir, se tocan chips que abren sheets).
        let paidBy = app.buttons["group_expense_paidby_chip"]
        XCTAssertTrue(paidBy.waitForExistence(timeout: 5), "No apareció el chip 'Pagado por'.")
        paidBy.tap()

        // El selector lista Tú/Ana/Beto; tocar una fila la selecciona y cierra el sheet.
        let anaRow = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Ana'")
        ).firstMatch
        XCTAssertTrue(anaRow.waitForExistence(timeout: 5), "El selector de pagador no listó a 'Ana'.")
        anaRow.tap()

        // Guardar: esperar a que el botón se habilite (canSave) y tocarlo.
        let save = app.buttons["group_expense_save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5), "No apareció el botón de guardar.")
        let enabled = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isEnabled == true"),
            object: save
        )
        XCTAssertEqual(
            XCTWaiter().wait(for: [enabled], timeout: 8),
            .completed,
            "El botón de guardar no se habilitó (canSave falso)."
        )
        save.tap()

        // La pantalla de éxito debe montar — verificamos su botón principal (inequívoco).
        XCTAssertTrue(
            app.buttons["group_expense_success_accept"].waitForExistence(timeout: 10),
            "No apareció la pantalla de éxito del gasto de grupo (group_expense_success_accept)."
        )
    }
}
