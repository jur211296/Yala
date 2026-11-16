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
            if freshSeedDecision(deferRequested: deferFreshSeed) == .deferToPostSyncHook {
                #if DEBUG
                print("PanelPreferencesMigration: fresh path → defer seed hasta post-sync hook")
                #endif
                return
            }

            // Punto seguro (el hook post-sync del paso 8.5) — seed opinionated P20-11
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

    // MARK: - La salud a la vista (lote 1 de la nota de salud, 11-nov-2026)

    /// Marca local (por iPhone, sin sincronizar) de que ya se decidió encender la salud.
    static let healthShownOnceKey = "panelHealthShownOnceV23"

    /// Decisión de Jürgen (opción A, 11-nov-2026): la nota de salud se enciende UNA vez a quien la tiene oculta solo
    /// porque venía así, es decir, con la lista de secciones ocultas exactamente igual a la de fábrica hasta la 2.2.
    /// Quien tocó Configurar Panel tiene otra lista y no se toca. Corre en el arranque, tras el seed y el sync de
    /// preferencias; sin siembra todavía, o con la lista vacía (puede no haber bajado aún la de iCloud), no decide y
    /// vuelve a mirar en el próximo arranque.
    @MainActor
    static func showHealthOnceIfUntouched(appPreferences: AppPreferences, defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: healthShownOnceKey), appPreferences.panelPrefsMigratedV2 else { return }
        let hidden = appPreferences.panelSectionsHidden
        guard !hidden.isEmpty else { return }
        if let next = healthShownSections(from: hidden) {
            appPreferences.panelSectionsHidden = next
        }
        defaults.set(true, forKey: healthShownOnceKey)
    }

    /// La lista con la salud a la vista, o `nil` si no es la de fábrica anterior (quien la tocó decide).
    static func healthShownSections(from hidden: [String]) -> [String]? {
        guard hidden == PanelDefaults.hiddenSectionsUntil22 else { return nil }
        return hidden.filter { $0 != PanelSectionKind.health.rawValue }
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
    /// `hasRemotePanelPreferences()` lee el iCloud-KV GLOBAL del proceso por
    /// `OwnerKeyValueStore` —no el dominio inyectado—, así que depende de lo que
    /// cualquier test haya escrito antes ahí y de las dos marcas de `.standard` que
    /// abren o cierran esa puerta. Mismo motivo por el que el test de la siembra
    /// llama a `setupDefaultsForNewUser()` a mano.
    ///
    /// **Desde `AppPreferences.init` se difiere SIEMPRE** (card cmvc, 2026-11-06). Hasta ese día
    /// sembraba ya cuando faltaba el token de iCloud Drive, como si eso probara que no hay cuenta.
    /// No lo prueba: con Drive apagado y la sesión de iCloud abierta el token falta, y si el
    /// iCloud-KV del Apple ID viaja igual, la siembra del `init` pisaba por last-write-wins el
    /// Panel que el resto de dispositivos tenía configurado. En el `init` CloudKit aún no
    /// contestó, así que no hay forma de distinguir; el paso 8.5 del arranque sí (`hasICloudAccount`,
    /// token O CloudKit `.available`) y re-invoca la migración sin diferir. Sin cuenta, ese paso no
    /// espera al hook y la siembra llega en cuanto CloudKit contesta (techo de 5 s).
    static func freshSeedDecision(deferRequested: Bool) -> FreshSeedDecision {
        deferRequested ? .deferToPostSyncHook : .seedNow
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
        // La PUERTA y no el store crudo. Con una sesión solo-grupos en un móvil prestado este KV es el del
        // DUEÑO: leído a pelo, su Panel haría saltarse la siembra, y como la puerta le enmascara también
        // la aplicación, el teléfono se quedaría sin siembra y sin configuración. Cerrada, contesta «no
        // hay nada» y se siembra en local.
        let iKV = OwnerKeyValueStore.shared
        // Prime the local cache from the last successful sync (idempotent; the
        // sync service also calls this during its own bootstrap).
        iKV.synchronize()
        return syncedPanelKeys.contains { iKV.object(forKey: $0) != nil }
    }
}
