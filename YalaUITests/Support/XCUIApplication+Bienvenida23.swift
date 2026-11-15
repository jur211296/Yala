//
//  XCUIApplication+Bienvenida23.swift
//  YalaUITests
//
//  Bienvenida 2.3 (`docs/onboarding-2-3/SPEC.md`, Y23-01 / Y23-03 / Y23-06): el primer nivel del Welcome ya no es el Hero
//  con «Empezar» ni el elector de tres tarjetas, sino la vitrina con sus accesos. Estos helpers son los caminos nuevos
//  que sustituyen a los toques viejos (`welcome_hero_cta`, `welcome_chooser_*`):
//
//  · «Es mi primera vez» → «Entrar con mi iCloud» (`welcome_access_icloud`): la misma puerta privada.
//  · «Ya tengo una cuenta» (Restaurar) → «Entrar con mi iCloud» con iCloud con datos (`-uitest-private-gate-icloud-has-data`)
//    y «Traer mis datos» (`welcome_private_icloud_restore`).
//  · «Vengo por un grupo» → la puerta de Grupos de la vitrina (con `-uitest-cloud-chooser`, que destapa Google y Apple
//    bajo uitest) y un proveedor: aparece el 2.º nivel de Grupos (crear, enlace, solo cuenta).
//

import XCTest

extension XCUIApplication {

    /// Seam de lanzamiento que destapa Google y Apple en la vitrina bajo uitest (sin él, solo hay iCloud).
    static let welcomeProvidersArgument = "-uitest-cloud-chooser"
    /// Seam de lanzamiento: la puerta privada encuentra datos en iCloud y ofrece «Traer mis datos».
    static let welcomeICloudHasDataArgument = "-uitest-private-gate-icloud-has-data"

    /// La vitrina está en pantalla: su acceso de iCloud está siempre (con y sin proveedores).
    @discardableResult
    func waitForWelcomeShowcase(timeout: TimeInterval = 60, file: StaticString = #filePath, line: UInt = #line) -> Bool {
        let icloud = buttons["welcome_access_icloud"]
        let shown = icloud.waitForExistence(timeout: timeout)
        XCTAssertTrue(shown, "No apareció la vitrina de la bienvenida («Entrar con mi iCloud»).", file: file, line: line)
        return shown
    }

    /// «Entrar con mi iCloud»: la puerta privada (lo que antes era «Es mi primera vez» → «En tu iCloud»).
    func tapWelcomeICloud(timeout: TimeInterval = 60, file: StaticString = #filePath, line: UInt = #line) {
        guard waitForWelcomeShowcase(timeout: timeout, file: file, line: line) else { return }
        buttons["welcome_access_icloud"].tap()
    }

    /// «Entrar con mi iCloud» con iCloud con datos y «Traer mis datos»: Restaurar (lo que antes era «Ya tengo una
    /// cuenta» con el bypass de uitest). Exige lanzar con `welcomeICloudHasDataArgument`.
    func openWelcomeRestore(timeout: TimeInterval = 60, file: StaticString = #filePath, line: UInt = #line) {
        tapWelcomeICloud(timeout: timeout, file: file, line: line)
        let restore = buttons["welcome_private_icloud_restore"]
        XCTAssertTrue(restore.waitForExistence(timeout: 20),
                      "La puerta privada no ofreció «Traer mis datos» (¿se lanzó con -uitest-private-gate-icloud-has-data?).",
                      file: file, line: line)
        restore.tap()
    }

    /// La puerta de Grupos de la vitrina y un proveedor: el 2.º nivel de Grupos (lo que antes era «Vengo por un
    /// grupo»). Exige lanzar con `welcomeProvidersArgument`. Con sesión fingida, la hoja de Grupos reusa la sesión y
    /// no lanza el proveedor elegido.
    func openWelcomeGroupsPaths(provider: String = "google", timeout: TimeInterval = 60,
                                file: StaticString = #filePath, line: UInt = #line) {
        guard waitForWelcomeShowcase(timeout: timeout, file: file, line: line) else { return }
        // Pausa antes de elegir la función de grupos: si la vitrina rota, el atajo desaparece con su función.
        buttons["welcome_showcase_pause"].tap()
        let segment = buttons["welcome_showcase_segment_splitAny"]
        XCTAssertTrue(segment.waitForExistence(timeout: 5), "Falta el segmento de «Divide cualquier gasto».",
                      file: file, line: line)
        segment.tap()
        let door = buttons["welcome_showcase_groups_door"]
        XCTAssertTrue(door.waitForExistence(timeout: 5),
                      "No apareció «Dividir gastos con amigos» (¿se lanzó con -uitest-cloud-chooser?).",
                      file: file, line: line)
        door.tap()
        let access = buttons["welcome_access_\(provider)"]
        XCTAssertTrue(access.waitForExistence(timeout: 5), "La puerta de Grupos no ofrece \(provider).",
                      file: file, line: line)
        access.tap()
        XCTAssertTrue(buttons["welcome_groups_create"].waitForExistence(timeout: 10),
                      "No apareció el 2.º nivel de Grupos.", file: file, line: line)
    }
}
