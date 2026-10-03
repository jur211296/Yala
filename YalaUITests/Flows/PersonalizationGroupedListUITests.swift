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

    /// Los ajustes de Personalización, de arriba abajo. Free: la fila «Pregúntale a Yala» solo existe sin
    /// Pro. «Idioma de la app» no está: solo aparece con un idioma forzado.
    private let expectedRows = [
        "personalization_row_expenses_only",
        "voice_language_menu",
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

        let firstRow = app.switches["personalization_row_expenses_only"]
        XCTAssertTrue(firstRow.waitForExistence(timeout: 10), "No apareció la fila «Solo gastos».")

        // Una `List` de SwiftUI es un UICollectionView: la fila tiene que colgar de uno.
        let inList = app.collectionViews.switches["personalization_row_expenses_only"]
        XCTAssertTrue(
            inList.exists,
            "La fila «Solo gastos» no cuelga de una lista del sistema: Personalización volvió a un ScrollView."
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
