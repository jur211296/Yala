//
//  DevSeedExchangeRatesFaceTests.swift
//  YalaTests
//
//  Pin del seam B1: el seed uitest escribe la cara post-pull del blob FX (strings
//  escala-8), no Doubles nativos. Un seed que solo escribe Doubles es un falso verde
//  para Mini — decodedRates() seguiría pasando si alguien revirtiera el decoder tolerante.
//  Ticket: Bugs/qa_cloud-fx-rates-blob-dos-caras.md
//

import Foundation
import Testing

@testable import Yala

#if DEBUG
@Suite("DevSeed FX · cara string escala-8")
struct DevSeedExchangeRatesFaceTests {

    private let twinRates: [String: Double] = ["ILS": 3.6123, "PEN": 3.75, "USD": 1.0]

    @Test func encodeScale8StringFaceBlob_valuesAreScale8DecimalStrings() throws {
        let blob = try DevSeedExchangeRates.encodeScale8StringFaceBlob(twinRates)
        let object = try #require(JSONSerialization.jsonObject(with: blob) as? [String: Any])

        #expect(object["ILS"] as? String == "3.61230000")
        #expect(object["PEN"] as? String == "3.75000000")
        #expect(object["USD"] as? String == "1.00000000")
        #expect(object["ILS"] is NSNumber == false)
        #expect(object["PEN"] is Double == false)
    }

    @Test func encodeScale8StringFaceBlob_strictDoubleDecoderFails() throws {
        // El decoder pre-fix era JSONDecoder().decode([String: Double]). Si el seed
        // volviera a escribir Doubles nativos, este decode PASARÍA y Mini tendría
        // un verde ciego. La cara-string tiene que tumbarlo.
        let blob = try DevSeedExchangeRates.encodeScale8StringFaceBlob(twinRates)
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode([String: Double].self, from: blob)
        }
    }

    @Test func stringFaceBlob_decodesToSameRatesAsNativeDoubleTwin() throws {
        let native = try ExchangeRate(
            dateKey: "2026-07-12",
            base: "USD",
            ratesDictionary: twinRates
        )
        let stringFace = ExchangeRate(
            dateKey: "2026-07-12",
            base: "USD",
            rates: try DevSeedExchangeRates.encodeScale8StringFaceBlob(twinRates)
        )
        #expect(stringFace.decodedRates() == native.decodedRates())
        #expect(stringFace.decodedRates() == ["ILS": 3.6123, "PEN": 3.75, "USD": 1.0])
    }
}
#endif

