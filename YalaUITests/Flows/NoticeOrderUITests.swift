//
//  NoticeOrderUITests.swift
//  YalaUITests
//
//  Ticket `notices-come-out-one-after-another-by-priority`: dos avisos que la app saca sola a la vez, de consumidores
//  distintos (`ContentView` y `MainTabView`), salen uno tras otro y en el orden de la cola — nunca juntos, nunca el de
//  menos prioridad delante. Antes cada consumidor drenaba lo suyo y ganaba el que miraba antes.
//
//  Hooks: `-uitest-milestone 10` encola la hoja del hito (MainTab · `normal`) ANTES que `-uitest-inbox-alert`
//  (ContentView · `high`) y que `-uitest-trial-offer` (ContentView · `normal`). Convenciones: scheme Yala Dev, sin sleeps.
//

import XCTest

final class NoticeOrderUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// El aviso de la Bandeja (`high`) sale antes que el hito (`normal`) aunque el hito llegara primero, y el hito no se
    /// monta encima: sale al cerrarlo.
    func test_higherPriorityNoticeOfTheShell_goesFirst_thenTheMainTabSheet() {
        let app = XCUIApplication()
        app.launchForUITest(inboxAlert: true, extraArguments: ["-uitest-milestone", "10"])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        let alertDismiss = app.buttons["inbox_alert_dismiss"]
        XCTAssertTrue(alertDismiss.waitForExistence(timeout: 15), "No se presentó el aviso de la Bandeja.")
        XCTAssertFalse(app.buttons["milestone_not_now"].exists,
                       "La hoja del hito salió a la vez que el aviso de la Bandeja, o delante de él.")

        alertDismiss.tap()
        // 45 s por lo mismo que `PaywallInboxAlertRoutingUITests`: espera detrás del desmontaje del cover anterior.
        let milestoneNotNow = app.buttons["milestone_not_now"]
        XCTAssertTrue(milestoneNotNow.waitForExistence(timeout: 45),
                      "La hoja del hito no salió al cerrar el aviso (se perdió en la cola).")
        XCTAssertFalse(alertDismiss.exists, "El aviso de la Bandeja salió dos veces.")

        milestoneNotNow.tap()
        XCTAssertTrue(app.buttons["panel_inbox_button"].waitForExistence(timeout: 15),
                      "Tras cerrar los dos avisos el Panel no quedó usable.")
        XCTAssertFalse(app.buttons["inbox_alert_dismiss"].exists, "El aviso de la Bandeja volvió a salir.")
    }

    /// Misma prioridad (`normal`): manda la llegada. El hito llegó antes que la oferta de prueba, así que sale primero
    /// aunque sean de consumidores distintos; la oferta espera y sale al cerrarlo.
    ///
    /// **Este caso no discrimina la regla, y está medido** (mutante del 2026-10-30, iOS 27.0): sin la cesión en los dos
    /// drenajes sigue verde, porque en este runtime `MainTabView` drena antes que `ContentView` al abrirse la matriz. Lo que
    /// fija aquí es que los dos salen, uno tras otro y sin solaparse. La dirección «un aviso de ContentView cede ante la hoja
    /// de MainTab» la fijan `NoticeOrderTests` (regla, cola y el source-scan de `drainContentViewIntents`). El caso de
    /// arriba sí cae con el mutante: el hito salía antes que el aviso de la Bandeja.
    func test_samePriorityNotices_comeOutInArrivalOrder_acrossConsumers() {
        let app = XCUIApplication()
        app.launchForUITest(trialOffer: true, extraArguments: ["-uitest-milestone", "10"])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        let milestoneNotNow = app.buttons["milestone_not_now"]
        XCTAssertTrue(milestoneNotNow.waitForExistence(timeout: 15), "No salió primero la hoja del hito.")
        XCTAssertFalse(app.buttons["trial_offer_dismiss"].exists,
                       "La oferta de prueba salió a la vez que el hito, o delante de él.")

        milestoneNotNow.tap()
        let trialDismiss = app.buttons["trial_offer_dismiss"]
        XCTAssertTrue(trialDismiss.waitForExistence(timeout: 45),
                      "La oferta de prueba no salió al cerrar el hito (se perdió en la cola).")
        trialDismiss.tap()
        XCTAssertTrue(app.buttons["panel_inbox_button"].waitForExistence(timeout: 15),
                      "Tras cerrar los dos avisos el Panel no quedó usable.")
    }
}
