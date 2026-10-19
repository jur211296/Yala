//
//  ColdStartICloudUnavailableUITests.swift
//  YalaUITests
//
//  **Con iCloud Drive apagado ANTES de abrir Yala, la app avisa en vez de arrancar vacía y muda** (card
//  `tablero-con-icloud-drive-apagado-antes-de-abrir-n5zw`, QA guiado del 19-oct, prueba A · i1o5).
//
//  Medido en el iPhone de QA: con Yala cerrada al apagar Drive, iOS vacía la copia local antes de que la app mida
//  nada, así que no hay caída de las filas, no arranca la gracia de cinco segundos y no salía ningún aviso. Desde
//  este ticket el ARRANQUE pide el aviso de «iCloud no está disponible» por su cuenta.
//
//  **El seam `-uitest-cold-start-icloud-check` habilita al PRODUCTOR, no fuerza la decisión.** El simulador nunca
//  tiene token de iCloud, así que sin él el chequeo en frío dispararía en todos los XCUITest que arrancan sin seed y
//  con el onboarding hecho; bajo `-uitest` está apagado salvo con el seam. Con él puesto, lo que decide es lo de
//  producción: el eje de sesión, la medida del store, el onboarding, la cuenta de iCloud, la cola y el drenaje.
//  Por eso los controles corren CON el seam: la ausencia del aviso la decide la lógica, no la falta del seam.
//
//  La sesión de la nube no tiene seam en XCUITest (nada pone `storageMode = .cloud` bajo `-uitest`): esa celda la fija
//  `RemoteWipeGraceLogicTests` con el predicado real. Aquí el control de sesión es la solo-grupos, que tampoco obedece.
//

import XCTest

final class ColdStartICloudUnavailableUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// El aviso es nativo y su copy viaja en 16 idiomas: se distingue por su número de botones (uno, «Entendido»,
    /// contra los dos del de borrado), igual que en `RemoteWipeNoticeRoutingUITests`.
    private func notice(in app: XCUIApplication) -> XCUIElement {
        app.alerts.firstMatch
    }

    /// Cuánto se espera para afirmar que NO sale: el caso positivo lo ve en ~10 s (splash + arranque + drenaje), y
    /// 20 s cubren eso con margen sin alargar la suite.
    private let absenceWindow: TimeInterval = 20

    private func assertNoNotice(in app: XCUIApplication, _ message: String,
                                file: StaticString = #filePath, line: UInt = #line) {
        let appears = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true"),
                                                object: notice(in: app))
        XCTAssertEqual(XCTWaiter().wait(for: [appears], timeout: absenceWindow), .timedOut, message,
                       file: file, line: line)
    }

    // MARK: - El caso de la card

    /// Store vacío, onboarding hecho, sesión privada con iCloud y el simulador sin token de iCloud: lo mismo que ve un
    /// iPhone que arranca con Drive apagado. Sale «iCloud no está disponible en este dispositivo» con «Entendido», sin
    /// «Empezar de cero», y al contestarlo la persona se queda en su app.
    func test_coldStart_withoutICloud_andAnEmptyStore_saysICloudIsUnavailable_andOffersNoWipe() {
        let app = XCUIApplication()
        app.launchForUITest(seed: nil, coldStartICloudCheck: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap no completó.")

        let alert = notice(in: app)
        XCTAssertTrue(alert.waitForExistence(timeout: 30), """
            La app arrancó vacía y sin aviso con iCloud no disponible: el arranque en frío no pidió \
            «iCloud no está disponible». Mira `requestColdStartICloudNoticeIfNeeded` en `ContentView`.
            """)
        XCTAssertEqual(alert.buttons.count, 1, """
            El aviso del arranque trae más de un botón: es el de «tus datos fueron eliminados de iCloud», con su \
            «Empezar de cero», sobre unos datos que siguen en iCloud.
            """)

        alert.buttons.element(boundBy: 0).tap()   // «Entendido»

        XCTAssertFalse(alert.waitForExistence(timeout: 3), "El aviso no se cerró al pulsar «Entendido».")
        XCTAssertFalse(app.buttons["welcome_hero_cta"].exists, "«Entendido» mandó a la persona al Welcome.")
        XCTAssertTrue(app.buttons["panel_inbox_button"].waitForExistence(timeout: 10),
                      "El Panel no quedó accesible tras cerrar el aviso.")
        // Y no vuelve en esta sesión: la petición del arranque es UNA.
        assertNoNotice(in: app, "El aviso del arranque volvió a salir tras contestarlo.")
    }

    // MARK: - Controles: el estado en que NO debe salir

    /// Con iCloud disponible el store vacío puede ser la importación que trae los datos: el arranque no afirma nada, y
    /// sobre todo no sale el aviso de borrado.
    func test_coldStart_withICloudAvailable_showsNoNotice() {
        let app = XCUIApplication()
        app.launchForUITest(seed: nil, fakeICloud: true, coldStartICloudCheck: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap no completó.")
        assertNoNotice(in: app, """
            Con iCloud disponible el arranque enseñó un aviso sobre un store vacío. Si trae dos botones, es «tus datos \
            fueron eliminados» en un arranque en el que nadie borró nada.
            """)
        XCTAssertTrue(app.buttons["panel_inbox_button"].exists, "La shell no está montada.")
    }

    /// Con datos en el store no hay nada que explicar.
    func test_coldStart_withDataInTheStore_showsNoNotice() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal", coldStartICloudCheck: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap no completó.")
        assertNoNotice(in: app, "Con datos en el store el arranque enseñó el aviso de iCloud no disponible.")
    }

    /// Sin onboarding la persona está en el Welcome, y el aviso estorbaría ahí.
    func test_coldStart_withoutOnboarding_showsNoNotice() {
        let app = XCUIApplication()
        app.launchForUITest(skipOnboarding: false, seed: nil, coldStartICloudCheck: true)
        // `uitest_ready` vive en la raíz de ContentView, que el cover del Welcome tapa: se espera el Hero directamente
        // (patrón de `WelcomeChooserUITests`).
        XCTAssertTrue(app.buttons["welcome_hero_cta"].waitForExistence(timeout: 60),
                      "Sin onboarding la app no arrancó en el Welcome: el control no mide lo que dice.")
        assertNoNotice(in: app, "Sin onboarding el arranque enseñó el aviso de iCloud encima del Welcome.")
    }

    /// Una sesión solo-grupos no guarda sus datos en el iCloud del Apple ID del teléfono: el aviso no es para ella.
    func test_coldStart_inAGroupsOnlySession_showsNoNotice() {
        let app = XCUIApplication()
        app.launchForUITest(seed: nil, groupInvite: true, coldStartICloudCheck: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap no completó.")
        assertNoNotice(in: app, "En una sesión solo-grupos el arranque enseñó el aviso de iCloud del Apple ID.")
    }
}
