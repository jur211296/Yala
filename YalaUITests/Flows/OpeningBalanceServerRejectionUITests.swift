//
//  OpeningBalanceServerRejectionUITests.swift
//  YalaUITests
//
//  Card 6n1o · cuando el servidor rechaza un saldo inicial (g27_01), el detalle del grupo lo dice con un aviso claro y
//  con su motivo, no con un error genérico.
//
//  El servidor no está en el simulador. `-uitest-opening-balance-server-rejection <código>` deja en el buzón el código
//  tal como lo devuelve el gateway; desde ahí, la traducción a motivo y el aviso van por el camino de producción. Sin el
//  seam (el control) el mismo grupo abre sin aviso.
//

import XCTest

final class OpeningBalanceServerRejectionUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func openGroup(rejection: String?) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(
            pro: true,
            seed: "grupos",
            deeplink: "groups",
            extraArguments: rejection.map { ["-uitest-opening-balance-server-rejection", $0] } ?? []
        )
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        let card = app.buttons.matching(identifier: "group_card").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 30), "No apareció la tarjeta del grupo.")
        XCTAssertTrue(card.waitForHittable(timeout: 10), "La tarjeta del grupo existe pero no es alcanzable.")
        card.tap()
        // El detalle a la vista ANTES del aviso: el seam deja el rechazo 1,5 s después de abrir, como llega en
        // producción, así que el aviso sale por el disparo de `revision` y no por el `onAppear`.
        XCTAssertTrue(app.buttons["group_members_button"].waitForExistence(timeout: 15), "El detalle no montó.")
        return app
    }

    private func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Pago confirmado: el aviso nombra el motivo y que el saldo vuelve a como está en el grupo; «OK» lo cierra y no vuelve.
    func test_lockedRejection_showsItsReason_andGoesAwayForGood() {
        let app = openGroup(rejection: "yala_opening_balance_locked")
        let alert = app.alerts["Tu cambio no llegó al grupo"]
        XCTAssertTrue(alert.waitForExistence(timeout: 15), "El rechazo del servidor no sacó su aviso en el detalle del grupo.")
        XCTAssertTrue(
            alert.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "ya tienen pagos confirmados")).firstMatch.exists,
            "El aviso no explica el motivo del pago confirmado."
        )
        // Card e6fd: el aviso dice que el saldo vuelve a como está en el grupo (el descarte lo fijan los unit de
        // `OpeningBalanceRejectionSettleTests`; aquí el seam solo deja el código en el buzón).
        XCTAssertTrue(
            alert.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "vuelve a quedar como está en el grupo")).firstMatch.exists,
            "El aviso no dice que el saldo vuelve a como está en el grupo."
        )
        attachScreenshot("aviso-pago-confirmado")
        alert.buttons.firstMatch.tap()
        XCTAssertTrue(alert.waitForNonExistence(timeout: 5), "El aviso no se cerró con OK.")
        XCTAssertTrue(app.buttons["group_members_button"].waitForExistence(timeout: 10), "El detalle del grupo no quedó a la vista.")
        XCTAssertFalse(alert.waitForExistence(timeout: 2), "El aviso volvió a salir: el motivo no se consumió.")
    }

    /// Sin permiso: otro texto, el del admin.
    func test_notAdminRejection_saysOnlyOwnerOrAdmin() {
        let app = openGroup(rejection: "yala_opening_balance_not_admin")
        let alert = app.alerts["Tu cambio no llegó al grupo"]
        XCTAssertTrue(alert.waitForExistence(timeout: 15), "El rechazo del servidor no sacó su aviso.")
        XCTAssertTrue(
            alert.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Solo el dueño o un administrador")).firstMatch.exists,
            "El aviso no explica que hace falta ser dueño o admin."
        )
        attachScreenshot("aviso-sin-permiso")
    }

    /// CONTROL: sin rechazo, el grupo abre sin aviso (el detalle a la vista es el discriminante).
    func test_withoutRejection_noNotice() {
        let app = openGroup(rejection: nil)
        XCTAssertFalse(app.alerts["Tu cambio no llegó al grupo"].waitForExistence(timeout: 4), "Salió un aviso sin rechazo.")
    }
}
