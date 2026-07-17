//
//  CloudRemoteConfig.swift
//  Yala
//
//  Remote-config del Modo Nube (DIFERIDOS #34, §j.1/§j.2): fetch de `GET /config` del gateway,
//  cache local last-cached-wins y flags EFECTIVOS (`CloudRemoteFlags`) que gatean las superficies
//  de ENTRADA (fila Almacenamiento para no-migrados, cards de sign-in nube del Welcome, entrada
//  secundaria M1, composición de `groupsBackendEnabled`).
//
//  Semántica ratificada por el owner (2026-07-17):
//  - Kill-switch = corta solo la ENTRADA. Un usuario YA `.cloud` conserva runtime/outbox/reversa
//    (este archivo NO gatea `CloudSyncRuntime` — cero lecturas desde ahí, a propósito).
//  - Percent 0-100 por flag + bucket estable por instalación (escalón gradual §j.2).
//  - Sin TTL de expiración del cache: todo flujo gateado exige red al ejecutarse y las entradas
//    re-fetchean en su `onAppear` (min-interval 6 h) — offline prolongado conserva el último
//    valor conocido, jamás degrada a un estado distinto del último que el server declaró.
//
//  DARK: en prod `CloudBackendConfig.isConfigured == false` ⇒ el fetch jamás corre (cero tráfico
//  nuevo) y las superficies ya estaban ocultas ANTES del AND remoto. En DEV el default ante cache
//  AUSENTE es ON (staging sirve 100 ⇒ mismo valor tras el fetch) → QA/uitest byte-idénticos.
//

import Foundation
import os

// MARK: - Snapshot persistido

/// Último `/config` conocido. Percents opcionales: un flag ausente en el wire decide por
/// `absentDefault` (tolerancia a evolución del shape — campos desconocidos se ignoran).
nonisolated struct RemoteFlagsSnapshot: Codable, Equatable {
    var cloudModeRolloutPercent: Int?
    var cloudOnboardingChoiceRolloutPercent: Int?
    var groupsBackendRolloutPercent: Int?
    var fetchedAt: Date
}

/// Shape del wire `GET /config` (v1). Se decodifica tolerante y se traduce al snapshot.
nonisolated struct RemoteConfigWireResponse: Codable {
    struct Flags: Codable {
        var cloudModeRolloutPercent: Int?
        var cloudOnboardingChoiceRolloutPercent: Int?
        var groupsBackendRolloutPercent: Int?
    }

    var v: Int?
    var flags: Flags?
}

// MARK: - Store (UserDefaults.standard, prefijo `cloudSync.`)

/// Persistencia del snapshot + seed del bucket. `.standard` a propósito: config GLOBAL de device
/// (no user-scoped) — el sweep de sign-out (`removeUserPreferenceKeys`) excluye `cloudSync.*` por
/// doc, así el cache y la cohorte sobreviven sign-out/re-entrada. Extensiones NO lo leen
/// (verificado: cero referencias CloudSync en YalaWidgets/YalaShare) → no hace falta App Group.
/// `defaults` inyectable (regla del repo: nunca `.standard` directo en tests).
nonisolated enum CloudRemoteConfigStore {
    static let snapshotKey = "cloudSync.remoteConfig.snapshot"
    static let bucketSeedKey = "cloudSync.remoteConfig.bucketSeed"

    static func readSnapshot(_ defaults: UserDefaults = .standard) -> RemoteFlagsSnapshot? {
        guard let data = defaults.data(forKey: snapshotKey) else { return nil }
        do {
            return try JSONDecoder().decode(RemoteFlagsSnapshot.self, from: data)
        } catch {
            // Snapshot corrupto (schema viejo/bit-rot) → como ausente; el próximo fetch lo repara.
            #if DEBUG
            print("CloudRemoteConfigStore: snapshot no decodifica (se ignora): \(error)")
            #endif
            return nil
        }
    }

    static func writeSnapshot(_ snapshot: RemoteFlagsSnapshot, defaults: UserDefaults = .standard) {
        do {
            defaults.set(try JSONEncoder().encode(snapshot), forKey: snapshotKey)
        } catch {
            #if DEBUG
            print("CloudRemoteConfigStore: snapshot no codifica: \(error)")
            #endif
        }
    }

    /// Seed de la cohorte: UUID creado UNA vez por instalación (estabilidad del bucket §j.2).
    static func bucketSeed(_ defaults: UserDefaults = .standard) -> String {
        if let existing = defaults.string(forKey: bucketSeedKey) { return existing }
        let fresh = UUID().uuidString
        defaults.set(fresh, forKey: bucketSeedKey)
        return fresh
    }
}

