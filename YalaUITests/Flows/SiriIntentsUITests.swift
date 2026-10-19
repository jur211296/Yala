//
//  SiriIntentsUITests.swift
//  YalaUITests
//
//  Las acciones de Siri de 2.2 corridas como las corre el sistema, con App Intents Testing (WWDC26): fuera del proceso
//  de la app y sin Siri de por medio. Card «Integrar Yala con el nuevo Siri con IA de iOS 27».
//  · La cuenta que Siri encuentra sale de la foto que escribe la app real al arrancar (`SiriFinanceSnapshot`).
//  · «¿Cuánto tengo?» y «¿Cuánto gasté?» corren sin abrir nada.
//  · «Abrir cuenta» (iOS 27, esquema `.system.open`) abre la ficha de esa cuenta en el Panel.
//  Lo que Siri DICE no se puede leer desde aquí (el marco no expone el diálogo): lo fijan `SiriFinanceSpeechTests`.
//  Seed `minimal`. Convenciones: CLAUDE.md (sin sleeps, scheme Yala Dev).
//

// App Intents Testing llega con Xcode 27; el CI compila con Xcode 26.6 y ahí esta suite no existe.
#if canImport(AppIntentsTesting)
import AppIntentsTesting
import XCTest

@available(iOS 27.0, *)
final class SiriIntentsUITests: XCTestCase {

    private let bundleIdentifier = "com.jurgenschmidt.yala.dev"
    private var app: XCUIApplication!
    private var definitions: IntentDefinitions!

    override func setUp() async throws {
        continueAfterFailure = false
        app = await XCUIApplication()
        await app.launchForUITest()
        let ready = await app.waitForUITestReady()
        XCTAssertTrue(ready, "uitest_ready ausente — bootstrap/seed no completó.")
        definitions = IntentDefinitions(bundleIdentifier: bundleIdentifier)
    }

    /// Siri encuentra las cuentas del Panel, por nombre y por id.
    func test_accountEntity_findsTheSeededAccounts() async throws {
        let accountDefinition = definitions.entities["YalaAccountEntity"]
        let suggested = try await accountDefinition.suggestedEntities()
        XCTAssertFalse(suggested.isEmpty, "Siri no ve ninguna cuenta: la foto no se escribió al arrancar.")

        let name: String = try suggested[0].name
        let matched = try await accountDefinition.entities(matching: name)
        let matchedNames: [String] = try matched.map { try $0.name }
        XCTAssertTrue(matchedNames.contains(name), "Buscar «\(name)» no devuelve esa cuenta: \(matchedNames)")

        let none = try await accountDefinition.entities(matching: "una cuenta que no existe 9f3")
        XCTAssertTrue(none.isEmpty)
    }

    /// Las dos preguntas corren sin abrir la app y sin error, con y sin parámetros.
    func test_spendingAndBalanceQueries_runWithoutOpeningTheApp() async throws {
        let lastMonth = definitions.enums["SiriSpendingPeriodOption"].makeCase("lastMonth")
        _ = try await definitions.intents["SpendingQueryIntent"].makeIntent(period: lastMonth).run()
        _ = try await definitions.intents["BalanceQueryIntent"].makeIntent().run()

        let account = try await definitions.entities["YalaAccountEntity"].suggestedEntities()
        let first = try XCTUnwrap(account.first)
        _ = try await definitions.intents["BalanceQueryIntent"].makeIntent(account: first).run()
    }

    /// «Abrir cuenta» abre la ficha de esa cuenta, por el camino del aviso de la tarjeta.
    func test_openAccount_opensItsDetailSheet() async throws {
        let account = try await definitions.entities["YalaAccountEntity"].suggestedEntities()
        let first = try XCTUnwrap(account.first, "Siri no ve ninguna cuenta.")
        _ = try await definitions.intents["OpenAccountIntent"].makeIntent(target: first).run()

        let sheet = await app.descendants(matching: .any)["account_detail_sheet"].firstMatch
        let opened = await sheet.waitForExistence(timeout: 15)
        XCTAssertTrue(opened, "«Abrir cuenta» no abrió la ficha de la cuenta.")
    }
}
#endif
