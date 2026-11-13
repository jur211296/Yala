//
//  PersonalizationGroupedListUITests.swift
//  YalaUITests
//
//  Personalización como lista agrupada del sistema (ticket `settings-redesign-as-grouped-lists-like-ios`):
//  (1) sus filas son celdas de una `List` — un `UICollectionView` en el árbol, no un `ScrollView` con
//  tarjetas sueltas, que es lo que la deja servir luego como columna; (2) el rediseño no pierde ningún
//  ajuste: cada uno sigue alcanzable bajando por la pantalla.
//  Lo que XCUITest no ve —bloques blancos sobre fondo no blanco, la densidad— lo mira el guion de QA
//  del ticket. Convenciones: ver CLAUDE.md (sin sleeps, scheme Yala Dev, targetear por a11y id).
//

import XCTest

final class PersonalizationGroupedListUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Los ajustes de Personalización, de arriba abajo. El interruptor de Yala IA sale con Pro y sin Pro desde UX 2.2
    /// · L14-12, y «Tono de Yala IA» desde L14-10. «Idioma de la app» (sale siempre desde L16-5) se mira aparte.
    /// «Solo gastos» salió con la decisión 48 de 2.3 (vive en «Cómo usas Yala»).
    private let expectedRows = [
        "voice_language_menu",
        "personalization_row_ai_tone",
        "personalization_row_ai_summary",
        "settings_colorful_icons_toggle",
        "personalization_row_chat_fab",
        "personalization_row_default_period",
        "personalization_row_first_weekday",
        "personalization_row_widget_hints",
        "personalization_row_average_line",
        "personalization_row_variations",
        "personalization_row_currency_format",
        "personalization_row_decimals",
        "personalization_row_auto_focus",
    ]

    private func openPersonalization() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(pro: false)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        app.openProfile()
        app.openSettingsSection("profile_personalization")
        return app
    }

    func test_personalization_isASystemGroupedList() {
        let app = openPersonalization()

        let firstRow = app.buttons["personalization_row_app_language"]
        XCTAssertTrue(firstRow.waitForExistence(timeout: 10), "No apareció la fila «Idioma de la app».")

        // Una `List` de SwiftUI es un UICollectionView: la fila tiene que colgar de uno.
        let inList = app.collectionViews.buttons["personalization_row_app_language"]
        XCTAssertTrue(
            inList.exists,
            "La fila «Idioma de la app» no cuelga de una lista del sistema: Personalización volvió a un ScrollView."
        )
    }

    func test_personalization_keepsEverySetting() {
        let app = openPersonalization()

        let list = app.collectionViews.firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 10), "No apareció la lista de Personalización.")

        // La lista monta solo las celdas visibles: se baja hasta encontrar cada una, en orden.
        for id in expectedRows {
            let row = app.descendants(matching: .any)[id]
            var swipes = 0
            while !(row.exists && row.isHittable) && swipes < 8 {
                list.swipeUp()
                swipes += 1
            }
            XCTAssertTrue(row.exists && row.isHittable, "El ajuste «\(id)» ya no se alcanza en Personalización.")
        }
    }
}
