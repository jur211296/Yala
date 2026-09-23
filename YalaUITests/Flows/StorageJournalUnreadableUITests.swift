//
//  StorageJournalUnreadableUITests.swift
//  YalaUITests
//
//  **Con el registro de la migración ilegible, «¿Dónde viven tus datos?» lo dice y no ofrece moverlos** (ticket
//  `an-unreadable-migration-journal-reads-as-never-started`). Hasta ese ticket, un fetch del journal que lanzaba se
//  pintaba como `.idle` —la pantalla de «nunca empezó», con «Migrar a la nube»— y borraba el motivo de la última parada.
//
//  El seam `-uitest-migration-journal-unreadable` hace lanzar el fetch del controller: finge la ENTRADA, y lo que se pinta
//  lo sigue decidiendo `CloudMigrationUIStateDeriver`. El caso sin seam es el control que hace discriminante al primero: la
//  misma navegación encuentra la pantalla de siempre.
//
//  **Scheme `Yala Dev`**, como sus vecinas (`StorageMigrationAttestUITests`): con `Yala` la fila no existe bajo `-uitest`.
//

import XCTest

final class StorageJournalUnreadableUITests: XCTestCase {
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

    private func openStorageRow(_ app: XCUIApplication) {
        let row = scrollTo(app, "storage_settings_row")
        XCTAssertTrue(row.waitForExistence(timeout: 5), """
            No aparece la fila «¿Dónde viven tus datos?» en Ajustes. Si la corrida usa el scheme `Yala`, es el kill de la \
            nube bajo `-uitest` y no este cambio: estos casos van con `Yala Dev`.
            """)
        row.tap()
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    /// El caso del ticket: la tarjeta honesta, sin la de estado ni la de migrar, y con la sección de Grupos (que puede
    /// durar, y es la única puerta para soltar esa cuenta).
    func test_unreadableJournal_saysSoAndOffersNothingThatMovesData() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal", fakeAttestSupport: true, migrationJournalUnreadable: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap no completó.")
        app.openProfile()
        openStorageRow(app)

        XCTAssertTrue(element(app, "storage_journal_unreadable_card").waitForExistence(timeout: 5), """
            Con el registro de la migración ilegible, la pantalla no dice que no pudo leerlo. Antes de este ticket pintaba \
            «nunca empezó».
            """)
        // Presencia que discrimina las ausencias de abajo: la sección de Grupos está montada en el mismo `case`.
        XCTAssertTrue(element(app, "storage_groups_associate_button").waitForExistence(timeout: 5),
                      "La sección de Grupos desapareció con el journal ilegible: no quedaría puerta para soltar esa cuenta.")
        XCTAssertFalse(element(app, "storage_migrate_button").exists,
                       "Con el journal ilegible se ofrece «Migrar a la nube»: se decidiría con una fase que no se leyó.")
        XCTAssertFalse(element(app, "storage_status_card").exists,
                       "Con el journal ilegible se pinta la pantalla de «nunca empezó».")
    }

    /// Control: sin el seam, la misma navegación encuentra la pantalla de siempre y ninguna tarjeta de «no pude leer».
    func test_control_readableJournal_showsTheUsualScreen() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal", fakeAttestSupport: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap no completó.")
        app.openProfile()
        openStorageRow(app)

        XCTAssertTrue(element(app, "storage_status_card").waitForExistence(timeout: 5), "La pantalla de almacenamiento no montó.")
        XCTAssertTrue(element(app, "storage_migrate_button").waitForExistence(timeout: 5),
                      "Sin el seam y con App Attest fingido, «Migrar a la nube» tiene que salir: si no, el positivo no discrimina.")
        XCTAssertFalse(element(app, "storage_journal_unreadable_card").exists,
                       "Con el journal legible sale la tarjeta de «no pudimos comprobar».")
    }
}
