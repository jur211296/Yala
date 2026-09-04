//
//  PanelPreferencesMigration.swift
//  Yala
//
//  One-shot classification of the legacy `panel_widget_configs_v1` JSON blob
//  into per-section order/hidden keys. Idempotent via a local sentinel flag.
//
//  P20-11: when no legacy blob exists (truly fresh install) we seed the
//  opinionated defaults defined in `AppPreferences.setupDefaultsForNewUser()`
//  instead of bucketizing an empty blob. This ensures a new user lands on
//  the curated Panel 2.0 defaults without waiting for onboarding flow to
//  complete.
//

import Foundation

enum PanelPreferencesMigration {

    /// Legacy storage key managed by `WidgetConfigManager`.
    static let legacyKey = "panel_widget_configs_v1"

    @MainActor
    static func runIfNeeded(
        appPreferences: AppPreferences,
        defaults: UserDefaults = .standard,
        deferFreshSeed: Bool = false
    ) {
        guard !appPreferences.panelPrefsMigratedV2 else { return }

        guard let legacyBlob = defaults.data(forKey: legacyKey) else {
            // No legacy blob locally. This runs from `AppPreferences.init`, BEFORE
            // `PreferenceSyncService.bootstrap()` has pulled remote values into local
            // UserDefaults — so the absence of a local blob does NOT guarantee a truly
            // fresh install. A new device (or reinstall) of an existing user who already
            // configured Panel 2.0 elsewhere also reaches this point with empty locals.
            //
            // Distinguish the two by inspecting iCloud KV directly: if the synced
            // per-section keys already exist there, the user has a real configuration
            // that `applyRemoteValues()` will merge in shortly. Seeding here would
            // overwrite it (each synced `didSet` writes the defaults back to iKV,
            // last-write-wins) and propagate the reset to all the user's devices.
            if hasRemotePanelPreferences() {
                // Existing user, new device — preserve the synced config. Mark the
                // per-device sentinel so we don't re-evaluate, without seeding.
                appPreferences.panelPrefsMigratedV2 = true
                #if DEBUG
                print("PanelPreferencesMigration: remote panel prefs detected → skip seeding (existing user)")
                #endif
                return
            }

            // No remote config detected — pero puede ser (a) install fresh real, o (b) un device
            // nuevo cuyo iKV aún no bajó (`NSUbiquitousKeyValueStore.synchronize` no bloquea por
            // red). Sembrar ahora clobbearía la config que está por llegar (last-write-wins).
            // Cuando se invoca desde `AppPreferences.init` (deferFreshSeed=true) DIFERIMOS el seed
            // SIN marcar el sentinel: AppBootstrapper re-invoca esto tras `iCloudFirstImportCompleted`
            // (gateado por MigrationGateLogic), cuando iKV ya está asentado y la decisión es segura.
            if freshSeedDecision(
                deferRequested: deferFreshSeed,
                isICloudAvailable: SwiftDataConfiguration.isICloudAvailable()
            ) == .deferToPostSyncHook {
                #if DEBUG
                print("PanelPreferencesMigration: fresh path → defer seed hasta post-sync hook")
                #endif
                return
            }

            // Punto seguro (post-sync vía hook, o sin cuenta iCloud) — seed opinionated P20-11
            // defaults para que la primera apertura del Panel sea "rica pero no saturada".
            appPreferences.setupDefaultsForNewUser()
            appPreferences.panelPrefsMigratedV2 = true
            #if DEBUG
            print("PanelPreferencesMigration: install fresh → setupDefaultsForNewUser applied")
            #endif
            return
        }

        // Upgrade path — bucketize the legacy blob into per-section keys,
        // preserving whatever the user had configured in v1.x.
        var orders: [PanelSectionKind: [String]] = [:]
        var hidden: [PanelSectionKind: [String]] = [:]

        // Only classify into sections that have persisted keys. Single-widget
        // sections (accounts, latestRecords, tools) and the health section
        // are toggled via `panelSectionsHidden`, not per-widget keys.
        let persistedSections: Set<PanelSectionKind> = [.tendencias, .distribucion, .planificacion]

        if let configs = try? JSONDecoder().decode([WidgetConfig].self, from: legacyBlob) {
            for config in configs {
                let section = config.type.panelSection
                guard persistedSections.contains(section) else { continue }
                orders[section, default: []].append(config.type.rawValue)
                if !config.isVisible {
                    hidden[section, default: []].append(config.type.rawValue)
                }
            }
        }

        appPreferences.panelTendenciasOrder     = orders[.tendencias]     ?? []
        appPreferences.panelTendenciasHidden    = hidden[.tendencias]     ?? []
        appPreferences.panelDistribucionOrder   = orders[.distribucion]   ?? []
        appPreferences.panelDistribucionHidden  = hidden[.distribucion]   ?? []
        appPreferences.panelPlanificacionOrder  = orders[.planificacion]  ?? []
        appPreferences.panelPlanificacionHidden = hidden[.planificacion]  ?? []

        appPreferences.panelPrefsMigratedV2 = true

        #if DEBUG
        print("PanelPreferencesMigration: upgrade path → \(orders.mapValues(\.count))")
        #endif
    }

