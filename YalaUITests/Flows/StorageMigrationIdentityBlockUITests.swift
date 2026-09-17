//
//  StorageMigrationIdentityBlockUITests.swift
//  YalaUITests
//
//  **«Migrar a la nube» sobre una cuenta que ya tiene datos se para y lo dice** (ticket
//  `settings-migrate-to-cloud-adopts-silently-instead-of-migrating`). Con una sesión de nube viva —la cuenta de sus grupos—
//  la comprobación se adelanta al toque de «Activar la nube», antes del consentimiento y de las dos confirmaciones.
//
//  Qué prueba esta suite y los unit no: que la respuesta asíncrona de la puerta llega a la pantalla —la hoja se presenta
//  desde un `Task`, se cierra, y detrás no se abre nada— y que una cuenta que puede recibir la migración sigue al
//  consentimiento como siempre.
//
//  **Qué NO prueba, y lo dice para que nadie lo lea al revés**: qué cuenta bloquea. El simulador no puede preguntar a
//  `/account/exists` con una sesión real, así que `-uitest-fake-migration-identity` finge la RESPUESTA de la puerta. La
//  decisión la fijan `StorageMigrationIdentityGateLogicTests` y la tabla [I]. `-uitest-fake-cloud-session` es lo que hace que
//  la comprobación vaya al toque: sin sesión, el toque va directo al consentimiento, así que la nota de la cuenta
//  (`storage_account_reuse_note`) se exige antes de tocar.
//
//  La cadena «Usar otra cuenta» → elección de Apple/Google va con `-uitest-pending-migration-block`, que publica el aviso al
//  crear el controller: con la sesión fingida ese botón no sale, a propósito, y sin sesión no se puede firmar en el
//  simulador. También finge la SALIDA, no la decisión.
//
//  **Scheme `Yala Dev`**, como el gate y el CI: con `Yala` la fila «¿Dónde viven tus datos?» no existe bajo `-uitest`
//  (`.claude/rules/testing.md`).
//

import XCTest

final class StorageMigrationIdentityBlockUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Baja por Ajustes hasta que el elemento sea alcanzable. Determinista: tope de intentos, sin sleeps.
    private func scrollTo(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        let element = app.buttons[identifier]
        var tries = 0
        while !element.isHittable && tries < 14 {
            app.swipeUp()
            tries += 1
        }
        return element
    }

    /// Lanza con sesión de nube fingida y App Attest fingido, abre «¿Dónde viven tus datos?» y devuelve «Activar la nube»,
    /// comprobando antes que la tarjeta anuncia la cuenta en uso: es la prueba de que el toque va por la comprobación
    /// adelantada y no directo al consentimiento.
    private func openMigrateCard(fakeMigrationIdentity: String) -> (XCUIApplication, XCUIElement) {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal", cloudSession: true, fakeAttestSupport: true,
                            fakeMigrationIdentity: fakeMigrationIdentity)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap no completó.")
        app.openProfile()

        let row = scrollTo(app, "storage_settings_row")
        XCTAssertTrue(row.waitForExistence(timeout: 5), """
            No aparece la fila «¿Dónde viven tus datos?» en Ajustes. Si la corrida usa el scheme `Yala`, es el kill de la \
            nube bajo `-uitest` y no este cambio: estos casos van con `Yala Dev`.
            """)
        row.tap()

        let migrate = app.descendants(matching: .any)["storage_migrate_button"]
        XCTAssertTrue(migrate.waitForExistence(timeout: 5), "No aparece «Activar la nube».")
        XCTAssertTrue(app.descendants(matching: .any)["storage_account_reuse_note"].waitForExistence(timeout: 5), """
            La tarjeta no anuncia la cuenta en uso: sin sesión viva el toque va directo al consentimiento y este caso no \
            probaría la comprobación adelantada.
            """)
        return (app, migrate)
    }

    /// Cuenta con finanzas personales y la sesión de sus grupos: la hoja sale al tocar, sin consentimiento detrás, solo con
    /// «Entendido» —cambiar de cuenta exige desasociar primero— y al cerrarla la tarjeta sigue ahí.
    func test_liveSession_accountWithPersonalData_blocksBeforeTheConsent() {
        let (app, migrate) = openMigrateCard(fakeMigrationIdentity: "personalData")
        migrate.tap()

        let title = app.staticTexts["storage_migrate_block_title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10), """
            Tocar «Activar la nube» con una cuenta que ya tiene datos no avisa. Es el bug del ticket: el flujo seguiría y la \
            migración acabaría adoptando esa cuenta en silencio.
            """)
        XCTAssertEqual(title.label, "Esa cuenta ya tiene finanzas personales")
        XCTAssertFalse(app.buttons["storage_consent_accept"].exists,
                       "El consentimiento se abrió detrás del aviso: la comprobación no paró el flujo.")
        XCTAssertFalse(app.buttons["storage_migrate_block_use_another"].exists, """
            Con la sesión de sus grupos, la hoja ofrece «Usar otra cuenta», un gesto que exige desasociar primero y que \
            esta pantalla no hace.
            """)

        let close = app.buttons["storage_migrate_block_close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        close.tap()
        XCTAssertTrue(title.waitForNonExistence(timeout: 5), "«Entendido» no cerró la hoja.")
        // `isHittable`, no `exists`: con una hoja arriba la tarjeta sigue en el árbol y `exists` no podía fallar.
        XCTAssertTrue(migrate.waitForHittable(timeout: 5), "Tras cerrar el aviso la tarjeta de migrar no se puede tocar.")
        // Con espera: una segunda hoja pedida en el mismo anchor aparece al cerrarse la primera (`.claude/rules/testing.md`),
        // así que un consentimiento pedido a la vez que el aviso solo se ve AHORA.
        XCTAssertFalse(app.buttons["storage_consent_accept"].waitForExistence(timeout: 3),
                       "Cerrar el aviso abrió el consentimiento: el toque siguió aunque la comprobación dijo que no.")
        XCTAssertFalse(title.waitForExistence(timeout: 2), "El aviso volvió a salir: la hoja no lo soltó al montar.")
    }

    /// El gemelo que hace discriminante al de arriba: con una cuenta que sí puede recibir la migración, el MISMO toque llega
    /// al consentimiento y no enseña ninguna hoja. **No prueba el valor `proceed` del seam**: al toque, «no se pudo
    /// preguntar» también sigue al consentimiento, así que sin el seam pasaría igual. Ese valor lo fija la paridad de
    /// `MigrationIdentityGateWiringTests`; lo que prueba este caso es que solo un bloqueo para el toque.
    func test_liveSession_accountThatCanReceiveTheMigration_goesOnToTheConsent() {
        let (app, migrate) = openMigrateCard(fakeMigrationIdentity: "proceed")
        migrate.tap()

        XCTAssertTrue(app.buttons["storage_consent_accept"].waitForExistence(timeout: 10), """
            Con una cuenta que puede recibir la migración, tocar «Activar la nube» no llegó al consentimiento: la \
            comprobación adelantada rompió el camino de siempre.
            """)
        XCTAssertFalse(app.staticTexts["storage_migrate_block_title"].exists)
    }

    // MARK: - «Usar otra cuenta»

    /// La elección de Apple/Google, venga de donde venga su id: el del contenedor puede pisar el de los botones
    /// (`.claude/rules/testing.md`), y los dos significan lo mismo aquí.
    private func signInChooser(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier IN %@",
            ["storage_signin_chooser", "storage_signin_apple", "storage_signin_google"])).firstMatch
    }

    /// Lanza con el aviso ya publicado y abre «¿Dónde viven tus datos?»: la hoja sale sola al llegar.
    private func openStorageWithPendingBlock(_ value: String) -> (XCUIApplication, XCUIElement) {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal", fakeAttestSupport: true, pendingMigrationBlock: value)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap no completó.")
        app.openProfile()

        let row = scrollTo(app, "storage_settings_row")
        XCTAssertTrue(row.waitForExistence(timeout: 5), """
            No aparece la fila «¿Dónde viven tus datos?» en Ajustes. Si la corrida usa el scheme `Yala`, es el kill de la \
            nube bajo `-uitest` y no este cambio: estos casos van con `Yala Dev`.
            """)
        row.tap()

        let title = app.staticTexts["storage_migrate_block_title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10), """
            El aviso publicado no llegó a la pantalla: la hoja no lo recoge al aparecer (`onChange` con `initial: true`).
            """)
        return (app, title)
    }

    /// Una cuenta rechazada de Apple: la hoja dice que Apple usa la cuenta del dispositivo y ofrece «Usar otra cuenta», que
    /// abre la elección de Apple/Google solo cuando la hoja ya bajó.
    func test_anotherAccount_opensTheSignInChoice_afterTheSheetCloses() {
        let (app, title) = openStorageWithPendingBlock("personalDataApple")

        XCTAssertTrue(app.staticTexts["storage_migrate_block_apple_note"].waitForExistence(timeout: 5), """
            La hoja no avisa de que con Apple se entra siempre con la cuenta del dispositivo: «Usar otra cuenta» → Apple \
            volvería a la misma cuenta rechazada.
            """)
        let chooser = signInChooser(app)
        XCTAssertFalse(chooser.exists, "La elección de Apple/Google ya estaba abierta con el aviso delante.")

        let another = app.buttons["storage_migrate_block_use_another"]
        XCTAssertTrue(another.waitForExistence(timeout: 5), "La hoja no ofrece «Usar otra cuenta».")
        another.tap()

        XCTAssertTrue(title.waitForNonExistence(timeout: 5), "«Usar otra cuenta» no cerró la hoja.")
        XCTAssertTrue(chooser.waitForExistence(timeout: 10), """
            «Usar otra cuenta» cerró la hoja y no abrió la elección de Apple/Google: la persona se queda sin el siguiente paso.
            """)
    }

    /// El gemelo que hace discriminante al de arriba: «Entendido» cierra y nada más. Y sin cuenta de Apple rechazada, la
    /// nota de Apple no sale.
    func test_understood_closesWithoutOpeningTheSignInChoice() {
        let (app, title) = openStorageWithPendingBlock("personalData")

        XCTAssertTrue(app.buttons["storage_migrate_block_use_another"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["storage_migrate_block_apple_note"].exists,
                       "La nota de Apple sale sin que la cuenta rechazada fuera de Apple.")

        let close = app.buttons["storage_migrate_block_close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        close.tap()

        XCTAssertTrue(title.waitForNonExistence(timeout: 5), "«Entendido» no cerró la hoja.")
        XCTAssertFalse(signInChooser(app).waitForExistence(timeout: 3),
                       "«Entendido» abrió la elección de Apple/Google: el gesto de «Usar otra cuenta» se quedó armado.")
        XCTAssertFalse(title.waitForExistence(timeout: 2), "El aviso volvió a salir: la hoja no lo soltó al montar.")
    }
}
