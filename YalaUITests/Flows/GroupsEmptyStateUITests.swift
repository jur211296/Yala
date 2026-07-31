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
//  DOS RAMAS desde el flip compilado `5490544d`. Con `groupsBackendEnabled` ON —lo que ocurre en
//  TODO XCUITest bajo `Yala Dev`, porque el default-ausente de remote-config es ON— la lista vacía
//  ya no tiene un solo aspecto: `GroupsEmptyStateLogic.decide(flagOn:hasSession:)` pinta el empty
//  state ESTÁNDAR ("aún no tienes grupos", CTA crear) solo CON sesión de nube, y el de RE-ENTRADA
//  ("tus grupos están en tu cuenta", CTA iniciar sesión) sin ella. El simulador nunca tiene sesión,
//  así que el caso estándar la finge con `-uitest-fake-cloud-session` y el de re-entrada se lanza
//  SIN el arg: ahí el estado por defecto YA ES el caso bajo prueba. Un test por rama, aserciones
//  sin relajar.
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
        app.launchForUITest(seed: nil, groupInvite: true, cloudSession: true)

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

    /// Rama de RE-ENTRADA (H-2026-07-18-7) — cobertura NUEVA: nadie afirmaba hasta ahora el
    /// comportamiento que introdujo el encendido del canal de Grupos. SIN sesión de nube el tab no
    /// ofrece "crear grupo" sino "inicia sesión para ver tus grupos"
    /// (`GroupsEmptyStateLogic.decide(flagOn: true, hasSession: false)` → `.signInToView`).
    ///
    /// Se lanza a propósito SIN `-uitest-fake-cloud-session`: el simulador no tiene sesión de nube
    /// jamás, así que el estado por defecto ES el caso bajo prueba. Este test DEPENDE de que el canal
    /// esté encendido: si `groupsBackendCompiledDefault` volviera a `false`, `decide` daría `.standard`
    /// y esto se pondría rojo. Eso es deseado —es el tripwire del flip—, no un flake.
    ///
    /// El tap del CTA queda fuera a propósito: presentar el sign-in pasa por `RouterEntryGate` y el
    /// anchor de `ContentView` (peek-first), que es una pieza móvil más y no lo que este caso afirma.
    func test_noGroups_withoutSession_showsSignInEmptyState() {
        let app = XCUIApplication()
        app.launchForUITest(seed: nil, groupInvite: true)

        // El id lo lleva el `YalaEmptyState` entero y lo heredan sus textos (el botón tiene el suyo),
        // así que se consulta por cualquier tipo de descendiente — igual que el caso estándar.
        let signedOut = app.descendants(matching: .any)["groups_empty_state_signin"].firstMatch
        XCTAssertTrue(
            signedOut.waitForExistence(timeout: 30),
            "Con el canal de Grupos ON y sin sesión, el tab debe pedir iniciar sesión (groups_empty_state_signin)."
        )
        // Y hay un BOTÓN de acción, no solo el texto: la oferta de iniciar sesión es accionable.
        // Se targetea por `groups_empty_state_signin` y NO por `groups_empty_signin_cta` —el id que
        // `YalaEmptyState.groupsSignedOut` le pone al botón— porque ese id no sobrevive en runtime:
        // el `.accessibilityIdentifier` que `GroupsContainerView` aplica al YalaEmptyState ENTERO se
        // propaga a los descendientes y lo pisa. Medido con un snapshot del árbol de accesibilidad
        // (2026-07-31): el botón real es `button|Iniciar sesión|groups_empty_state_signin`.
        XCTAssertTrue(
            app.buttons["groups_empty_state_signin"].exists,
            "El empty state de re-entrada montó sin un botón accionable para iniciar sesión."
        )
        // Y NO se ofrece el empty state estándar: sin sesión, "crear grupo" no es una oferta honesta.
        XCTAssertFalse(
            app.descendants(matching: .any)["groups_empty_state"].firstMatch.exists,
            "Sin sesión no debe ofrecerse el empty state estándar de crear grupo."
        )
        XCTAssertFalse(
            app.activityIndicators["groups_loading_spinner"].exists,
            "El spinner de carga sigue visible tras cargar (debería haberse resuelto al empty state)."
        )
    }
}
