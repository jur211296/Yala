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
//  En producción el fetch YA CORRE (D-R1 paso 1 abrió `CloudBackendConfig.isConfigured`) y el server
//  sirve los tres percents en 0 ⇒ las superficies de entrada siguen ocultas, pero AHORA por el AND
//  remoto y no por la ausencia de configuración. La ventana previa al primer fetch tampoco destapa
//  nada: en prod `absentDefault` es `false` (fail-closed). En DEV el default ante cache AUSENTE es ON
//  (staging sirve 100 ⇒ mismo valor tras el fetch) → QA/uitest byte-idénticos.
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
    /// Entrada a la SESIÓN SECUNDARIA (M1). Optional CON DEFAULT, igual que `minSupportedBuild` y por
    /// la misma razón: el snapshot cacheado en disco puede ser de un build anterior a este campo, y
    /// **un snapshot viejo tiene que leerse como «percent ausente», jamás como error de decode** — si
    /// no decodifica, `readSnapshot` lo trata como ausente y el device pierde TAMBIÉN los otros tres
    /// percents hasta el siguiente fetch. Ausente ⇒ decide `absentDefault` (prod: fail-closed).
    var secondarySessionRolloutPercent: Int? = nil
    /// Forzado de actualización (min-version): build por debajo del cual el cliente bloquea.
    /// Optional con default ⇒ snapshots viejos cacheados (sin este campo) decodifican a nil y los
    /// call-sites previos no rompen. Ausente/0 = desactivado (`ForceUpdateDecisionLogic` fail-open).
    var minSupportedBuild: Int? = nil
    var fetchedAt: Date
}

