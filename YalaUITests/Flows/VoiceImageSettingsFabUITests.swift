//
//  VoiceImageSettingsFabUITests.swift
//  YalaUITests
//
//  Cobertura XCUITest de la parte DETERMINISTA de `voice-settings-fab` (17.4-17.9)
//  e `image-settings-fab` (18.6-18.7):
//   - El selector de idioma de voz (Menu en PersonalizationSettings) cambia el valor.
//   - El menú del FAB ofrece las opciones de voz / imagen / manual.
//  NOTA: los escenarios de toggle "Entrada por voz/imagen con IA" (17.1-17.3 /
//  18.1-18.4) están OBSOLETOS — la voz/imagen pasaron de opt-in a feature Pro
//  (el FAB las muestra con ProBadge si free). La grabación / PhotosPicker / OCR /
//  permisos del sistema (17.13+ / 18.9+) son no-deterministas y quedan fuera.
//  Lanza free (los controles existen igual; el selector de idioma no está gated).
//  Convenciones: ver CLAUDE.md (sin sleeps, scheme Yala Dev).
//

import XCTest

final class VoiceImageSettingsFabUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Seleccionar un idioma de voz distinto actualiza el selector (el label del
    /// Menu lee `appPreferences.voiceLanguage.displayName`). Se verifica que el
    /// label CAMBIA (cross-locale: no se acopla al texto exacto). El re-render del
    /// binding es asíncrono → esperar el snapshot con predicate.
    func test_voiceLanguageSelectorChangesValue() {
        let app = XCUIApplication()
        app.launchForUITest(pro: false)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        app.openProfile()
        app.openSettingsSection("profile_personalization")

        let menu = app.buttons["voice_language_menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 5), "No apareció el selector de idioma de voz.")
        let initialLabel = menu.label  // default = .system

        menu.tap()  // abre el menú del sistema con las opciones
        let englishOption = app.buttons["voice_language_option_en"]
        XCTAssertTrue(englishOption.waitForExistence(timeout: 5), "No apareció la opción de idioma inglés.")
        englishOption.tap()

        // El selector vuelve a colapsar reflejando el nuevo idioma → el label cambia.
        let changed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label != %@", initialLabel),
            object: menu
        )
        XCTAssertEqual(
            XCTWaiter().wait(for: [changed], timeout: 5),
            .completed,
            "El selector de idioma de voz no reflejó el cambio tras seleccionar inglés."
        )
    }

    /// Con voz/imagen como features (FAB condicional), el menú del FAB ofrece las
    /// 3 entradas: voz, imagen y manual (locked con ProBadge si free, pero existen).
    func test_fabMenuShowsVoiceImageManualOptions() {
        let app = XCUIApplication()
        app.launchForUITest(pro: false)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        // Desde 2026-09-02 el FAB NO está a la vista con el Panel arriba del todo:
        // las acciones viven en la fila del hero (`panel_quick_actions`) y los
        // flotantes sólo entran cuando el scroll se la lleva. Hay que bajar para
        // llegar a ellos — el molde del `scrollTo` de `YalaAccountUITests`.
        let fab = app.buttons["fab_new_transaction"]
        var intentos = 0
        while !fab.isHittable && intentos < 14 {
            app.swipeUp()
            intentos += 1
        }
        XCTAssertTrue(
            fab.waitForExistence(timeout: 10),
            "No apareció el FAB principal tras bajar por el Panel."
        )
        fab.tap()

        XCTAssertTrue(
            app.buttons["fab_voice"].waitForExistence(timeout: 5),
            "El menú del FAB no ofrece la entrada por voz."
        )
        XCTAssertTrue(
            app.buttons["fab_image"].exists,
            "El menú del FAB no ofrece la entrada por imagen."
        )
        XCTAssertTrue(
            app.buttons["fab_manual"].exists,
            "El menú del FAB no ofrece la entrada manual."
        )
    }
}
