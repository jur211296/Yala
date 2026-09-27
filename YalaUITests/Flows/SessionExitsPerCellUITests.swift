//
//  SessionExitsPerCellUITests.swift
//  YalaUITests
//
//  Paso 9 del rediseño de sesiones (ADR 2026-09-09 «Sesiones — dos ejes» §5-6): Ajustes enseña los mismos DOS
//  botones —«Cerrar sesión» y «Vaciar datos»— en todas las celdas, y la hoja de «Cerrar sesión» es la de SU
//  celda. La fila es una sola en las cuatro, así que lo que demuestra de qué celda es cada pantalla es el
//  identifier de escenario de la hoja (`destructive_scope_sheet_<operación>`).
//
//  Celdas alcanzables en el simulador con los seams que ya existen:
//   - C · privada sin nube: el arranque por defecto.
//   - D · privada + sesión de grupos: `-uitest-fake-cloud-session` (finge el predicado GLOBAL de sesión).
//   - F · solo grupos: el mismo seam + `-uitest-group-invite`.
//  La E (nube completa) no tiene seam de `storageMode == .cloud` y la cubre la tabla unitaria
//  (`CloudSignOutFlowLogicTests`, `DestructiveScopeLogicTests`).
//
//  Solo UN test CONFIRMA el cierre, y con un seam que lo para antes del arm: el de la sesión que sobrevive a su cierre
//  (`-uitest-sign-out-keeps-session`). Los demás abren la hoja, leen su escenario y la cancelan: el seam de la sesión no
//  crea una real, y un cierre que llegara al arm borraría el store del simulador en el siguiente arranque MANUAL.
//

import XCTest

