//
//  AppUpdateServiceTests.swift
//  YalaTests
//
//  Integración ligera del servicio con `defaults`/`session`/`now` inyectables: gate de cache
//  (no golpea la red dentro de la ventana), rehidratación de `appStoreURL` desde el `trackId`
//  cacheado, y storefront del device en la URL del lookup.
//

import Foundation
import Testing

@testable import Yala

private final class StubHTTPSession: SyncHTTPSession, @unchecked Sendable {
    var callCount = 0
    private(set) var lastRequest: URLRequest?
    let version: String
    let trackId: Int

    init(version: String = "99.0.0", trackId: Int = 12345) {
        self.version = version
        self.trackId = trackId
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        callCount += 1
        lastRequest = request
        let body = "{\"resultCount\":1,\"results\":[{\"version\":\"\(version)\",\"trackId\":\(trackId)}]}"
        let response = HTTPURLResponse(
            url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (Data(body.utf8), response)
    }
}

@MainActor
@Suite("AppUpdateService — cache, trackId y storefront (inyectable)")
struct AppUpdateServiceTests {

    @Test func checkForUpdate_skipsNetwork_withinCacheWindow() async {
        let defaults = makeIsolatedDefaults()
        let now = Date(timeIntervalSince1970: 2_000_000)
        // Chequeado hace 1h → dentro de la ventana de 24h.
        defaults.set(now.addingTimeInterval(-3600), forKey: "appUpdate.lastChecked")
        let stub = StubHTTPSession()
        let service = AppUpdateService(session: stub, defaults: defaults, now: { now })

        await service.checkForUpdate(regionCode: "US")

        #expect(stub.callCount == 0)
    }

    @Test func checkForUpdate_hitsNetwork_whenNoCache_andCachesResult() async {
        let defaults = makeIsolatedDefaults()
        let now = Date(timeIntervalSince1970: 2_000_000)
        let stub = StubHTTPSession(version: "99.0.0", trackId: 55555)
        let service = AppUpdateService(session: stub, defaults: defaults, now: { now })

        await service.checkForUpdate(regionCode: "PE")

        #expect(stub.callCount == 1)
        #expect(service.latestVersion == "99.0.0")
        #expect(defaults.string(forKey: "appUpdate.latestVersion") == "99.0.0")
        #expect(defaults.integer(forKey: "appUpdate.trackId") == 55555)
        #expect(service.appStoreURL == URL(string: "https://apps.apple.com/app/id55555"))
    }

    @Test func checkForUpdate_storefront_inLookupURL() async throws {
        let defaults = makeIsolatedDefaults()
        let stub = StubHTTPSession()
        let service = AppUpdateService(session: stub, defaults: defaults, now: { .now })

        await service.checkForUpdate(regionCode: "PE")

        let request = try #require(stub.lastRequest)
        let items = try #require(
            URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems)
        #expect(items.contains(URLQueryItem(name: "country", value: "pe")))
    }

    @Test func loadCachedState_rehydratesAppStoreURL_fromCachedTrackId() {
        let defaults = makeIsolatedDefaults()
        defaults.set("99.0.0", forKey: "appUpdate.latestVersion")
        defaults.set(98765, forKey: "appUpdate.trackId")
        // init llama loadCachedState → appStoreURL desde el trackId cacheado (cold-launch).
        let service = AppUpdateService(session: StubHTTPSession(), defaults: defaults, now: { .now })

        #expect(service.appStoreURL == URL(string: "https://apps.apple.com/app/id98765"))
    }
}
