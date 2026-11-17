//
//  ImportarGrupoUITests.swift
//  YalaUITests
//
//  «Traer un grupo de Splitwise o Tricount» (2.3, gancho de llegada de Grupos): la entrada en Crear grupo, la vista previa,
//  «¿Quién eres tú?», el error de un archivo que no es un export, y el aviso del grupo con el emparejamiento de quien se
//  une. El selector de Archivos es del sistema: el archivo llega por `-uitest-import-csv` (`ImportarGrupoUITestSeams`).
//  Crear el grupo de verdad no se puede (server-first, sin sesión real): lo que espera tras crearlo se siembra con
//  `-uitest-import-pending`. Con `YALA_CAPTURE_DIR` (vía `TEST_RUNNER_YALA_CAPTURE_DIR`) guarda las capturas del cierre.
//  Convenciones: ver CLAUDE.md (sin sleeps, scheme Yala Dev, a11y ids).
//

import XCTest

final class ImportarGrupoUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private static let splitwiseCSV = """
    Date,Description,Category,Cost,Currency,Jürgen,Ana,Luis,Pia
    2026-03-01,Hotel en Cusco,Hotel,300.00,PEN,200.00,-100.00,0.00,-100.00
    2026-03-02,"Cena, pisco y postre",Dining out,120.00,PEN,-30.00,90.00,-30.00,-30.00
    2026-03-03,Taxi al aeropuerto,Taxi,40.00,PEN,-10.00,-10.00,30.00,-10.00
    2026-03-04,Tour en dólares,General,45.00,USD,15.00,-15.00,0.00,0.00
    2026-03-04,Pia paid Jürgen,Payment,50.00,PEN,-50.00,0.00,0.00,50.00
    ,Total balance,,,PEN,110.00,-20.00,0.00,-90.00
    ,Total balance,,,USD,15.00,-15.00,0.00,0.00
    """

    private static let bankStatementCSV = """
    Fecha,Comercio,Monto
    2026-01-01,Wong,25.00
    """

    /// Escribe el CSV en `/tmp` con el nombre de un export real (de ahí sale el nombre propuesto del grupo).
    private func writeCSV(_ text: String, name: String) throws -> String {
        let dir = URL(fileURLWithPath: "/tmp").appendingPathComponent("yala-uitest-import-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(name)
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url.path
    }

    private func openNewGroupForm(_ app: XCUIApplication) {
        let newGroup = app.buttons.matching(NSPredicate(format: "identifier IN %@",
                                                        ["groups_toolbar_new_group", "groups_action_new_group"])).firstMatch
        XCTAssertTrue(newGroup.waitForExistence(timeout: 30), "No apareció «Nuevo grupo».")
        newGroup.tap()
        XCTAssertTrue(app.textFields["group_form_name_input"].waitForExistence(timeout: 10), "No se abrió el formulario.")
    }

    // MARK: - 1 · Crear desde un export de Splitwise

    func test_newGroup_fromASplitwiseExport_previewsBalances_asksWhoYouAre_andFillsTheForm() throws {
        let path = try writeCSV(Self.splitwiseCSV, name: "viaje-a-cusco_2026-03-05_export.csv")
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "grupos", deeplink: "groups", cloudSession: true, groupsConsent: true,
                            extraArguments: ["-uitest-import-csv", path])
        openNewGroupForm(app)
        capture(app, "1-crear-grupo-con-la-entrada")

        let entry = app.buttons["group_import_entry"]
        XCTAssertTrue(entry.waitForExistence(timeout: 5), "Falta «Traer un grupo de Splitwise o Tricount» en Crear grupo.")
        entry.tap()

        let choose = app.buttons["group_import_choose_file"]
        XCTAssertTrue(choose.waitForExistence(timeout: 5), "La hoja no ofrece «Elegir archivo».")
        capture(app, "2-como-traerlo")
        choose.tap()

        // Vista previa: cada persona con su saldo. Luis está al día.
        let pia = element(app, "group_import_person_Pia")
        XCTAssertTrue(pia.waitForExistence(timeout: 10), "No salió la vista previa con las personas.")
        XCTAssertTrue(pia.label.contains("Debe") && pia.label.contains("90.00"), "Pia debe 90 en soles: \(pia.label)")
        let luis = element(app, "group_import_person_Luis")
        XCTAssertTrue(luis.label.contains("Al día"), "Luis no tiene saldo: \(luis.label)")
        let jurgen = element(app, "group_import_person_Jürgen")
        XCTAssertTrue(jurgen.label.contains("110.00") && jurgen.label.contains("15.00"),
                      "Jürgen tiene saldo en soles y en dólares: \(jurgen.label)")
        capture(app, "3-vista-previa")

        // «Usar» sin decir quién eres lo pide.
        let use = app.buttons["group_import_use"]
        use.tap()
        let footer = element(app, "group_import_me_footer")
        XCTAssertTrue(footer.label.hasPrefix("Elige quién eres"), "No pide elegir quién eres: \(footer.label)")

        let me = app.buttons["group_import_me_Jürgen"]
        // La fila tiene que quedar ENCIMA de la barra de abajo: debajo, `isHittable` dice que sí y el toque cae en «Usar».
        scrollTo(app, me, above: use)
        me.tap()
        XCTAssertTrue(me.isSelected, "La fila elegida no queda marcada.")
        capture(app, "4-quien-eres")
        use.tap()

        // De vuelta en el formulario: tarjeta de lo elegido, nombre y moneda del export.
        let chosen = element(app, "group_import_chosen")
        XCTAssertTrue(chosen.waitForExistence(timeout: 5), "El formulario no enseña lo traído.")
        XCTAssertTrue(chosen.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Splitwise")).firstMatch.exists,
                      "La tarjeta no dice de dónde vienen los saldos.")
        let name = app.textFields["group_form_name_input"]
        XCTAssertEqual(name.value as? String, "Viaje a cusco", "No se propuso el nombre del archivo.")
        capture(app, "5-formulario-relleno")
    }

    // MARK: - 2 · Un archivo que no es un export

    func test_aFileThatIsNotAnExport_saysWhy_andOffersAnotherFile() throws {
        let path = try writeCSV(Self.bankStatementCSV, name: "extracto.csv")
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "grupos", deeplink: "groups", cloudSession: true, groupsConsent: true,
                            extraArguments: ["-uitest-import-csv", path])
        openNewGroupForm(app)
        app.buttons["group_import_entry"].tap()
        let choose = app.buttons["group_import_choose_file"]
        XCTAssertTrue(choose.waitForExistence(timeout: 5))
        choose.tap()

        let message = element(app, "group_import_error_message")
        XCTAssertTrue(message.waitForExistence(timeout: 10), "No salió el error.")
        XCTAssertTrue(message.label.hasPrefix("No parece un archivo de Splitwise ni de Tricount"), message.label)
        XCTAssertEqual(app.buttons["group_import_choose_file"].label, "Elegir otro archivo")
        capture(app, "6-archivo-que-no-sirve")
    }

    // MARK: - 3 · Dentro del grupo: emparejar a quien se unió

    func test_pendingImport_banner_matchesWhoJoined_andWaitsForWhoDidNot() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "grupos", deeplink: "groups", cloudSession: true, groupsConsent: true,
                            extraArguments: ["-uitest-import-pending"])
        let card = app.descendants(matching: .any).matching(identifier: "group_card").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 30), "No apareció la tarjeta del grupo.")
        card.tap()

        let banner = element(app, "group_import_pending_banner")
        XCTAssertTrue(banner.waitForExistence(timeout: 15), "No salió el aviso de saldos por emparejar.")
        let missing = banner.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Por emparejar")).firstMatch
        XCTAssertTrue(missing.exists, "El aviso no dice quién falta.")
        // Solo quien falta: tú ya estás emparejado desde que creaste el grupo.
        XCTAssertTrue(missing.label.hasSuffix("Carla") && !missing.label.contains("Tú"), missing.label)
        capture(app, "7-aviso-en-el-grupo")

        app.buttons["group_import_pending_match"].tap()
        let carla = element(app, "group_import_match_Carla")
        XCTAssertTrue(carla.waitForExistence(timeout: 10), "No se abrió la hoja de emparejar.")
        let apply = app.buttons["group_import_apply"]
        // El otro miembro se propone solo (mismo nombre): ya hay algo que poner.
        XCTAssertTrue(apply.isEnabled, "Con el miembro propuesto, «Poner saldos» tiene que estar activo.")
        capture(app, "8-emparejar")
        apply.tap()

        // Lo puesto queda marcado y Carla sigue esperando.
        let done = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Saldo puesto")).firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 10), "No se marcó el saldo puesto.")
        XCTAssertTrue(carla.exists, "Carla no se unió: tiene que seguir esperando.")
        XCTAssertFalse(apply.isEnabled, "Sin nadie más emparejado no queda nada que poner.")
        capture(app, "9-saldo-puesto")

        app.buttons["group_import_match_close"].tap()
        XCTAssertTrue(banner.waitForExistence(timeout: 5), "Con Carla pendiente el aviso sigue.")
        let balances = app.buttons["group_detail_tab_balances"]
        XCTAssertTrue(balances.waitForExistence(timeout: 5))
        balances.tap()
        capture(app, "10-saldos-del-grupo")
    }

    // MARK: - Ayudas

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    /// Baja con arrastres cortos hasta que el elemento se puede tocar y, si se pasa `above`, queda por encima de él.
    private func scrollTo(_ app: XCUIApplication, _ element: XCUIElement, above bar: XCUIElement? = nil) {
        _ = element.waitForExistence(timeout: 5)
        func reachable() -> Bool {
            guard element.exists, element.isHittable else { return false }
            guard let bar else { return true }
            return element.frame.maxY < bar.frame.minY - 8
        }
        var tries = 0
        while !reachable() && tries < 10 {
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
            start.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)))
            tries += 1
        }
        XCTAssertTrue(reachable(), "No se llegó a «\(element.identifier)».")
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        guard let dir = ProcessInfo.processInfo.environment["YALA_CAPTURE_DIR"] else { return }
        let url = URL(fileURLWithPath: dir).appendingPathComponent("despues-\(name).png")
        do {
            try app.screenshot().pngRepresentation.write(to: url)
        } catch {
            print("ImportarGrupoUITests: captura no guardada: \(error)")
        }
    }
}
