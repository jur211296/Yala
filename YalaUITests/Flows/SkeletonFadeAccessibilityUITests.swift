//
//  SkeletonFadeAccessibilityUITests.swift
//  YalaUITests
//
//  Card C1 (fluidez, 2026-11-01): el esqueleto se funde con los datos sin duplicar botones. Mientras dura el fundido
//  conviven dos copias de la pantalla, y un XCUITest que toque justo entonces caería con «varios elementos» si las dos
//  estuvieran en el árbol de accesibilidad (lo que retiró el primer intento, card pjum).
//
//  A 0,25 s el fundido es más corto que una consulta de XCUITest, así que se alarga con
//  `-uitest-skeleton-fade-seconds` (solo cambia cuánto dura) y se miran los identificadores del Panel a mitad.
//
//  Medido al escribirlo (2026-11-01, iOS 27.0): con el fundido alargado a 20 s el esqueleto se ve encima de los datos en
//  la captura, y el árbol no tiene duplicados. **Este caso no discrimina la salida oculta**: siguió verde con dos
//  mutantes, sin el `accessibilityHidden` de `LoadingExitTransition` y con las dos copias montadas a la vez por
//  opacidad. En los dos, ningún identificador del esqueleto salió en el árbol (inferido: la copia con
//  `.redacted(reason: .placeholder)` no se expone). Lo que fija es el criterio de la card —el Panel, a mitad del
//  fundido, con un solo elemento por identificador y «Nuevo» respondiendo— y se pondrá rojo si un cambio expone el
//  esqueleto (quitarle la redacción, otro molde de carga).
//

import XCTest

final class SkeletonFadeAccessibilityUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Los identificadores del Panel que salen más de una vez. Las filas de una lista (`…_row`) se repiten a propósito.
    private func duplicatedPanelIdentifiers(in app: XCUIApplication) -> [String] {
        let ids = app.descendants(matching: .any).allElementsBoundByIndex
            .map(\.identifier)
            .filter { $0.hasPrefix("panel_") && !$0.hasSuffix("_row") }
        var counts: [String: Int] = [:]
        for id in ids { counts[id, default: 0] += 1 }
        return counts.filter { $0.value > 1 }.map { "\($0.key) ×\($0.value)" }.sorted()
    }

    /// El Panel: mientras el esqueleto se funde, ningún botón ni sección sale dos veces, y «Nuevo» responde.
    func test_panel_skeletonFade_keepsOneCopyOfEachElement() {
        let app = XCUIApplication()
        app.launchForUITest(extraArguments: ["-uitest-skeleton-fade-seconds", "20"])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        let newRecord = app.buttons["panel_action_new"]
        XCTAssertTrue(newRecord.waitForExistence(timeout: 10), "No apareció la fila de acciones del Panel.")
        for _ in 0..<3 {
            let duplicated = duplicatedPanelIdentifiers(in: app)
            XCTAssertTrue(duplicated.isEmpty, "Durante el fundido del esqueleto hay elementos duplicados: \(duplicated).")
        }

        // A mitad del fundido, «Nuevo» es uno solo y abre el formulario.
        newRecord.tap()
        XCTAssertTrue(app.textFields["new_transaction_amount"].waitForExistence(timeout: 5),
                      "Tocar «Nuevo» a mitad del fundido no abrió el formulario.")
    }
}
