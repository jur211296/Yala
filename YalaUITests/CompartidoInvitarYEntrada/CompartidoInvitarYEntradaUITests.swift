//
//  CompartidoInvitarYEntradaUITests.swift
//  YalaUITests
//
//  Lote 3 de Compartido (26-nov-2026): entrar sin grupo obligatorio e invitar a una persona.
//
//  - Sin grupos (y sin cuenta, el caso por defecto del simulador): la pestaña enseña la vista completa —chips, la fila
//    «Nuevo gasto · Voz · Foto · Yala IA» y el vacío de cada chip—, y «Nuevo gasto» pregunta «¿Con quién?» con
//    «Escribir un nombre». Es el selector de Grupos (`GroupPickerSheet`), no una pantalla nueva.
//  - «Añadir persona» abre la hoja del nombre. Crear la persona pide el servidor (`create_person_group`): con la sesión
//    fingida y sin JWT el alta no sale del teléfono y el error se dice DENTRO de la hoja, sin guardar nada.
//  - Quien abre el enlace de una persona ve «X te invita a Yala» y «Unirme a Yala»; al entrar, «Ya estás conectado».
//

import XCTest

final class CompartidoInvitarYEntradaUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: Entrada sin grupo

    func test_sinGrupos_vistaCompleta_yNuevoGastoPreguntaConQuien() {
        let app = XCUIApplication()
        app.launchForUITest(seed: nil, groupInvite: true)

        let full = app.descendants(matching: .any)["compartido_empty_full"].firstMatch
        XCTAssertTrue(full.waitForExistence(timeout: 30), "Sin grupos, la pestaña debe enseñar la vista completa.")
        XCTAssertTrue(app.buttons["compartido_chip_grupos"].exists, "Faltan los chips Grupos | Personas.")
        XCTAssertTrue(app.buttons["groups_action_new_expense"].exists, "Falta «Nuevo gasto» en la fila de captura.")
        XCTAssertTrue(app.buttons["groups_receipt_voice"].exists && app.buttons["groups_receipt_ai"].exists,
                      "Faltan Voz e Yala IA: la fila tiene que ser la de Grupos.")
        // El vacío del chip Grupos lleva al mismo sitio que la tarjeta de pasos: conserva su id.
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "groups_empty_state"))
            .firstMatch.exists, "El vacío de Grupos perdió su botón.")

        app.buttons["compartido_chip_personas"].tap()
        XCTAssertTrue(app.buttons["compartido_empty_people_action"].waitForExistence(timeout: 5),
                      "El chip Personas sin nadie debe invitar a apuntar el primero.")

        app.buttons["groups_action_new_expense"].tap()
        let write = app.buttons["compartido_write_name"]
        XCTAssertTrue(write.waitForExistence(timeout: 10), "«Nuevo gasto» sin nadie debe preguntar «¿Con quién?».")
        write.tap()
        let field = app.textFields["compartido_new_person_field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "«Escribir un nombre» no abrió el campo.")
        // Sin nombre, «Añadir» no hace nada.
        XCTAssertFalse(app.buttons["compartido_new_person_add"].isEnabled)
    }

    func test_voz_sinNadie_tambienPreguntaConQuien() {
        let app = XCUIApplication()
        app.launchForUITest(seed: nil, groupInvite: true)
        let voice = app.buttons["groups_receipt_voice"]
        XCTAssertTrue(voice.waitForExistence(timeout: 30))
        voice.tap()
        XCTAssertTrue(app.buttons["compartido_write_name"].waitForExistence(timeout: 10),
                      "Voz sin nadie con quien apuntar debe preguntar «¿Con quién?» antes de escuchar.")
    }

    // MARK: Añadir persona

    func test_anadirPersona_abreElNombre_yUnAltaQueNoSalePorRedSeDiceEnLaHoja() {
        let app = XCUIApplication()
        app.launchForUITest(seed: nil, groupInvite: true, cloudSession: true, groupsConsent: true)
        let people = app.buttons["compartido_chip_personas"]
        XCTAssertTrue(people.waitForExistence(timeout: 30))
        people.tap()

        let add = app.buttons["compartido_toolbar_add_person"]
        XCTAssertTrue(add.waitForExistence(timeout: 10), "En el chip Personas la barra debe ofrecer «Añadir persona».")
        add.tap()

        let field = app.textFields["compartido_new_person_field"]
        XCTAssertTrue(field.waitForExistence(timeout: 10), "«Añadir persona» no abrió la hoja del nombre.")
        field.typeText("Marta")
        let confirm = app.buttons["compartido_new_person_add"]
        XCTAssertTrue(confirm.isEnabled)
        // La hoja sube con el teclado: «Añadir» se toca cuando dejó de moverse (testing.md, tocar tras escribir).
        XCTAssertTrue(app.waitForSettledLayout(of: confirm))
        confirm.tap()

        // La sesión fingida no tiene JWT: el alta no sale del teléfono. Lo dice la hoja y no se crea nadie.
        XCTAssertTrue(app.staticTexts["compartido_add_person_error"].waitForExistence(timeout: 20),
                      "Un alta que no llega al servidor tiene que decirse dentro de la hoja.")
        XCTAssertFalse(app.descendants(matching: .any)["group_created_title"].exists,
                       "Sin servidor no puede salir «ya está en Compartido».")
    }

    // MARK: Persona añadida

    /// La hoja de grupo creado, con una persona: su texto («Marta ya está en Compartido») y el botón de invitar de
    /// siempre. Y Marta sale en Personas aunque todavía no haya gastos con ella.
    func test_personaAnadida_hojaConSuTexto_yApareceEnPersonas() {
        let app = XCUIApplication()
        app.launchForUITest(seed: nil, groupInvite: true, cloudSession: true, groupsConsent: true,
                            extraArguments: ["-uitest-seed-compartido-persona", "-uitest-group-created-sheet"])
        let title = app.staticTexts["group_created_title"]
        XCTAssertTrue(title.waitForExistence(timeout: 30), "No salió la hoja de persona añadida.")
        XCTAssertTrue(title.label.contains("Marta"), "El título debe nombrar a la persona: \(title.label)")
        XCTAssertTrue(app.buttons["group_created_invite"].exists, "La invitación es la de siempre.")
        app.buttons["group_created_later"].tap()

        let people = app.buttons["compartido_chip_personas"]
        XCTAssertTrue(people.waitForExistence(timeout: 10))
        people.tap()
        let card = app.descendants(matching: .any)["compartido_person_card"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10), "La persona recién añadida tiene que salir en Personas.")
    }

    // MARK: Invitación a una persona

    func test_invitacionAPersona_dicenTeInvitanAYala_yEntraConectado() {
        let app = XCUIApplication()
        app.launchForUITest(
            skipOnboarding: false, seed: nil, inviteOnboarding: true, inviteBranded: true, joinPhase: "active",
            extraArguments: ["-uitest-invite-person"])

        let title = app.staticTexts["invite_person_title"]
        XCTAssertTrue(title.waitForExistence(timeout: 30), "La invitación a una persona debe enseñar su tarjeta.")
        XCTAssertFalse(app.descendants(matching: .any)["invite_group_card"].exists,
                       "La invitación a una persona no es la tarjeta de un grupo.")
        let join = app.buttons["invite_join_button"]
        XCTAssertTrue(join.exists)
        join.tap()

        XCTAssertTrue(app.staticTexts["invite_ready_title"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["invite_ready_continue"].exists,
                      "Una persona no tiene «Ver el grupo»: al entrar se sigue a Compartido.")
        XCTAssertFalse(app.buttons["invite_ready_view_group"].exists)
    }

    /// No regresión: la invitación a un GRUPO sigue con su tarjeta de grupo.
    func test_invitacionAGrupo_sigueConLaTarjetaDelGrupo() {
        let app = XCUIApplication()
        app.launchForUITest(skipOnboarding: false, seed: nil, inviteOnboarding: true, inviteBranded: true)
        XCTAssertTrue(app.descendants(matching: .any)["invite_group_card"].firstMatch.waitForExistence(timeout: 30))
        XCTAssertFalse(app.staticTexts["invite_person_title"].exists)
    }
}
