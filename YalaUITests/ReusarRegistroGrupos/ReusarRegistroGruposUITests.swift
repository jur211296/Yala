//
//  ReusarRegistroGruposUITests.swift
//  YalaUITests
//
//  «Reusar» con gastos de grupo (encargo del 21-nov), de punta a punta: «Elige un registro» trae el gasto de «Jurpi»
//  con su chip y deja apagados, con su motivo, el de un grupo archivado y el de uno del que saliste; elegirlo abre el
//  formulario ya compartido (grupo, moneda, total y división) sin guardar nada, y guardar crea el pago compartido.
//  Semilla `minimal` + `-uitest-seed-reusar-grupo` (`DevSeedReusarGrupo`), idioma de la suite (es-419).
//

import XCTest

final class ReusarRegistroGruposUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func adjuntar(_ app: XCUIApplication, _ nombre: String) {
        let foto = XCTAttachment(screenshot: app.screenshot())
        foto.name = nombre
        foto.lifetime = .keepAlways
        add(foto)
    }

    private func abrirReusar() -> (XCUIApplication, XCUIElement) {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal", deeplink: "scheduledPayments",
                            extraArguments: ["-uitest-seed-reusar-grupo"])
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")
        let reusar = app.buttons["scheduled_payments_create_from_record_button"]
        XCTAssertTrue(reusar.waitForExistence(timeout: 15), "Pagos no ofrece «Reusar».")
        reusar.tap()
        let picker = app.descendants(matching: .any)["recurring_record_picker_list"]
        XCTAssertTrue(picker.waitForExistence(timeout: 10), "No se abrió «Elige un registro».")
        return (app, picker)
    }

    /// La fila de un registro de la hoja, por su descripción.
    private func fila(_ picker: XCUIElement, _ texto: String) -> XCUIElement {
        picker.buttons.matching(NSPredicate(format: "identifier == 'record_row' AND label CONTAINS %@", texto)).firstMatch
    }

    private func buscar(_ app: XCUIApplication, _ picker: XCUIElement, _ texto: String) {
        let campo = picker.textFields["records_list_search_field"]
        XCTAssertTrue(campo.waitForExistence(timeout: 5))
        campo.tap()
        campo.typeText(texto)
        cerrarTeclado(app)
    }

    /// El teclado tapa la lista y la mueve al irse: se cierra con Intro y se espera a que no quede ninguno antes de
    /// tocar una fila (`testing.md`, tocar tras escribir).
    private func cerrarTeclado(_ app: XCUIApplication) {
        app.typeText("\n")
        let sinTeclado = expectation(for: NSPredicate(format: "count == 0"), evaluatedWith: app.keyboards)
        XCTAssertEqual(XCTWaiter.wait(for: [sinTeclado], timeout: 5), .completed, "El teclado no se cerró.")
    }

    func test_gastoDeGrupo_seOfrece_yCreaUnPagoCompartidoDeEseGrupo() {
        let (app, picker) = abrirReusar()

        buscar(app, picker, "Luz Del Sur")
        let luz = fila(picker, "Luz Del Sur")
        XCTAssertTrue(luz.waitForExistence(timeout: 10), "El gasto de grupo «Luz Del Sur» no sale en «Elige un registro».")
        XCTAssertTrue(app.waitForSettledLayout(of: luz), "La fila no se quedó quieta.")
        XCTAssertTrue(luz.label.contains("Jurpi"), "La fila no lleva el chip del grupo: «\(luz.label)».")
        // Solo una fila del gasto: la pata de «Préstamo a grupos» no se ofrece.
        XCTAssertEqual(picker.buttons.matching(NSPredicate(format: "identifier == 'record_row' AND label CONTAINS 'Luz Del Sur'")).count, 1,
                       "Salió también la pata de «Préstamo a grupos».")
        adjuntar(app, "reusar-gasto-de-grupo")
        luz.tap()

        // El formulario, ya compartido y sin guardar nada.
        let nombre = app.textFields["scheduled_name_field"]
        XCTAssertTrue(nombre.waitForExistence(timeout: 10), "No se abrió el formulario.")
        XCTAssertEqual(nombre.value as? String, "Luz Del Sur")
        let monto = app.textFields["scheduled_amount_field"]
        XCTAssertTrue((monto.value as? String ?? "").hasPrefix("120"), "El monto no es el total del gasto: \(monto.value ?? "").")
        let interruptor = app.switches["scheduled_group_expense_toggle"]
        XCTAssertTrue(interruptor.waitForExistence(timeout: 5), "«¿Es un gasto compartido?» no está a la vista.")
        XCTAssertEqual(interruptor.value as? String, "1", "El pago no nace compartido.")
        let grupo = app.buttons["scheduled_group_row"]
        XCTAssertTrue(grupo.exists && grupo.label.contains("Jurpi"), "No eligió el grupo del gasto: «\(grupo.label)».")
        let division = app.buttons["scheduled_split_division_row"]
        XCTAssertTrue(division.label.contains("Entre 2"), "No copió la división: «\(division.label)».")
        adjuntar(app, "reusar-formulario-compartido")

        app.buttons["toolbar_save_button"].tap()
        // El gasto quedó como su primer pago: el siguiente toca el mes que viene, y la lista enseña este mes.
        let siguienteMes = app.buttons["period_navigation_next"].firstMatch
        XCTAssertTrue(siguienteMes.waitForExistence(timeout: 10), "La lista de pagos no volvió tras guardar.")
        siguienteMes.tap()
        let pago = app.buttons.matching(NSPredicate(format: "identifier == 'scheduled_payment_row' AND label BEGINSWITH 'Luz Del Sur'")).firstMatch
        XCTAssertTrue(pago.waitForExistence(timeout: 10), "El pago compartido no aparece en la lista.")
        adjuntar(app, "reusar-pago-creado")

        // Al abrirlo es compartido de «Jurpi», con su división (el gasto quedó como su primer pago).
        pago.tap()
        let editar = app.buttons["pencil"].firstMatch
        if editar.waitForExistence(timeout: 5) { editar.tap() }
        XCTAssertTrue(app.buttons["scheduled_group_row"].waitForExistence(timeout: 10),
                      "El pago guardado no es compartido.")
        XCTAssertTrue(app.buttons["scheduled_group_row"].label.contains("Jurpi"))
    }

    func test_gastoDeGrupoQueYaNoSePuedeUsar_saleApagadoConSuMotivo() {
        let (app, picker) = abrirReusar()

        buscar(app, picker, "Internet viejo")
        let apagado = picker.descendants(matching: .any)["recurring_record_picker_unavailable"].firstMatch
        XCTAssertTrue(apagado.waitForExistence(timeout: 10), "El gasto del grupo archivado no sale apagado.")
        XCTAssertTrue(apagado.label.contains("archivado"), "No dice por qué: «\(apagado.label)».")
        adjuntar(app, "reusar-grupo-archivado")
        XCTAssertTrue(app.waitForSettledLayout(of: apagado), "La fila apagada no se quedó quieta.")
        apagado.tap()
        XCTAssertFalse(app.textFields["scheduled_name_field"].waitForExistence(timeout: 2),
                       "Un gasto de un grupo archivado abrió el formulario.")
        // El toque cayó en la fila y no hizo nada: la hoja y la fila siguen ahí.
        XCTAssertTrue(picker.exists && apagado.exists, "El toque sobre la fila apagada cerró o cambió la hoja.")

        let campo = picker.textFields["records_list_search_field"]
        campo.tap()
        let actual = campo.value as? String ?? ""
        campo.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: actual.count) + "Agua")
        cerrarTeclado(app)
        let salio = picker.descendants(matching: .any)["recurring_record_picker_unavailable"].firstMatch
        XCTAssertTrue(salio.waitForExistence(timeout: 10), "El gasto de un grupo del que saliste no sale apagado.")
        XCTAssertTrue(salio.label.contains("Ya no estás"), "No dice por qué: «\(salio.label)».")
    }
}
