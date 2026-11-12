//
//  StatisticsRecordsFilterObservationUITests.swift
//  YalaUITests
//
//  Ticket `statistics-and-records-filter-onchange-may-fall-asleep-like-the-panel`: el conductor que reprodujo en el Panel
//  que un `onChange(of: sessionState.selectedAccountIDs)` se DORMÍA tras volver a primer plano (3 de 7 corridas, ticket
//  `panel-stayed-filtered-after-removing-the-account-chip`), adaptado a Estadísticas › Distribución
//  (`DetailContainerView`) y a la pestaña Registros (`RecordsStandaloneView`), que recalculan con ese mismo molde.
//
//  Diez rondas: filtrar por una cuenta desde la hoja de Filtros y quitar el filtro con la «x» de su cápsula; en las
//  rondas impares, ir a inicio y volver antes de quitarlo. Tras cada quitar, la cifra tiene que volver a la de sin
//  filtro; con el filtro puesto tiene que ser otra, o el caso no discriminaría.
//  Seed `minimal`: «Cuenta Principal» (PEN, casi todo el movimiento) y «Ahorros USD», con cifras distintas.
//  Convenciones: sin sleeps, scheme Yala Dev.
//
//  Qué cubre cada caso (medido con mutantes el 2026-11-06, 5 de 5 en verde sin ellos):
//  - Distribución: quitar con la «x» solo llega al recálculo por los `onChange` (`DetailContainerView` sobre
//    `sessionState.selectedAccountIDs` y `CategoriesFilterRecalcObservers` sobre `viewModel.selectedAccounts`). Con los
//    DOS ciegos a la retirada, cae en la ronda 1; con solo el del contenedor, pasa (el otro lo cubre).
//  - Registros (desde la revisión 2.3, decisiones 15 y 16): la cuenta elegida la dice el chip «Cuenta ▾», no una cápsula
//    de la banda, y se quita con su «Todas las cuentas», que llama al mismo `onFilterChange` que la «x».
//    Antes: la «x» recalcula directamente (`onFilterChange` de la barra), la hoja al cerrarse (`onDisappear`) y el
//    cambio de pestaña también (`RecordsNavObserver`). Su `onChange` de `selectedAccountIDs` no lo ejercita ningún gesto
//    de este conductor: con él ciego, pasa. Cae en la ronda 1 si además se quita el `onFilterChange`. Es la red de la
//    cifra, no del observador.
//

import XCTest

final class StatisticsRecordsFilterObservationUITests: XCTestCase {
    private let rounds = 10
    private let filteredAccount = "Ahorros USD"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: - Casos

