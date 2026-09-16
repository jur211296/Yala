//
//  GroupsAttestTerminalBannerUITests.swift
//  YalaUITests
//
//  El aviso FIJO de la pestaña Grupos cuando este teléfono lleva más de un día sin conseguir App Attest (ticket
//  `groups-tab-does-not-say-this-phone-cannot-sync-groups`, decisión de Jürgen del 2026-09-15, opción 1).
//
//  **Cómo se llega al estado sin fingir el veredicto.** `-uitest-groups-attest-terminal` no fuerza ningún predicado:
//  escribe TRES rechazos por el camino de producción (`GroupsAttestStreakStore.recordRejection`) con relojes
//  separados, y deja que `GroupsAttestVerdictLogic` decida. Un seam que devolviera `isTerminal = true` dejaría
//  ciegos a los dos casos de aquí (`.claude/rules/testing.md`).
//
//  **Los dos casos prueban cosas distintas y el segundo es el que discrimina.** El primero, que con el veredicto
//  puesto y una sesión viva el tab lo dice sin que nadie toque nada. El segundo, que con el MISMO veredicto y sin
//  sesión NO lo dice: la racha describe al teléfono y sobrevive al cierre de sesión a propósito, así que sin esa
//  mitad el tab le contaría una avería de Grupos a quien ya está leyendo «crea tu cuenta». Ese caso se lanza con la
//  racha sembrada —no con el estado por defecto— para que la ausencia signifique algo: una aserción negativa sobre
//  un input que ya la garantiza no prueba nada.
//
//  **Y ese segundo caso depende del quinto momento de recálculo para discriminar, aunque no lo parezca.** La siembra
//  corre al final del bootstrap, cuando la pestaña ya montó: con solo los momentos de gesto, el último recálculo caía
//  con la racha todavía ausente y la ausencia del aviso se cumplía por el ORDEN, no por el gate de la sesión —medido
//  el 2026-09-15, con el mutante `hasLiveSession: true` en VERDE. Lo que lo arregla es
//  `GroupsAttestStreakStore.didChangeNotification`: si alguien retira ese `.onReceive`, este caso deja de medir nada.
//
//  **La cuarta condición, el canal, no es ejercitable aquí:** `groupsBackendCompiledCapability` es una constante de
//  compilación y moverla pide recompilar. La cubre la tabla de `GroupsAttestTabNoticeLogicTests`.
//
//  Convenciones: ver CLAUDE.md (sin sleeps, scheme Yala Dev, a11y ids).
//

import XCTest

final class GroupsAttestTerminalBannerUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// El id va en el CONTENEDOR del aviso y lo heredan sus dos textos, así que se consulta por cualquier tipo
    /// de descendiente — mismo molde que `groups_empty_state`.
    private func banner(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["groups_attest_terminal_banner"].firstMatch
    }

    /// Con el veredicto terminal y sesión viva, la pestaña Grupos lo dice **sin que la persona intente nada**.
    /// Hasta este ticket, el mismo hecho solo salía al cerrar sesión, desasociar o salir de un grupo.
    func test_attestTerminal_withLiveSession_showsPinnedNotice() {
        let app = XCUIApplication()
        // `groupInvite:` arranca en el tab Grupos (modo solo-grupos); la sesión y el consent fingidos son los que
        // dejan la lista en su rama estándar, igual que en `GroupsEmptyStateUITests`.
        app.launchForUITest(seed: nil,
                            groupInvite: true,
                            cloudSession: true,
                            groupsConsent: true,
                            groupsAttestTerminal: true)

        XCTAssertTrue(
            banner(in: app).waitForExistence(timeout: 30),
            """
            No apareció `groups_attest_terminal_banner`: con el veredicto de App Attest terminal, la pestaña \
            Grupos volvió a callarse y la persona solo se enteraría al intentar salir.
            """
        )
    }

    /// **La población del bug: alguien que TIENE grupos.** Los otros casos montan la lista vacía, donde el
    /// `ScrollView` con el pull-to-refresh ni siquiera está en el árbol; aquí el aviso convive con las tarjetas, el
    /// resumen y el buscador, que es donde de verdad va a leerlo quien edita gastos que no llegan.
    func test_attestTerminal_withGroups_showsNoticeOverTheList() {
        let app = XCUIApplication()
        // `deeplink: "groups"` aterriza directo en el tab, sin el scroll de «Más» que iOS 27.0 no honra
        // (molde y medición en `GroupsSmokeUITests`).
        app.launchForUITest(pro: true, seed: "grupos", deeplink: "groups",
                            cloudSession: true, groupsConsent: true, groupsAttestTerminal: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        XCTAssertTrue(
            banner(in: app).waitForExistence(timeout: 30),
            "El aviso no salió sobre la lista de grupos, que es justo la pantalla de quien edita gastos que no llegan."
        )
    }

    /// **Sin el consent de Grupos aceptado, no hay aviso aunque el veredicto sea cierto y la sesión esté viva.** La
    /// racha la escribe también el motor personal, así que esta persona puede tenerla sin haber tocado Grupos nunca:
    /// el tab le está ofreciendo aceptar el consent y encima le diría que sus cambios de grupos no llegan. Lo cazó
    /// una lente adversarial el 2026-09-15; hasta entonces el aviso salía.
    func test_attestTerminal_withoutGroupsConsent_hidesNotice() {
        let app = XCUIApplication()
        // Con sesión y SIN `groupsConsent:`: el mismo lanzamiento del caso positivo menos el consent.
        app.launchForUITest(seed: nil, groupInvite: true, cloudSession: true, groupsAttestTerminal: true)

        // Se espera a que la pantalla real monte antes de afirmar la ausencia. Con sesión y sin consent, la rama del
        // empty state es `.needsConsent`.
        let consentState = app.descendants(matching: .any)["groups_empty_state_consent"].firstMatch
        XCTAssertTrue(
            consentState.waitForExistence(timeout: 30),
            "La pestaña Grupos no llegó a su empty state de consent; la ausencia del aviso no mediría nada."
        )
        XCTAssertFalse(
            banner(in: app).exists,
            """
            `groups_attest_terminal_banner` salió sin el consent de Grupos aceptado: el tab anuncia que no llegan \
            unos cambios de grupos que esta persona no puede tener, encima de la pantalla que le pide aceptar.
            """
        )
    }

    /// El MISMO veredicto, sin sesión en la nube: no hay aviso. La racha es cierta —la app la acaba de escribir—
    /// y la frase sería mentira: nada está sincronizando y el tab ya está pidiendo crear la cuenta.
    func test_attestTerminal_withoutSession_hidesNotice() {
        let app = XCUIApplication()
        app.launchForUITest(seed: nil, groupInvite: true, groupsAttestTerminal: true)

        // Se espera a que la pantalla REAL monte antes de afirmar la ausencia: sobre un tab a medio cargar, la
        // ausencia se cumpliría sola. Sin sesión y sin cuenta previa, la rama es la de alta (C2).
        let emptyState = app.descendants(matching: .any)["groups_empty_state_create_account"].firstMatch
        XCTAssertTrue(
            emptyState.waitForExistence(timeout: 30),
            "La pestaña Grupos no llegó a montar su empty state; la ausencia del aviso no mediría nada."
        )
        XCTAssertFalse(
            banner(in: app).exists,
            """
            `groups_attest_terminal_banner` salió SIN sesión en la nube: el tab está contando una avería de \
            Grupos a quien todavía no tiene cuenta, encima del empty state que le pide crearla.
            """
        )
    }
}
