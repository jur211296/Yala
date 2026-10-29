//
//  UXAudit22Lote04UITests.swift
//  YalaUITests
//
//  Auditoría UX 2.2 · lote decidido 04 (2026-10-19): cuenta, cerrar sesión y modo solo grupos. Cada caso fija una decisión
//  de Jürgen tal como la ve la persona, con su control cuando la aserción es negativa. Scheme `Yala Dev`.
//

import XCTest

final class UXAudit22Lote04UITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Baja por Ajustes hasta que el botón sea alcanzable. Determinista: tope de intentos, sin sleeps.
    private func scrollTo(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        let element = app.buttons[identifier]
        var tries = 0
        while !element.isHittable && tries < 14 {
            app.swipeUp()
            tries += 1
        }
        return element
    }

    // MARK: - L20-6 · sin cuenta de Yala, «Quitar mis datos de este dispositivo», sola y al final

    /// Celda privada sin cuenta (seed `minimal`, sin sesión): la fila de salida se llama por lo que hace, va DEBAJO de
    /// «Legal» (su propia tarjeta, separada de «Calificar») y su hoja lleva el mismo verbo.
    func test_privateCellWithoutAccount_rowSaysRemoveMyData_aloneAtTheEnd_andItsSheetToo() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap no completó.")
        app.openProfile()

        let row = scrollTo(app, "profile_security_signout")
        XCTAssertTrue(row.waitForExistence(timeout: 5), "No está la fila de salida en Ajustes.")
        XCTAssertTrue(row.label.contains("Quitar mis datos de este dispositivo"), "La fila no dice qué hace: \(row.label)")
        XCTAssertFalse(row.label.contains("Cerrar sesión"), "Sin cuenta de Yala la fila sigue diciendo «Cerrar sesión».")

        let terms = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Términos de uso")).firstMatch
        XCTAssertTrue(terms.exists, "Control: no se encontró «Términos de uso», la última fila de «Legal».")
        XCTAssertGreaterThan(row.frame.minY, terms.frame.maxY, """
            La fila no va al final: sigue dentro de «Seguridad y cuenta», entre «Calificar» y la ayuda.
            """)

        row.tap()
        XCTAssertTrue(app.staticTexts["¿Quitar tus datos de este dispositivo?"].waitForExistence(timeout: 5),
                      "La hoja de la fila no lleva su verbo.")
        let confirm = app.buttons["destructive_scope_confirm"]
        XCTAssertTrue(confirm.exists)
        XCTAssertEqual(confirm.label, "Quitar mis datos")
        app.buttons["destructive_scope_cancel"].tap()
    }

    // MARK: - L20-7 · la espera se ve, y el aviso ofrece exportar primero

    /// En el simulador no hay espejo de iCloud, así que la espera del export se agota: primero la tarjeta de progreso, a
    /// los 45 s el aviso. Sus tres botones van en el orden decidido: Exportar · Esperar · Quitar mis datos igualmente (en
    /// esta celda, sin cuenta de Yala, el verbo es el de su fila: decisión A de Jürgen, 2026-10-19).
    func test_privateSignOut_waitShowsTheUploadCard_andTheNoticeOffersExportFirst() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap no completó.")
        app.openProfile()

        scrollTo(app, "profile_security_signout").tap()
        let confirm = app.buttons["destructive_scope_confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "La hoja de salida no ofrece confirmar.")
        confirm.tap()

        let card = app.descendants(matching: .any)["profile_signout_upload_card"]
        XCTAssertTrue(card.waitForExistence(timeout: 15), """
            Mientras espera a iCloud no sale la tarjeta de progreso: vuelve el pie gris de una línea (L20-7).
            """)
        XCTAssertTrue(card.label.contains("Subiendo tus cambios a iCloud"), "La tarjeta no dice qué pasa: \(card.label)")
        XCTAssertFalse(app.staticTexts["profile_signout_working_caption"].exists,
                       "Salen la tarjeta y el pie viejo a la vez.")

        // El texto del aviso, no `app.alerts.firstMatch` (`testing.md`).
        let title = app.alerts.staticTexts["Aún faltan cambios por subir a iCloud"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 90), "A los 45 s no salió el aviso de cambios sin subir.")

        let export = app.alerts.buttons["Exportar mis registros"].firstMatch
        let wait = app.alerts.buttons["Esperar"].firstMatch
        let discard = app.alerts.buttons["Quitar mis datos igualmente"].firstMatch
        XCTAssertTrue(export.exists, "El aviso no ofrece exportar antes de perder nada.")
        XCTAssertTrue(wait.exists)
        XCTAssertTrue(discard.exists)
        XCTAssertLessThan(export.frame.minY, wait.frame.minY, "«Exportar mis registros» no va primero.")
        XCTAssertLessThan(wait.frame.minY, discard.frame.minY, "«Quitar mis datos igualmente» no va al final.")
        XCTAssertFalse(app.alerts.buttons["Cerrar sesión igualmente"].exists,
                       "Sin cuenta de Yala el aviso vuelve a decir «Cerrar sesión igualmente».")

        wait.tap()
        XCTAssertTrue(card.waitForExistence(timeout: 10), "«Esperar» no volvió a la espera con su tarjeta.")
    }

    // MARK: - L19-15 · solo grupos

    /// En solo grupos no salen ni «Sincronización iCloud» ni «Dónde viven tus datos», y «Activar Yala completo» está. El
    /// control de la negativa es «Exportar datos», de la misma sección.
    func test_groupsOnly_settingsHideTheICloudRows_andOfferTheFullYala() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "solo-grupos", groupInvite: true, cloudSession: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        app.openProfile()

        XCTAssertTrue(app.buttons["profile_activate_full_yala"].waitForExistence(timeout: 10),
                      "En solo grupos no está «Activar Yala completo».")
        let reset = scrollTo(app, "profile_security_reset_data")
        XCTAssertTrue(reset.exists, "Control: la sección «Datos» no se montó.")
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Exportar datos")).firstMatch.exists,
                      "Control: falta «Exportar datos» en la sección «Datos».")
        XCTAssertFalse(app.buttons["storage_settings_row"].exists, "«Dónde viven tus datos» sigue en solo grupos.")
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Sincronización iCloud")).firstMatch.exists,
                       "«Sincronización iCloud» sigue en solo grupos.")
    }

    // MARK: - L19-17 · volver a tus grupos

    /// La única salida de la pestaña sin sesión es un botón que dice «Entrar en mi cuenta», y la hoja ofrece «Continuar
    /// con Google» (no «Crear cuenta»).
    func test_groupsSignedOut_ctaSaysEnterMyAccount_andTheSheetSaysContinue() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal", deeplink: "groups",
                            extraArguments: ["-groups.hadSessionEver", "YES", "-hasShownGroupsOnboarding", "YES"])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap no completó.")

        let cta = app.buttons["groups_empty_state_signin"].firstMatch
        XCTAssertTrue(cta.waitForExistence(timeout: 20), "No salió el estado «Tus grupos están en tu cuenta».")
        XCTAssertTrue(cta.label.contains("Entrar en mi cuenta"), "El botón no dice «Entrar en mi cuenta»: \(cta.label)")

        cta.tap()
        let google = app.buttons["groups_signin_button_google"]
        XCTAssertTrue(google.waitForExistence(timeout: 10), "No se abrió «Conecta tu cuenta».")
        XCTAssertTrue(google.label.contains("Continuar con Google"), "La hoja sigue con otro verbo: \(google.label)")
    }

    // MARK: - L20-9 · «Tu cuenta de Yala»

    /// Arriba, el correo con el icono del proveedor, y «Dónde viven tus datos» es una fila que se toca.
    func test_yalaAccount_showsTheEmail_andDataLocationIsARow() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal", extraArguments: ["-uitest-fake-backend-session"])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap no completó.")
        app.openProfile()

        scrollTo(app, "profile_yala_account").tap()
        let identity = app.descendants(matching: .any)["yala_account_identity"].firstMatch
        XCTAssertTrue(identity.waitForExistence(timeout: 5), "«Tu cuenta de Yala» no dice con qué cuenta estás.")
        XCTAssertTrue(identity.label.contains("ana@icloud.com"), "No sale el correo: \(identity.label)")
        XCTAssertTrue(app.staticTexts["Si usas el mismo correo, Apple y Google abren esta misma cuenta."].exists,
                      "Falta la frase del método.")
        XCTAssertTrue(app.buttons["yala_account_data_location"].exists, "«Dónde viven tus datos» no es una fila.")
    }

    // MARK: - L20-10, superado el 2026-10-29 (encargo S27i)

    /// Cuenta de grupos con sesión privada (seed `minimal` + sesión fingida). Hasta el encargo S27i lo de este teléfono se
    /// quedaba y la alerta lo decía; desde la decisión de Jürgen del 2026-10-29 «Eliminar cuenta» se lo lleva también (y lo
    /// de iCloud), así que la hoja y la alerta dicen que se borra todo.
    func test_deleteAccount_groupsAccountWithPrivateData_finalAlertSaysEverythingGoes() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal", extraArguments: ["-uitest-fake-backend-session"])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap no completó.")
        app.openProfile()

        scrollTo(app, "profile_yala_account").tap()
        let delete = app.buttons["yala_account_delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        delete.tap()
        // S12h (2026-10-27): la fila dice también que sales de los grupos y que volver pide una invitación nueva.
        XCTAssertTrue(app.staticTexts[
            "Sales de tus grupos y tu nombre pasa a «Usuario eliminado». Para volver a uno, te tienen que invitar otra vez."
        ].waitForExistence(timeout: 5),
                      "La hoja no dice que eliminar la cuenta te saca de tus grupos ni cómo se vuelve.")
        let sheet = XCTAttachment(screenshot: app.screenshot())
        sheet.name = "eliminar-cuenta-fila-grupos"
        sheet.lifetime = .keepAlways
        add(sheet)
        app.buttons["delete_account_continue"].tap()

        let body = app.alerts.staticTexts
            .matching(NSPredicate(format: "label CONTAINS %@", "se eliminarán por completo")).firstMatch
        XCTAssertTrue(body.waitForExistence(timeout: 5), """
            La alerta final no dice que se borra todo: desde el encargo S27i la cuenta con iCloud privado se lleva también \
            lo de este teléfono.
            """)
        XCTAssertFalse(app.alerts.staticTexts["Se borra tu cuenta de Yala. Lo de este dispositivo se queda."].firstMatch.exists)
        app.alerts.buttons["Cancelar"].firstMatch.tap()
    }
}