// MARK: - Flags efectivos

/// SSOT de los flags remotos EFECTIVOS. Molde `CloudSyncFlags`: getter = override de tests >
/// decisión (snapshot cacheado + bucket + default por build). Ajuste A2 del review: bajo
/// `isRunningTests` se IGNORA el snapshot persistido de `.standard` (el host del sim puede traer
/// uno real de una corrida manual) — los tests son deterministas vía override o default.
nonisolated enum CloudRemoteFlags {

    /// DEV: ausencia de config ⇒ ON (sim/XCUITest sin fetch previo no pierden superficie; staging
    /// sirve 100 ⇒ mismo valor tras el fetch). Prod: OFF fail-closed.
    static var absentDefault: Bool {
        #if DEV_BUILD
        return true
        #else
        return false
        #endif
    }

    #if DEV_BUILD
    /// Panel DEBUG: simular el kill-switch (remote OFF) sin tocar staging. Solo DEV_BUILD.
    static let debugForceOffKey = "cloudSync.debug.remoteFlagsForceOff"
    #endif

    /// Disponibilidad del Modo Nube (§j.1) — gatea SOLO entradas, jamás el runtime (decisión owner).
    static var cloudModeEnabled: Bool {
        if let override = cloudModeEnabledTestOverride { return override }
        return decide(\.cloudModeRolloutPercent)
    }

    /// Sub-flag §j.1: pantalla de elección born-cloud del onboarding (escalón posterior del rollout).
    static var cloudOnboardingChoiceEnabled: Bool {
        if let override = cloudOnboardingChoiceEnabledTestOverride { return override }
        return decide(\.cloudOnboardingChoiceRolloutPercent)
    }

    /// Kill-switch remoto del canal Grupos→backend. Se COMPONE con el flag compilado en
    /// `CloudSyncFlags.groupsBackendEnabled` (remoto solo puede MATAR, nunca encender solo).
    static var groupsBackendEnabled: Bool {
        if let override = groupsBackendEnabledTestOverride { return override }
        return decide(\.groupsBackendRolloutPercent)
    }

    /// Mirror NONISOLATED de `SwiftDataConfiguration.isRunningTests` (ese vive bajo el default
    /// actor MainActor y estos getters se leen desde cualquier actor). Misma señal canónica
    /// (`YALA_TEST_MODE=1` del TestAction) + el fallback de framework cargado; cacheado en `let`.
    private static let isRunningTests: Bool = {
        if ProcessInfo.processInfo.environment["YALA_TEST_MODE"] == "1" { return true }
        return NSClassFromString("XCTestObservationCenter") != nil
    }()

    /// Mirror nonisolated de `SwiftDataConfiguration.isUITesting` (SERIO 1 del review adversarial:
    /// bajo `-uitest` el HOST no es unit test — sin este corte, `decide()` leería `.standard` del
    /// sim de XCUITest y un snapshot/toggle stale de una corrida manual rompería el determinismo
    /// del XCUITest del chooser). Solo DEBUG, como el original.
    private static let isUITestHost: Bool = {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-uitest")
        #else
        return false
        #endif
    }()

    private static func decide(_ percentPath: KeyPath<RemoteFlagsSnapshot, Int?>) -> Bool {
        // Tests PRIMERO: jamás leer `.standard` (ni snapshot ni la key DEBUG — estado del sim
        // host ≠ determinismo, tanto unit como XCUITest). Los tests inyectan overrides o
        // defaults aislados en la Store.
        if isRunningTests || isUITestHost { return absentDefault }
        #if DEV_BUILD
        if UserDefaults.standard.bool(forKey: debugForceOffKey) { return false }
        #endif
        guard let snapshot = CloudRemoteConfigStore.readSnapshot() else { return absentDefault }
        return RemoteFlagDecisionLogic.isEnabled(
            percent: snapshot[keyPath: percentPath],
            bucket: RemoteFlagDecisionLogic.stableBucket(seed: CloudRemoteConfigStore.bucketSeed()),
            absentDefault: absentDefault
        )
    }

    // Overrides de tests (patrón `storageMode`: setter en memoria + reset explícito).
    nonisolated(unsafe) private static var cloudModeEnabledTestOverride: Bool?
    nonisolated(unsafe) private static var cloudOnboardingChoiceEnabledTestOverride: Bool?
    nonisolated(unsafe) private static var groupsBackendEnabledTestOverride: Bool?

    static func _testSetOverrides(
        cloudMode: Bool? = nil,
        onboardingChoice: Bool? = nil,
        groupsBackend: Bool? = nil
    ) {
        cloudModeEnabledTestOverride = cloudMode
        cloudOnboardingChoiceEnabledTestOverride = onboardingChoice
        groupsBackendEnabledTestOverride = groupsBackend
    }

    static func _testResetOverrides() {
        cloudModeEnabledTestOverride = nil
        cloudOnboardingChoiceEnabledTestOverride = nil
        groupsBackendEnabledTestOverride = nil
    }
}

