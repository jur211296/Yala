//
//  GroupsEmptyStateUITests.swift
//  YalaUITests
//
//  Cobertura XCUITest del "Problema-1" del hardening de grupos (spinner vs empty state en
//  cold launch, commits 063f6aff/5b0e9b1c): tras la primera carga, un usuario SIN grupos ve
//  el empty state — NO se queda atascado en el spinner. Modo solo-grupos (`-uitest-group-invite`)
//  sin seed de grupos: arranca en el tab Grupos, vacío. No requiere iCloud (flags locales).
//  El coalescing del debounce y el dismiss remoto son cross-device (device/TestFlight).
//  Convenciones: ver CLAUDE.md (sin sleeps, scheme Yala Dev, a11y ids).
//

import XCTest

final class GroupsEmptyStateUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_noGroups_showsEmptyState_notStuckSpinner() {
        let app = XCUIApplication()
        // Solo grupos + sin seed de grupos → el tab Grupos monta vacío.
        app.launchForUITest(seed: nil, groupInvite: true)

        // El empty state aparece tras la primera carga (hasLoadedOnce) → confirma que NO se
        // queda atascado en `groups_loading_spinner`. Timeout generoso por el bootstrap.
        // El id `groups_empty_state` lo comparten el botón "Crear grupo" y los textos de
        // YalaEmptyState → consultar por cualquier tipo de descendiente.
        let empty = app.descendants(matching: .any)["groups_empty_state"].firstMatch
        XCTAssertTrue(
            empty.waitForExistence(timeout: 30),
            "No apareció groups_empty_state — la vista de Grupos pudo quedar atascada en el spinner."
        )
        // Y el spinner ya no está presente (se resolvió a empty).
        XCTAssertFalse(
            app.activityIndicators["groups_loading_spinner"].exists,
            "El spinner de carga sigue visible tras cargar (debería haberse resuelto al empty state)."
        )
    }
}
