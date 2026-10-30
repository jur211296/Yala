//
//  PreferredCurrencyFallbackParityTests.swift
//  YalaTests
//
//  Card 2jj6 (2026-10-30): sin `defaultCurrencyCode` guardado —entre «Empezar de cero» y el onboarding— la app caía a
//  soles, `CurrencyDefaults` a la región y la caché de los widgets a dólares, que además reconvertía todo el histórico.
//  Criterio de Jürgen (card 2h3c, 2026-10-08): si falta, la de la región. Aquí se fija que los lectores caen al MISMO
//  valor y que lo deciden en un solo sitio (`CurrencyDefaults.preferred`).
//

import Foundation
import Testing
@testable import Yala

@MainActor
@Suite("Divisa principal ausente — paridad de lectores")
struct PreferredCurrencyFallbackParityTests {

    private static func makeIsolatedDefaults() throws -> UserDefaults {
        try #require(UserDefaults(suiteName: "PreferredCurrencyFallbackParityTests.\(UUID().uuidString)"))
    }

    // MARK: - La regla

    @Test func preferred_withoutStoredCurrency_isTheRegionOne() {
        #expect(CurrencyDefaults.preferred(storedRaw: nil, regionCode: "US") == .usd)
        #expect(CurrencyDefaults.preferred(storedRaw: nil, regionCode: "PE") == .pen)
        #expect(CurrencyDefaults.preferred(storedRaw: nil, regionCode: "ES") == .eur)
    }

    @Test func preferred_withStoredCurrency_ignoresTheRegion() {
        #expect(CurrencyDefaults.preferred(storedRaw: "EUR", regionCode: "US") == .eur)
    }

    @Test func preferred_withAnUnknownStoredCode_fallsBackToTheRegion() {
        #expect(CurrencyDefaults.preferred(storedRaw: "xxx", regionCode: "PE") == .pen)
    }

    // MARK: - Los lectores, sin divisa guardada

    @Test func readers_withoutStoredCurrency_agree() throws {
        let defaults = try Self.makeIsolatedDefaults()
        #expect(defaults.string(forKey: CurrencyDefaults.preferredCurrencyKey) == nil)

        let expected = CurrencyDefaults.preferred(in: defaults)
        let app = AppPreferences(defaults: defaults).defaultCurrencyCode
        let widgets = WidgetDataCache.preferredCurrencyCode(defaults: defaults)

        #expect(app == expected, "La app pinta \(app.rawValue) y la regla dice \(expected.rawValue).")
        #expect(widgets == expected.rawValue, "Los widgets calculan en \(widgets) y la app pinta \(app.rawValue).")
    }

    @Test func readers_withStoredCurrency_agree() throws {
        let defaults = try Self.makeIsolatedDefaults()
        defaults.set("EUR", forKey: CurrencyDefaults.preferredCurrencyKey)

        #expect(AppPreferences(defaults: defaults).defaultCurrencyCode == .eur)
        #expect(WidgetDataCache.preferredCurrencyCode(defaults: defaults) == "EUR")
    }

    /// «Empezar de cero» borra la key con la app abierta. `AppPreferences` relee por presencia el resto de keys; esta
    /// tiene que volver a la regla, o la app sigue en la divisa de antes mientras los widgets caen a la región.
    @Test func appPreferences_whenTheKeyIsRemoved_fallsBackLikeTheOthers() async throws {
        let defaults = try Self.makeIsolatedDefaults()
        let fallback = CurrencyDefaults.preferred(in: defaults)
        let stored: CurrencyCode = fallback == .eur ? .gbp : .eur
        defaults.set(stored.rawValue, forKey: CurrencyDefaults.preferredCurrencyKey)
        let prefs = AppPreferences(defaults: defaults)
        #expect(prefs.defaultCurrencyCode == stored)

        defaults.removeObject(forKey: CurrencyDefaults.preferredCurrencyKey)
        for _ in 0..<50 where prefs.defaultCurrencyCode != fallback {
            try await Task.sleep(for: .milliseconds(20))
        }

        #expect(prefs.defaultCurrencyCode == fallback)
        #expect(defaults.string(forKey: CurrencyDefaults.preferredCurrencyKey) == nil, "Releer no puede escribir la key.")
    }

    // MARK: - Un solo sitio decide

    /// Nadie en `Yala/` lee la key con un `??` propio: así fue como divergieron los lectores. Un lector nuevo pasa por
    /// `CurrencyDefaults.preferred`.
    @Test func noReaderHasItsOwnFallback() throws {
        let repoRoot = URL(fileURLWithPath: "\(#filePath)").deletingLastPathComponent().deletingLastPathComponent()
        let appRoot = repoRoot.appending(path: "Yala")
        let enumerator = try #require(FileManager.default.enumerator(at: appRoot, includingPropertiesForKeys: nil))
        let pattern = try Regex(#"forKey:\s*(CurrencyDefaults\.preferredCurrencyKey|"defaultCurrencyCode"|Keys\.defaultCurrencyCode)\)\s*\?\?"#)

        var offenders: [String] = []
        var scanned = 0
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            scanned += 1
            let source = try String(contentsOf: url, encoding: .utf8)
            for (index, line) in source.components(separatedBy: "\n").enumerated()
            where !line.trimmingCharacters(in: .whitespaces).hasPrefix("//") && line.contains(pattern) {
                offenders.append("\(url.lastPathComponent):\(index + 1)")
            }
        }

        #expect(scanned > 500, "El scan no recorrió `Yala/` (\(scanned) ficheros).")
        #expect(offenders.isEmpty, "Lectores con su propia divisa por defecto: \(offenders)")
    }
}