// MARK: - Cliente

/// Fetch de `GET /config` (público, sin auth/attest — config pre-sesión). Fire-and-forget desde
/// el boot y los `onAppear` de las entradas; NUNCA bloquea nada. Escribe el snapshot SOLO en
/// éxito (last-cached-wins). Breadcrumb fuera de `#if DEBUG` (molde `CloudSyncBreadcrumb`,
/// sin PII — solo percents/counts).
@MainActor
final class RemoteConfigClient {

    static let shared = RemoteConfigClient()

    private let baseURL: URL
    private let urlSession: SyncHTTPSession
    private let defaults: UserDefaults
    private var inFlight = false

    init(
        baseURL: URL = ProxyConfig.baseURL,
        urlSession: SyncHTTPSession = URLSession.shared,
        defaults: UserDefaults = .standard
    ) {
        self.baseURL = baseURL
        self.urlSession = urlSession
        self.defaults = defaults
    }

    /// Re-fetchea si venció el min-interval (o nunca se fetcheó). Idempotente y coalescente
    /// (un fetch en vuelo hace no-op del siguiente kick). `force` salta el min-interval
    /// (panel DEBUG); `now` inyectado se usa para el gate Y como `fetchedAt` del snapshot.
    func refreshIfDue(force: Bool = false, now: Date = .now) async {
        guard CloudBackendConfig.isConfigured else { return } // prod placeholder: cero tráfico
        guard !inFlight else { return }
        let last = CloudRemoteConfigStore.readSnapshot(defaults)?.fetchedAt
        guard force || RemoteFlagDecisionLogic.shouldRefresh(lastFetchedAt: last, now: now) else { return }
        inFlight = true
        defer { inFlight = false }

        var request = URLRequest(url: baseURL.appendingPathComponent("config"))
        request.httpMethod = "GET"
        if force {
            // El endpoint sirve `Cache-Control: public, max-age=300` y URLSession lo cachea
            // client-side — un force (panel DEBUG post-flip de staging) debe ver el valor VIVO.
            request.cachePolicy = .reloadIgnoringLocalCacheData
        }
        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                RemoteConfigBreadcrumb.fetchFailed(reason: "status_\(status)")
                return
            }
            let wire = try JSONDecoder().decode(RemoteConfigWireResponse.self, from: data)
            let snapshot = RemoteFlagsSnapshot(
                cloudModeRolloutPercent: wire.flags?.cloudModeRolloutPercent,
                cloudOnboardingChoiceRolloutPercent: wire.flags?.cloudOnboardingChoiceRolloutPercent,
                groupsBackendRolloutPercent: wire.flags?.groupsBackendRolloutPercent,
                fetchedAt: now
            )
            CloudRemoteConfigStore.writeSnapshot(snapshot, defaults: defaults)
            RemoteConfigBreadcrumb.fetched(snapshot)
        } catch {
            // Fallo de red/decode = benigno por diseño (last-cached-wins, default fail-closed);
            // jamás `try?` silenciado — el breadcrumb lo hace observable en Console.app.
            RemoteConfigBreadcrumb.fetchFailed(reason: String(describing: type(of: error)))
        }
    }
}

// MARK: - Breadcrumb (Console.app, fuera de #if DEBUG, sin PII)

/// Rastros del remote-config. Fuera de `#if DEBUG` a propósito (espeja `CloudSyncBreadcrumb`):
/// el kill-switch solo se valida del todo en device/TestFlight. Sin PII (solo percents/razones).
nonisolated enum RemoteConfigBreadcrumb {
    private static let logger = Logger(subsystem: "com.yala", category: "CloudSync")

    static func fetched(_ snapshot: RemoteFlagsSnapshot) {
        let cloud = snapshot.cloudModeRolloutPercent.map(String.init) ?? "nil"
        let groups = snapshot.groupsBackendRolloutPercent.map(String.init) ?? "nil"
        let choice = snapshot.cloudOnboardingChoiceRolloutPercent.map(String.init) ?? "nil"
        logger.notice(
            "CloudSync remoteConfig fetched cloud=\(cloud, privacy: .public) choice=\(choice, privacy: .public) groups=\(groups, privacy: .public)"
        )
    }

    static func fetchFailed(reason: String) {
        logger.notice("CloudSync remoteConfig fetchFailed reason=\(reason, privacy: .public)")
    }
}
