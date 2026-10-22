//
//  OrphanedRecordsUITests.swift
//  YalaUITests
//
//  Movimientos que se quedaron sin cuenta por un borrado anterior: el Panel avisa con la cifra, deja elegir a qué
//  cuenta moverlos y, movidos, vuelven al saldo. Card `tablero-los-movimientos-que-quedaron-sin-cuenta-sovw`.
//  Seed `movimientos-sin-cuenta`: el corpus de `cuenta-con-movimientos` con «Efectivo QA» eliminada a pelo, así que
//  Taxi −25 y Teléfono −33 están sin cuenta, «Banco QA» tiene el Sueldo +1.000 y «Dólares QA» está vacía.
//

import XCTest

final class OrphanedRecordsUITests: XCTestCase {

    private let bank = "Banco QA"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// El aviso sale con la cifra; la hoja cuenta 2 y propone «Banco QA» (misma moneda); al mover, el aviso se va y el
    /// saldo de «Banco QA» pasa de 1.000 a 942.
    func test_orphanedRecords_noticeCountsThem_andMovingThemRestoresTheBalance() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "movimientos-sin-cuenta")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        let banner = app.buttons["orphaned_records_banner"]
        XCTAssertTrue(banner.waitForExistence(timeout: 10), "El Panel no avisa de los movimientos sin cuenta.")
        XCTAssertTrue(banner.label.contains("2"), "El aviso debía decir 2: «\(banner.label)».")
        banner.tap()

        let count = app.descendants(matching: .any)["orphaned_records_count"]
        XCTAssertTrue(count.waitForExistence(timeout: 5), "La hoja no dice cuántos movimientos son.")
        XCTAssertTrue(count.label.hasSuffix(" 2"), "La hoja debía contar 2 y dice «\(count.label)».")

        let destination = app.buttons["orphaned_records_destination_\(bank)"]
        XCTAssertTrue(destination.waitForExistence(timeout: 5), "No aparece «\(bank)» como destino.")
        XCTAssertTrue(destination.isSelected, "El destino por defecto debía ser la cuenta en la misma moneda.")

        let move = app.buttons["orphaned_records_move"]
        XCTAssertTrue(move.waitForHittable(timeout: 5))
        move.tap()

        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: banner)
        wait(for: [gone], timeout: 10)

        app.openProfile()
        app.openSettingsSection("profile_accounts")
        let bankRow = app.buttons["accounts_row_\(bank)"]
        let moved = expectation(for: NSPredicate(format: "label CONTAINS '942'"), evaluatedWith: bankRow)
        wait(for: [moved], timeout: 10)
    }

    /// Sin huérfanos no hay aviso. Control del caso de arriba: con `cuenta-con-movimientos` (los mismos datos, la cuenta
    /// sin eliminar) el aviso no sale.
    func test_noOrphanedRecords_noNotice() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "cuenta-con-movimientos")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        // Algo del Panel que sí está, para que la ausencia diga algo.
        XCTAssertTrue(app.descendants(matching: .any)["panel_quick_actions"].waitForExistence(timeout: 10),
                      "El Panel no llegó a pintarse.")
        XCTAssertFalse(app.buttons["orphaned_records_banner"].waitForExistence(timeout: 4),
                       "Sin movimientos sin cuenta no debía salir el aviso.")
    }
}
