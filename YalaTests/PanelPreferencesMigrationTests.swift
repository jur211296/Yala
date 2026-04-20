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

        #expect(prefs.panelTendenciasOrder == [
            "tendencia_saldo", "flujo_efectivo", "gastos_por_naturaleza"
        ])
        #expect(prefs.panelTendenciasHidden == [
            "tendencia_saldo", "gastos_por_naturaleza"
        ])
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

    // MARK: - noLegacyData — fresh install (P20-11: seeds opinionated defaults)

    @Test func migration_noLegacyData_seedsP20_11Defaults() {
        let defaults = Self.makeSuite()
        // No `panel_widget_configs_v1` key — simulate fresh install

        let prefs = AppPreferences(defaults: defaults)

        #expect(prefs.panelPrefsMigratedV2 == true)

        // Tendencias: trend + cashFlow visible, weekdayBar + need hidden
        #expect(prefs.panelTendenciasOrder == [
            "tendencia_saldo", "flujo_efectivo", "gasto_por_dia", "gastos_por_naturaleza",
        ])
        #expect(prefs.panelTendenciasHidden == [
            "gasto_por_dia", "gastos_por_naturaleza",
        ])

        // Distribución: only categoriesPie visible
        #expect(prefs.panelDistribucionOrder == [
            "categorias_torta", "subcategorias_principales", "categorias_principales",
            "subcategorias_torta", "distribucion_por_etiquetas",
        ])
        #expect(prefs.panelDistribucionHidden == [
            "subcategorias_principales", "categorias_principales",
            "subcategorias_torta", "distribucion_por_etiquetas",
        ])

        // Planificación: budgets + scheduledPayments visible (groupsSummary
        // removed entirely in P20-11).
        #expect(prefs.panelPlanificacionOrder == [
            "presupuestos", "pagos_planificados",
        ])
        #expect(prefs.panelPlanificacionHidden == [])

        #expect(prefs.panelSectionsHidden == [])
    }

    // MARK: - setupDefaultsForNewUser — idempotent across call sites

    @Test func setupDefaultsForNewUser_overwritesWithOpinionatedDefaults() {
        let defaults = Self.makeSuite()
        defaults.set(true, forKey: AppPreferences.Keys.panelPrefsMigratedV2)
        let prefs = AppPreferences(defaults: defaults)

        // Seed some custom state first to confirm setupDefaults overwrites it.
        prefs.panelTendenciasOrder = ["flujo_efectivo"]
        prefs.panelTendenciasHidden = []

        prefs.setupDefaultsForNewUser()

        #expect(prefs.panelTendenciasOrder.first == "tendencia_saldo")
        #expect(prefs.panelTendenciasHidden.contains("gasto_por_dia"))
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
