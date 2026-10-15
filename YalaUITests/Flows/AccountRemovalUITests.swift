//
//  AccountRemovalUITests.swift
//  YalaUITests
//
//  Eliminar una cuenta con movimientos: la app pregunta si moverlos o borrarlos (decisión A, 2026-10-15).
//  Card `tablero-al-eliminar-una-cuenta-sus-movimientos-q-ofst`. Seed `cuenta-con-movimientos`: «Efectivo QA»
//  (Taxi −25, Teléfono −33), «Banco QA» (Sueldo +1.000) y «Dólares QA» (vacía), todas sin más datos.
//

import XCTest

final class AccountRemovalUITests: XCTestCase {

    private let source = "Efectivo QA"
    private let bank = "Banco QA"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Abre el formulario de «Efectivo QA» y toca «Eliminar cuenta».
    private func openRemoval(_ app: XCUIApplication) {
        app.launchForUITest(seed: "cuenta-con-movimientos")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        app.openProfile()
        app.openSettingsSection("profile_accounts")

        let row = app.buttons["accounts_row_\(source)"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "El seed no dejó «\(source)».")
        row.tap()

        let delete = app.buttons["account_delete_button"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5), "No apareció «Eliminar cuenta».")
        // `isHittable` LANZA con el elemento entero fuera de pantalla (`testing.md`): se mira el marco.
        var swipes = 0
        while !app.windows.firstMatch.frame.contains(delete.frame) && swipes < 8 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(delete.waitForHittable(timeout: 3), "«Eliminar cuenta» no quedó a la vista.")
        delete.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["account_removal_sheet"].waitForExistence(timeout: 5),
            "Eliminar una cuenta con movimientos no preguntó: la cuenta se habría eliminado sin más.")
        let count = app.descendants(matching: .any)["account_removal_count_records"]
        XCTAssertTrue(count.waitForExistence(timeout: 5), "La hoja no dice cuántos movimientos hay.")
        XCTAssertTrue(count.label.hasSuffix(" 2"), "La hoja debía contar 2 movimientos y dice «\(count.label)».")
    }

    /// Mover (la opción por defecto) a «Banco QA»: la cuenta desaparece y su saldo pasa al destino (1.000 − 58).
    func test_deleteAccountWithRecords_movesThemToAnotherAccount() {
        let app = XCUIApplication()
        openRemoval(app)

        let destination = app.buttons["account_removal_destination_\(bank)"]
        XCTAssertTrue(destination.waitForExistence(timeout: 5), "No aparece «\(bank)» como destino.")
        XCTAssertTrue(destination.isSelected, "El destino por defecto debía ser la cuenta en la misma moneda.")

        let proceed = app.buttons["account_removal_proceed"]
        XCTAssertTrue(proceed.waitForHittable(timeout: 5))
        proceed.tap()

        let gone = expectation(
            for: NSPredicate(format: "exists == false"), evaluatedWith: app.buttons["accounts_row_\(source)"])
        wait(for: [gone], timeout: 10)
        let bankRow = app.buttons["accounts_row_\(bank)"]
        let movedBalance = expectation(for: NSPredicate(format: "label CONTAINS '942'"), evaluatedWith: bankRow)
        wait(for: [movedBalance], timeout: 10)
    }

    /// Borrar pide confirmación con la cifra; al confirmar, la cuenta y sus dos movimientos desaparecen y el
    /// saldo del resto no cambia.
    func test_deleteAccountWithRecords_deletesThemAfterConfirming() {
        let app = XCUIApplication()
        openRemoval(app)

        let deleteOption = app.buttons["account_removal_option_delete"]
        XCTAssertTrue(deleteOption.waitForHittable(timeout: 5))
        deleteOption.tap()
        let proceed = app.buttons["account_removal_proceed"]
        XCTAssertTrue(proceed.waitForHittable(timeout: 5))
        proceed.tap()

        let confirmCount = app.descendants(matching: .any)["account_removal_confirm_count"]
        XCTAssertTrue(confirmCount.waitForExistence(timeout: 5), "Borrar no pidió confirmación.")
        XCTAssertTrue(confirmCount.label.hasSuffix(" 2"), "La confirmación debía decir 2: «\(confirmCount.label)».")
        XCTAssertTrue(
            app.buttons["accounts_row_\(source)"].exists, "La cuenta se eliminó antes de confirmar.")

        let confirm = app.buttons["account_removal_confirm_delete"]
        XCTAssertTrue(confirm.waitForHittable(timeout: 5))
        confirm.tap()

        let gone = expectation(
            for: NSPredicate(format: "exists == false"), evaluatedWith: app.buttons["accounts_row_\(source)"])
        wait(for: [gone], timeout: 10)
        let bankRow = app.buttons["accounts_row_\(bank)"]
        XCTAssertTrue(bankRow.waitForExistence(timeout: 5))
        XCTAssertTrue(bankRow.label.contains("1,000") || bankRow.label.contains("1.000"),
                      "Borrar no debía tocar «\(bank)»: «\(bankRow.label)».")
        XCTAssertFalse(bankRow.label.contains("942"), "Borrar movió los movimientos en vez de borrarlos.")
    }
}
