//
//  SiriOnDeviceEntryUITests.swift
//  YalaUITests
//
//  «Anotar con Siri» sin Pro (auditoría UX 2.2, L15-6, encendido el 2026-10-21): con el modelo del iPhone listo, el
//  dictado se lee en el teléfono y deja el borrador en la Bandeja; sin él, Siri abre Yala en la hoja de Pro.
//  El intent se corre como lo corre el sistema, con App Intents Testing (molde `SiriIntentsUITests`). El simulador no
//  tiene el modelo de Apple: `-uitest-siri-model` lo finge, y con `available` la lectura es un stub cuya nota
//  (`QA modelo del iPhone`) no sale de ningún otro camino. La decisión del gate, sin seam, la fija `SiriEntryRouteTests`.
//  Seed `minimal`, sin Pro. Convenciones: CLAUDE.md (sin sleeps, scheme Yala Dev).
//

// App Intents Testing llega con Xcode 27; el CI compila con Xcode 26.6 y ahí esta suite no existe.
#if canImport(AppIntentsTesting)
import AppIntentsTesting
import XCTest

@available(iOS 27.0, *)
final class SiriOnDeviceEntryUITests: XCTestCase {

    private let bundleIdentifier = "com.jurgenschmidt.yala.dev"
    private let dictation = "Anota 20 soles en almuerzo"

    override func setUp() async throws {
        continueAfterFailure = false
    }

    private func launch(model: String) async -> XCUIApplication {
        let app = await XCUIApplication()
        await app.launchForUITest(pro: false, extraArguments: ["-uitest-siri-model", model])
        let ready = await app.waitForUITestReady()
        XCTAssertTrue(ready, "uitest_ready ausente — bootstrap/seed no completó.")
        return app
    }

    private func runSiriEntry() async throws {
        let definitions = IntentDefinitions(bundleIdentifier: bundleIdentifier)
        _ = try await definitions.intents["SiriNaturalEntryIntent"].makeIntent(text: dictation).run()
    }

    /// Gratis y sin el modelo: la hoja de Pro de la voz, como hasta hoy.
    func test_free_withoutTheModel_opensTheProSheet() async throws {
        let app = await launch(model: "deviceNotEligible")
        try await runSiriEntry()

        let proSheet = await app.buttons["upgrade_prompt_cta"].firstMatch
        let shown = await proSheet.waitForExistence(timeout: 15)
        XCTAssertTrue(shown, "Sin el modelo del iPhone, Siri tenía que abrir la hoja de Pro (upgrade_prompt_cta).")
        await attachScreenshot(app, "siri-gratis-sin-modelo-hoja-de-pro")
    }

    /// Gratis y con el modelo apagado o sin descargar: también la hoja de Pro.
    func test_free_withTheModelNotReady_opensTheProSheet() async throws {
        let app = await launch(model: "modelNotReady")
        try await runSiriEntry()

        let shown = await app.buttons["upgrade_prompt_cta"].firstMatch.waitForExistence(timeout: 15)
        XCTAssertTrue(shown, "Con el modelo sin descargar, Siri tenía que abrir la hoja de Pro (upgrade_prompt_cta).")
    }

    /// Sale a segundo plano y vuelve: la vuelta convierte la cola de Siri en borradores y reescribe la caché que lee el
    /// intent (cuentas, subcategorías).
    private func backgroundAndBack(_ app: XCUIApplication, _ when: String) async {
        await XCUIDevice.shared.press(.home)
        let background = await app.wait(for: .runningBackground, timeout: 15)
        XCTAssertTrue(background, "Yala no pasó a segundo plano \(when).")
        await app.activate()
        let foreground = await app.wait(for: .runningForeground, timeout: 15)
        XCTAssertTrue(foreground, "Yala no volvió a primer plano \(when).")
    }

    /// Gratis y con el modelo listo: el borrador del teléfono en la Bandeja, sin hoja de Pro.
    func test_free_withTheModel_leavesTheDraftInTheInbox() async throws {
        let app = await launch(model: "available")
        try await runSiriEntry()

        let proSheet = await app.buttons["upgrade_prompt_cta"].firstMatch
        let paywall = await proSheet.waitForExistence(timeout: 5)
        XCTAssertFalse(paywall, "Con el modelo del iPhone listo, Siri no tenía que abrir la hoja de Pro.")

        // El intent deja el dictado en la cola del App Group; la app lo convierte en borrador al volver a primer plano.
        await backgroundAndBack(app, "tras dictar")

        let inboxButton = await app.buttons["panel_inbox_button"].firstMatch
        let hasInbox = await inboxButton.waitForExistence(timeout: 10)
        XCTAssertTrue(hasInbox, "No apareció el botón de la Bandeja en el Panel.")
        await inboxButton.tap()

        let draft = await app.buttons["inbox_draft_row_QA modelo del iPhone"].firstMatch
        let drafted = await draft.waitForExistence(timeout: 15)
        XCTAssertTrue(drafted, "El dictado leído en el teléfono tenía que dejar su borrador en la Bandeja.")
        await attachScreenshot(app, "siri-gratis-con-modelo-borrador-en-bandeja")
    }

    private func attachScreenshot(_ app: XCUIApplication, _ name: String) async {
        let shot = await app.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
#endif