@Suite("DevSeed FX · cableado (source-scan)")
struct DevSeedExchangeRatesFaceWiringTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    private static func code(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    @Test func seedWritesStringFace_notNativeDoubles() throws {
        let seed = try Self.code("Yala/Seed/DevSeedExchangeRates.swift")
        #expect(seed.contains("encodeScale8StringFaceBlob("), """
            el seed uitest dejó de pasar por el encoder cara-string. Sin él, `-uitest-seed` \
            vuelve a escribir Doubles nativos y Mini obtiene un verde ciego si alguien \
            revierte el decoder tolerante.
            """)
        #expect(seed.contains("ratesDictionary") == false, """
            DevSeedExchangeRates volvió a ExchangeRate(ratesDictionary:), que serializa \
            Doubles nativos. Ese camino no discrimina las dos caras del blob.
            """)
    }

    @Test func uitestSeedPath_stillCallsDevSeedExchangeRates() throws {
        let service = try Self.code("Yala/Seed/DevSeedService.swift")
        #expect(service.contains("DevSeedExchangeRates.create("), """
            DevSeedService ya no siembra tasas. El launch `-uitest -uitest-seed <perfil>` \
            no plantaría la cara-string y Mini no tendría blob que discriminar.
            """)

        let bootstrap = try Self.code("Yala/App/AppBootstrapper.swift")
        #expect(bootstrap.contains("UITestHooks.seedProfile"), """
            applyUITestSeed dejó de leer `-uitest-seed`. El perfil existente ya no llega \
            al seed cara-string.
            """)
        #expect(bootstrap.contains("DevSeedService().seed("), """
            applyUITestSeed dejó de llamar DevSeedService. El flag `-uitest-seed` queda \
            como no-op.
            """)
        #expect(bootstrap.contains("Self.restoreUITestSecondaryCurrencies(into:"), """
            applyUITestSeed ya no restaura secondaryCurrencies tras el seed. \
            `-uitest-reset` las borra y el gráfico del Panel pinta empty state: \
            Mini no ve panel_exchange_rate_widget.
            """)
        let seedCall = try #require(bootstrap.range(of: "DevSeedService().seed("))
        let restoreCall = try #require(bootstrap.range(of: "Self.restoreUITestSecondaryCurrencies(into:"))
        #expect(seedCall.lowerBound < restoreCall.lowerBound, """
            la restauración de secondaryCurrencies se movió ANTES del seed. \
            Tiene que ir después: el wipe ya corrió, el seed no las toca, \
            y Mini las necesita para montar el gráfico.
            """)
    }

    @Test func panelChart_exposesStableEnglishSnakeIdentifier() throws {
        let widget = try Self.code("Yala/App/Views/Panel/ExchangeRateWidget.swift")
        #expect(widget.contains(".accessibilityIdentifier(\"panel_exchange_rate_widget\")"), """
            desapareció el id del gráfico del Panel. Mini no tiene ancla estable para \
            afirmar el widget in-app (no es la extensión WidgetKit).
            """)
    }

    @Test func panelThematicSection_containsChildrenSoWidgetIdSurvives() throws {
        let section = try Self.code("Yala/App/Views/Panel/Sections/PanelThematicSection.swift")
        #expect(section.contains(".accessibilityElement(children: .contain)"), """
            PanelThematicSection perdió children: .contain. Un identifier en el \
            contenedor vuelve a pisar a los hijos: Mini solo ve panel_section_tools \
            y panel_exchange_rate_widget no aparece en el árbol.
            """)
        #expect(section.contains(".accessibilityIdentifier(\"panel_section_\\(kind.rawValue)\")"), """
            desapareció el id de sección interpolado. Las 7 secciones del Panel \
            (accounts/health/tendencias/distribucion/planificacion/latestRecords/tools) \
            dejan de exponer panel_section_<kind>.
            """)
        #expect(section.contains("children: .ignore") == false, """
            PanelThematicSection usa children: .ignore — eso oculta los ids hijos \
            (panel_exchange_rate_widget). El patrón correcto es children: .contain \
            ANTES del identifier de sección.
            """)
        #expect(section.contains("children: .combine") == false, """
            PanelThematicSection usa children: .combine — fusiona hijos en un solo \
            elemento y Mini no puede afirmar panel_exchange_rate_widget por id.
            """)
        let contain = try #require(section.range(of: ".accessibilityElement(children: .contain)"))
        let sectionId = try #require(
            section.range(of: ".accessibilityIdentifier(\"panel_section_\\(kind.rawValue)\")")
        )
        #expect(contain.lowerBound < sectionId.lowerBound, """
            children: .contain tiene que ir ANTES del identifier de sección. \
            Al revés, SwiftUI trata el contenedor como un solo elemento y pisa \
            los ids hijos.
            """)
    }

    @Test func panelDashboardUITests_stillTargetSectionIdentifier() throws {
        let ui = try Self.code("YalaUITests/Flows/PanelDashboardUITests.swift")
        #expect(ui.contains("panel_section_planificacion"), """
            PanelDashboardUITests dejó de afirmar panel_section_planificacion. \
            El cambio a children: .contain no debe romper el id de las otras \
            secciones; este test es el ancla XCUI de ese contrato.
            """)
    }
}

#if DEBUG
@MainActor
@Suite("DevSeed FX · restore secondaryCurrencies (F1)")
struct DevSeedExchangeRatesSecondaryRestoreTests {

    @Test func restoreUITestSecondaryCurrencies_writesUSDandEUR() {
        let defaults = makeIsolatedDefaults(prefix: "fx.secondary")
        defaults.removeObject(forKey: AppPreferences.Keys.secondaryCurrencies)
        #expect(defaults.string(forKey: AppPreferences.Keys.secondaryCurrencies) == nil)

        AppBootstrapper.restoreUITestSecondaryCurrencies(into: defaults)

        #expect(defaults.string(forKey: AppPreferences.Keys.secondaryCurrencies) == "USD,EUR")
        let prefs = AppPreferences(defaults: defaults)
        #expect(prefs.secondaryCurrencies == ["USD", "EUR"])
    }
}
#endif

@Suite("Panel · section identifiers")
struct PanelSectionKindIdentifierTests {

    @Test func allCases_keepStableRawValuesUsedAsAccessibilityIds() {
        let expected = [
            "accounts",
            "health",
            "tendencias",
            "distribucion",
            "planificacion",
            "latestRecords",
            "tools",
        ]
        #expect(PanelSectionKind.allCases.map(\.rawValue) == expected, """
            cambió un rawValue de PanelSectionKind. Los XCUITests y Mini buscan \
            panel_section_<rawValue>; un rename rompe el árbol sin tocar el widget.
            """)
    }
}
