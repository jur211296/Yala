//
//  XCUIApplication+Yala.swift
//  YalaUITests
//
//  Harness base para XCUITests de Yala: lanzar con launch args de uitest y
//  esperar deterministamente a que bootstrap+seed terminen (señal uitest_ready).
//  Convenciones: ver CLAUDE.md (sin sleeps, page-objects, scheme Yala Dev).
//

import XCTest

extension XCUIApplication {
    /// Lanza la app en modo UI-test con los launch args indicados.
    /// Por defecto: estado limpio + onboarding saltado + seed minimal (rápido).
    @discardableResult
    func launchForUITest(
        reset: Bool = true,
        skipOnboarding: Bool = true,
        pro: Bool = false,
        seed: String? = "minimal",
        deeplink: String? = nil,
        deeplinkURL: String? = nil,
        seedDesync: Bool = false,
        onboarding: Bool = false,
        inboxAlert: Bool = false,
        trialOffer: Bool = false,
        forceUpdate: Bool = false,
        aiConsent: Bool = false,
        groupInvite: Bool = false,
        fakeICloud: Bool = false,
        cloudSession: Bool = false,
        groupsConsent: Bool = false,
        groupsEducativo: Bool = false,
        inviteOnboarding: Bool = false,
        joinPhase: String? = nil,
        joinSoftTimeout: String? = nil,
        extraArguments: [String] = []
    ) -> XCUIApplication {
        var args = ["-uitest"]
        if reset { args.append("-uitest-reset") }
        if skipOnboarding { args.append("-uitest-skip-onboarding") }
        if pro { args.append("-uitest-pro") }
        if let seed {
            args.append("-uitest-seed")
            args.append(seed)
        }
        if seedDesync { args.append("-uitest-seed-desync") }
        if let deeplink {
            args.append("-uitest-deeplink")
            args.append(deeplink)
        }
        if let deeplinkURL {
            args.append("-uitest-deeplink-url")
            args.append(deeplinkURL)
        }
        if onboarding { args.append("-uitest-onboarding") }
        if inboxAlert { args.append("-uitest-inbox-alert") }
        if trialOffer { args.append("-uitest-trial-offer") }
        if forceUpdate { args.append("-uitest-force-update") }
        if aiConsent { args.append("-uitest-ai-consent") }
        if groupInvite { args.append("-uitest-group-invite") }
        if fakeICloud { args.append("-uitest-fake-icloud") }
        // Sesión de nube fingida + consent de Grupos aceptado. Son parámetros nombrados y no
        // `extraArguments:` crudo a propósito: `-uitest-fake-cloud-session` es vecino tipográfico de
        // `-uitest-fake-backend-session` (otro hook, otro significado) y un typo en un string suelto
        // daría un rojo MUDO — el arg desconocido se ignora en silencio.
        if cloudSession { args.append("-uitest-fake-cloud-session") }
        if groupsConsent { args.append("-uitest-groups-consent") }
        // C2 · invierte el early-return que desmonta el educativo bajo `-uitest`. Va aquí, con nombre, y
        // NO por `extraArguments:` por la misma razón que sus dos vecinos: un typo en un string suelto se
        // ignora en silencio y el rojo resultante no menciona el arg. **Por defecto `false`**, así que
        // ninguna corrida existente cambia: el sheet del educativo interceptaría los taps de toda la suite
        // de Grupos, que es justo por lo que ese early-return existe.
        if groupsEducativo { args.append("-uitest-groups-educativo") }
        if inviteOnboarding { args.append("-uitest-invite-onboarding") }
        if let joinPhase {
            args.append("-uitest-join-phase")
            args.append(joinPhase)
        }
        if let joinSoftTimeout {
            args.append("-uitest-join-soft-timeout")
            args.append(joinSoftTimeout)
        }
        // Args crudos adicionales (aditivo — p.ej. "-uitest-cloud-chooser").
        args.append(contentsOf: extraArguments)
        launchArguments = args
        launch()
        return self
    }

    /// Espera a que el root exponga `uitest_ready` (bootstrap + seed completos).
    /// Timeout generoso por si el test usa seed realista/pesado.
    @discardableResult
    func waitForUITestReady(timeout: TimeInterval = 120) -> Bool {
        descendants(matching: .any)
            .matching(identifier: "uitest_ready")
            .firstMatch
            .waitForExistence(timeout: timeout)
    }

    // MARK: - Navegación reutilizable

    /// Abre el sheet de Perfil desde el avatar del toolbar del Panel.
    /// Falla el test si el avatar no aparece (la app no llegó al Panel) o si
    /// aparece pero no es alcanzable (algo lo tapa y el tap se perdería).
    @discardableResult
    func openProfile(timeout: TimeInterval = 10) -> XCUIApplication {
        let avatar = buttons["profile_avatar"]
        XCTAssertTrue(avatar.waitForExistence(timeout: timeout), "No apareció el avatar de Perfil (profile_avatar) en el Panel.")
        // `exists` NO implica alcanzable, y la diferencia es justo la que produce un
        // rojo MUDO: con un sheet presentado encima, el Panel sigue ENTERO en el árbol
        // de accesibilidad —`profile_avatar` y `fab_new_transaction` «existen»— pero sin
        // punto de impacto. XCUITest computa entonces el hit point en `{-1, -1}`,
        // sintetiza el tap ahí y no pasa nada: sin error, sin excepción, sin traza. El
        // test sigue como si el Perfil se hubiera abierto y muere mucho después, en la
        // pantalla que nunca llegó a montarse. Así se leyó durante dos días el rojo de
        // `profile_favorites` (Lista Negra, 2026-08-02) como «la fila no aparece»
        // cuando el Perfil ni siquiera se había abierto.
        XCTAssertTrue(
            avatar.waitForHittable(timeout: timeout),
            "El avatar de Perfil existe pero NO es alcanzable — algo lo tapa (¿un sheet sin cerrar?) y el tap se perdería."
        )
        avatar.tap()
        return self
    }

