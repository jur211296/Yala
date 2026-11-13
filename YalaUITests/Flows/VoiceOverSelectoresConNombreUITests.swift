//
//  VoiceOverSelectoresConNombreUITests.swift
//  YalaUITests
//
//  Card «VoiceOver: cinco selectores sin nombre fuera de Planificación» (2.3). Lo que VoiceOver lee de un control es
//  su etiqueta de accesibilidad: aquí se mira en el árbol real, no en el código. El resto de los cinco lo fija el
//  source-scan de `VoiceOverSelectoresConNombreTests` (sus pantallas piden sesión de nube o datos que el seed
//  `minimal` no trae).
//

import XCTest

final class VoiceOverSelectoresConNombreUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Estadísticas → chip Registros (revelando el chip si queda fuera de vista). Molde: `AdvancedFiltersUITests`.
    private func openRecords(_ app: XCUIApplication) {
        app.selectTab(.statistics)
        let recordsChip = app.buttons["detail_chip_registros"]
        XCTAssertTrue(recordsChip.waitForExistence(timeout: 10), "No apareció el chip Registros.")
        let chipsBar = app.scrollViews.containing(.button, identifier: "detail_chip_insights").firstMatch
        if chipsBar.exists {
            chipsBar.swipeLeft()
        }
        recordsChip.tap()
    }

    /// El segmentado «Mostrar solo / Ocultar» de los filtros se llama «Modo del filtro» (idioma fijado por
    /// `launchForUITest`). Con `Picker("")` la etiqueta salía vacía y VoiceOver leía solo el segmento.
    func test_filtrosDeRegistros_elSelectorDeModoTieneNombre() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        openRecords(app)
        app.openRecordsFilters()

        let picker = app.segmentedControls["filters_include_exclude_picker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5), "No se montó el selector Mostrar solo / Ocultar.")
        XCTAssertEqual(picker.label, "Modo del filtro", "VoiceOver no lee el nombre del selector de modo.")
        // Lo de dentro no cambia: los dos segmentos siguen ahí y con su texto.
        XCTAssertEqual(picker.buttons.count, 2, "El selector perdió segmentos.")
    }
}
