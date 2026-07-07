//
//  GroupDetailDeeplinkColdLaunchUITests.swift
//  YalaUITests
//
//  XCUI e2e del fix `ba8513e5`: un deep link `yala://groups/<id>` se PERDÍA en cold
//  launch (llegaba pre-init, se difería al DeferredIntentBuffer y la serialización de
//  `.groupDetail` colapsaba el groupID → intent descartado). El defer→drain lo cubre a
//  nivel lógica `DeferredIntentBufferLogicTests`; esto es el e2e de UI del cold launch.
//
//  Patrón de 2 launches (el store `-uitest` persiste en disco):
//   1. Sembrar `grupos` → se persiste "Viaje a Cusco" + su `SplitGroup.id` en
//      `uitest.seededGroupID`. Terminar la app.
//   2. Relanzar SIN reset ni seed con `-uitest-deeplink-url yala://groups/seeded-first`:
//      el hook resuelve `seeded-first` al id persistido y lo inyecta PRE-init por
//      `handleIncomingURL` → defer real → drain (bootstrap paso 20) → ruta al detalle.
//

import XCTest

final class GroupDetailDeeplinkColdLaunchUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_groupDeepLink_survivesColdLaunch_routesToDetail() {
        let app = XCUIApplication()

        // Launch 1: sembrar grupos (persiste el store en disco + el id del 1er grupo en
        // `uitest.seededGroupID`). `waitForUITestReady` confirma que bootstrap+seed
        // completaron; no verificamos `group_card` aquí porque el landing es el Panel (no
        // la tab de grupos) — la prueba real del seed+ruteo es el Launch 2 de abajo.
        app.launchForUITest(pro: true, seed: "grupos")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — el seed de grupos no completó.")
        app.terminate()

        // Launch 2: cold launch SIN reset ni seed (conserva los datos) + deep link con token.
        app.launchForUITest(reset: false, pro: true, seed: nil, deeplinkURL: "yala://groups/seeded-first")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente en el relanzamiento (cold launch).")

        // El detalle se abre tras el drain (post-ready). `group_members_button` (toolbar) es
        // DETAIL-ONLY → prueba inequívoca de que ruteó al DETALLE y no quedó en la LISTA de
        // grupos (que también muestra `group_header_balance` vía el resumen global → ambiguo).
        let membersButton = app.descendants(matching: .any).matching(identifier: "group_members_button").firstMatch
        XCTAssertTrue(
            membersButton.waitForExistence(timeout: 20),
            "El deep link en cold launch NO ruteó al detalle del grupo (group_members_button ausente)."
        )

        // Corrobora que la banda de balance del detalle renderizó (default tab = registros).
        XCTAssertTrue(
            app.descendants(matching: .any).matching(identifier: "group_header_balance").firstMatch.waitForExistence(timeout: 5),
            "El detalle del grupo no renderizó la banda de balance (group_header_balance)."
        )
    }
}