    /// Desde el Perfil abierto, navega a una sección de ajustes (push del NavigationStack).
    /// `rowID` es el accessibilityIdentifier de la fila — ej. "profile_accounts",
    /// "profile_categories", "profile_tags". Reutilizable por todas las áreas de Settings.
    func openSettingsSection(_ rowID: String, timeout: TimeInterval = 10) {
        let row = buttons[rowID]
        XCTAssertTrue(row.waitForExistence(timeout: timeout), "No apareció la fila de ajustes '\(rowID)'.")
        row.tap()
    }

    // MARK: - Transacciones

    /// Cierra la pantalla de éxito que queda tras guardar una transacción y espera
    /// a que se desmonte de verdad.
    ///
    /// **Guardar NO cierra el sheet de `NewTransactionView`**: su `body` conmuta a
    /// `TransactionSuccessView` (`NewTransactionView.swift:252`), que solo se descarta
    /// con «Aceptar» o «Registrar otro». Mientras siga montada, el Panel de fondo
    /// permanece en el árbol de accesibilidad ⇒ **afirmar que `fab_new_transaction`
    /// existe NO prueba que se volvió al Panel** (se cumple igual con el sheet puesto),
    /// y cualquier tap sobre el Panel se pierde en `{-1, -1}`. La señal determinista es
    /// que la pantalla de éxito desapareció; a partir de ahí el Panel vuelve a ser
    /// alcanzable. Todo test que guarde una transacción y siga interactuando con la app
    /// tiene que pasar por aquí.
    @discardableResult
    func dismissTransactionSuccess(timeout: TimeInterval = 10) -> XCUIApplication {
        let accept = buttons["transaction_success_accept"]
        XCTAssertTrue(
            accept.waitForExistence(timeout: timeout),
            "No apareció la pantalla de éxito de la transacción (transaction_success_accept) — el guardado no completó."
        )
        accept.tap()
        XCTAssertTrue(
            accept.waitForNonExistence(timeout: timeout),
            "La pantalla de éxito no se cerró tras tocar «Aceptar» — el sheet sigue tapando el Panel."
        )
        return self
    }

    // MARK: - Menú (···) de Registros

    /// El menú (···) de la toolbar de Registros (tab Registros de Estadísticas /
    /// RecordsStandaloneView). Visible solo en modo normal (no en modo selección).
    /// Señal canónica de "estamos en la lista de Registros en modo normal".
    var recordsOverflowMenu: XCUIElement { buttons["records_overflow_menu"] }

    /// Abre el menú (···) de Registros y toca "Filtrar". El botón `filters_toolbar_button`
    /// vive ahora DENTRO del menú (antes era un botón directo del toolbar).
    func openRecordsFilters(timeout: TimeInterval = 10) {
        let menu = recordsOverflowMenu
        XCTAssertTrue(menu.waitForExistence(timeout: timeout), "No apareció el menú (···) de Registros.")
        menu.tap()
        let filters = buttons["filters_toolbar_button"]
        XCTAssertTrue(filters.waitForExistence(timeout: timeout), "El menú (···) no ofreció 'Filtrar'.")
        filters.tap()
    }

    /// Abre el menú (···) de Registros y toca "Seleccionar" → entra en modo selección.
    /// El botón `records_select_button` vive ahora DENTRO del menú.
    func openRecordsSelectMode(timeout: TimeInterval = 10) {
        let menu = recordsOverflowMenu
        XCTAssertTrue(menu.waitForExistence(timeout: timeout), "No apareció el menú (···) de Registros.")
        menu.tap()
        let select = buttons["records_select_button"]
        XCTAssertTrue(select.waitForExistence(timeout: timeout), "El menú (···) no ofreció 'Seleccionar'.")
        select.tap()
    }
}

extension XCUIElement {
    /// Espera (sin sleeps) a que el elemento sea REALMENTE alcanzable por un tap.
    /// `exists` solo dice que está en el árbol de accesibilidad; `isHittable` añade
    /// que tiene un punto de impacto válido — la diferencia entre un tap que actúa y
    /// uno que se sintetiza en `{-1, -1}` y se pierde sin error. El predicate
    /// re-consulta, así que absorbe la animación de cierre de un sheet.
    ///
    /// Consultar `isHittable` de un elemento que NO existe lanza, así que llamar a
    /// esto siempre DESPUÉS de `waitForExistence`.
    func waitForHittable(timeout: TimeInterval) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isHittable == true"),
            object: self
        )
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
