//
//  ExportBeforeLosingItUITests.swift
//  YalaUITests
//
//  L20-8 (decisión de Jürgen, 2026-10-18): la hoja de «Cerrar sesión» SIN copia en iCloud ofrece «Exportar antes», que
//  saca el archivo de todo sin asistente y no cierra la sesión. La celda sin copia no se alcanza en el simulador (el
//  testigo del montaje dice siempre que hay copia), así que entra por el seam `-uitest-private-signout-no-copy`, que
//  solo elige la HOJA. Su control, sin el seam: la hoja con copia no lo ofrece.
//  La hoja de compartir es de iOS y no se deja tocar desde aquí; que al cerrarla vuelva la hoja de alcance se midió en
//  el barrido del 2026-10-19 (`capturas/despues-8*.png`).
//

import XCTest

final class ExportBeforeLosingItUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func openSignOutSheet(noCopy: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal", extraArguments: noCopy ? ["-uitest-private-signout-no-copy"] : [])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        app.openProfile()
        let row = app.buttons["profile_security_signout"]
        var swipes = 0
        while !row.isHittable && swipes < 14 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(row.isHittable, "No se llega a «Cerrar sesión».")
        row.tap()
        XCTAssertTrue(app.buttons["destructive_scope_confirm"].waitForExistence(timeout: 5),
                      "No apareció la hoja de «Cerrar sesión».")
        return app
    }

    func test_signOutWithoutACopy_offersExportFirst_andExportingDoesNotSignOut() {
        let app = openSignOutSheet(noCopy: true)
        let sheet = app.descendants(matching: .any).matching(identifier: "destructive_scope_sheet_signout_private_no_copy").firstMatch
        XCTAssertTrue(sheet.exists, "Con el seam, la hoja no es la de sin copia.")

        let export = app.buttons["signout_export_before"]
        XCTAssertTrue(export.exists, "La hoja de cerrar sesión sin copia no ofrece «Exportar antes» (L20-8).")
        export.tap()
        XCTAssertTrue(app.buttons["destructive_scope_confirm"].waitForNonExistence(timeout: 5),
                      "«Exportar antes» no cerró la hoja de alcance para enseñar el archivo.")
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "profile_signout_working_caption").firstMatch.exists,
                       "«Exportar antes» empezó a cerrar la sesión.")
    }

    /// Control: con copia en iCloud no se pierde nada y la hoja no ofrece exportar.
    func test_signOutWithACopy_doesNotOfferExport() {
        let app = openSignOutSheet(noCopy: false)
        XCTAssertFalse(app.buttons["signout_export_before"].exists, "La hoja con copia en iCloud no debería ofrecer exportar.")
    }
}