    func test_distribution_followsTheAccountFilter_acrossBackgroundRoundTrips() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, deeplinkURL: "yaladev://statistics/categories")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        let figure = app.descendants(matching: .any)["stats_hero_amount"]
        runRounds(
            app: app, figure: figure, screen: "Distribución",
            openFilters: {
                let filters = app.buttons["filters_toolbar_button"]
                XCTAssertTrue(filters.waitForExistence(timeout: 10) && filters.waitForHittable(timeout: 5),
                              "Distribución no enseña el botón de Filtros.")
                filters.tap()
            }
        )
    }

    func test_recordsTab_followsTheAccountFilter_acrossBackgroundRoundTrips() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, extraArguments: Self.recordsTabArgs)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        app.selectTab(.records)

        let figure = app.descendants(matching: .any)["records_summary_balance"]
        runRounds(
            app: app, figure: figure, screen: "Registros", openFilters: { Self.openStandaloneRecordsFilters(app) }
        )
    }

    /// En la pestaña Registros el menú «···» no lleva el id `records_overflow_menu` (ese lo pone Estadísticas al
    /// montarlo): se busca por su etiqueta, «Más opciones», dentro de la barra de navegación.
    private static func openStandaloneRecordsFilters(_ app: XCUIApplication) {
        let menu = app.navigationBars.buttons["Más opciones"].firstMatch
        XCTAssertTrue(menu.waitForExistence(timeout: 10) && menu.waitForHittable(timeout: 5),
                      "No apareció el menú (···) de la pestaña Registros.")
        menu.tap()
        let filters = app.buttons["filters_toolbar_button"]
        XCTAssertTrue(filters.waitForExistence(timeout: 10), "El menú (···) no ofreció «Filtrar».")
        filters.tap()
    }

    /// La pestaña Registros en la barra (por defecto no está). Entre comillas de plist: ver `LoadTimesUITests`.
    private static let recordsTabArgs = [
        "-tabBarConfiguration", #""{\"activeTabs\":[\"panel\",\"statistics\",\"records\"]}""#,
    ]

    // MARK: - Conductor

    private func runRounds(
        app: XCUIApplication, figure: XCUIElement, screen: String, openFilters: () -> Void
    ) {
        XCTAssertTrue(figure.waitForExistence(timeout: 20), "No se ve la cifra de \(screen).")
        let unfiltered = settledLabel(of: figure)
        XCTAssertFalse(unfiltered.isEmpty, "La cifra de \(screen) no tiene texto.")

        for round in 1...rounds {
            filterByAccount(app, openFilters: openFilters)
            XCTAssertTrue(
                waitForLabel(of: figure, toSatisfy: "label != %@", unfiltered),
                "Ronda \(round) de \(screen): con «\(filteredAccount)» filtrada la cifra sigue en \(unfiltered) "
                    + "(o el filtro no recalculó, o el caso no discrimina).")

            if round % 2 == 1 {
                XCUIDevice.shared.press(.home)
                app.activate()
                XCTAssertTrue(figure.waitForExistence(timeout: 15), "Ronda \(round): al volver no se ve la cifra.")
            }

            removeAccountFilter(app, round: round)
            XCTAssertTrue(
                waitForLabel(of: figure, toSatisfy: "label == %@", unfiltered),
                "Ronda \(round) de \(screen): quitado el filtro, la cifra se quedó en \(figure.label) "
                    + "en vez de volver a \(unfiltered): quitar el filtro no recalculó la pantalla.")
        }
    }

    private func filterByAccount(_ app: XCUIApplication, openFilters: () -> Void) {
        openFilters()
        let account = app.buttons[filteredAccount].firstMatch
        XCTAssertTrue(account.waitForExistence(timeout: 10) && account.waitForHittable(timeout: 5),
                      "Filtros no ofrece la cuenta «\(filteredAccount)».")
        account.tap()
        let apply = app.buttons["filters_apply_button"]
        XCTAssertTrue(apply.waitForExistence(timeout: 5), "No apareció «Aplicar».")
        apply.tap()
        XCTAssertTrue(apply.waitForNonExistence(timeout: 5), "«Aplicar» no cerró Filtros.")
        if let quick = quickAccountChip(app) {
            // Registros: la cuenta la dice el chip, no la banda.
            XCTAssertTrue(
                waitForValue(of: quick, filteredAccount),
                "El chip «Cuenta» no dice «\(filteredAccount)» (dice «\(String(describing: quick.value))»).")
            return
        }
        XCTAssertTrue(
            app.buttons.matching(identifier: "applied_filter_chip").firstMatch.waitForExistence(timeout: 10),
            "No apareció la cápsula del filtro de cuenta.")
    }

    /// El chip «Cuenta ▾» de Registros, si la pantalla lo tiene (Estadísticas no).
    private func quickAccountChip(_ app: XCUIApplication) -> XCUIElement? {
        let chip = app.descendants(matching: .any)["records_quick_account"].firstMatch
        return chip.exists ? chip : nil
    }

    private func waitForValue(of element: XCUIElement, _ expected: String) -> Bool {
        let predicate = NSPredicate { object, _ in
            ((object as? XCUIElement)?.value as? String ?? "") == expected
        }
        return XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: element)], timeout: 8)
            == .completed
    }

    /// La «x» de la cápsula (`FilterChipView`, etiqueta «Quitar filtro»): el mismo gesto que en el Panel.
    private func removeAccountFilter(_ app: XCUIApplication, round: Int) {
        if let quick = quickAccountChip(app) {
            quick.tap()
            let all = app.buttons["Todas las cuentas"].firstMatch
            XCTAssertTrue(all.waitForExistence(timeout: 5), "Ronda \(round): el chip no ofrece «Todas las cuentas».")
            all.tap()
            XCTAssertTrue(waitForValue(of: quick, ""), "Ronda \(round): el chip sigue con la cuenta elegida.")
            return
        }
        let chips = app.buttons.matching(identifier: "applied_filter_chip")
        XCTAssertEqual(chips.count, 1, "Ronda \(round): se esperaba solo la cápsula de la cuenta: "
                       + "\(chips.allElementsBoundByIndex.map(\.label))")
        let remove = app.buttons["Quitar filtro"].firstMatch
        XCTAssertTrue(remove.waitForExistence(timeout: 5) && remove.waitForHittable(timeout: 5),
                      "Ronda \(round): la «x» de la cápsula no es alcanzable.")
        remove.tap()
        XCTAssertTrue(chips.firstMatch.waitForNonExistence(timeout: 5), "Ronda \(round): la cápsula no se fue.")
    }

    // MARK: - Esperas

    private func waitForLabel(of element: XCUIElement, toSatisfy format: String, _ value: String) -> Bool {
        let predicate = NSPredicate(format: format, value)
        return XCTWaiter.wait(for: [expectation(for: predicate, evaluatedWith: element)], timeout: 8) == .completed
    }

    /// La cifra rueda al cambiar (`animatesValue`): se lee cuando dos lecturas seguidas coinciden.
    private func settledLabel(of element: XCUIElement) -> String {
        var previous = element.label
        let deadline = Date().addingTimeInterval(8)
        while Date() < deadline {
            _ = element.waitForNonExistence(timeout: 1)
            let current = element.label
            if current == previous { return current }
            previous = current
        }
        return previous
    }
}
