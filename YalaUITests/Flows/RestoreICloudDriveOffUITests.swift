//
//  RestoreICloudDriveOffUITests.swift
//  YalaUITests
//
//  Card 6a12 (ticket `restore-with-icloud-drive-off-mounts-without-mirror`). Con la sesión de iCloud abierta e iCloud
//  Drive apagado, «Restaurar» decía «Activa iCloud» porque miraba el token de Drive. El seam
//  `-uitest-fake-icloud-drive-off` finge ese iPhone (sin token, CloudKit `.available`); el control, sin seam, es el
//  simulador tal cual: sin cuenta, y ahí «Activa iCloud» sigue siendo la verdad.
//
//  Ruta: Hero → «Ya tengo una cuenta» → «Restaurar desde iCloud».
//

import XCTest

final class RestoreICloudDriveOffUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(driveOffWithAccount: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        var extra = ["-uitest-cloud-chooser"]
        if driveOffWithAccount { extra.append("-uitest-fake-icloud-drive-off") }
        app.launchForUITest(reset: true, skipOnboarding: false, seed: nil, extraArguments: extra)
        return app
    }

    private func openRestore(_ app: XCUIApplication) {
        let heroCTA = app.buttons["welcome_hero_cta"]
        XCTAssertTrue(heroCTA.waitForExistence(timeout: 60), "No apareció el CTA del Hero.")
        heroCTA.tap()
        let existingBranch = app.buttons["welcome_chooser_restore"]
        XCTAssertTrue(existingBranch.waitForExistence(timeout: 10), "No apareció «Ya tengo una cuenta».")
        existingBranch.tap()
        let restoreCard = app.buttons["welcome_existing_restore"]
        XCTAssertTrue(restoreCard.waitForExistence(timeout: 10), "No apareció «Restaurar desde iCloud».")
        restoreCard.tap()
    }

    /// Drive apagado con la sesión abierta: Restaurar busca (y aquí, sin datos, dice que no los encontró), no pide
    /// activar iCloud. Con el arreglo revertido sale «Activa iCloud» en el acto.
    func test_driveOffWithAccount_searchesInsteadOfAskingForICloud() {
        let app = launch(driveOffWithAccount: true)
        openRestore(app)
        let notFound = app.descendants(matching: .any)["welcome_restore_not_found"]
        let disabled = app.descendants(matching: .any)["welcome_restore_icloud_disabled"]
        let deadline = Date().addingTimeInterval(60)
        while Date() < deadline && !notFound.exists && !disabled.exists {
            _ = notFound.waitForExistence(timeout: 1)
        }
        attachScreenshot(app, named: "drive-off-con-cuenta")
        XCTAssertFalse(disabled.exists, "Con Drive apagado y cuenta de iCloud, Restaurar pidió activar iCloud.")
        XCTAssertTrue(notFound.exists, "Restaurar no terminó la búsqueda.")
    }

    private func attachScreenshot(_ app: XCUIApplication, named name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// Control: sin cuenta de iCloud (el simulador), sigue diciendo «Activa iCloud».
    func test_withoutAccount_stillAsksForICloud() {
        let app = launch(driveOffWithAccount: false)
        openRestore(app)
        XCTAssertTrue(app.descendants(matching: .any)["welcome_restore_icloud_disabled"].waitForExistence(timeout: 20),
                      "Sin cuenta de iCloud, Restaurar tiene que pedir activarla.")
    }
}
