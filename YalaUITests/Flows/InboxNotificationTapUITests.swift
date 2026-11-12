//
//  InboxNotificationTapUITests.swift
//  YalaUITests
//
//  Tocar la notificación de un pago de Apple Pay abre la Bandeja, y el aviso «tienes borradores en la Bandeja» no sale
//  después: ni con la Bandeja abierta, ni al cerrarla, ni en la siguiente vuelta a la app (ticket
//  `notification-tap-opens-inbox-then-inbox-notice-pops-after`).
//
//  El simulador no deja tocar el banner de iOS, así que el toque se finge con `-uitest-inbox-notification-tap`, que
//  entra por el mismo `NotificationService.routeTap` que el toque real; el aviso lo pide su productor de verdad
//  (`checkForPendingInboxDrafts`) con los borradores de la semilla y el pago de Apple Pay que el gancho encola.
//

import XCTest

final class InboxNotificationTapUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launch(mode: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(extraArguments: ["-uitest-inbox-notification-tap", mode])
        return app
    }

    /// El aviso no sale mientras la Bandeja está abierta, ni al cerrarla.
    private func assertInboxOpensWithoutTheNotice(_ app: XCUIApplication, _ context: String, showing merchant: String? = nil) {
        let close = app.buttons["inbox_close"]
        XCTAssertTrue(close.waitForExistence(timeout: 30), "\(context): la notificación no abrió la Bandeja (inbox_close).")
        XCTAssertFalse(app.buttons["inbox_alert_view"].waitForExistence(timeout: 4),
                       "\(context): con la Bandeja abierta salió el aviso de borradores nuevos.")
        if let merchant {
            let row = app.descendants(matching: .any).containing(NSPredicate(format: "label CONTAINS[c] %@", merchant)).firstMatch
            XCTAssertTrue(row.waitForExistence(timeout: 5), "\(context): la Bandeja no enseñaba el pago de la notificación (\(merchant)).")
        }
        close.tap()
        XCTAssertFalse(app.buttons["inbox_alert_view"].waitForExistence(timeout: 5),
                       "\(context): al cerrar la Bandeja salió el aviso de borradores nuevos que ya se habían visto.")
    }

    /// Vuelve a la app sin tocar nada: lo visto en la Bandeja no vuelve a avisarse.
    private func assertNoticeDoesNotComeBackOnNextResume(_ app: XCUIApplication, _ context: String) {
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 15), "Yala no pasó a segundo plano.")
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15), "Yala no volvió delante.")
        XCTAssertFalse(app.buttons["inbox_alert_view"].waitForExistence(timeout: 6),
                       "\(context): al volver a la app salió el aviso de los borradores que ya se vieron en la Bandeja.")
    }

    /// Con la app cerrada: el toque llega antes de que termine el arranque y abre la Bandeja.
    func test_coldLaunch_tapOpensInbox_andTheNoticeNeverFollows() {
        let app = launch(mode: "cold")
        assertInboxOpensWithoutTheNotice(app, "En frío", showing: "Wong")
        assertNoticeDoesNotComeBackOnNextResume(app, "En frío")
    }

    /// Con la app delante: el aviso de los borradores de la semilla ya está en pantalla cuando llega el toque. El aviso
    /// se cierra solo y sale la Bandeja en su lugar.
    func test_foreground_tapWithTheNoticeOnScreen_opensInboxInstead() {
        let app = launch(mode: "foreground")
        XCTAssertTrue(app.buttons["inbox_alert_view"].waitForExistence(timeout: 30),
                      "Al arrancar con borradores nuevos tenía que salir el aviso (control del productor).")
        assertInboxOpensWithoutTheNotice(app, "Delante, con el aviso en pantalla")
    }

    /// Con la app en segundo plano, el toque llega ANTES que el aviso del primer plano.
    func test_background_tapBeforeTheNotice_opensInbox_andTheNoticeNeverFollows() {
        let app = launch(mode: "warm-tap-first")
        dismissLaunchNotice(app)
        resumeWithTheApplePayNotification(app)
        assertInboxOpensWithoutTheNotice(app, "Desde segundo plano (toque primero)", showing: "Tambo")
        assertNoticeDoesNotComeBackOnNextResume(app, "Desde segundo plano (toque primero)")
    }

    /// Con la app en segundo plano, el toque llega DESPUÉS que el aviso del primer plano.
    func test_background_tapAfterTheNotice_opensInbox_andTheNoticeNeverFollows() {
        let app = launch(mode: "warm-check-first")
        dismissLaunchNotice(app)
        resumeWithTheApplePayNotification(app)
        assertInboxOpensWithoutTheNotice(app, "Desde segundo plano (aviso primero)", showing: "Tambo")
        assertNoticeDoesNotComeBackOnNextResume(app, "Desde segundo plano (aviso primero)")
    }

    /// Control positivo del productor: los borradores de la semilla son nuevos al arrancar y el aviso sale. Sin esto, los
    /// casos de arriba pasarían también con un productor que no avisara nunca.
    private func dismissLaunchNotice(_ app: XCUIApplication) {
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        let dismiss = app.buttons["inbox_alert_dismiss"]
        XCTAssertTrue(dismiss.waitForExistence(timeout: 30),
                      "Al arrancar con borradores nuevos tenía que salir el aviso de la Bandeja (control del productor).")
        dismiss.tap()
        XCTAssertFalse(app.buttons["inbox_close"].exists, "La Bandeja no tenía que abrirse sin tocar la notificación.")
    }

    private func resumeWithTheApplePayNotification(_ app: XCUIApplication) {
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 15), "Yala no pasó a segundo plano.")
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15), "Yala no volvió delante.")
    }
}
