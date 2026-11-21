//
//  SaludFinancieraDetalleUITests.swift
//  YalaUITests
//
//  La hoja de la nota de salud en tres secciones (opción A de Jürgen, 20-nov-2026): las cápsulas bajan a su sección,
//  el caso «no alcanza» enseña la comparación y un consejo sin cifra negativa, «Revisar o mover pagos» abre Pagos
//  planificados, y con datos reales los presupuestos abren su detalle y la invitación lleva a Presupuestos.
//

import XCTest

final class SaludFinancieraDetalleUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Las cápsulas son el índice: tocar Ritmo deja su sección a la vista, y tocar Presupuestos vuelve arriba.
    func test_capsulas_bajanASuSeccion() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "minimal", extraArguments: ["-uitest-salud-estado", "noalcanza"])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        abrirHoja(app)

        let ritmo = app.descendants(matching: .any)["health_section_ritmo"]
        XCTAssertTrue(ritmo.waitForExistence(timeout: 10), "Falta la sección Ritmo.")
        let racha = app.descendants(matching: .any)["health_streak"]
        XCTAssertFalse(racha.isHittable, "La racha ya se veía al abrir: el caso no prueba que la cápsula baje.")

        app.buttons["health_capsule_ritmo"].tap()
        XCTAssertTrue(esperar(racha.isHittable), "Tocar la cápsula de Ritmo no baja a su sección.")

        app.buttons["health_capsule_compromisos"].firstMatch.tap()
        let comparacion = app.descendants(matching: .any)["health_commit_to_pay"]
        XCTAssertTrue(esperar(comparacion.isHittable), "Tocar la cápsula de Compromisos no lleva a su sección.")
    }

    /// El caso de la captura de Jürgen: no alcanza. La hoja compara lo que falta pagar con el dinero de hoy, dice cuánto
    /// faltaría en ámbar y propone qué hacer; nada de «No alcanza» ni de cifras negativas. «Revisar o mover pagos» abre
    /// Pagos planificados.
    func test_noAlcanza_comparaSinCifraNegativa_yRevisarAbrePagos() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "minimal", extraArguments: ["-uitest-salud-estado", "noalcanza"])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        abrirHoja(app)

        let frase = app.descendants(matching: .any)["health_commit_lead"]
        XCTAssertTrue(frase.waitForExistence(timeout: 10), "Compromisos no dice cuánto falta pagar y cuánto tienes.")
        XCTAssertTrue(app.descendants(matching: .any)["health_commit_short"].exists, "No dice cuánto faltaría.")
        XCTAssertTrue(app.descendants(matching: .any)["health_commit_money_today"].exists, "Falta la barra de tu dinero.")

        let negativos = app.staticTexts.allElementsBoundByIndex.filter {
            $0.label.contains("-S/") || $0.label.contains("−")
                || $0.label.range(of: #"S/\s*-"#, options: .regularExpression) != nil
        }
        XCTAssertTrue(negativos.isEmpty, "La hoja enseña cifras negativas: \(negativos.map(\.label))")
        let alarma = app.staticTexts.allElementsBoundByIndex.filter { $0.label.hasPrefix("No alcanza") }
        XCTAssertTrue(alarma.isEmpty, "La hoja sigue diciendo «No alcanza».")

        let revisar = app.buttons["health_commit_open_payments"]
        XCTAssertTrue(revisar.waitForExistence(timeout: 5))
        bajarHasta(revisar, en: app)
        revisar.tap()
        let chip = app.buttons["planning_chip_scheduledPayments"]
        XCTAssertTrue(chip.waitForExistence(timeout: 10), "«Revisar o mover pagos» no lleva a Planificación.")
        XCTAssertTrue(chip.isSelected, "«Revisar o mover pagos» no deja Pagos planificados elegido.")
    }

    /// Semilla `realista` con los presupuestos en sus cuatro estados: hay uno pasado, la sección lo dice y su fila abre
    /// el presupuesto.
    func test_conDatos_presupuestoPasado_abreSuDetalle() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "realista", budgetStates: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        abrirHoja(app)

        XCTAssertTrue(app.descendants(matching: .any)["health_section_presupuestos"].waitForExistence(timeout: 15),
                      "Falta la sección Presupuestos.")
        XCTAssertTrue(app.descendants(matching: .any)["health_section_compromisos"].exists, "Falta Compromisos.")
        XCTAssertTrue(app.descendants(matching: .any)["health_section_ritmo"].exists, "Falta Ritmo.")
        XCTAssertTrue(app.descendants(matching: .any)["health_how_it_works"].exists, "«¿Cómo se calcula?» no está.")

        let fila = app.buttons["health_budget_row"].firstMatch
        XCTAssertTrue(fila.waitForExistence(timeout: 10), "Con presupuestos, la hoja no pinta sus barras.")
        bajarHasta(fila, en: app)
        fila.tap()
        XCTAssertTrue(app.descendants(matching: .any)["budget_detail"].waitForExistence(timeout: 10),
                      "Tocar el presupuesto no abre su detalle.")
    }

    /// Semilla `cuenta-con-movimientos`: sin presupuestos ni pagos. La hoja invita a crear un presupuesto y a agregar
    /// un pago, y la invitación lleva a Presupuestos.
    func test_sinPresupuestos_invitaACrearUno_yLlevaAPresupuestos() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "cuenta-con-movimientos")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        abrirHoja(app)

        let invitacion = app.buttons["health_budgets_empty"]
        XCTAssertTrue(invitacion.waitForExistence(timeout: 15), "Sin presupuestos, la hoja no invita a crear uno.")
        XCTAssertTrue(app.descendants(matching: .any)["health_payments_empty"].exists,
                      "Sin pagos planificados, la hoja no invita a agregar uno.")

        bajarHasta(invitacion, en: app)
        invitacion.tap()
        let chip = app.buttons["planning_chip_budgets"]
        XCTAssertTrue(chip.waitForExistence(timeout: 10), "La invitación no lleva a Planificación.")
        XCTAssertTrue(chip.isSelected, "La invitación no deja Presupuestos elegido.")
    }

    // MARK: - Ayudas

    private func abrirHoja(_ app: XCUIApplication) {
        let card = app.buttons["panel_health_compact"]
        XCTAssertTrue(card.waitForExistence(timeout: 20), "La nota de salud no sale en el Panel.")
        card.tap()
        XCTAssertTrue(app.descendants(matching: .any)["health_breakdown"].waitForExistence(timeout: 5),
                      "Tocar la tarjeta no abre la hoja.")
    }

    /// Arrastres cortos hasta dejar el elemento tocable (la hoja abre grande y su scroll es el último).
    private func bajarHasta(_ elemento: XCUIElement, en app: XCUIApplication) {
        let scroll = app.scrollViews.element(boundBy: max(0, app.scrollViews.count - 1))
        var intentos = 0
        while !elemento.isHittable && intentos < 10 {
            scroll.swipeUp(velocity: .slow)
            intentos += 1
        }
    }

    private func esperar(_ condicion: @autoclosure @escaping () -> Bool, timeout: TimeInterval = 5) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condicion() }, object: nil)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
