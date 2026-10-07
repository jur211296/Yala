//
//  WelcomeFreshStartAlertUITests.swift
//  YalaUITests
//
//  Pin del bug «cerrar el alert de Empezar desde cero deja el Welcome en blanco, sin salida».
//
//  **Por qué existe, y por qué es un XCUITest y no un test de lógica.** El defecto no estaba en
//  ninguna decisión: estaba en el ORDEN de presentación de UIKit. El alert cuelga del anchor de
//  `ContentView` y el Welcome es un `fullScreenCover` del MISMO anchor; un anchor no puede presentar
//  dos cosas a la vez, así que al encender el alert SwiftUI **desmontaba el cover** —por su setter,
//  con lo que `showWelcomeFlow` quedaba en `false` legítimamente—. Al cerrar el alert no quedaba nada
//  debajo: pantalla negra, cero elementos interactivos, y la única salida era matar la app.
//
//  Eso no lo caza ningún test de lógica, porque no hay lógica que corregir: los flags hacían lo que
//  decían. Sólo se ve montando la jerarquía de verdad. Medido en simulador el 2026-09-03: el árbol
//  quedaba en `screenHash 1njjbcs`, `count 6`, **cero targets**.
//
//  El fix devuelve al Chooser explícitamente en vez de confiar en que quede algo montado debajo, con
//  un guard `if !hasCompletedOnboarding` que el alert de «el wipe falló» comparte: si el onboarding ya
//  está completo, el alert vino de un camino donde el Welcome NO estaba montado y reabrirlo le
//  plantaría el flujo de bienvenida a alguien que ya usa la app.
//
//  Es un camino de PRODUCCIÓN: lo pisa cualquiera que reinstale o vuelva teniendo datos locales. No
//  depende de ningún flag — ni Grupos, ni nube, ni sesión secundaria.
//

import XCTest

final class WelcomeFreshStartAlertUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Cancelar el alert devuelve al Chooser con sus tres vías intactas.
    ///
    /// La aserción NO es «no está en blanco»: es que las TRES cards están y son tapeables. Un test
    /// que sólo comprobara la ausencia de la pantalla negra pasaría con un Chooser a medio montar,
    /// que es un modo de fallo vecino y igual de inútil para la persona.
    func testCancelFreshStartWipe_returnsToChooser_notToABlankScreen() throws {
        let app = XCUIApplication()
        // El seed importa: el alert SÓLO aparece si hay datos previos (`hasExistingData`). Sin seed
        // la rama va directa al onboarding y este test no probaría nada — pasaría en verde sin
        // haber visto jamás el alert. Por eso abajo se afirma que el alert EXISTE antes de cancelarlo.
        app.launchForUITest(reset: true, skipOnboarding: false, seed: "grupos")

        // `uitest_ready` vive en el root de ContentView, que queda CUBIERTO por el cover del Welcome:
        // se espera el Hero directamente, como hacen sus vecinos.
        let heroCTA = app.buttons["welcome_hero_cta"]
        XCTAssertTrue(heroCTA.waitForExistence(timeout: 60), "No apareció el CTA del Hero.")
        heroCTA.tap()

        let newBranch = app.buttons["welcome_chooser_new"]
        XCTAssertTrue(newBranch.waitForExistence(timeout: 10), "No apareció la card «Es mi primera vez».")
        newBranch.tap()

        // Control positivo del montaje: si el alert no llegó a salir, cancelar no prueba nada.
        let cancelButton = app.alerts.buttons.element(boundBy: 1)
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 10),
                      "No apareció el alert de «Empezar desde cero» — ¿el seed dejó de producir datos previos?")
        cancelButton.tap()

        // El corazón del pin: las tres vías del Chooser, vivas.
        XCTAssertTrue(app.buttons["welcome_chooser_new"].waitForExistence(timeout: 10), """
            Cancelar dejó al usuario sin Chooser. Éste es el bug: el alert se presenta desde el anchor \
            de ContentView y desmonta el cover del Welcome, así que al cerrarlo no queda nada debajo \
            y la app se queda en negro, sin más salida que matarla.
            """)
        XCTAssertTrue(app.buttons["welcome_chooser_restore"].exists,
                      "El Chooser volvió a medias: falta «Ya tengo una cuenta».")
        XCTAssertTrue(app.buttons["welcome_chooser_invite"].exists,
                      "El Chooser volvió a medias: falta «Vengo por un grupo».")
    }

    /// Y que la vuelta sea utilizable, no sólo visible: se re-entra por otra vía.
    ///
    /// El copy del alert promete que cancelar deja elegir otra cosa. Un Chooser que se pinta pero no
    /// responde al tap cumpliría el test de arriba y seguiría incumpliendo la promesa — es
    /// exactamente el modo de fallo del `contentShape` mal colocado que ya mordió en `GroupFormView`.
    func testCancelFreshStartWipe_leavesTheChooserUsable() throws {
        let app = XCUIApplication()
        app.launchForUITest(reset: true, skipOnboarding: false, seed: "grupos")

        let heroCTA = app.buttons["welcome_hero_cta"]
        XCTAssertTrue(heroCTA.waitForExistence(timeout: 60), "No apareció el CTA del Hero.")
        heroCTA.tap()

        let newBranch = app.buttons["welcome_chooser_new"]
        XCTAssertTrue(newBranch.waitForExistence(timeout: 10), "No apareció la card «Es mi primera vez».")
        newBranch.tap()

        let cancelButton = app.alerts.buttons.element(boundBy: 1)
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 10), "No apareció el alert de «Empezar desde cero».")
        cancelButton.tap()

        // Re-tocar la MISMA card tiene que volver a abrir el alert: la vuelta al Chooser no deja el
        // estado a medias (el flag del alert bajado, la card viva y su acción cableada).
        let newBranchAgain = app.buttons["welcome_chooser_new"]
        XCTAssertTrue(newBranchAgain.waitForExistence(timeout: 10), "El Chooser no volvió.")
        newBranchAgain.tap()
        XCTAssertTrue(app.alerts.buttons.element(boundBy: 1).waitForExistence(timeout: 10), """
            Tras cancelar, re-tocar «Es mi primera vez» ya no abre el alert. El Chooser volvió pero \
            inerte: el flag del alert se quedó arriba y su `isPresented` no puede volver a subir.
            """)
    }

    // MARK: - Tras salir de un adopt (onboarding ya completo, Welcome debajo)

    /// Ticket `fresh-start-alert-cancel-after-an-adopt-exit-lands-in-the-app`. El adopt deja `hasCompletedOnboarding` en
    /// `true` (kill-safety de `onAdoptStarted`) y sus salidas vuelven al Welcome sin bajarlo. Con la guarda vieja,
    /// «Cancelar» no reabría nada y la persona aterrizaba en la app, sobre los datos que acababa de decidir no borrar.
    ///
    /// El seam `-uitest-welcome-after-adopt-exit` finge ese estado de ENTRADA (en el simulador no hay SIWA); el alert, sus
    /// botones y el testigo son los de producción. Seed `minimal`: basta con datos personales para que salga el alert.
    func testAfterAnAdoptExit_cancelReturnsToTheChooser_notIntoTheApp() throws {
        let app = XCUIApplication()
        app.launchForUITest(reset: true, skipOnboarding: false, seed: "minimal", welcomeAfterAdoptExit: true)

        // El seam abre el Welcome directamente en la elección, como el `onBack` de un adopt.
        let newBranch = app.buttons["welcome_chooser_new"]
        XCTAssertTrue(newBranch.waitForExistence(timeout: 60), "El Welcome de vuelta de un adopt no apareció en la elección.")
        newBranch.tap()

        let cancelButton = app.alerts.buttons.element(boundBy: 1)
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 10),
                      "No apareció «¿Borrar todo y continuar?» — ¿el seed dejó de producir datos personales?")
        cancelButton.tap()

        XCTAssertTrue(app.buttons["welcome_chooser_new"].waitForExistence(timeout: 10), """
            Tras salir de un adopt, «Cancelar» no volvió a la elección privado/nube: la persona aterrizó dentro de la app. \
            Con el onboarding ya completo, la guarda vieja (`if !hasCompletedOnboarding`) no reabría el Welcome.
            """)
        XCTAssertTrue(app.buttons["welcome_chooser_restore"].exists, "La elección volvió a medias: falta «Ya tengo una cuenta».")
    }

    /// El «OK» del aviso de que el borrado falló, en el mismo estado. `-uitest-fail-wipe` hace lanzar el borrado antes
    /// de tocar nada, así que el aviso sale y los datos siguen ahí: volver a la elección es lo único honesto.
    func testAfterAnAdoptExit_failedWipeOKReturnsToTheChooser_notIntoTheApp() throws {
        let app = XCUIApplication()
        app.launchForUITest(reset: true, skipOnboarding: false, seed: "minimal", welcomeAfterAdoptExit: true,
                            extraArguments: ["-uitest-fail-wipe"])

        let newBranch = app.buttons["welcome_chooser_new"]
        XCTAssertTrue(newBranch.waitForExistence(timeout: 60), "El Welcome de vuelta de un adopt no apareció en la elección.")
        newBranch.tap()

        let confirm = app.alerts.buttons.element(boundBy: 0)
        XCTAssertTrue(confirm.waitForExistence(timeout: 10), "No apareció «¿Borrar todo y continuar?».")
        confirm.tap()

        // Control positivo del montaje: el aviso de fallo tiene que salir, o el «OK» no prueba nada.
        let ok = app.alerts.buttons.element(boundBy: 0)
        XCTAssertTrue(ok.waitForExistence(timeout: 10), "No apareció el aviso de que el borrado falló.")
        XCTAssertEqual(app.alerts.buttons.count, 1, "El aviso de fallo tiene un único botón; esto es otro alert.")
        ok.tap()

        XCTAssertTrue(app.buttons["welcome_chooser_new"].waitForExistence(timeout: 10), """
            Tras salir de un adopt, el «OK» del aviso de fallo no volvió a la elección: la persona aterrizó en la app \
            sobre unos datos que el borrado no llegó a tocar.
            """)
    }
}
