//
//  ForeignCurrencyAccountSeedUITests.swift
//  YalaUITests
//
//  El CABLEADO del seam `-uitest-seed-foreign-account <ISO>`: que el launch argument llegue de
//  verdad hasta el store. Área `settings-currency-exchange`.
//
//  **Por qué hace falta un XCUITest si el fixture ya tiene ocho unit tests.** Aquellos prueban que
//  `DevSeedForeignCurrencyAccount.create` deja las filas bien marcadas, llamándolo directamente. Lo
//  que ninguno puede ver es el tramo que va del argumento a esa llamada —`UITestHooks`
//  → `AppBootstrapper.applyUITestSeed` → `DevSeedService`—, y ese tramo es el que rompe en silencio:
//  un arg que deja de leerse no da error, da un corpus sin filas aproximadas. Los siete tickets de
//  FX que dependen de este montaje leerían entonces «no aparece el ≈» como un veredicto sobre la
//  app, cuando sería un veredicto sobre el seam.
//
//  Los dos casos van en pareja a propósito: el positivo solo, con un seam que sembrara siempre,
//  pasaría igual. Convenciones: ver CLAUDE.md (sin sleeps, scheme Yala Dev).
//

import XCTest

final class ForeignCurrencyAccountSeedUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// El nombre de la cuenta que siembra el fixture. Literal a propósito y sin localizar
    /// (`DevSeedForeignCurrencyAccount.accountName`): el target de UI tests no importa `Yala`.
    private let seededAccountName = "QA FX"

    /// Con el arg: la cuenta existe, y en la divisa pedida.
    func test_foreignAccountArgument_seedsTheAccount() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal", foreignAccount: "JPY")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        app.openProfile()
        app.openSettingsSection("profile_accounts")

        let row = app.buttons["accounts_row_\(seededAccountName)"]
        XCTAssertTrue(row.waitForExistence(timeout: 10), """
            No se sembró la cuenta «\(seededAccountName)» con `-uitest-seed-foreign-account JPY`. \
            El fixture tiene sus propios unit tests, así que lo que este rojo señala es el CABLEADO: \
            UITestHooks.foreignAccountCurrency → AppBootstrapper.applyUITestSeed → DevSeedService.
            """)
    }

    /// Sin el arg: la cuenta NO existe.
    ///
    /// Es lo que hace informativo al caso de arriba, y además protege el control negativo del que
    /// dependen los tickets de FX: el seam tiene que estar APAGADO por defecto, o sus filas
    /// aproximadas le pondrían «≈» a los totales de toda la suite.
    func test_withoutTheArgument_theAccountIsAbsent() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        app.openProfile()
        app.openSettingsSection("profile_accounts")

        // Se espera a que la lista MONTE antes de afirmar la ausencia: sobre una pantalla que aún
        // no ha cargado, «no está» es cierto por accidente y el test pasaría con el seam encendido.
        let anySeededAccount = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "accounts_row_")
        ).firstMatch
        XCTAssertTrue(anySeededAccount.waitForExistence(timeout: 10), "La lista de cuentas no montó.")

        XCTAssertFalse(
            app.buttons["accounts_row_\(seededAccountName)"].exists,
            "La cuenta «\(seededAccountName)» apareció SIN pedir el seam: entonces está encendido por defecto."
        )
    }
}
