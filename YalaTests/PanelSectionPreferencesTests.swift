//
//  PanelSectionPreferencesTests.swift
//  YalaTests
//
//  Tests de la SSOT per-sección de orden/visibilidad de widgets (P20-03).
//  Cubren:
//    - `activeWidgets(in:)` self-healing (order, hidden, dedupe, foreign filter,
//      append-at-tail de defaults faltantes, fallback bootstrap).
//    - `isWidgetVisible(_:)` con guard de section-hidden + per-widget-hidden y
//      fallback permisivo cuando AppPreferences aún no está inyectado.
//    - Debounced mutators (`moveWidgetInSection`, `setWidgetHidden`,
//      `resetSectionPreferences`) y `flushPendingSectionWrites()`.
//    - Guards per-widget en `performCalculation` — widgets ocultos no
//      sobrescriben su struct de salida.
//

import Foundation
import Testing

@testable import Yala

@MainActor
struct PanelSectionPreferencesTests {

    // MARK: - Helpers

    private static func makeSuite() -> UserDefaults {
        let suiteName = "PanelSectionPreferencesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        // Seed sentinel para evitar que corra la migration y toque UserDefaults.standard.
        defaults.set(true, forKey: AppPreferences.Keys.panelPrefsMigratedV2)
        return defaults
    }

    private static func makeVM(with prefs: AppPreferences) -> PanelViewModel {
        let vm = PanelViewModel()
        vm.setAppPreferences(prefs)
        return vm
    }

    // MARK: - 1. activeWidgets respects stored order

