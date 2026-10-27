//
//  GroupsCrearDecididoUITests.swift
//  YalaUITests
//
//  Lote decidido 2.2 · 13 (Grupos: crear el primer grupo, educativo, consentimiento y entrar con Apple o Google), con las
//  decisiones B de Jürgen del 2026-10-18. El educativo-consentimiento (L12-4/L12-5/L12-7) vive en
//  `GroupsEducationalUITests` y la rama de la bienvenida (L12-12) en `WelcomeChooserUITests`; aquí, el resto.
//
//  Lo que no se puede probar aquí, y no se busque: crear el grupo de verdad. El simulador no tiene sesión real y la
//  creación es server-first, así que los casos llegan hasta el formulario y no lo guardan.
//  Convenciones: ver CLAUDE.md (sin sleeps, scheme Yala Dev, a11y ids).
//

import XCTest

final class GroupsCrearDecididoUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// **L12-1 · icono en las tres pestañas del grupo y nombre solo en la elegida; «Balances» pasa a «Saldos».** El
    /// nombre se lee igual con VoiceOver aunque el chip enseñe solo el icono.
    func test_groupDetailTabs_nameOnlyOnTheSelectedOne_andSaldos() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "grupos", deeplink: "groups", cloudSession: true, groupsConsent: true)

        let card = app.descendants(matching: .any).matching(identifier: "group_card").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 30), "No apareció la tarjeta del grupo.")
        card.tap()

        let saldos = app.buttons["group_detail_tab_balances"]
        XCTAssertTrue(saldos.waitForExistence(timeout: 10), "No apareció la pestaña de saldos.")
        XCTAssertEqual(saldos.label, "Saldos", "La pestaña sigue diciendo «Balances» (L12-1).")
        // Sin elegir, el chip no pinta su nombre: el texto visible «Saldos» todavía no existe dentro del botón.
        XCTAssertFalse(saldos.staticTexts["Saldos"].exists, "La pestaña sin elegir pinta su nombre (L12-1).")
        let stats = app.buttons["group_detail_tab_stats"]
        XCTAssertTrue(stats.exists && stats.isHittable,
                      "«Estadísticas» no se puede tocar entera: con los tres nombres salía cortada contra el borde.")

        saldos.tap()
        XCTAssertTrue(saldos.staticTexts["Saldos"].waitForExistence(timeout: 5),
                      "La pestaña elegida no enseña su nombre.")
    }

    /// **L12-3 · «Un último paso · Continuar» pasa a decir qué se acepta: «Ver y aceptar».**
    func test_needsConsentEmptyState_buttonSaysReviewAndAccept() {
        let app = XCUIApplication()
        app.launchForUITest(seed: nil, groupInvite: true, cloudSession: true)

        let cta = app.buttons["groups_empty_state_consent"].firstMatch
        XCTAssertTrue(cta.waitForExistence(timeout: 30), "Falta el estado vacío del consentimiento.")
        XCTAssertEqual(cta.label, "Ver y aceptar", "El botón no dice adónde lleva (L12-3).")
    }

    /// **L12-9 · crear es escribir un nombre y guardar**: el nombre trae ejemplo y las tres opciones van plegadas en
    /// «Más opciones», con palabras de persona.
    func test_newGroupForm_optionsAreFoldedUnderMoreOptions() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "grupos", deeplink: "groups", cloudSession: true, groupsConsent: true)

        openNewGroupForm(in: app)

        let nameInput = app.textFields["group_form_name_input"]
        XCTAssertTrue(nameInput.waitForExistence(timeout: 10), "No se abrió el formulario de grupo.")
        XCTAssertEqual(nameInput.placeholderValue, "Ej.: Viaje a Cusco", "El nombre no trae ejemplo (L12-9).")

        let simplify = app.switches["Menos pagos entre ustedes"]
        XCTAssertFalse(simplify.exists, "Las opciones salen desplegadas: tienen que ir plegadas en «Más opciones».")
        let more = app.buttons["group_form_more_options"]
        XCTAssertTrue(more.exists, "Falta «Más opciones».")
        more.tap()
        XCTAssertTrue(simplify.waitForExistence(timeout: 5),
                      "«Más opciones» no despliega «Menos pagos entre ustedes» (antes «Simplificar deudas»).")
        // avq3 · mismas palabras que en Ajustes del grupo (L19-7): crear y ajustar nombran igual la misma opción.
        XCTAssertTrue(app.switches["Ver las deudas en una sola moneda"].exists,
                      "Falta «Ver las deudas en una sola moneda»: crear no dice lo mismo que Ajustes del grupo (avq3).")
        XCTAssertTrue(app.staticTexts["Cómo se reparte un gasto nuevo"].exists,
                      "Falta «Cómo se reparte un gasto nuevo»: crear no dice lo mismo que Ajustes del grupo (avq3).")
    }

    /// **L12-11 · si para crear hubo que aceptar, al terminar vuelve al formulario.** Con sesión y sin consentimiento,
    /// «Nuevo grupo» abre el consentimiento; al aceptarlo, el formulario se abre solo.
    func test_createGroup_afterAcceptingTheConsent_opensTheForm() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "grupos", deeplink: "groups", cloudSession: true)

        openNewGroupForm(in: app)

        let accept = app.buttons["groups_consent_accept"]
        XCTAssertTrue(accept.waitForExistence(timeout: 15), "«Nuevo grupo» sin consentimiento no lo pidió.")
        accept.tap()

        XCTAssertTrue(app.textFields["group_form_name_input"].waitForExistence(timeout: 15),
                      "Tras aceptar, la cadena no volvió al formulario de grupo (L12-11).")
    }

    /// **L13-8 · «Grupo» del botón + sin ningún grupo explica el paso que falta** y lleva al formulario; cancelarlo no
    /// deja un gasto pedido que salte después.
    func test_panelGroupWithoutGroups_offersCreateGroup() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal", cloudSession: true, groupsConsent: true)

        app.revealPanelFAB().tap()
        let groupOption = app.buttons["panel_fab_group"]
        XCTAssertTrue(groupOption.waitForExistence(timeout: 5), "No apareció la opción «Grupo» del botón +.")
        groupOption.tap()

        let title = app.staticTexts["group_needed_title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10),
                      "Sin grupos, «Grupo» no explicó que primero hay que crear uno (L13-8).")
        app.buttons["group_needed_create"].tap()

        let nameInput = app.textFields["group_form_name_input"]
        XCTAssertTrue(nameInput.waitForExistence(timeout: 15), "«Crear grupo» no abrió el formulario de grupo.")
        XCTAssertFalse(app.textFields["group_expense_amount"].exists,
                       "El gasto se abrió antes de crear el grupo.")
    }

    // MARK: - Helpers

    private func openNewGroupForm(in app: XCUIApplication) {
        // Desde la card kzhe «Nuevo grupo» está arriba, bajo el resumen.
        let newGroup = app.buttons["groups_action_new_group"]
        XCTAssertTrue(newGroup.waitForExistence(timeout: 30), "No apareció «Nuevo grupo» arriba en Grupos.")
        newGroup.tap()
    }
}
