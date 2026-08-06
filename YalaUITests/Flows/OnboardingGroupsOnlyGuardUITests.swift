//
//  OnboardingGroupsOnlyGuardUITests.swift
//  YalaUITests
//
//  Cobertura XCUITest del área onboarding "Solo grupos" (commit 182c326a).
//  Dos caras:
//   1. SIN iCloud (sim por defecto): el paso Propósito ofrece la card "Dividir gastos
//      con amigos" (onboarding_purpose_groups) y elegirla AVANZA — el muro iCloud se
//      retiró con el canal de Grupos encendido (chip C4).
//   2. CON iCloud (forzado por -uitest-fake-icloud): happy-path e2e — elegir la card
//      avanza al paso de moneda, donde el botón "Continuar" está HABILITADO pese a no
//      haber nombre de cuenta (oculto en Solo Grupos), y el onboarding completa
//      aterrizando en el tab Grupos. Esto ejercita el fix del "botón Continuar muerto"
//      (2.0.5) que antes solo era verificable en device con iCloud.
//
//  ⚠️ Este fichero solo puede ejercitar la columna «canal backend ON»: bajo `-uitest`
//  `CloudSyncFlags.groupsBackendEnabled` es SIEMPRE `true` (`CloudRemoteConfig.decide`
//  corta en `isUITestHost` devolviendo `absentDefault`, que bajo DEV_BUILD es `true`), y
//  no hay launch arg que lo apague. Las dos celdas de canal OFF —el muro legítimo cuando
//  el kill remoto está activo— viven en YalaTests/OnboardingGroupsPurposeGateLogicTests.
//
//  Usa el hook -uitest-onboarding (presenta OnboardingView directo sin marcarlo
//  completado). Convenciones: ver CLAUDE.md (sin sleeps, scheme Yala Dev).
//

import XCTest

final class OnboardingGroupsOnlyGuardUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Avanza del step de nombre al paso Propósito y devuelve la app ya en ese paso.
    /// `fakeICloud` fuerza `isAccountAvailable=true` (para el happy-path que necesita
    /// pasar el guard de iCloud, imposible en sim sin este hook).
    ///
    /// `cloudSession` finge la sesión de NUBE, que es otro gate distinto: `-uitest-fake-icloud` habla
    /// de la cuenta de iCloud del OS y no crea sesión backend. Lo necesita el happy-path porque
    /// aterriza en el tab Grupos vacío, y con `groupsBackendEnabled` ON —todo XCUITest bajo Yala Dev—
    /// ese landing sin sesión es el empty state de RE-ENTRADA, no el estándar que este test asserta.
    private func launchAtPurposeStep(fakeICloud: Bool = false, cloudSession: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(skipOnboarding: false, seed: nil, onboarding: true,
                            fakeICloud: fakeICloud, cloudSession: cloudSession)

        let nameField = app.textFields["onboarding_name_field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 30), "No apareció onboarding_name_field.")
        nameField.tap()
        nameField.typeText("QA")

        let next = app.buttons["onboarding_next_button"]
        XCTAssertTrue(next.waitForExistence(timeout: 5), "No apareció onboarding_next_button.")
        next.tap()
        return app
    }

    /// El paso Propósito ofrece las 3 opciones, incluida la nueva "Dividir gastos con amigos".
    func test_purposeStep_offersGroupsOnlyCard() {
        let app = launchAtPurposeStep()

        XCTAssertTrue(
            app.buttons["onboarding_purpose_groups"].waitForExistence(timeout: 10),
            "La card 'Dividir gastos con amigos' (onboarding_purpose_groups) no está en el paso Propósito."
        )
        // No-regresión de las otras dos opciones.
        XCTAssertTrue(app.buttons["onboarding_purpose_control"].exists, "Falta la card 'Llevar el control'.")
        XCTAssertTrue(app.buttons["onboarding_purpose_expenses"].exists, "Falta la card 'Solo anotar gastos'.")
    }

    /// LA CELDA DEL BUG (chip C4): sin cuenta iCloud —el estado por defecto del sim, y el de
    /// todo usuario born-cloud— y con el canal de Grupos ON, elegir "Solo grupos" YA NO se
    /// bloquea. Hasta el fix salía la alerta "Activa iCloud para usar grupos" y la elección no
    /// se registraba, cerrando la única ruta del onboarding a `.groupsOnly`.
    ///
    /// La aserción que carga el peso es POSITIVA y no la ausencia de la alerta: llegar al paso
    /// de moneda solo es posible si `selectedUsageMode == .groupsOnly` (en `fullControl` el
    /// siguiente paso es `.accounts`, que no tiene selector de moneda), y el campo de nombre de
    /// cuenta ausente lo confirma. Una aserción negativa a secas pasaría igual si el tap se
    /// hubiera perdido — la familia del falso verde de `.claude/rules/testing.md`.
    func test_groupsOnlyCard_withoutICloud_isAllowed_channelOn() {
        let app = launchAtPurposeStep()

        let groupsCard = app.buttons["onboarding_purpose_groups"]
        XCTAssertTrue(groupsCard.waitForExistence(timeout: 10), "No apareció la card de solo-grupos.")
        groupsCard.tap()

        XCTAssertFalse(
            app.alerts.firstMatch.waitForExistence(timeout: 3),
            "Volvió el muro iCloud: el canal de Grupos ya no vive en CloudKit y el aviso miente."
        )

        let next = app.buttons["onboarding_next_button"]
        XCTAssertTrue(next.waitForExistence(timeout: 5), "No apareció el botón Siguiente en Propósito.")
        next.tap()

        XCTAssertTrue(
            app.buttons["onboarding_currency_selector"].waitForExistence(timeout: 10),
            "No se llegó al paso de moneda: la elección de 'Solo grupos' no se registró."
        )
        XCTAssertFalse(
            app.textFields["onboarding_account_name"].exists,
            "El paso alcanzado no es el de Solo Grupos (el campo de nombre de cuenta debería estar oculto)."
        )
    }

    /// LA MITAD QUE NO ES COSMÉTICA DEL CHIP C5: el tap de vuelta. Con "Dividir gastos con
    /// amigos" elegido, tocar "Llevar el control de mi dinero" no hacía NADA —su closure era
    /// `if expensesOnlyMode { … }`, un selector de tres cards decidido con un booleano de dos—
    /// así que el usuario que cambiaba de idea tenía que pasar por "Solo anotar gastos". Y como
    /// la card ADEMÁS se pintaba marcada (la otra mitad), no tenía motivo para sospechar que su
    /// tap se había perdido.
    ///
    /// La aserción que carga el peso es POSITIVA: el paso de CUENTAS solo es alcanzable si el
    /// modo volvió al grupo de control — `OnboardingStepPlan` lo salta entero con `.groupsOnly`,
    /// cuyo siguiente paso es el de moneda. Afirmar la ausencia del selector de moneda se
    /// cumpliría igual si el tap se hubiera perdido y el flujo no hubiera avanzado, que es la
    /// familia del falso verde de `.claude/rules/testing.md`.
    ///
    /// La MARCA (la primera mitad) no se afirma aquí y no es un olvido: `binaryCard` expone solo
    /// `accessibilityIdentifier` —la selección es un `stroke`, no un trait— así que no es
    /// observable desde XCUITest sin tocar el componente, que está fuera del alcance del chip.
    /// Vive en YalaTests/OnboardingPurposeSelectionLogicTests.
    func test_purposeStep_tapBackToControl_afterGroupsOnly_takesEffect() {
        let app = launchAtPurposeStep()

        let groupsCard = app.buttons["onboarding_purpose_groups"]
        XCTAssertTrue(groupsCard.waitForExistence(timeout: 10), "No apareció la card de solo-grupos.")
        groupsCard.tap()

        let controlCard = app.buttons["onboarding_purpose_control"]
        XCTAssertTrue(controlCard.waitForExistence(timeout: 5), "No apareció la card 'Llevar el control'.")
        controlCard.tap()

        let next = app.buttons["onboarding_next_button"]
        XCTAssertTrue(next.waitForExistence(timeout: 5), "No apareció el botón Siguiente en Propósito.")
        next.tap()

        XCTAssertTrue(
            app.buttons["onboarding_accounts_multiple"].waitForExistence(timeout: 10),
            """
            El tap de 'Llevar el control' se perdió: con .groupsOnly todavía puesto el siguiente \
            paso es el de moneda, no el de cuentas.
            """
        )
    }

    /// Happy-path con iCloud disponible (forzado por -uitest-fake-icloud): elegir "Solo
    /// grupos" avanza al paso de moneda (sin guard), donde el botón "Continuar" está
    /// HABILITADO aunque el campo de nombre de cuenta esté oculto — regresión del bug
    /// del "botón Continuar muerto" (fix 2.0.5). Completa y aterriza en el tab Grupos.
    /// La sesión de nube va fingida porque la aserción final espera el empty state ESTÁNDAR
    /// del tab (ver el docblock de `launchAtPurposeStep`); lo que este caso prueba es el
    /// onboarding, no la rama de re-entrada, que tiene su propio test en GroupsEmptyStateUITests.
    func test_groupsOnly_withICloud_currencyStepEnablesContinueAndCompletes() {
        let app = launchAtPurposeStep(fakeICloud: true, cloudSession: true)

        let groupsCard = app.buttons["onboarding_purpose_groups"]
        XCTAssertTrue(groupsCard.waitForExistence(timeout: 10), "No apareció la card de solo-grupos.")
        groupsCard.tap()

        // Con iCloud disponible NO debe aparecer el guard → avanzar al paso de moneda.
        let next = app.buttons["onboarding_next_button"]
        XCTAssertTrue(next.waitForExistence(timeout: 5), "No apareció el botón Siguiente en Propósito.")
        next.tap()

        // Estamos en el paso de moneda (el selector confirma el paso). Si el guard hubiera
        // bloqueado, el modo seguiría en fullControl y este selector no aparecería.
        XCTAssertTrue(
            app.buttons["onboarding_currency_selector"].waitForExistence(timeout: 10),
            "No se llegó al paso de moneda (onboarding_currency_selector ausente) — ¿el guard bloqueó?"
        )

        // EL FIX: en Solo Grupos el campo de nombre de cuenta está oculto y el botón
        // "Continuar" debe estar HABILITADO (antes quedaba muerto permanentemente).
        XCTAssertFalse(
            app.textFields["onboarding_account_name"].exists,
            "En Solo Grupos el campo de nombre de cuenta debe estar oculto."
        )
        let continueBtn = app.buttons["onboarding_next_button"]
        XCTAssertTrue(continueBtn.waitForExistence(timeout: 5), "No apareció el botón Continuar en el paso de moneda.")
        XCTAssertTrue(
            continueBtn.isEnabled,
            "El botón 'Continuar' debe estar HABILITADO en Solo Grupos (regresión del botón muerto)."
        )

        // Continuar → paso de confirmación → completar el onboarding.
        continueBtn.tap()
        let finish = app.buttons["onboarding_next_button"]
        XCTAssertTrue(finish.waitForExistence(timeout: 10), "No apareció el CTA final (confirmación).")
        finish.tap()

        // Aterriza en el tab Grupos (Solo Grupos, sin grupos → empty state).
        XCTAssertTrue(
            app.descendants(matching: .any)["groups_empty_state"].waitForExistence(timeout: 20),
            "No se aterrizó en el tab Grupos (groups_empty_state ausente tras completar)."
        )
    }
}
