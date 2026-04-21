//
//  AppUpdateService.swift
//  Yala
//
//  Consulta iTunes Lookup API para detectar si hay una versión nueva
//  disponible en el App Store. Cache de 24h, fail silently.
//

import Foundation

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

    private let session: URLSession
    private static let productionBundleID = "com.jurgenschmidt.yala"
    private static let cacheDuration: TimeInterval = 24 * 60 * 60

    private static let lastCheckedKey = "appUpdate.lastChecked"
    private static let latestVersionKey = "appUpdate.latestVersion"

    // MARK: - Init

    private init(session: URLSession = .shared) {
        self.session = session
        loadCachedState()
    }

    // MARK: - Public Methods

    func checkForUpdate() async {
        let defaults = UserDefaults.standard

        // Check cache — skip if checked within 24h (init already loaded cached state)
        if let lastChecked = defaults.object(forKey: Self.lastCheckedKey) as? Date,
           Date.now.timeIntervalSince(lastChecked) < Self.cacheDuration {
            return
        }

        // Build URL
        guard let url = URL(string: "https://itunes.apple.com/lookup?bundleId=\(Self.productionBundleID)&country=us") else {
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                #if DEBUG
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                print("AppUpdateService: Non-2xx response: \(code)")
                #endif
                return
            }

            let decoded = try JSONDecoder().decode(ITunesLookupResponse.self, from: data)

            guard decoded.resultCount > 0,
                  let result = decoded.results.first else {
                isUpdateAvailable = false
                return
            }

            // Cache result
            defaults.set(result.version, forKey: Self.latestVersionKey)
            defaults.set(Date.now, forKey: Self.lastCheckedKey)

            latestVersion = result.version
            appStoreURL = URL(string: "https://apps.apple.com/app/id\(result.trackId)")

            updateAvailability()
        } catch {
            #if DEBUG
            print("AppUpdateService: Error checking for update: \(error)")
            #endif
        }
    }

    func dismissBanner() {
        dismissedInSession = true
    }

    // MARK: - Private

    private func loadCachedState() {
        let defaults = UserDefaults.standard
        latestVersion = defaults.string(forKey: Self.latestVersionKey)
        updateAvailability()
    }

    private func updateAvailability() {
        guard let latest = latestVersion else {
            isUpdateAvailable = false
            return
        }
        let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        isUpdateAvailable = Self.compareVersions(current: current, latest: latest) == .orderedAscending
    }

    /// Compares two semantic version strings by numeric components.
    /// Returns .orderedAscending if current < latest (update available).
    static func compareVersions(current: String, latest: String) -> ComparisonResult {
        let currentParts = current.split(separator: ".").compactMap { Int($0) }
        let latestParts = latest.split(separator: ".").compactMap { Int($0) }

        let maxCount = max(currentParts.count, latestParts.count)
        for i in 0..<maxCount {
            let c = i < currentParts.count ? currentParts[i] : 0
            let l = i < latestParts.count ? latestParts[i] : 0
            if c < l { return .orderedAscending }
            if c > l { return .orderedDescending }
        }
        return .orderedSame
    }
}