final class SessionExitsPerCellUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Las filas de salida que el ADR retiró. Ninguna puede volver en ninguna celda.
    private let retiredRows = [
        "profile_security_signout_plain", "profile_security_signout_groups",
        "profile_security_exit_yala_split", "profile_security_exit_yala_legacy",
        "profile_security_delete_account",
    ]

    /// Baja por Ajustes hasta que el botón sea hittable (la sección Seguridad y cuenta vive al final).
    /// Determinista: tope de intentos, sin sleeps.
    private func scrollTo(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        let element = app.buttons[identifier]
        var tries = 0
        while !element.isHittable && tries < 14 {
            app.swipeUp()
            tries += 1
        }
        return element
    }

    /// Los dos botones están, y ninguna de las salidas retiradas.
    private func assertTwoButtons(_ app: XCUIApplication, cell: String) {
        let reset = scrollTo(app, "profile_security_reset_data")
        XCTAssertTrue(reset.waitForExistence(timeout: 5), "\(cell): falta «Vaciar datos».")
        let signOut = scrollTo(app, "profile_security_signout")
        XCTAssertTrue(signOut.waitForExistence(timeout: 5), "\(cell): falta «Cerrar sesión».")
        for retired in retiredRows {
            XCTAssertFalse(app.buttons[retired].exists, "\(cell): volvió la fila retirada '\(retired)'.")
        }
    }

    /// Abre la hoja de «Cerrar sesión», devuelve su identifier de escenario y la cierra sin confirmar.
    private func signOutSheetScenario(_ app: XCUIApplication) -> String {
        scrollTo(app, "profile_security_signout").tap()
        let sheet = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "destructive_scope_sheet_"))
            .firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 5), "La hoja de «Cerrar sesión» no se presentó.")
        let scenario = sheet.identifier
        app.buttons["destructive_scope_cancel"].tap()
        return scenario
    }

    func test_privateCell_C_twoButtons_andPrivateSheet() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap no completó.")
        app.openProfile()

        assertTwoButtons(app, cell: "C")
        let scenario = signOutSheetScenario(app)
        // Con o sin copia en iCloud, pero la del privado SIN grupos. Cuál de las dos lo decide el testigo del
        // mount, y bajo `-uitest` el store es propio y ese testigo se queda en su valor por defecto: el aviso
        // «sin copia» y su segundo gesto los fijan los source-scans de `PrivateSignOutWiringTests` y el device-QA.
        XCTAssertTrue(scenario.hasPrefix("destructive_scope_sheet_signout_private"), "C mostró \(scenario)")
        XCTAssertFalse(scenario.contains("with_groups"), "C mostró la hoja del «equipo»: \(scenario)")
    }

    func test_teamCell_D_twoButtons_andTeamSheet() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal", cloudSession: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap no completó.")
        app.openProfile()

        assertTwoButtons(app, cell: "D")
        let scenario = signOutSheetScenario(app)
        XCTAssertTrue(scenario.hasPrefix("destructive_scope_sheet_signout_private_with_groups"),
                      "D (privada + grupos) mostró \(scenario): no hay «salir solo de grupos».")
    }

    /// F es además la celda donde «Eliminar mi cuenta» NO existía antes del paso 9: la fila excluía el modo
    /// group-invite con una premisa de la era CKShare. Aquí tiene que aparecer, dentro de «Tu cuenta de Yala».
    func test_groupsOnlyCell_F_twoButtons_groupsOnlySheet_andDeleteAccountInsideYalaAccount() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "solo-grupos", groupInvite: true, cloudSession: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        app.openProfile()

        assertTwoButtons(app, cell: "F")
        let scenario = signOutSheetScenario(app)
        XCTAssertEqual(scenario, "destructive_scope_sheet_signout_groups_only")

        let accountRow = scrollTo(app, "profile_yala_account")
        XCTAssertTrue(accountRow.waitForExistence(timeout: 5), "F: falta «Tu cuenta de Yala».")
        accountRow.tap()
        XCTAssertTrue(app.buttons["yala_account_delete"].waitForExistence(timeout: 5),
                      "F: «Eliminar mi cuenta» tiene que estar en «Tu cuenta de Yala» (App Store 5.1.1 v).")
    }

    /// Ticket `sign-out-exits-do-not-verify-the-cloud-session-closed`. Hasta el 2026-09-26 el cierre descartaba lo que
    /// devolvía `CloudAuthService.signOut()` y armaba el borrado igual: con la sesión superviviente, el teléfono quedaba
    /// como recién instalado con la sesión de quien cerró dentro. Ahora se para ANTES del arm y lo dice.
    ///
    /// **Es el único test de este fichero que confirma, y el seam es lo que lo hace seguro**: con el arreglo el cierre se
    /// para antes de `armSignOutWipe`. Si este test se pone rojo porque sale la pantalla de reabrir, el arm YA SE ESCRIBIÓ
    /// en el simulador (`cloudSync.signOutWipeArmed` sobrevive a `-uitest-reset`, ticket
    /// `uitest-reset-keeps-the-sign-out-wipe-arm`): no abras la app a mano antes de borrarlo, o el arranque se llevará el store.
    ///
    /// **Celda C, y no F ni D, medido:** con `-uitest-fake-cloud-session` no hay JWT, así que la subida de grupos de F y D se
    /// para antes con «Tu sesión caducó» y nunca llega a `signOut()`. La C no sube grupos. Espera al export de iCloud, y en
    /// el host de test eso puede agotar sus 45 s y enseñar «Aún faltan cambios por subir a iCloud»: «Cerrar sesión
    /// igualmente» sigue al mismo `finalizeSessionExit`, que es donde vive la comprobación.
    func test_privateCell_C_signOutWithASurvivingSession_stopsAndSaysSo() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal", signOutKeepsSession: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap no completó.")
        app.openProfile()

        scrollTo(app, "profile_security_signout").tap()
        let confirm = app.buttons["destructive_scope_confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "La hoja de «Cerrar sesión» no ofrece confirmar.")
        confirm.tap()

        // Se espera el TEXTO del motivo, no «un alert»: `alerts.firstMatch` casaba al instante con otra cosa (medido).
        let survived = app.alerts.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "sigue abierta")).firstMatch
        let exportPending = app.alerts.buttons["Cerrar sesión igualmente"].firstMatch
        let deadline = Date().addingTimeInterval(120)
        while !survived.exists && Date() < deadline {
            if exportPending.exists { exportPending.tap() }
            _ = survived.waitForExistence(timeout: 2)
        }
        XCTAssertTrue(survived.exists, """
            No salió el aviso de que la sesión sigue abierta: el cierre se paró en silencio, armó el borrado o enseñó el \
            texto de otro bloqueo.
            """)
        XCTAssertFalse(app.descendants(matching: .any)["signout_relaunch_screen"].exists,
                       "Salió la pantalla de reabrir: el cierre armó el borrado con la sesión viva. Borra el arm del simulador.")

        // El reintento: cerrar el aviso devuelve el cierre a reposo, y «Cerrar sesión» vuelve a abrir su hoja. Con la fase
        // pegada en `.blocked`, el toque volvería a enseñar el aviso en vez de la hoja.
        app.alerts.buttons.firstMatch.tap()
        scrollTo(app, "profile_security_signout").tap()
        XCTAssertTrue(app.buttons["destructive_scope_confirm"].waitForExistence(timeout: 10),
                      "Tras cerrar el aviso, «Cerrar sesión» no vuelve a abrir su hoja: el reintento no tiene puerta.")
        app.buttons["destructive_scope_cancel"].tap()
    }
}
