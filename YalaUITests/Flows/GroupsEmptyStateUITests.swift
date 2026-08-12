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
//  CINCO RAMAS desde C2 (eran dos desde el flip compilado `5490544d`). Con `groupsBackendEnabled` ON
//  —lo que ocurre en TODO XCUITest bajo `Yala Dev`, porque el default-ausente de remote-config es ON— la
//  lista vacía dice QUÉ FALTA, con la misma precedencia que usa la puerta:
//
//    educativo sin ver → `groups_empty_state_educational`
//    sin sesión y NUNCA tuvo cuenta → `groups_empty_state_create_account`   ← el caso por DEFECTO del sim
//    sin sesión pero SÍ tuvo → `groups_empty_state_signin`
//    con sesión y sin consent → `groups_empty_state_consent`
//    todo listo → `groups_empty_state`
//
//  El simulador nunca tiene sesión real, así que las ramas con identidad la fingen con
//  `-uitest-fake-cloud-session` (+ `-uitest-groups-consent` donde hace falta pasar el consent), y la de
//  alta se lanza SIN args: ahí el estado por defecto YA ES el caso bajo prueba. Un test por rama,
//  aserciones sin relajar.
//
//  **La rama `.signInToView` NO es ejercitable aquí y no se busque:** exige el latch
//  `GroupsSessionHistoryMarker`, que es monotónico y lo limpia `-uitest-reset` a propósito (si no,
//  contaminaría todas las corridas siguientes). Armarlo pediría dos lanzamientos encadenados con
//  `reset: false`, y eso deja el latch puesto para el resto de la suite — el anti-patrón exacto de
//  `testing.md`. Su cobertura es la tabla de `GroupsEmptyStateLogicTests` + device-qa.
//

import XCTest

final class GroupsEmptyStateUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Rama ESTÁNDAR: con sesión de nube, la lista vacía ofrece crear grupo y el spinner se resolvió.
    func test_noGroups_showsEmptyState_notStuckSpinner() {
        let app = XCUIApplication()
        // Solo grupos + sin seed de grupos → el tab Grupos monta vacío. La sesión FINGIDA es lo que
        // mantiene la rama `.standard`: sin ella, con el canal de Grupos ON, este tab pinta el empty
        // state de re-entrada (ver el test de abajo) y este caso nunca vería `groups_empty_state`.
        // C2 · el consent también hace falta: con sesión pero sin él la rama es `.needsConsent`, no
        // `.standard` — el tab avisa de que queda un paso en vez de ofrecer crear un grupo que el tap no
        // podría crear todavía. Los dos args son ortogonales a propósito (ver `UITestHooks`).
        app.launchForUITest(seed: nil, groupInvite: true, cloudSession: true, groupsConsent: true)

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

    /// **Rama de ALTA (C2), y es la celda del chip.** Sin sesión y sin haber tenido NUNCA una cuenta, el
    /// tab no dice «tus grupos están en tu cuenta» —no hay ninguna cuenta suya, ni ningunos grupos suyos
    /// esperando— sino que hay que CREARLA. Hasta C2 esta población leía el copy de la re-entrada, que le
    /// mentía dos veces.
    ///
    /// Se lanza a propósito SIN `-uitest-fake-cloud-session`: el simulador no tiene sesión de nube jamás y
    /// `-uitest-reset` limpia el latch, así que el estado por defecto ES el caso bajo prueba. Este test
    /// DEPENDE de que el canal esté encendido: si `groupsBackendCompiledDefault` volviera a `false`,
    /// `decide` daría `.standard` y esto se pondría rojo. Eso es deseado —es el tripwire del flip—, no un
    /// flake.
    ///
    /// El tap del CTA queda fuera a propósito: presentar el sign-in pasa por `RouterEntryGate` y el anchor
    /// de `ContentView` (peek-first), que es una pieza móvil más y no lo que este caso afirma.
    func test_noGroups_neverHadAccount_showsCreateAccountEmptyState() {
        let app = XCUIApplication()
        app.launchForUITest(seed: nil, groupInvite: true)

        // El id lo lleva el `YalaEmptyState` entero y lo heredan sus textos (el botón tiene el suyo),
        // así que se consulta por cualquier tipo de descendiente — igual que el caso estándar.
        let createAccount = app.descendants(matching: .any)["groups_empty_state_create_account"].firstMatch
        XCTAssertTrue(
            createAccount.waitForExistence(timeout: 30),
            "Con el canal ON, sin sesión y sin cuenta previa, el tab debe ofrecer CREAR la cuenta."
        )
        // Y hay un BOTÓN de acción, no solo el texto. Se targetea por el id del CONTENEDOR y NO por
        // `groups_empty_create_account_cta` —el que `YalaEmptyState` le pone al botón— porque ese no
        // sobrevive en runtime: el `.accessibilityIdentifier` que `GroupsContainerView` aplica al
        // `YalaEmptyState` ENTERO se propaga a los descendientes y lo pisa (medido 2026-07-31 sobre la
        // rama hermana; la regla completa está en `testing.md`).
        XCTAssertTrue(
            app.buttons["groups_empty_state_create_account"].exists,
            "El empty state de alta montó sin un botón accionable."
        )
        // Y NO se ofrece el estándar ni el de re-entrada: los tres dicen cosas distintas.
        XCTAssertFalse(
            app.descendants(matching: .any)["groups_empty_state"].firstMatch.exists,
            "Sin sesión no debe ofrecerse el empty state estándar de crear grupo."
        )
        XCTAssertFalse(
            app.descendants(matching: .any)["groups_empty_state_signin"].firstMatch.exists,
            "A quien nunca tuvo cuenta no se le dice que sus grupos están en ella."
        )
        XCTAssertFalse(
            app.activityIndicators["groups_loading_spinner"].exists,
            "El spinner de carga sigue visible tras cargar (debería haberse resuelto al empty state)."
        )
    }

    /// **Rama de CONSENT (C2).** Con sesión viva y sin consent, el tap de «crear grupo» acabaría en
    /// `GroupsConsentView`; el empty state lo anuncia en vez de que aparezca como una sorpresa a mitad de
    /// camino. Es la rama que `GroupCreateRoutingLogic` ya devolvía (`.needsConsent`) y que la lista vacía
    /// no reflejaba.
    func test_noGroups_withSessionWithoutConsent_showsConsentEmptyState() {
        let app = XCUIApplication()
        // Sesión SÍ, consent NO: los dos seams son ortogonales justamente para poder montar esta celda.
        app.launchForUITest(seed: nil, groupInvite: true, cloudSession: true)

        let consent = app.descendants(matching: .any)["groups_empty_state_consent"].firstMatch
        XCTAssertTrue(
            consent.waitForExistence(timeout: 30),
            "Con sesión y sin consent, el tab debe anunciar que queda un paso (groups_empty_state_consent)."
        )
        XCTAssertFalse(
            app.descendants(matching: .any)["groups_empty_state"].firstMatch.exists,
            "Sin consent no debe ofrecerse el empty state estándar: el tap no podría crear el grupo."
        )
    }
}
