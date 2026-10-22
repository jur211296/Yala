//
//  StorageMigrationAttestUITests.swift
//  YalaUITests
//
//  **Sin App Attest, Ajustes no ofrece la nube** (ticket `cloud-migration-offers-the-cloud-to-a-phone-without-app-attest`).
//  La card de «¿Dónde viven tus datos?» —«Migrar a la nube» o «Activar la nube en este dispositivo»— cuelga de
//  `StorageRowGateLogic.offersCloudMigrationEntry`, que desde el 2026-09-16 pide además App Attest.
//
//  Lo que esta suite prueba y la tabla unitaria no: que la pantalla de verdad lee la capacidad. El simulador no tiene App
//  Attest y ningún scheme compartido pone `YALA_DEV_SHARED_SECRET`, así que el caso sin seam es la CONDICIÓN con el
//  predicado real (`.claude/rules/testing.md`: el test de la condición corre sin el seam). El caso con
//  `-uitest-fake-attest-support` es el que demuestra que la misma consulta encuentra la card cuando la puerta está
//  abierta: sin él, el negativo no discrimina nada.
//
//  **Scheme `Yala Dev`, como el gate y el CI** (`testing.md`, «¿Dónde viven tus datos?»): con `Yala`,
//  `cloudModeEnabled` vale `false` bajo `-uitest` —el kill puesto—, con seed `minimal` la fila no existe y los dos casos
//  caen en `openStorageScreen`, con ruido y no en verde.
//  La cara «Activar la nube en este dispositivo» necesita el marcador de un líder en el mirror y no tiene seam: comparte
//  el mismo `if`, así que la cubren la tabla y los scans.
//

import XCTest

final class StorageMigrationAttestUITests: XCTestCase {
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

    /// Abre «¿Dónde viven tus datos?» y espera a que el `case .idle` entero esté montado. Las dos presencias juntas lo
    /// prueban: la tarjeta de estado solo sale en `.idle` y `.cloudActive`, y el botón de asociar de Grupos solo con sesión
    /// privada y sin cuenta de grupos (`GroupsAssociationLogic.offersAssociate`), nunca en la nube. La sección va en ese
    /// `case` justo encima de la card, así que cuando las dos existen el `if` de la card ya se evaluó.
    private func openStorageScreen(_ app: XCUIApplication) {
        let row = scrollTo(app, "storage_settings_row")
        XCTAssertTrue(row.waitForExistence(timeout: 5), """
            No aparece la fila «¿Dónde viven tus datos?» en Ajustes. Si la corrida usa el scheme `Yala`, es el kill de la \
            nube bajo `-uitest` y no este cambio: estos casos van con `Yala Dev`.
            """)
        row.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["storage_status_card"].waitForExistence(timeout: 5),
            "La pantalla de almacenamiento no montó.")
        XCTAssertTrue(
            app.descendants(matching: .any)["storage_groups_associate_button"].waitForExistence(timeout: 5), """
            No apareció «Asociar una cuenta para grupos». Con la tarjeta de estado ya en pantalla, o la pantalla no está \
            en `.idle` o la sección de Grupos no se montó: sin eso, la ausencia de la card no demuestra nada.
            """)
    }

    private func migrateCard(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["storage_migrate_button"]
    }

    /// La CONDICIÓN, sin el seam: el simulador no tiene App Attest y todo lo demás está abierto (nube encendida en
    /// `Yala Dev`, sesión privada en iCloud, nada en vuelo), así que lo único que puede esconder la card es el attest.
    func test_withoutAppAttest_storageDoesNotOfferTheCloud() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap no completó.")
        app.openProfile()
        openStorageScreen(app)

        XCTAssertFalse(migrateCard(app).exists, """
            Sin App Attest, Ajustes ofrece la card de la nube. Este teléfono crearía la cuenta en el servidor y no \
            subiría nada: la migración se reintenta sin fin.
            """)
    }

    /// El gemelo que hace discriminante al de arriba: con la capacidad fingida, la MISMA consulta, en el mismo momento,
    /// encuentra la card. Si este cae, el negativo no está probando nada.
    func test_withAppAttest_storageOffersTheCloud() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal", fakeAttestSupport: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap no completó.")
        app.openProfile()
        openStorageScreen(app)

        let card = migrateCard(app)
        XCTAssertTrue(card.exists, """
            Con App Attest, Ajustes no ofrece «Migrar a la nube». Si esto pasa en un iPhone de verdad, la nube desaparece \
            para todo el que tiene sus datos en iCloud.
            """)
        XCTAssertTrue(card.isEnabled, "La card de la nube sale, pero con el botón deshabilitado: nadie puede migrar.")
    }
}