    // MARK: - Decisión de siembra (pura)

    enum FreshSeedDecision: Equatable {
        /// Sembrar ahora mismo: la respuesta «no hay nada remoto» es de fiar.
        case seedNow
        /// Esperar al hook post-sync del paso 8.5 del bootstrap.
        case deferToPostSyncHook
    }

    /// Decide si la siembra de una instalación fresca puede correr ya o hay que
    /// diferirla.
    ///
    /// Está extraída y es pura porque el camino real no se puede aislar en un test:
    /// `hasRemotePanelPreferences()` lee el `NSUbiquitousKeyValueStore` GLOBAL del
    /// proceso —no el dominio inyectado—, así que cualquier test que haya escrito una
    /// preferencia sincronizada antes lo contamina. Mismo motivo por el que el test
    /// de la siembra llama a `setupDefaultsForNewUser()` a mano.
    ///
    /// **Sin cuenta iCloud no hay iKV del que puedan bajar preferencias**, así que
    /// «no encuentro nada remoto» deja de ser ambiguo: es una instalación fresca de
    /// verdad y sembrar no puede pisar nada. Es el mismo predicado con el que
    /// `MigrationGateLogic.shouldWaitForCloudKit` decide `.runNow`; hasta ahora esta
    /// rama esperaba igualmente hasta 15 s a un hook que en su caso no traería nada.
    static func freshSeedDecision(
        deferRequested: Bool,
        isICloudAvailable: Bool
    ) -> FreshSeedDecision {
        guard deferRequested else { return .seedNow }
        return isICloudAvailable ? .deferToPostSyncHook : .seedNow
    }

    /// Synced per-section keys that carry the user's Panel 2.0 configuration.
    /// (`panelPrefsMigratedV2` is intentionally excluded — it is per-device.)
    private static let syncedPanelKeys: [String] = [
        AppPreferences.Keys.panelTendenciasOrder,
        AppPreferences.Keys.panelTendenciasHidden,
        AppPreferences.Keys.panelDistribucionOrder,
        AppPreferences.Keys.panelDistribucionHidden,
        AppPreferences.Keys.panelPlanificacionOrder,
        AppPreferences.Keys.panelPlanificacionHidden,
        AppPreferences.Keys.panelSectionsHidden,
        AppPreferences.Keys.panelSectionsOrder,
    ]

    /// Whether iCloud KV already holds a Panel configuration written by another
    /// device of the same user. Checks `object(forKey:) != nil` (not "non-empty")
    /// because an empty string is a valid state — the user may have hidden every
    /// widget in a section — and still means a real config exists to preserve.
    private static func hasRemotePanelPreferences() -> Bool {
        let iKV = NSUbiquitousKeyValueStore.default
        // Prime the local cache from the last successful sync (idempotent; the
        // sync service also calls this during its own bootstrap).
        iKV.synchronize()
        return syncedPanelKeys.contains { iKV.object(forKey: $0) != nil }
    }
}
