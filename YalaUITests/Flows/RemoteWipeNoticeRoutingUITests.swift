//
//  RemoteWipeNoticeRoutingUITests.swift
//  YalaUITests
//
//  El aviso de «tus datos fueron eliminados de iCloud», por la vía que le corresponde.
//
//  **Qué cubre que ningún escáner alcanza** (ticket `remote-wipe-alert-skips-the-router`):
//   1. Que el aviso se presenta DE VERDAD cuando entra por la cola del router, que la shell sigue
//      montada debajo y que lo que viaja detrás en la cola ESPERA en vez de apilarse encima. Hasta el
//      2026-09-14 lo encendía un `@State` desde una tarea de fondo: con el anchor ocupado, SwiftUI
//      descartaba la presentación en silencio.
//   1b. Y la vuelta: al contestarlo, el intent retenido presenta. Ese es el aserto que prueba que
//      contestar suelta la CONDICIÓN VIVA y no sólo el flag del alert — sin eso, el router se queda
//      retenido con el aviso ya cerrado, que es el brick del ticket por su otra cara.
//   2. Que la red de presentación efectiva NO lo desarma cuando sí está en pantalla. Esa red existe
//      para soltar la matriz de readiness si UIKit no llegó a montar el alert, y su sonda contesta
//      «¿hay algo presentado?» a UIKit. Si esa sonda se equivocara hacia `false` —otra versión de iOS,
//      otro envoltorio de presentación—, el aviso se iría solo a los ~9 s y nadie se enteraría: el
//      caso 1 de esta suite espera esa ventana entera con el alert delante.
//   3. A dónde aterriza cada botón, que es la otra mitad del ticket.
//
//  **Lo que NO cubre, y tiene ticket propio**: el PRODUCTOR. En producción el aviso lo pide la gracia
//  de cinco segundos de `ContentView`, que arranca cuando las filas personales desaparecen del store
//  bajo el proceso vivo, y para eso no hay seam (`remote-wipe-receiver-has-no-behaviour-test`). El hook
//  `-uitest-remote-wipe-notice` encola el intent; el drenaje re-mide sus tres condiciones vivas igual
//  que en producción, así que lo que se ejercita de ahí en adelante es el camino real.
//
//  Sin seed a propósito: el drenaje exige que no haya vida personal en el store (`hasPersonalData`), que
//  es precisamente el hecho del que habla el aviso.
//

import XCTest

final class RemoteWipeNoticeRoutingUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// **Se lanza SIEMPRE con la oferta de prueba en cola, y es el instrumento que da valor a la suite.**
    /// El paywall es `.normal` y el aviso `.high`, así que el orden de drenaje es determinista: el aviso
    /// primero, el paywall esperando detrás del blocker. Lo que se afirma con él son las dos mitades de
    /// la matriz — que nada se monta ENCIMA del aviso, y que lo retenido presenta cuando el aviso se
    /// contesta—, y las dos se pierden si alguien devuelve la matriz al `@State` del alert.
    private func launchWithNotice() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(seed: nil, trialOffer: true, extraArguments: ["-uitest-remote-wipe-notice"])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap no completó.")
        return app
    }

    /// Los dos botones se localizan por POSICIÓN y no por su texto: el alert es nativo y su copy viaja
    /// en 16 idiomas, así que fijar el literal ataría la suite al idioma del simulador. El orden es el
    /// del `actions` builder — destructivo primero, cancelar después— y los dos casos de abajo lo
    /// verifican por su consecuencia: si se invirtiera, los dos fallarían a la vez y por su aterrizaje.
    private func notice(in app: XCUIApplication) -> XCUIElement {
        app.alerts.firstMatch
    }

    func test_notice_presentsOverTheShell_andThePresentationNetLeavesItAlone() {
        let app = launchWithNotice()
        let alert = notice(in: app)
        XCTAssertTrue(alert.waitForExistence(timeout: 30), """
            El aviso de vaciado remoto no se presentó. Si el intent se drenó igual, mira las tres
            condiciones vivas del drenaje: store sin vida personal, onboarding completo y el eje de
            sesión (que el backfill del arranque escribe con el onboarding dado por hecho).
            """)
        XCTAssertEqual(alert.buttons.count, 2, "El aviso no trae sus dos ramas.")

        // **Nada se monta ENCIMA**: el paywall que viaja en la misma cola espera detrás del blocker en
        // vez de apilarse sobre el aviso. Es la mitad de la matriz que se rompe si el blocker vuelve a
        // colgar del `@State` del alert.
        XCTAssertFalse(app.buttons["trial_offer_dismiss"].exists, """
            La oferta de prueba se montó encima del aviso: dos presentaciones del mismo anchor. El
            blocker de la matriz dejó de retener la cola mientras el aviso está en pantalla.
            """)
        // Y la shell sigue montada debajo — control del instrumento más que aserto: con el aviso ya
        // presentado por la cola, el anchor estaba libre por construcción.
        XCTAssertTrue(app.buttons["panel_inbox_button"].exists, "La shell no está debajo del aviso.")

        // Y la red de presentación efectiva lo deja en paz. Su cap de ciclo son ~9 s (8 reintentos de
        // `RelaunchNetLogic` más el primer chequeo); esperar 15 s cubre la ventana entera con margen.
        // Si la sonda de UIKit dejara de reconocer la presentación, el aviso se desarmaría aquí.
        let desaparece = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: alert)
        XCTAssertEqual(
            XCTWaiter().wait(for: [desaparece], timeout: 15), .timedOut, """
            La red de presentación desarmó un aviso que SÍ estaba en pantalla. La sonda
            (`ModalPresentationProbe`) dejó de reconocer la presentación de un `.alert` en este runtime:
            arréglala antes de que el desarme se coma avisos buenos.
            """)
    }

    func test_notice_keepWaiting_leavesTheAppWhereItWas() {
        let app = launchWithNotice()
        let alert = notice(in: app)
        XCTAssertTrue(alert.waitForExistence(timeout: 30), "El aviso de vaciado remoto no se presentó.")

        alert.buttons.element(boundBy: 1).tap()   // «Seguir esperando»

        XCTAssertFalse(alert.waitForExistence(timeout: 3), "El aviso no se cerró al pulsar «Seguir esperando».")
        XCTAssertFalse(app.buttons["welcome_hero_cta"].exists, """
            Cancelar mandó a la persona al Welcome. Esta rama no navega a ninguna parte: sus datos
            siguen sin estar, pero la app estaba montada debajo y ahí se queda.
            """)
        // **Y el router vuelve a drenar**, que es lo que prueba que contestar el aviso soltó la condición
        // viva y no sólo el flag del alert: la oferta de prueba llevaba toda la sesión retenida en cola.
        // Sin ese desarme, el blocker se queda puesto y esto no aparece nunca — el brick del ticket.
        // 45 s como en `PaywallInboxAlertRoutingUITests`: este paso espera al DESMONTAJE del anterior,
        // que es la latencia que la app no controla.
        XCTAssertTrue(app.buttons["trial_offer_dismiss"].waitForExistence(timeout: 45), """
            El intent retenido no presentó al contestar el aviso: la condición viva
            (`remoteWipeNoticePending`) se quedó puesta y el router sigue retenido.
            """)
        // Y la app responde: nada quedó pegado por encima.
        app.buttons["trial_offer_dismiss"].tap()
        XCTAssertTrue(app.buttons["panel_inbox_button"].waitForExistence(timeout: 10),
                      "El Panel no quedó accesible tras cerrar el aviso y el paywall.")
    }

    func test_notice_startFresh_landsOnTheWelcomeHero() {
        let app = launchWithNotice()
        let alert = notice(in: app)
        XCTAssertTrue(alert.waitForExistence(timeout: 30), "El aviso de vaciado remoto no se presentó.")

        alert.buttons.element(boundBy: 0).tap()   // «Empezar de cero»

        // El aterrizaje ELEGIDO, y el mismo que el del vaciado que llega por señal: el Hero del
        // Welcome, con sus tres ramas —entre ellas «Restaurar de iCloud», que es la que sirve a quien
        // crea que esto fue un error—. Antes de este ticket el destino dependía de lo que quedara en
        // las preferencias: con el chooser dado por visto, iba directo al formulario del onboarding.
        XCTAssertTrue(app.buttons["welcome_hero_cta"].waitForExistence(timeout: 30), """
            «Empezar de cero» no aterrizó en el Hero del Welcome.
            """)
    }
}
