//
//  InviteRecoveryPasteVisibleUITests.swift
//  YalaUITests
//
//  Card zdio (lote 2.3 · UI): en «Pega tu enlace de invitación», con un enlace largo en el campo y el teclado abierto, el
//  botón fijo «Unirme al grupo» tapaba media «Pegar» (QA del iPhone de pruebas, 2026-11-05). El botón «Pegar» es el
//  control del sistema y no acepta toques sintéticos: aquí se mide que no quede debajo de «Unirme al grupo».
//  `YALA_CAPTURES` (vía `TEST_RUNNER_YALA_CAPTURES`) guarda la captura.
//

import XCTest

final class InviteRecoveryPasteVisibleUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    func test_longLinkWithKeyboard_joinButtonDoesNotCoverPaste() {
        let link = "https://yala-app.pe/invite?g=11111111-2222-3333-4444-555555555555&t=uitest-token-largo-para-ocupar-"
            + "varias-lineas-del-campo-de-texto-como-un-enlace-real&n=DepaMirafloresYAmigos"
        let app = XCUIApplication()
        // Bienvenida 2.3 (Y23-06): «Vengo por un grupo» es la puerta de Grupos de la vitrina, con un proveedor.
        app.launchForUITest(skipOnboarding: false, seed: nil, extraArguments: [XCUIApplication.welcomeProvidersArgument])
        app.openWelcomeGroupsPaths()
        let joinCard = app.buttons["welcome_groups_join"]
        XCTAssertTrue(joinCard.waitForExistence(timeout: 10))
        joinCard.tap()

        let paste = app.buttons["invite_recovery_paste"]
        XCTAssertTrue(paste.waitForExistence(timeout: 10), "No hay botón «Pegar».")
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        field.typeText(link)
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "El teclado no está abierto.")
        let join = app.buttons["primary_button"]
        let enabled = expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: join)
        wait(for: [enabled], timeout: 10)
        // Que el teclado y el desplazamiento se asienten antes de medir.
        let settled = expectation(description: "asentado")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { settled.fulfill() }
        wait(for: [settled], timeout: 3)

        capture(app, "pegar-con-enlace-largo")
        XCTAssertLessThanOrEqual(paste.frame.maxY, join.frame.minY,
                                 "«Unirme al grupo» tapa «Pegar»: \(paste.frame) bajo \(join.frame).")
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
        guard let dir = ProcessInfo.processInfo.environment["YALA_CAPTURES"], !dir.isEmpty else { return }
        do {
            try app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
        } catch {
            #if DEBUG
            print("InviteRecoveryPasteVisibleUITests: Error: \(error)")
            #endif
        }
    }
}
