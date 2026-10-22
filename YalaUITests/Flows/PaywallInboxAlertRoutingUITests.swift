//
//  PaywallInboxAlertRoutingUITests.swift
//  YalaUITests
//
//  Regresión del bug TestFlight 2.0.5 "toolbar muerta + bandeja que no abre":
//  con un paywall y el alert de inbox compitiendo por el MISMO anchor del
//  shell, la matriz de readiness debe serializarlos (el segundo ESPERA en
//  cola, jamás se descarta ni se monta encima) y tras cerrar ambos la toolbar
//  debe seguir viva y la Bandeja accesible.
//
//  Hooks: -uitest-inbox-alert + -uitest-trial-offer (las emisiones
//  automáticas de monetización están suprimidas en uitest a propósito).
//  Orden determinista: .showInboxAlert es priority .high → drena primero;
//  .presentTrialOffer espera detrás del blocker activeInboxAlert.
//  Convenciones: ver CLAUDE.md (sin sleeps, identifiers, scheme Yala Dev).
//

import XCTest

final class PaywallInboxAlertRoutingUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_alertAndPaywallSerialize_thenToolbarAliveAndInboxOpens() {
        let app = XCUIApplication()
        app.launchForUITest(inboxAlert: true, trialOffer: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        // 1. El alert de inbox (priority high) presenta primero; el paywall
        //    NO puede montarse encima en el mismo anchor (espera en cola).
        let alertDismiss = app.buttons["inbox_alert_dismiss"]
        XCTAssertTrue(alertDismiss.waitForExistence(timeout: 15), "No se presentó el InboxAlertModal.")
        XCTAssertFalse(
            app.buttons["trial_offer_dismiss"].exists,
            "El paywall se montó ENCIMA del alert (doble presentación mismo anchor — la matriz no serializó)."
        )

        // 2. Cerrar el alert ("Más tarde") libera el blocker → el paywall
        //    retenido presenta AHORA (antes se descartaba en silencio).
        alertDismiss.tap()
        let paywallDismiss = app.buttons["trial_offer_dismiss"]
        // 45 s y no 10 s: este paso es el único del test que espera detrás del DESMONTAJE del cover
        // anterior (alert y paywall comparten anchor — UIKit no monta el segundo hasta que el
        // primero se ha ido), así que hereda la latencia de desmontaje del runtime, que la app no
        // controla. Matriz 2×2 del 2026-07-28: el caso completo mide 12,9 s clavados en iOS 26.4.1
        // y 19-39 s en iOS 27.0, y los fallos de esta suite se concentraron aquí, en 27.0, con
        // umbrales de 10 s y de 25 s; con margen holgado pasó 5/5. Lo que se afirma —que el intent
        // retenido presenta y no se pierde en silencio— no cambia; el umbral solo se consume en el
        // caso malo.
        XCTAssertTrue(paywallDismiss.waitForExistence(timeout: 45), "El paywall retenido no se presentó al cerrar el alert (intent perdido).")

        // 3. Cerrar el paywall no deja capa fantasma: la toolbar del Panel
        //    responde y la Bandeja abre con los drafts del seed.
        paywallDismiss.tap()
        let inboxButton = app.buttons["panel_inbox_button"]
        XCTAssertTrue(inboxButton.waitForExistence(timeout: 10), "No apareció el botón de bandeja tras cerrar el paywall.")
        inboxButton.tap()
        XCTAssertTrue(
            app.buttons["inbox_draft_row_Almuerzo equipo"].waitForExistence(timeout: 5),
            "La Bandeja no abrió tras cerrar alert+paywall — toolbar muerta o sheet bloqueado."
        )
    }
}
