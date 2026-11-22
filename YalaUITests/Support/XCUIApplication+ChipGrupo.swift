//
//  XCUIApplication+ChipGrupo.swift
//  YalaUITests
//
//  El editor de la Bandeja con chip de grupo (22-nov-2026): el enlace «Convertir a gasto compartido» pasó a un chip de
//  la fila de abajo, y «Guardar y hacer recurrente» al menú «…». Estos dos pasos los repiten varias clases.
//

import XCTest

extension XCUIApplication {

    /// Elige `groupName` en el chip de grupo y toca «Guardar», que sigue el flujo de convertir a compartido con ese grupo
    /// (un solo grupo: el form de grupo abre directo).
    func chooseDraftGroupAndSave(_ groupName: String, file: StaticString = #filePath, line: UInt = #line) {
        let chip = buttons["draft_editor_group_chip"]
        XCTAssertTrue(chip.waitForExistence(timeout: 10), "El editor no ofrece el chip de grupo.", file: file, line: line)
        chip.tap()
        let item = buttons[groupName].firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 5), "El menú del chip no ofrece «\(groupName)».", file: file, line: line)
        item.tap()
        XCTAssertTrue(
            chip.waitForValue(groupName, timeout: 5),
            "El chip no pasó a decir «\(groupName)» (valor: \(chip.value as? String ?? "")).", file: file, line: line)
        let save = buttons["inbox_approve_button"]
        XCTAssertTrue(save.waitForEnabled(timeout: 5), "«Guardar» no se encendió con el grupo elegido.", file: file, line: line)
        save.tap()
    }

    /// Abre el menú «…» del editor de la Bandeja y devuelve «Guardar y hacer recurrente».
    func draftApproveAndMakeRecurringItem(file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let more = buttons["draft_editor_more"]
        XCTAssertTrue(more.waitForExistence(timeout: 10), "El editor no tiene el menú «…».", file: file, line: line)
        more.tap()
        return buttons["inbox_approve_and_make_recurring_button"]
    }
}

private extension XCUIElement {

    /// Espera a que el `value` de accesibilidad sea `expected`.
    func waitForValue(_ expected: String, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "value == %@", expected)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    /// Espera a que el elemento esté activo.
    func waitForEnabled(timeout: TimeInterval) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: self)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
