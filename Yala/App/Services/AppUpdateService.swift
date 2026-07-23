//
//  AppUpdateService.swift
//  Yala
//
//  Consulta iTunes Lookup API para detectar si hay una versión nueva disponible en el App Store.
//  Cache de 24h, fail silently. La lógica pura (comparación, gate de cache, URL) vive en
//  `AppUpdateDecisionLogic` (testeable sin red/UserDefaults/Bundle).
//

import Foundation
import os

// MARK: - iTunes Lookup Response

private struct ITunesLookupResponse: Decodable {
    let resultCount: Int
    let results: [ITunesResult]
}

private struct ITunesResult: Decodable {
    let version: String
    let trackId: Int
}

// MARK: - AppUpdateService

@MainActor @Observable
final class AppUpdateService {

    static let shared = AppUpdateService()

    // MARK: - Public State

    private(set) var isUpdateAvailable = false
    private(set) var latestVersion: String?
    private(set) var appStoreURL: URL?

    private var dismissedInSession = false

    var shouldShowBanner: Bool {
        isUpdateAvailable && !dismissedInSession
    }

    // MARK: - Private

    private let session: SyncHTTPSession
    private let defaults: UserDefaults
    private let now: () -> Date
    private static let productionBundleID = "com.jurgenschmidt.yala"
    private static let cacheDuration: TimeInterval = AppUpdateDecisionLogic.defaultCacheDuration

    private static let lastCheckedKey = "appUpdate.lastChecked"
    private static let latestVersionKey = "appUpdate.latestVersion"
    // Se persiste para rehidratar `appStoreURL` en cold-launch-desde-cache (antes solo-memoria →
    // el botón del banner abría nada hasta un lookup fresco). Limpiado por DataWipeService.
    private static let trackIdKey = "appUpdate.trackId"

    // MARK: - Init

    /// `defaults`/`session`/`now` inyectables (regla del repo: nunca `.standard`/`.shared`/`Date()`
    /// directos en tests). `SyncHTTPSession` es el protocolo de red del repo (`URLSession` conforma).
    init(
        session: SyncHTTPSession = URLSession.shared,
        defaults: UserDefaults = .standard,
        now: @escaping () -> Date = { .now }
    ) {
        self.session = session
        self.defaults = defaults
        self.now = now
        loadCachedState()
    }

    // MARK: - Public Methods

    /// `regionCode` inyectable para test determinista; en producción = storefront del device.
    func checkForUpdate(regionCode: String? = Locale.current.region?.identifier) async {
        // Gate de cache — salta si se chequeó dentro de la ventana (init ya cargó el estado cacheado).
        let lastChecked = defaults.object(forKey: Self.lastCheckedKey) as? Date
        guard AppUpdateDecisionLogic.shouldCheckNetwork(
            lastChecked: lastChecked, now: now(), cacheDuration: Self.cacheDuration
        ) else {
            return
        }

        guard let url = AppUpdateDecisionLogic.makeLookupURL(
            bundleID: Self.productionBundleID, regionCode: regionCode
        ) else {
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10

        let storefront = (regionCode ?? "us").lowercased()

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                #if DEBUG
                print("AppUpdateService: Non-2xx response: \(code)")
                #endif
                AppUpdateBreadcrumb.failed(reason: "status_\(code)")
                return
            }

            let decoded = try JSONDecoder().decode(ITunesLookupResponse.self, from: data)

            guard decoded.resultCount > 0,
                  let result = decoded.results.first else {
                isUpdateAvailable = false
                AppUpdateBreadcrumb.checked(
                    storefront: storefront, latest: "none",
                    current: Self.currentVersion, updateAvailable: false
                )
                return
            }

            // Cache result (versión + trackId para rehidratar la URL en el próximo cold launch)
            defaults.set(result.version, forKey: Self.latestVersionKey)
            defaults.set(result.trackId, forKey: Self.trackIdKey)
            defaults.set(now(), forKey: Self.lastCheckedKey)

            latestVersion = result.version
            appStoreURL = Self.appStoreURL(trackId: result.trackId)

            updateAvailability()
            AppUpdateBreadcrumb.checked(
                storefront: storefront, latest: result.version,
                current: Self.currentVersion, updateAvailable: isUpdateAvailable
            )
        } catch {
            #if DEBUG
            print("AppUpdateService: Error checking for update: \(error)")
            #endif
            AppUpdateBreadcrumb.failed(reason: String(describing: type(of: error)))
        }
    }

    func dismissBanner() {
        dismissedInSession = true
    }

    #if DEBUG
    /// UI tests: fuerza el estado "hay update disponible" sin tocar la red,
    /// para testear el UpdateAvailableBanner de forma determinista. La detección
    /// real (URLSession a iTunes) queda fuera del XCUITest.
    func forceUpdateAvailableForUITest() {
        latestVersion = "99.0.0"
        appStoreURL = URL(string: "https://apps.apple.com/app/idyala")
        isUpdateAvailable = true
        dismissedInSession = false
    }
    #endif

    // MARK: - Private

    private func loadCachedState() {
        latestVersion = defaults.string(forKey: Self.latestVersionKey)
        if let trackId = Self.cachedTrackId(defaults) {
            appStoreURL = Self.appStoreURL(trackId: trackId)
        }
        updateAvailability()
    }

    private func updateAvailability() {
        guard let latest = latestVersion else {
            isUpdateAvailable = false
            return
        }
        isUpdateAvailable = AppUpdateDecisionLogic.isUpdateAvailable(
            current: Self.currentVersion, latest: latest
        )
    }

    /// Versión instalada. Cadena vacía si `CFBundleShortVersionString` faltara → fail-closed en
    /// `AppUpdateDecisionLogic.isUpdateAvailable` (no molestar con versión desconocida; gap #5).
    private static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    private static func cachedTrackId(_ defaults: UserDefaults) -> Int? {
        let value = defaults.integer(forKey: trackIdKey)
        return value > 0 ? value : nil
    }

    private static func appStoreURL(trackId: Int) -> URL? {
        URL(string: "https://apps.apple.com/app/id\(trackId)")
    }

    /// Forwarder retro-compatible; la lógica vive en `AppUpdateDecisionLogic.compare`.
    static func compareVersions(current: String, latest: String) -> ComparisonResult {
        AppUpdateDecisionLogic.compare(current: current, latest: latest)
    }
}

// MARK: - Breadcrumb (Console.app, fuera de #if DEBUG, sin PII)

/// Rastros del chequeo de actualización, observables en release/TestFlight (molde
/// `RemoteConfigBreadcrumb`): los `print` DEBUG existentes son invisibles en prod. Sin PII —
/// storefront (región), versiones semver y el tipo del error son públicos y seguros.
nonisolated enum AppUpdateBreadcrumb {
    private static let logger = Logger(subsystem: "com.yala", category: "AppUpdate")

    static func checked(storefront: String, latest: String, current: String, updateAvailable: Bool) {
        logger.notice(
            "AppUpdate checked storefront=\(storefront, privacy: .public) latest=\(latest, privacy: .public) current=\(current, privacy: .public) updateAvailable=\(updateAvailable, privacy: .public)"
        )
    }

    static func failed(reason: String) {
        logger.notice("AppUpdate failed reason=\(reason, privacy: .public)")
    }
}
