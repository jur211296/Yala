//
//  PanelPreferencesMigrationTests.swift
//  YalaTests
//
//  Tests para PanelPreferencesMigration — foundation del epic Panel 2.0.
//  Verifica la migración one-shot del JSON legacy `panel_widget_configs_v1`
//  a las 6 keys per-sección en AppPreferences, incluyendo casos corner:
//  JSON ausente, JSON inválido, segunda ejecución no-op.
//

import Foundation
import Testing

@testable import Yala

@MainActor
struct PanelPreferencesMigrationTests {

    // MARK: - Helpers

    private static func makeSuite() -> UserDefaults {
        let suiteName = "PanelPreferencesMigrationTests.\(UUID().uuidString)"
        return UserDefaults(suiteName: suiteName)!
    }

    private static func writeLegacyJSON(_ configs: [WidgetConfig], to defaults: UserDefaults) {
        let data = try! JSONEncoder().encode(configs)
        defaults.set(data, forKey: PanelPreferencesMigration.legacyKey)
    }

    // MARK: - runsOnce — classifies all widgets into their sections

    @Test func migration_runsOnce_fromLegacyJSON() {
        let defaults = Self.makeSuite()
        let legacy: [WidgetConfig] = [
            WidgetConfig(id: UUID(), type: .trend,               isVisible: true,  size: .medium),
            WidgetConfig(id: UUID(), type: .categoriesPie,       isVisible: true,  size: .large),
            WidgetConfig(id: UUID(), type: .budgets,             isVisible: false, size: .medium),
            WidgetConfig(id: UUID(), type: .latestRecords,       isVisible: true,  size: .medium),
            WidgetConfig(id: UUID(), type: .exchangeRate,        isVisible: false, size: .medium),
        ]
        Self.writeLegacyJSON(legacy, to: defaults)

        let prefs = AppPreferences(defaults: defaults)

        #expect(prefs.panelPrefsMigratedV2 == true)
        #expect(prefs.panelTendenciasOrder     == ["tendencia_saldo"])
        #expect(prefs.panelDistribucionOrder   == ["categorias_torta"])
        #expect(prefs.panelPlanificacionOrder  == ["presupuestos"])
        // latestRecords + exchangeRate classify to single-widget sections (no per-sec keys for them,
        // their visibility will go through panelSectionsHidden in P20-02 — not this test)
    }

    // MARK: - respectsLegacyOrder — preserves relative order per section