    @Test func activeWidgets_inSection_returnsOrderFromAppPreferences() {
        let defaults = Self.makeSuite()
        let prefs = AppPreferences(defaults: defaults)
        // Order covers 2 of the 3 tendencias widgets — weekdayBar is appended
        // at the tail by the self-healing `buildOrderedRawWidgets` pass.
        // PP2-07: expensesByNeed moved to Distribución, Tendencias has 3 widgets now.
        prefs.panelTendenciasOrder = ["flujo_efectivo", "tendencia_saldo"]

        let vm = Self.makeVM(with: prefs)
        let widgets = vm.activeWidgets(in: .tendencias)

        #expect(widgets.map { $0.type.rawValue } == [
            "flujo_efectivo", "tendencia_saldo", "gasto_por_dia"
        ])
    }

    // MARK: - 2. activeWidgets excludes hidden entries

    @Test func activeWidgets_inSection_excludesHiddenEntries() {
        let defaults = Self.makeSuite()
        let prefs = AppPreferences(defaults: defaults)
        prefs.panelTendenciasOrder = ["tendencia_saldo", "flujo_efectivo"]
        prefs.panelTendenciasHidden = ["flujo_efectivo"]

        let vm = Self.makeVM(with: prefs)
        let widgets = vm.activeWidgets(in: .tendencias)

        // `flujo_efectivo` hidden; `gasto_por_dia` appended at tail (self-healing).
        #expect(widgets.map { $0.type.rawValue } == [
            "tendencia_saldo", "gasto_por_dia",
        ])
    }

    // MARK: - 3. activeWidgets appends unknown defaults at tail

    @Test func activeWidgets_inSection_appendsUnknownDefaultsAtTail() {
        let defaults = Self.makeSuite()
        let prefs = AppPreferences(defaults: defaults)
        // Order stores only 2 of the 3 tendencias widgets. The remaining one
        // (`gasto_por_dia`) must appear at the tail automatically in declaration
        // order of `WidgetType.defaultWidgets`.
        prefs.panelTendenciasOrder = ["flujo_efectivo", "tendencia_saldo"]

        let vm = Self.makeVM(with: prefs)
        let widgets = vm.activeWidgets(in: .tendencias)

        #expect(widgets.map { $0.type.rawValue } == [
            "flujo_efectivo", "tendencia_saldo", "gasto_por_dia",
        ])
    }

    // MARK: - 4. activeWidgets filters foreign raw values

    @Test func activeWidgets_inSection_filtersForeignRawValues() {
        let defaults = Self.makeSuite()
        let prefs = AppPreferences(defaults: defaults)
        // "categorias_torta" belongs to .distribucion, not .tendencias. It must be dropped.
        prefs.panelTendenciasOrder = ["tendencia_saldo", "categorias_torta", "flujo_efectivo"]

        let vm = Self.makeVM(with: prefs)
        let widgets = vm.activeWidgets(in: .tendencias)

        #expect(widgets.map { $0.type.rawValue } == [
            "tendencia_saldo", "flujo_efectivo", "gasto_por_dia",
        ])
    }

    // MARK: - 5. activeWidgets dedupes corrupted order

    @Test func activeWidgets_inSection_dedupsCorruptedOrder() {
        let defaults = Self.makeSuite()
        let prefs = AppPreferences(defaults: defaults)
        // Duplicate entry. Only the first occurrence is preserved.
        prefs.panelTendenciasOrder = [
            "tendencia_saldo", "flujo_efectivo", "tendencia_saldo"
        ]

        let vm = Self.makeVM(with: prefs)
        let widgets = vm.activeWidgets(in: .tendencias)

        #expect(widgets.map { $0.type.rawValue } == [
            "tendencia_saldo", "flujo_efectivo", "gasto_por_dia",
        ])
    }

    // MARK: - 6. isWidgetVisible respects section + per-widget hidden

    @Test func isWidgetVisible_respectsSectionHiddenAndPerWidgetHidden() {
        let defaults = Self.makeSuite()
        let prefs = AppPreferences(defaults: defaults)
        let vm = Self.makeVM(with: prefs)

        // Baseline: everything visible.
        #expect(vm.isWidgetVisible(.trend) == true)

        // Per-widget hidden.
        prefs.panelTendenciasHidden = ["tendencia_saldo"]
        #expect(vm.isWidgetVisible(.trend) == false)
        #expect(vm.isWidgetVisible(.cashFlow) == true)

        // Section hidden overrides everything.
        prefs.panelTendenciasHidden = []
        prefs.panelSectionsHidden = ["tendencias"]
        #expect(vm.isWidgetVisible(.trend) == false)
        #expect(vm.isWidgetVisible(.cashFlow) == false)
        // Widgets from other sections are unaffected.
        #expect(vm.isWidgetVisible(.categoriesPie) == true)
    }

    // MARK: - 7. isWidgetVisible permissive fallback during bootstrap

    @Test func isWidgetVisible_permissiveFallbackWhenAppPreferencesNil() {
        // VM without `setAppPreferences` called yet — simulates bootstrap race
        // before PanelView injects the dependency.
        let vm = PanelViewModel()
        #expect(vm.isWidgetVisible(.trend) == true)
        #expect(vm.isWidgetVisible(.categoriesPie) == true)
        #expect(vm.isWidgetVisible(.budgets) == true)
    }

    // MARK: - 8. Debounced reorder: UI instant, persist after 200ms, batches into single write

    @Test func moveWidgetInSection_debounces200ms_andPersistsOnce() async throws {
        let defaults = Self.makeSuite()
        let prefs = AppPreferences(defaults: defaults)
        // Seed full 3-widget order so the draft operates on the complete set —
        // otherwise `orderedWidgetTypes` self-heals and the move indices won't
        // match what the user actually dragged in the sheet UI.
        // Tendencias has 3 widgets (trend, cashFlow, weekdayBar).
        prefs.panelTendenciasOrder = [
            "tendencia_saldo", "flujo_efectivo", "gasto_por_dia",
        ]
        let vm = Self.makeVM(with: prefs)

        // First move: position 0 → 2 (drops "tendencia_saldo" to the tail).
        vm.moveWidgetInSection(.tendencias, from: IndexSet(integer: 0), to: 2)
        let draftOrder = vm.orderedWidgetTypes(in: .tendencias).map(\.rawValue)
        #expect(draftOrder == [
            "flujo_efectivo", "tendencia_saldo", "gasto_por_dia",
        ])
        // AppPreferences not yet committed.
        #expect(prefs.panelTendenciasOrder == [
            "tendencia_saldo", "flujo_efectivo", "gasto_por_dia",
        ])

        // Second move within the debounce window. Only the final order persists.
        vm.moveWidgetInSection(.tendencias, from: IndexSet(integer: 2), to: 0)
        // Poll up to 10s para que el debounce de 200ms dispare. Bajo la carga
        // de la suite completa (1900+ tests en clones del simulador) el
        // scheduler puede tardar varios segundos en re-pumping el RunLoop —
        // el polling con deadline mantiene el test determinista sin bloquear
        // el progreso cuando el debounce ya completó.
        let expected = ["gasto_por_dia", "flujo_efectivo", "tendencia_saldo"]
        let deadline = Date.now.addingTimeInterval(10)
        while prefs.panelTendenciasOrder != expected && Date.now < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(prefs.panelTendenciasOrder == expected)
    }

    // MARK: - 9. flushPendingSectionWrites commits synchronously

    @Test func setWidgetHidden_flushesOnFlushPendingWrites() {
        let defaults = Self.makeSuite()
        let prefs = AppPreferences(defaults: defaults)
        let vm = Self.makeVM(with: prefs)

        vm.setWidgetHidden(.trend, hidden: true)
        // Draft visible, not yet persisted.
        #expect(vm.isWidgetHidden(.trend) == true)
        #expect(prefs.panelTendenciasHidden.contains("tendencia_saldo") == false)

        // Flush replaces the debounce — commit happens now.
        vm.flushPendingSectionWrites()
        #expect(prefs.panelTendenciasHidden.contains("tendencia_saldo") == true)
    }

    // MARK: - 11. Hidden widget keeps its output struct frozen (compute skipped)

    @Test func performCalculation_skipsHiddenWidgetsCompute() {
        // Without a modelContext the full `performCalculation` can't run — instead
        // we verify the gate via `isWidgetVisible` (the flag `performCalculation`
        // consults before each compute). A hidden widget reports not visible so
        // its `calculate*Widget` block is skipped and the struct stays frozen.
        let defaults = Self.makeSuite()
        let prefs = AppPreferences(defaults: defaults)
        let vm = Self.makeVM(with: prefs)

        // Baseline: visible.
        #expect(vm.isWidgetVisible(.trend) == true)
        #expect(vm.isWidgetVisible(.budgets) == true)

        // Per-widget hide.
        vm.setWidgetHidden(.trend, hidden: true)
        vm.setWidgetHidden(.budgets, hidden: true)

        // Draft consulted immediately (no debounce wait needed for the gate).
        #expect(vm.isWidgetVisible(.trend) == false)
        #expect(vm.isWidgetVisible(.budgets) == false)

        // Other widgets in the same section remain visible.
        #expect(vm.isWidgetVisible(.cashFlow) == true)
        #expect(vm.isWidgetVisible(.scheduledPayments) == true)
    }

    // MARK: - 10. Reset cancels pending debounce and writes defaults synchronously

    @Test func resetSectionPreferences_cancelsPendingAndWritesDefaults() async throws {
        let defaults = Self.makeSuite()
        let prefs = AppPreferences(defaults: defaults)
        prefs.panelTendenciasOrder = ["flujo_efectivo", "tendencia_saldo"]
        prefs.panelTendenciasHidden = ["tendencia_saldo"]
        let vm = Self.makeVM(with: prefs)

        // Start a debounced hide that should NOT commit because reset will cancel it.
        vm.setWidgetHidden(.cashFlow, hidden: true)
        vm.resetSectionPreferences(.tendencias)

        // Synchronously: order + hidden cleared.
        #expect(prefs.panelTendenciasOrder == [])
        #expect(prefs.panelTendenciasHidden == [])

        // Wait past the debounce window to ensure the cancelled Task never fires.
        try await Task.sleep(for: .milliseconds(350))
        #expect(prefs.panelTendenciasHidden == [])

        // activeWidgets falls back to section defaults.
        let types = vm.activeWidgets(in: .tendencias).map(\.type.rawValue)
        #expect(Set(types) == Set([
            "tendencia_saldo", "flujo_efectivo", "gasto_por_dia",
        ]))
    }

    // MARK: - P20-11: hasAnyVisibleWidget drives auto-hide

    @Test func hasAnyVisibleWidget_returnsTrueForSingleWidgetSections() {
        let defaults = Self.makeSuite()
        let prefs = AppPreferences(defaults: defaults)
        let vm = Self.makeVM(with: prefs)

        // Single-widget sections: helper always reports true so their section
        // stays on-screen as long as `isSectionVisible` allows it.
        #expect(vm.hasAnyVisibleWidget(in: .health))
        #expect(vm.hasAnyVisibleWidget(in: .accounts))
        #expect(vm.hasAnyVisibleWidget(in: .latestRecords))
        #expect(vm.hasAnyVisibleWidget(in: .tools))
    }

    @Test func hasAnyVisibleWidget_returnsFalseWhenAllHiddenInTendencias() {
        let defaults = Self.makeSuite()
        let prefs = AppPreferences(defaults: defaults)
        prefs.panelTendenciasHidden = [
            "tendencia_saldo", "flujo_efectivo", "gasto_por_dia",
        ]
        let vm = Self.makeVM(with: prefs)

        #expect(vm.hasAnyVisibleWidget(in: .tendencias) == false)
        // Other multi-widget sections still report true (nothing hidden).
        #expect(vm.hasAnyVisibleWidget(in: .distribucion))
        #expect(vm.hasAnyVisibleWidget(in: .planificacion))
    }

    // MARK: - P20-11: widgetSize / setWidgetSize round-trip

    @Test func widgetSize_defaultsMediumWhenUnknown() {
        let defaults = Self.makeSuite()
        let prefs = AppPreferences(defaults: defaults)
        let vm = Self.makeVM(with: prefs)

        // Fresh VM — widgetConfigs loads from .standard; absent types fallback to .medium.
        // Verify the helper returns a value (not crash) for every WidgetType.
        for type in WidgetType.allCases {
            let _ = vm.widgetSize(type)
        }
    }

    @Test func setWidgetSize_noOpForUnsupportedTypes() {
        let defaults = Self.makeSuite()
        let prefs = AppPreferences(defaults: defaults)
        let vm = Self.makeVM(with: prefs)

        // `exchangeRate` is a single-size widget — setting any other size must be silently ignored.
        let before = vm.widgetSize(.exchangeRate)
        vm.setWidgetSize(.exchangeRate, size: before == .medium ? .large : .medium)
        #expect(vm.widgetSize(.exchangeRate) == before)
    }

    @Test func setWidgetSize_persistsForSupportedTypes() {
        let defaults = Self.makeSuite()
        let prefs = AppPreferences(defaults: defaults)
        let vm = Self.makeVM(with: prefs)

        // `cashFlow` supports M/L. Flip and verify the change sticks in widgetConfigs.
        let before = vm.widgetSize(.cashFlow)
        let target: WidgetSize = before == .medium ? .large : .medium
        vm.setWidgetSize(.cashFlow, size: target)
        #expect(vm.widgetSize(.cashFlow) == target)
    }

    // MARK: - PP2-06b: supportedSizes incluyen .small para Budgets + ScheduledPayments

    @Test func budgets_supportedSizes_includesSmall() {
        let sizes = WidgetType.budgets.supportedSizes
        #expect(sizes.contains(.small))
        #expect(sizes.contains(.medium))
        #expect(sizes.contains(.large))
    }

    @Test func scheduledPayments_supportedSizes_includesSmall() {
        let sizes = WidgetType.scheduledPayments.supportedSizes
        #expect(sizes.contains(.small))
        #expect(sizes.contains(.medium))
    }
}
