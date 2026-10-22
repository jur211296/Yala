//
//  AppUpdateDecisionLogic.swift
//  Yala
//
//  Lógica PURA del banner "Actualización disponible" (extraída de AppUpdateService para
//  testeo sin red ni UserDefaults ni Bundle). Comparación de versiones, gate de cache y
//  construcción de la URL del iTunes Lookup. `nonisolated` — se llama desde cualquier actor.
//

import Foundation

nonisolated enum AppUpdateDecisionLogic {

    /// Ventana de cache por defecto entre chequeos de red (24 h).
    static let defaultCacheDuration: TimeInterval = 24 * 60 * 60

    /// Componentes NUMÉRICOS de una versión semver. Componentes no numéricos se descartan
    /// (`"2.0.5-beta"` → `[2, 0]`) — comportamiento IDÉNTICO al histórico, fijado por tests.
    static func parse(_ version: String) -> [Int] {
        version.split(separator: ".").compactMap { Int($0) }
    }

    /// Compara dos versiones por componentes numéricos. `.orderedAscending` sii `current < latest`.
    static func compare(current: String, latest: String) -> ComparisonResult {
        let currentParts = parse(current)
        let latestParts = parse(latest)
        let maxCount = max(currentParts.count, latestParts.count)
        for i in 0..<maxCount {
            let c = i < currentParts.count ? currentParts[i] : 0
            let l = i < latestParts.count ? latestParts[i] : 0
            if c < l { return .orderedAscending }
            if c > l { return .orderedDescending }
        }
        return .orderedSame
    }

    /// FAIL-CLOSED: si `current` (o `latest`) no aporta NINGÚN componente numérico —
    /// `CFBundleShortVersionString` ausente/corrupto, o respuesta rara del store— la versión es
    /// "desconocida" y NO se muestra el banner. Antes el default `"0.0.0"` hacía el banner siempre
    /// visible (gap #5). Con versiones válidas: `current < latest`.
    static func isUpdateAvailable(current: String, latest: String) -> Bool {
        guard !parse(current).isEmpty, !parse(latest).isEmpty else { return false }
        return compare(current: current, latest: latest) == .orderedAscending
    }

    /// `true` sii toca golpear la red: nunca se chequeó, o venció la ventana de cache. El gate se
    /// evalúa SOLO en éxito previo (`lastChecked` se persiste solo tras un 2xx) → un fallo no
    /// bloquea la próxima ventana.
    static func shouldCheckNetwork(lastChecked: Date?, now: Date, cacheDuration: TimeInterval) -> Bool {
        guard let lastChecked else { return true }
        return now.timeIntervalSince(lastChecked) >= cacheDuration
    }

    /// URL del iTunes Lookup con storefront del device (gap #3 — antes `country=us` hardcodeado).
    /// `regionCode` viene de `Locale.current.region?.identifier` (regla del repo: región = país, NO
    /// AppLocale). Se normaliza a minúscula y cae a `"us"` si es nil. `URLComponents` codifica seguro.
    static func makeLookupURL(bundleID: String, regionCode: String?) -> URL? {
        var comps = URLComponents(string: "https://itunes.apple.com/lookup")
        let country = (regionCode ?? "us").lowercased()
        comps?.queryItems = [
            URLQueryItem(name: "bundleId", value: bundleID),
            URLQueryItem(name: "country", value: country),
        ]
        return comps?.url
    }
}
