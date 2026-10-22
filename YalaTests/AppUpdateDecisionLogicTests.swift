//
//  AppUpdateDecisionLogicTests.swift
//  YalaTests
//
//  Lógica pura del banner de actualización: comparación de versiones, gate de cache, storefront
//  en la URL, y el FAIL-CLOSED de "versión desconocida" (gap #5).
//

import Foundation
import Testing

@testable import Yala

@Suite("AppUpdateDecisionLogic — comparación, cache y URL (tabla)")
struct AppUpdateDecisionLogicTests {

    // MARK: - compare

    @Test func compare_ordering() {
        #expect(AppUpdateDecisionLogic.compare(current: "1.0.0", latest: "1.0.0") == .orderedSame)
        #expect(AppUpdateDecisionLogic.compare(current: "1.0.0", latest: "1.0.1") == .orderedAscending)
        #expect(AppUpdateDecisionLogic.compare(current: "1.2.0", latest: "1.3.0") == .orderedAscending)
        #expect(AppUpdateDecisionLogic.compare(current: "1.0.0", latest: "2.0.0") == .orderedAscending)
        #expect(AppUpdateDecisionLogic.compare(current: "2.0.5", latest: "2.0.4") == .orderedDescending)
        // Longitudes distintas: componentes faltantes = 0.
        #expect(AppUpdateDecisionLogic.compare(current: "1.2", latest: "1.2.0") == .orderedSame)
        #expect(AppUpdateDecisionLogic.compare(current: "1.2", latest: "1.2.1") == .orderedAscending)
    }

    @Test func compare_nonNumericSuffix_dropsComponent() {
        // Comportamiento histórico fijado: "2.0.5-beta" → [2, 0] (el "5-beta" no parsea a Int).
        #expect(AppUpdateDecisionLogic.parse("2.0.5-beta") == [2, 0])
        // ⇒ "2.0.5-beta" (=[2,0]) es MENOR que "2.0.5" (=[2,0,5]).
        #expect(AppUpdateDecisionLogic.compare(current: "2.0.5-beta", latest: "2.0.5") == .orderedAscending)
    }

    // MARK: - isUpdateAvailable (fail-closed)

    @Test func isUpdateAvailable_true_whenCurrentBelowLatest() {
        #expect(AppUpdateDecisionLogic.isUpdateAvailable(current: "2.0.4", latest: "2.0.5"))
        #expect(AppUpdateDecisionLogic.isUpdateAvailable(current: "1.9.9", latest: "2.0.0"))
    }

    @Test func isUpdateAvailable_false_whenEqualOrNewer() {
        #expect(!AppUpdateDecisionLogic.isUpdateAvailable(current: "2.0.5", latest: "2.0.5"))
        #expect(!AppUpdateDecisionLogic.isUpdateAvailable(current: "2.0.6", latest: "2.0.5"))
    }

    @Test func isUpdateAvailable_failClosed_whenVersionUnknown() {
        // gap #5: current vacío/no numérico (CFBundleShortVersionString ausente) → NO molestar.
        #expect(!AppUpdateDecisionLogic.isUpdateAvailable(current: "", latest: "2.0.5"))
        #expect(!AppUpdateDecisionLogic.isUpdateAvailable(current: "abc", latest: "2.0.5"))
        // latest vacío (respuesta rara del store) → tampoco.
        #expect(!AppUpdateDecisionLogic.isUpdateAvailable(current: "2.0.5", latest: ""))
    }

    // MARK: - shouldCheckNetwork

    @Test func shouldCheckNetwork_gate() {
        let cache: TimeInterval = 24 * 60 * 60
        let now = Date(timeIntervalSince1970: 1_000_000)
        // Nunca chequeó → sí.
        #expect(AppUpdateDecisionLogic.shouldCheckNetwork(lastChecked: nil, now: now, cacheDuration: cache))
        // Dentro de la ventana → no.
        #expect(!AppUpdateDecisionLogic.shouldCheckNetwork(
            lastChecked: now.addingTimeInterval(-3600), now: now, cacheDuration: cache))
        // Justo en el borde (>= venció) → sí.
        #expect(AppUpdateDecisionLogic.shouldCheckNetwork(
            lastChecked: now.addingTimeInterval(-cache), now: now, cacheDuration: cache))
        // Más allá de la ventana → sí.
        #expect(AppUpdateDecisionLogic.shouldCheckNetwork(
            lastChecked: now.addingTimeInterval(-cache - 1), now: now, cacheDuration: cache))
    }

    // MARK: - makeLookupURL (storefront)

    @Test func makeLookupURL_usesLowercasedRegion() throws {
        let url = try #require(AppUpdateDecisionLogic.makeLookupURL(bundleID: "com.test", regionCode: "PE"))
        let items = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        #expect(items.contains(URLQueryItem(name: "country", value: "pe")))
        #expect(items.contains(URLQueryItem(name: "bundleId", value: "com.test")))
        #expect(url.absoluteString.hasPrefix("https://itunes.apple.com/lookup"))
    }

    @Test func makeLookupURL_fallsBackToUS_whenRegionNil() throws {
        let url = try #require(AppUpdateDecisionLogic.makeLookupURL(bundleID: "com.test", regionCode: nil))
        let items = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        #expect(items.contains(URLQueryItem(name: "country", value: "us")))
    }
}
