//
//  UserDataResetScopeUITests.swift
//  YalaUITests
//
//  Las dos ramas CONDICIONALES de la hoja de alcance de «Vaciar mis datos» (§3.3.1 + D10), ejercitadas
//  por la condición REAL — SIN los seams `-uitest-groups-batch-demo` / `-uitest-groups-batch-running`,
//  que hacen que `canLeaveAllGroups(_:)` devuelva `true` en su PRIMERA línea
//  (`UserDataResetView.swift:68-72`), antes de mirar el resumen ⇒ los tests que los usan cubren el
//  FLUJO del batch pero no lo que DECIDE la rama:
//    · CON deuda → desvío «Ver mis grupos» (`wipe_view_groups`) y NADA de batch.
//    · CON grupos y CERO deuda → batch «También salir de mis grupos» (`wipe_leave_groups`) y NADA de desvío.
//
//  Lo que pinnean es el fix del 2026-08-03 (`.sheet(item:)`): con `.sheet(isPresented:)` el resumen de
//  grupos se leía de un `@State` mutado en el MISMO tap que enciende el flag, SwiftUI armaba el `Config`
//  con el valor anterior (`.empty`) y no lo re-evaluaba ⇒ NINGUNA de las dos ramas llegaba a ofrecerse
//  nunca, con la deuda bien calculada. Su gemelo de eliminar-cuenta (D5) es `DeleteAccountDialogUITests`,
//  el único test que cazó el bug; en Vaciar no lo habría cazado nadie.
//
//  Los dos gates de `canLeaveAllGroups` se cumplen sin ningún launch arg: `CloudSyncFlags.groupsBackendEnabled`
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

    /// CON deuda (seed `grupos`) la hoja ofrece el desvío «Ver mis grupos», NO ofrece el batch D10 (no se
    /// ofrece con saldos vivos) y mantiene disponible la acción destructiva — el aviso informa, jamás
    /// bloquea (línea roja GDPR de D5).
    func test_wipeScope_withGroupDebt_offersViewGroups_andNotBatchLeave() {
        let app = openWipeScopeSheet(seed: "grupos")

        let viewGroups = app.buttons["wipe_view_groups"]
        XCTAssertTrue(viewGroups.waitForExistence(timeout: 5),
                      "No apareció 'wipe_view_groups' — la rama de deuda de la hoja de Vaciar no se ofreció.")
        XCTAssertFalse(app.buttons["wipe_leave_groups"].exists,
                       "'wipe_leave_groups' NO debe aparecer con deuda (el batch no se ofrece con saldos vivos).")
        XCTAssertTrue(app.buttons["destructive_scope_confirm"].exists,
                      "La acción destructiva debe seguir disponible (el aviso informa, no bloquea).")
    }

    /// CON grupos y CERO deuda (seed `grupos-saldado`) la hoja ofrece el batch D10 y NO el desvío de deuda.
    /// Es la condición REAL de `canLeaveAllGroups`: flag ON + `hasGroups` + `!hasOutstandingDebt`.
    func test_wipeScope_withGroupsAndNoDebt_offersBatchLeave_andNotViewGroups() {
        let app = openWipeScopeSheet(seed: "grupos-saldado")

        let leaveGroups = app.buttons["wipe_leave_groups"]
        XCTAssertTrue(leaveGroups.waitForExistence(timeout: 5),
                      "No apareció 'wipe_leave_groups' — el batch D10 no se ofreció con grupos y cero deuda.")
        XCTAssertFalse(app.buttons["wipe_view_groups"].exists,
                       "'wipe_view_groups' NO debe aparecer sin deuda.")
        XCTAssertTrue(app.buttons["destructive_scope_confirm"].exists,
                      "La acción destructiva debe seguir disponible.")
    }
}
