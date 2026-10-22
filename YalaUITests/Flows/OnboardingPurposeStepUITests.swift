//
//  OnboardingPurposeStepUITests.swift
//  YalaUITests
//
//  Cobertura XCUITest del paso «Propósito» del onboarding personal.
//
//  Desde el 2026-09-10 el paso ofrece DOS cards —«Llevar el control de mi dinero» y «Solo anotar
//  gastos»— y no tres: «Dividir gastos con amigos» se retiró junto con su modo `.groupsOnly`
//  (ADR 2026-09-09 §7). Solo-grupos es una sesión que se abre desde el Welcome («Vengo por un
//  grupo»), no un propósito de quien ya eligió llevar sus finanzas. Este fichero cubría antes esa
//  card; lo que queda es lo que sigue siendo observable desde aquí:
//   1. Qué cards pinta el paso: las dos, y no la de grupos.
//   2. El tap de vuelta del chip C5: tocar «Llevar el control» después de otro propósito surte
//      efecto. Hoy se sale de «Solo anotar gastos», el único otro propósito que queda.
//
//  La MARCA de cada card no es afirmable desde aquí (`binaryCard` solo expone su
//  `accessibilityIdentifier`; la selección es un `stroke`, no un trait): vive en
//  YalaTests/OnboardingPurposeSelectionLogicTests.
//
//  Usa el hook -uitest-onboarding (presenta OnboardingView directo sin marcarlo
//  completado). Convenciones: ver CLAUDE.md (sin sleeps, scheme Yala Dev).
//

import XCTest

final class OnboardingPurposeStepUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Avanza del step de nombre al paso Propósito y devuelve la app ya en ese paso.
    private func launchAtPurposeStep() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(skipOnboarding: false, seed: nil, onboarding: true)

        let nameField = app.textFields["onboarding_name_field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 30), "No apareció onboarding_name_field.")
        nameField.tap()
        nameField.typeText("QA")

        let next = app.buttons["onboarding_next_button"]
        XCTAssertTrue(next.waitForExistence(timeout: 5), "No apareció onboarding_next_button.")
        next.tap()
        return app
    }

    /// El paso Propósito muestra dos cards y la de grupos ya no está.
    ///
    /// La aserción negativa NO se sostiene sola —una card ausente porque el paso no llegó a montarse se
    /// leería igual—, así que va detrás de las dos POSITIVAS: estamos de verdad en el paso Propósito
    /// porque sus dos cards están. Y corre sin ningún seam de sesión ni de iCloud, en el onboarding
    /// inicial y en el modo `.icloud` por defecto del simulador: la celda exacta donde la card vieja SÍ se
    /// pintaba, con este mismo recorrido.
    func test_purposeStep_offersTwoCards_andNoGroupsCard() {
        let app = launchAtPurposeStep()

        XCTAssertTrue(
            app.buttons["onboarding_purpose_control"].waitForExistence(timeout: 10),
            "No se llegó al paso Propósito (falta 'Llevar el control'): la aserción negativa no probaría nada."
        )
        XCTAssertTrue(app.buttons["onboarding_purpose_expenses"].exists, "Falta la card 'Solo anotar gastos'.")
        let cards = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "onboarding_purpose_"))
        XCTAssertEqual(cards.count, 2, "El paso Propósito tiene que pintar exactamente dos cards; pinta \(cards.count).")

        XCTAssertFalse(
            app.buttons["onboarding_purpose_groups"].exists,
            """
            Volvió la card «Dividir gastos con amigos» al paso Propósito. Solo-grupos es una sesión que se \
            abre desde el Welcome («Vengo por un grupo»), no un propósito del onboarding (ADR 2026-09-09 §7).
            """
        )
    }

    /// El tap de vuelta: con otro propósito elegido, tocar «Llevar el control de mi dinero» tiene que surtir
    /// efecto. Es la mitad del chip C5 que se ve desde aquí, y con dos cards solo caza que el tap NO haga
    /// nada: la forma exacta del bug de C5 (`if expensesOnlyMode { … }`) da el mismo resultado saliendo de
    /// «Solo anotar gastos», el único otro propósito que queda. Esa forma la fija el source-scan de
    /// `OnboardingPurposeSelectionLogicTests`, y el caso `.dayToDay` su tabla.
    ///
    /// La aserción que carga el peso es POSITIVA: el paso de CUENTAS solo es alcanzable si el modo volvió
    /// al grupo de control — `OnboardingStepPlan` lo salta entero con `.expensesOnly`, cuyo siguiente paso
    /// es el de moneda. Afirmar la ausencia del selector de moneda se cumpliría igual si el tap se hubiera
    /// perdido y el flujo no hubiera avanzado, que es la familia del falso verde de
    /// `.claude/rules/testing.md`.
    func test_purposeStep_tapBackToControl_afterExpensesOnly_takesEffect() {
        let app = launchAtPurposeStep()

        let expensesCard = app.buttons["onboarding_purpose_expenses"]
        XCTAssertTrue(expensesCard.waitForExistence(timeout: 10), "No apareció la card 'Solo anotar gastos'.")
        expensesCard.tap()

        let controlCard = app.buttons["onboarding_purpose_control"]
        XCTAssertTrue(controlCard.waitForExistence(timeout: 5), "No apareció la card 'Llevar el control'.")
        controlCard.tap()

        let next = app.buttons["onboarding_next_button"]
        XCTAssertTrue(next.waitForExistence(timeout: 5), "No apareció el botón Siguiente en Propósito.")
        next.tap()

        XCTAssertTrue(
            app.buttons["onboarding_accounts_multiple"].waitForExistence(timeout: 10),
            """
            El tap de 'Llevar el control' se perdió: con .expensesOnly todavía puesto el siguiente \
            paso es el de moneda, no el de cuentas.
            """
        )
    }
}
