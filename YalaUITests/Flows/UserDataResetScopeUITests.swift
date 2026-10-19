//
//  UserDataResetScopeUITests.swift
//  YalaUITests
//
//  Las dos ramas CONDICIONALES de la hoja de alcance de «Vaciar mis datos» (§3.3.1 + D10), ejercitadas
//  por la condición REAL — SIN los seams `-uitest-groups-batch-demo` / `-uitest-groups-batch-running`,
//  que fuerzan la oferta del batch (desde L19-12, `GroupsGlobalSettingsView.offersLeaveAllGroups`) antes de
//  mirar el resumen ⇒ los tests que los usan cubren el FLUJO del batch pero no lo que DECIDE la rama:
//    · CON deuda → desvío «Ver mis grupos» (`wipe_view_groups`) y NADA de batch.
//    · CON grupos y CERO deuda → ni desvío ni batch: «Salir de todos mis grupos» vive en Ajustes de Grupos (L19-12).
//
//  Lo que pinnean es el fix del 2026-08-03 (`.sheet(item:)`): con `.sheet(isPresented:)` el resumen de
//  grupos se leía de un `@State` mutado en el MISMO tap que enciende el flag, SwiftUI armaba el `Config`
//  con el valor anterior (`.empty`) y no lo re-evaluaba ⇒ NINGUNA de las dos ramas llegaba a ofrecerse
//  nunca, con la deuda bien calculada. Su gemelo de eliminar-cuenta (D5) es `DeleteAccountDialogUITests`,
//  el único test que cazó el bug; en Vaciar no lo habría cazado nadie.
//
//  Los dos gates de la oferta del batch se cumplen sin ningún launch arg: `CloudSyncFlags.groupsBackendEnabled`
//  está ON en todo XCUITest bajo el scheme `Yala Dev` (`DEV_BUILD` ⇒ default-ausente de remote-config), y
//  `hasGroups` lo da el seed. La deuda la decide el PERFIL: `grupos` deja al usuario acreedor neto en 2
//  grupos (+140 PEN en «Viaje a Lima»; +190 PEN y +46,66 USD en «Viaje a Cusco») ⇒
//  `outstandingDebtGroupCount == 2`; `grupos-saldado` es el MISMO dataset con las liquidaciones
//  confirmadas que lo dejan en cero (`DevSeedGroups.createSettled`).
//  Convenciones: ver CLAUDE.md (sin sleeps, scheme Yala Dev, targeting por accessibilityIdentifier).
//

import XCTest