    @Test func migration_respectsLegacyOrder() {
        let defaults = Self.makeSuite()
        // Mixed across sections, but relative order within Distribucion must be preserved
        let legacy: [WidgetConfig] = [
            WidgetConfig(id: UUID(), type: .subcategoriesPie, isVisible: true,  size: .large),   // distribucion [0]
            WidgetConfig(id: UUID(), type: .trend,            isVisible: true,  size: .medium),  // tendencias [0]
            WidgetConfig(id: UUID(), type: .topSpending,      isVisible: false, size: .medium),  // distribucion [1]
            WidgetConfig(id: UUID(), type: .cashFlow,         isVisible: true,  size: .medium),  // tendencias [1]
            WidgetConfig(id: UUID(), type: .categoriesPie,    isVisible: true,  size: .large),   // distribucion [2]
        ]
        Self.writeLegacyJSON(legacy, to: defaults)

        let prefs = AppPreferences(defaults: defaults)

        #expect(prefs.panelTendenciasOrder == ["tendencia_saldo", "flujo_efectivo"])
        #expect(prefs.panelDistribucionOrder == [
            "subcategorias_torta", "categorias_principales", "categorias_torta"
        ])
    }

    // MARK: - capturesHiddenWidgets

    @Test func migration_capturesHiddenWidgets() {
        let defaults = Self.makeSuite()
        let legacy: [WidgetConfig] = [
            WidgetConfig(id: UUID(), type: .trend,          isVisible: false, size: .medium),
            WidgetConfig(id: UUID(), type: .cashFlow,       isVisible: true,  size: .medium),
            WidgetConfig(id: UUID(), type: .expensesByNeed, isVisible: false, size: .medium),
        ]
        Self.writeLegacyJSON(legacy, to: defaults)

        let prefs = AppPreferences(defaults: defaults)

        // expensesByNeed pertenece a Distribución, no a Tendencias.
        #expect(prefs.panelTendenciasOrder == ["tendencia_saldo", "flujo_efectivo"])
        #expect(prefs.panelTendenciasHidden == ["tendencia_saldo"])
        #expect(prefs.panelDistribucionOrder == ["gastos_por_naturaleza"])
        #expect(prefs.panelDistribucionHidden == ["gastos_por_naturaleza"])
    }

    // MARK: - guardedBySentinel — second run is no-op

    @Test func migration_guardedBySentinel_doesNotOverwrite() {
        let defaults = Self.makeSuite()

        // Simulate state where migration ran, user reordered after migration,
        // and a second runIfNeeded call must leave the user's order alone.
        defaults.set(true, forKey: AppPreferences.Keys.panelPrefsMigratedV2)
        defaults.set("flujo_efectivo,tendencia_saldo", forKey: AppPreferences.Keys.panelTendenciasOrder)
        // Also put legacy JSON that WOULD produce a different order if migration ran:
        let legacy: [WidgetConfig] = [
            WidgetConfig(id: UUID(), type: .trend,    isVisible: true, size: .medium),
            WidgetConfig(id: UUID(), type: .cashFlow, isVisible: true, size: .medium),
        ]
        Self.writeLegacyJSON(legacy, to: defaults)

        let prefs = AppPreferences(defaults: defaults)

        // User's custom order preserved
        #expect(prefs.panelTendenciasOrder == ["flujo_efectivo", "tendencia_saldo"])
        #expect(prefs.panelPrefsMigratedV2 == true)
    }

    // MARK: - fresh install siembra los predeterminados curados

    @Test func freshInstall_seedsCuratedDefaults() {
        let defaults = Self.makeSuite()
        let prefs = AppPreferences(defaults: defaults)
        // `init` invoca `runIfNeeded(deferFreshSeed: true)`. Sin cuenta iCloud la
        // siembra ya no se difiere (no hay iKV del que puedan bajar preferencias),
        // así que en el simulador esto siembra dentro del propio `init`. Lo
        // llamamos igualmente a mano para que el test siga siendo válido en un
        // entorno CON cuenta, donde el seed real corre en el hook post-sync.
        prefs.setupDefaultsForNewUser()

        // Tendencias: solo la gráfica de Tendencias. Promedio diario y Flujo de
        // efectivo van en el ORDEN (para poder recuperarlos) pero nacen apagados.
        #expect(prefs.panelTendenciasOrder == [
            "tendencia_saldo", "gasto_por_dia", "flujo_efectivo",
        ])
        #expect(prefs.panelTendenciasHidden == ["gasto_por_dia", "flujo_efectivo"])

        // Distribución conserva su reparto interno aunque la sección nazca oculta:
        // así `isSectionEffectivelyEmpty` sigue siendo falso y el botón
        // «Restablecer widgets de Distribución» no aparece.
        #expect(prefs.panelDistribucionOrder == [
            "categorias_torta", "subcategorias_torta", "gastos_por_naturaleza",
            "categorias_principales", "subcategorias_principales", "distribucion_por_etiquetas",
        ])
        #expect(prefs.panelDistribucionHidden == [
            "categorias_principales", "subcategorias_principales", "distribucion_por_etiquetas",
        ])

        // Planificación: Pagos planificados + Presupuestos, ambos visibles.
        #expect(prefs.panelPlanificacionOrder == [
            "pagos_planificados", "presupuestos",
        ])
        #expect(prefs.panelPlanificacionHidden == [])

        // Tres secciones nacen ocultas.
        #expect(prefs.panelSectionsHidden == ["health", "distribucion", "tools"])
        #expect(prefs.panelSectionsOrder == [])
    }

    // MARK: - El encargo, en una sola aserción de alto nivel

    /// Pin del contrato de producto: un usuario nuevo ve CUATRO secciones y CUATRO
    /// widgets. Si alguien cambia la tabla de `PanelDefaults` sin querer, cae aquí y
    /// no en un test de bajo nivel que no dice qué se rompió.
    @Test func freshInstall_muestraCuatroSeccionesYCuatroWidgets() {
        let defaults = Self.makeSuite()
        let prefs = AppPreferences(defaults: defaults)
        prefs.setupDefaultsForNewUser()
        // Enciende el centinela: sin esto la lectura RESUELVE desde la tabla y el test
        // mediría `PanelDefaults` consigo mismo en vez de lo que la siembra persistió.
        prefs.panelPrefsMigratedV2 = true

        let visibleSections = PanelSectionKind.allCases.filter {
            !prefs.resolvedSectionsHidden.contains($0.rawValue)
        }
        #expect(visibleSections == [.accounts, .tendencias, .planificacion, .latestRecords])

        let vm = PanelViewModel()
        vm.setAppPreferences(prefs)
        let visibleWidgets = visibleSections.flatMap { vm.activeWidgets(in: $0).map(\.type) }
        #expect(visibleWidgets == [.trend, .scheduledPayments, .budgets, .latestRecords])
    }

    // MARK: - setupDefaultsForNewUser — idempotent across call sites

    @Test func setupDefaultsForNewUser_overwritesWithCuratedDefaults() {
        let defaults = Self.makeSuite()
        defaults.set(true, forKey: AppPreferences.Keys.panelPrefsMigratedV2)
        let prefs = AppPreferences(defaults: defaults)

        // Estado custom previo, para confirmar que el seed lo sobrescribe.
        prefs.panelTendenciasOrder = ["flujo_efectivo"]
        prefs.panelTendenciasHidden = []
        prefs.panelSectionsHidden = []

        prefs.setupDefaultsForNewUser()

        #expect(prefs.panelTendenciasOrder.first == "tendencia_saldo")
        #expect(prefs.panelTendenciasHidden == ["gasto_por_dia", "flujo_efectivo"])
        #expect(prefs.panelDistribucionHidden.contains("categorias_principales"))
        #expect(prefs.panelSectionsHidden == ["health", "distribucion", "tools"])
    }

    // MARK: - Sin cuenta iCloud el seed NO se difiere

    /// Antes, una instalación sin cuenta iCloud esperaba igualmente al hook post-sync
    /// del paso 8.5 del bootstrap — hasta 15 s a por una señal que en su caso no iba a
    /// llegar. Sin cuenta no hay iKV del que bajar nada, así que la ambigüedad que
    /// motivaba el diferido no existe.
    ///
    /// Se prueba la decisión PURA y no el camino completo a propósito:
    /// `hasRemotePanelPreferences()` lee el `NSUbiquitousKeyValueStore` global del
    /// proceso, que cualquier test anterior que escriba una preferencia sincronizada
    /// contamina. Un test de integración aquí daría verde o rojo según el ORDEN de la
    /// suite, que es peor que no tenerlo.
    @Test func freshSeedDecision_matriz() {
        // Sin cuenta iCloud: sembrar ya, aunque el llamador pidiera diferir.
        #expect(PanelPreferencesMigration.freshSeedDecision(
            deferRequested: true, isICloudAvailable: false) == .seedNow)

        // Con cuenta iCloud: diferir, que es lo que evita pisar la configuración que
        // aún puede estar bajando.
        #expect(PanelPreferencesMigration.freshSeedDecision(
            deferRequested: true, isICloudAvailable: true) == .deferToPostSyncHook)

        // Llamado desde el punto seguro (el hook), nunca se difiere.
        #expect(PanelPreferencesMigration.freshSeedDecision(
            deferRequested: false, isICloudAvailable: true) == .seedNow)
        #expect(PanelPreferencesMigration.freshSeedDecision(
            deferRequested: false, isICloudAvailable: false) == .seedNow)
    }

    // MARK: - upgrade path — does not trigger setupDefaults

    @Test func migration_withLegacyData_doesNotCallSetupDefaults() {
        let defaults = Self.makeSuite()
        // Write legacy blob with only one widget — if migration seeded defaults
        // the other two tendencias widgets would appear in order. They must not.
        let legacy: [WidgetConfig] = [
            WidgetConfig(id: UUID(), type: .trend, isVisible: true, size: .medium),
        ]
        Self.writeLegacyJSON(legacy, to: defaults)

        let prefs = AppPreferences(defaults: defaults)

        // Only trend is bucketized from legacy — defaults NOT applied.
        #expect(prefs.panelTendenciasOrder == ["tendencia_saldo"])
        // No hidden entries persisted from legacy (trend was visible).
        #expect(prefs.panelTendenciasHidden == [])
    }

    // MARK: - invalidJSON — corrupt blob

    @Test func migration_invalidJSON_writesEmpty() {
        let defaults = Self.makeSuite()
        // Write junk bytes under the legacy key
        defaults.set(Data([0x01, 0x02, 0xFF]), forKey: PanelPreferencesMigration.legacyKey)

        let prefs = AppPreferences(defaults: defaults)

        #expect(prefs.panelPrefsMigratedV2 == true)
        #expect(prefs.panelTendenciasOrder == [])
        #expect(prefs.panelDistribucionOrder == [])
        #expect(prefs.panelPlanificacionOrder == [])
    }
}