/// Shape del wire `GET /config` (v1). Se decodifica tolerante y se traduce al snapshot.
nonisolated struct RemoteConfigWireResponse: Codable {
    struct Flags: Codable {
        var cloudModeRolloutPercent: Int?
        var cloudOnboardingChoiceRolloutPercent: Int?
        var groupsBackendRolloutPercent: Int?
        var secondarySessionRolloutPercent: Int?
    }

    struct ForceUpdate: Codable {
        var minSupportedBuild: Int?
    }

    var v: Int?
    var flags: Flags?
    var forceUpdate: ForceUpdate?
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

    /// Percent PROPIO de la entrada a sesión secundaria (M1, chip M2). Hasta él, el compuesto
    /// `CloudSyncFlags.secondarySessionEntryAvailable` tomaba prestado el kill-switch de
    /// `cloudModeEnabled` — que no se puede mover sin mover también las superficies de alta. El AND
    /// con `cloudModeEnabled` se CONSERVA: son dos palancas independientes y cualquiera mata la
    /// entrada (doble kill-switch, gratis). Como el resto de su clase, gatea SOLO la ENTRADA.
    static var secondarySessionEnabled: Bool {
        if let override = secondarySessionEnabledTestOverride { return override }
        return decide(\.secondarySessionRolloutPercent)
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
    nonisolated(unsafe) private static var secondarySessionEnabledTestOverride: Bool?

    static func _testSetOverrides(
        cloudMode: Bool? = nil,
        onboardingChoice: Bool? = nil,
        groupsBackend: Bool? = nil,
        secondarySession: Bool? = nil
    ) {
        cloudModeEnabledTestOverride = cloudMode
        cloudOnboardingChoiceEnabledTestOverride = onboardingChoice
        groupsBackendEnabledTestOverride = groupsBackend
        secondarySessionEnabledTestOverride = secondarySession
    }

    static func _testResetOverrides() {
        cloudModeEnabledTestOverride = nil
        cloudOnboardingChoiceEnabledTestOverride = nil
        groupsBackendEnabledTestOverride = nil
        secondarySessionEnabledTestOverride = nil
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
    private var inFlight: Task<Bool, Never>?

    init(
        baseURL: URL = ProxyConfig.baseURL,
        urlSession: SyncHTTPSession = URLSession.shared,
        defaults: UserDefaults = .standard
    ) {
        self.baseURL = baseURL
        self.urlSession = urlSession
        self.defaults = defaults
    }

    /// Re-fetchea si venció el min-interval (o nunca se fetcheó). `now` inyectado se usa para el
    /// gate Y como `fetchedAt` del snapshot.
    ///
    /// **La coalescencia tiene dos reglas, no una.** Un kick normal (boot, `onAppear`) que llega con
    /// un fetch en vuelo hace no-op: el que está en curso ya trae la respuesta del server. Un
    /// `force` **espera** a ese fetch en vez de rendirse ante él, porque su call-site lee el flag
    /// JUSTO DESPUÉS y rendirse significa decidir con el snapshot viejo. `force` salta además el
    /// min-interval, como siempre.
    ///
    /// Límite conocido y aceptado: el fetch que se espera pudo salir sin
    /// `reloadIgnoringLocalCacheData`, así que su respuesta puede venir de la caché HTTP del
    /// endpoint (`max-age=300`). El caso que este camino protege —teléfono recién instalado— no
    /// tiene caché que reutilizar, y pedir por segunda vez lo mismo reintroduce el tráfico y la
    /// carrera de escrituras que esperar evita.
    ///
    /// **El fetch vive en una Task NO estructurada, y eso es deliberado.** Antes corría dentro del
    /// árbol del caller, así que desmontar la vista que lo lanzó cancelaba la petición; ahora no.
    /// Es el precio de poder compartirlo: si el caller que lo arrancó pudiera matarlo, un `force`
    /// que está esperando esa misma respuesta se quedaría sin ella por culpa de otro. Lo que cambia
    /// es que el frame que espera se suelta al completar el fetch (tope: el timeout de `URLSession`)
    /// en vez de al instante; ningún call-site ACTÚA por eso — todos comprueban `Task.isCancelled`
    /// después—, y el snapshot se escribe igual, que es lo que queremos.
    func refreshIfDue(force: Bool = false, now: Date = .now) async {
        guard CloudBackendConfig.isConfigured else { return } // sin backend no hay a quién preguntar

        if let running = inFlight {
            guard force else { return }                    // kick normal: coalesce, igual que antes
            // Esperar al que está en curso le da al que forzó exactamente lo que pedía —la respuesta
            // más fresca del server— sin una segunda petición y sin dos escrituras del snapshot que
            // puedan aterrizar fuera de orden. Rendirse aquí ERA el bug del recién instalado: el boot
            // deja un fetch en vuelo, el invitado tapea el enlace encima, el `force` salía sin tocar
            // nada, y la re-lectura del flag —todavía apagado, porque nadie escribió el snapshot— le
            // enseñaba «no pudimos abrir esta invitación» con el canal perfectamente encendido.
            if await running.value { return }
            // El fetch esperado NO trajo config (no-200, red caída, decode roto): el snapshot no
            // avanzó, y conformarse cambiaría un fallo por otro —la misma alerta falsa cada vez que
            // el refresco del arranque falle—. El `force` sigue adelante con el suyo.
            //
            // Salvo que ya no haga falta: esperar al de otro ALARGA la ventana de cancelación que
            // documenta `WelcomeGroupsGateView.evaluate`, y encadenar una segunda petición cuando el
            // caller ya se fue (step desmontado, sheet cerrado) no le sirve a nadie.
            guard !Task.isCancelled else { return }
            // Y si mientras esperábamos otro `force` ya arrancó el suyo, esperamos a ÉSE en vez de
            // abrir un tercero: dos puertas pueden estar despiertas a la vez (el enlace de invitación
            // y la del Welcome), y N forces reaccionando al MISMO fallo abrirían N peticiones y N
            // escrituras del snapshot — exactamente la carrera que esperar existe para evitar. Si ése
            // también falla nos conformamos: dos fallos seguidos ya no son una ventana, es el server.
            //
            // Una sola re-comprobación y NO un bucle: `running` puede seguir en `inFlight` hasta que su
            // creador reanude su `defer`, y girar sobre una task ya terminada no cedería el MainActor.
            if let siguiente = inFlight, siguiente != running {
                _ = await siguiente.value
                return
            }
        }

        let last = CloudRemoteConfigStore.readSnapshot(defaults)?.fetchedAt
        guard force || RemoteFlagDecisionLogic.shouldRefresh(lastFetchedAt: last, now: now) else { return }

        let task = Task { @MainActor [self] in await performFetch(force: force, now: now) }
        inFlight = task
        // Por IDENTIDAD y no `nil` a secas: si mientras corría éste otro `force` arrancó el suyo (solo
        // ocurre tras un fallo), `inFlight` ya apunta a ESE y borrarlo perdería su coalescencia.
        defer { if inFlight == task { inFlight = nil } }
        _ = await task.value
    }

    /// El fetch en sí. Devuelve `true` SOLO si escribió snapshot (200 + decode), y esa es la señal
    /// que necesita un `force` que esperó: saber si ya tiene su respuesta o si le toca reintentar.
    private func performFetch(force: Bool, now: Date) async -> Bool {
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
                return false
            }
            let wire = try JSONDecoder().decode(RemoteConfigWireResponse.self, from: data)
            let snapshot = RemoteFlagsSnapshot(
                cloudModeRolloutPercent: wire.flags?.cloudModeRolloutPercent,
                cloudOnboardingChoiceRolloutPercent: wire.flags?.cloudOnboardingChoiceRolloutPercent,
                groupsBackendRolloutPercent: wire.flags?.groupsBackendRolloutPercent,
                secondarySessionRolloutPercent: wire.flags?.secondarySessionRolloutPercent,
                minSupportedBuild: wire.forceUpdate?.minSupportedBuild,
                fetchedAt: now
            )
            CloudRemoteConfigStore.writeSnapshot(snapshot, defaults: defaults)
            RemoteConfigBreadcrumb.fetched(snapshot)
            return true
        } catch {
            // Fallo de red/decode = benigno por diseño (last-cached-wins, default fail-closed);
            // jamás `try?` silenciado — el breadcrumb lo hace observable en Console.app.
            RemoteConfigBreadcrumb.fetchFailed(reason: String(describing: type(of: error)))
            return false
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
        let secondary = snapshot.secondarySessionRolloutPercent.map(String.init) ?? "nil"
        let minBuild = snapshot.minSupportedBuild.map(String.init) ?? "nil"
        logger.notice(
            "CloudSync remoteConfig fetched cloud=\(cloud, privacy: .public) choice=\(choice, privacy: .public) groups=\(groups, privacy: .public) secondary=\(secondary, privacy: .public) minBuild=\(minBuild, privacy: .public)"
        )
    }

    static func fetchFailed(reason: String) {
        logger.notice("CloudSync remoteConfig fetchFailed reason=\(reason, privacy: .public)")
    }
}