final class UserDataResetScopeUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Baja por el ScrollView de Ajustes hasta que la fila sea hittable (la sección DATOS vive al final).
    /// Determinista: tope de intentos, sin sleeps.
    private func scrollUntilHittable(_ element: XCUIElement, in app: XCUIApplication) {
        var tries = 0
        while !element.isHittable && tries < 12 {
            app.swipeUp()
            tries += 1
        }
    }

    /// Perfil de seed → hoja de alcance de Vaciar abierta y montada. Sin ningún seam del batch: la rama
    /// la decide el resumen REAL que `GroupService.accountDeletionGroupsSummary()` calcula al tap.
    private func openWipeScopeSheet(seed: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(seed: seed)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        app.openProfile()
        let resetRow = app.buttons["profile_security_reset_data"]
        XCTAssertTrue(resetRow.waitForExistence(timeout: 10), "No apareció la fila 'Vaciar mis datos'.")
        scrollUntilHittable(resetRow, in: app)
        resetRow.tap()

        let startBtn = app.buttons["wipe_data_start"]
        XCTAssertTrue(startBtn.waitForExistence(timeout: 5), "No apareció el botón 'Vaciar mis datos'.")
        startBtn.tap()

        // La acción destructiva es la señal canónica de "la hoja de alcance está montada".
        XCTAssertTrue(app.buttons["destructive_scope_confirm"].waitForExistence(timeout: 5),
                      "No apareció la hoja de alcance de Vaciar ('destructive_scope_confirm').")
        return app
    }

    /// CON deuda (seed `grupos`) la hoja ofrece el desvío «Ver mis grupos» y mantiene disponible la acción
    /// destructiva — el aviso informa, jamás bloquea (línea roja GDPR de D5).
    func test_wipeScope_withGroupDebt_offersViewGroups() {
        let app = openWipeScopeSheet(seed: "grupos")

        let viewGroups = app.buttons["wipe_view_groups"]
        XCTAssertTrue(viewGroups.waitForExistence(timeout: 5),
                      "No apareció 'wipe_view_groups' — la rama de deuda de la hoja de Vaciar no se ofreció.")
        XCTAssertTrue(app.buttons["destructive_scope_confirm"].exists,
                      "La acción destructiva debe seguir disponible (el aviso informa, no bloquea).")
    }

    /// L19-12 (decisión de Jürgen, 2026-10-18): con grupos y CERO deuda (seed `grupos-saldado`, la única celda en la que
    /// la hoja ofrecía «También salir de mis grupos») la hoja ya NO lo ofrece: vive en Ajustes de Grupos
    /// (`GroupBatchLeaveUITests`). Con el botón devuelto a la hoja, este caso se pone rojo.
    func test_wipeScope_withGroupsAndNoDebt_noLongerOffersLeavingTheGroups() {
        let app = openWipeScopeSheet(seed: "grupos-saldado")

        XCTAssertTrue(app.buttons["wipe_export_before"].waitForExistence(timeout: 5),
                      "La hoja de Vaciar no ofrece «Exportar antes».")
        XCTAssertFalse(app.buttons["wipe_leave_groups"].exists,
                       "«También salir de mis grupos» sigue en la hoja de Vaciar: L19-12 lo llevó a Ajustes de Grupos.")
        XCTAssertFalse(app.buttons["wipe_view_groups"].exists, "'wipe_view_groups' NO debe aparecer sin deuda.")
        XCTAssertTrue(app.buttons["destructive_scope_confirm"].exists, "La acción destructiva debe seguir disponible.")
    }

    /// B3 (lote 20) + L20-1: «Exportar antes» abre la exportación con «Todo» elegido. Hasta B3 abría con
    /// «Últimos 30 días», y quien hacía la copia sin tocar nada se llevaba un mes y luego lo borraba todo.
    func test_exportBefore_opensTheExportWithEverything() {
        let app = openWipeScopeSheet(seed: "minimal")

        let exportBefore = app.buttons["wipe_export_before"]
        XCTAssertTrue(exportBefore.waitForExistence(timeout: 5), "La hoja de Vaciar no ofrece «Exportar antes».")
        exportBefore.tap()

        let all = app.buttons["export_period_all"]
        XCTAssertTrue(all.waitForExistence(timeout: 10), "«Exportar antes» no abrió la pantalla de exportar.")
        XCTAssertTrue(all.isSelected, "«Exportar antes» abrió con otro período: la copia de antes de vaciar es la de todo.")
    }

    /// L20-5: la pantalla de Vaciar es una frase y dos botones — «Exportar una copia antes» y «Vaciar mis datos». La
    /// copia abre la misma exportación, con «Todo».
    func test_wipeScreen_isOneSentenceAndTwoButtons() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        app.openProfile()
        let resetRow = app.buttons["profile_security_reset_data"]
        XCTAssertTrue(resetRow.waitForExistence(timeout: 10), "No apareció la fila 'Vaciar datos'.")
        scrollUntilHittable(resetRow, in: app)
        resetRow.tap()

        let sentence = app.descendants(matching: .any).matching(identifier: "wipe_data_sentence").firstMatch
        XCTAssertTrue(sentence.waitForExistence(timeout: 5), "Falta la frase de la pantalla de Vaciar.")
        XCTAssertTrue(sentence.label.contains("No se puede deshacer"), "La frase no avisa de que no se deshace.")
        XCTAssertFalse(app.staticTexts["Vaciar todos tus datos"].exists, "El título repetido sigue en la pantalla.")
        XCTAssertTrue(app.buttons["wipe_data_start"].exists, "Falta «Vaciar mis datos».")

        let copy = app.buttons["wipe_export_copy"]
        XCTAssertTrue(copy.exists, "Falta «Exportar una copia antes».")
        copy.tap()
        let all = app.buttons["export_period_all"]
        XCTAssertTrue(all.waitForExistence(timeout: 10), "«Exportar una copia antes» no abrió la exportación.")
        XCTAssertTrue(all.isSelected, "La copia de antes de vaciar no abrió con «Todo».")
    }
}
