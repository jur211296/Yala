//
//  PanelViewModelTests.swift
//  YalaTests
//
//  Unit tests for PanelViewModel pure logic (account sorting, sort order consistency).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

struct PanelViewModelTests {

    // MARK: - Helpers

    private func makeAccount(name: String, isArchived: Bool = false) -> Account {
        let account = Account(
            name: name,
            currencyCode: "PEN",
            colorHex: "#000000",
            iconName: "creditcard",
            type: "bank"
        )
        account.isArchived = isArchived
        return account
    }

    // MARK: - orderedActiveAccounts

    @MainActor @Test func orderedActiveAccounts_excludesArchived() {
        let vm = PanelViewModel()
        let active = makeAccount(name: "Checking")
        let archived = makeAccount(name: "Old", isArchived: true)

        let result = vm.orderedActiveAccounts(
            from: [active, archived],
            sortOrderNames: ["Checking", "Old"]
        )
        #expect(result.count == 1)
        #expect(result[0].name == "Checking")
    }

    @MainActor @Test func orderedActiveAccounts_respectsSortOrder() {
        let vm = PanelViewModel()
        let a = makeAccount(name: "Alpha")
        let b = makeAccount(name: "Beta")
        let c = makeAccount(name: "Charlie")

        let result = vm.orderedActiveAccounts(
            from: [a, b, c],
            sortOrderNames: ["Charlie", "Alpha", "Beta"]
        )
        #expect(result[0].name == "Charlie")
        #expect(result[1].name == "Alpha")
        #expect(result[2].name == "Beta")
    }

    @MainActor @Test func orderedActiveAccounts_unknownFallsToEnd() {
        let vm = PanelViewModel()
        let known = makeAccount(name: "Checking")
        let unknown = makeAccount(name: "NewAccount")

        let result = vm.orderedActiveAccounts(
            from: [unknown, known],
            sortOrderNames: ["Checking"]
        )
        #expect(result[0].name == "Checking")
        #expect(result[1].name == "NewAccount")
    }

    @MainActor @Test func orderedActiveAccounts_bothUnknown_sortByName() {
        let vm = PanelViewModel()
        let z = makeAccount(name: "Zeta")
        let a = makeAccount(name: "Alpha")

        let result = vm.orderedActiveAccounts(
            from: [z, a],
            sortOrderNames: []
        )
        #expect(result[0].name == "Alpha")
        #expect(result[1].name == "Zeta")
    }

    // MARK: - ensureAccountsSortOrderConsistency

    @MainActor @Test func sortOrderConsistency_removesDeleted() {
        let vm = PanelViewModel()
        let a = makeAccount(name: "Checking")

        let result = vm.ensureAccountsSortOrderConsistency(
            accounts: [a],
            currentOrder: ["Checking", "Savings"]
        )
        #expect(result == ["Checking"])
    }

    @MainActor @Test func sortOrderConsistency_addsNew() {
        let vm = PanelViewModel()
        let a = makeAccount(name: "Checking")
        let b = makeAccount(name: "NewAccount")

        let result = vm.ensureAccountsSortOrderConsistency(
            accounts: [a, b],
            currentOrder: ["Checking"]
        )
        #expect(result == ["Checking", "NewAccount"])
    }

    @MainActor @Test func sortOrderConsistency_preservesExisting() {
        let vm = PanelViewModel()
        let a = makeAccount(name: "Alpha")
        let b = makeAccount(name: "Beta")
        let c = makeAccount(name: "Charlie")

        let result = vm.ensureAccountsSortOrderConsistency(
            accounts: [a, b, c],
            currentOrder: ["Charlie", "Alpha", "Beta"]
        )
        #expect(result == ["Charlie", "Alpha", "Beta"])
    }

    @MainActor @Test func sortOrderConsistency_emptyAccounts() {
        let vm = PanelViewModel()

        let result = vm.ensureAccountsSortOrderConsistency(
            accounts: [],
            currentOrder: ["Checking", "Savings"]
        )
        #expect(result == [])
    }

    @MainActor @Test func sortOrderConsistency_emptyCurrentOrder() {
        let vm = PanelViewModel()
        let a = makeAccount(name: "Alpha")
        let b = makeAccount(name: "Beta")

        let result = vm.ensureAccountsSortOrderConsistency(
            accounts: [a, b],
            currentOrder: []
        )
        // Both are new → appended in array order
        #expect(result.contains("Alpha"))
        #expect(result.contains("Beta"))
    }

    @MainActor @Test func sortOrderConsistency_roundTrip() {
        let vm = PanelViewModel()
        let a = makeAccount(name: "Alpha")
        let b = makeAccount(name: "Beta")
        let c = makeAccount(name: "Charlie")

        // First, get consistency output
        let consistent = vm.ensureAccountsSortOrderConsistency(
            accounts: [a, b, c],
            currentOrder: ["Beta", "Charlie", "Alpha"]
        )

        // Use that output as sortOrderNames for orderedActiveAccounts
        let ordered = vm.orderedActiveAccounts(from: [a, b, c], sortOrderNames: consistent)

        #expect(ordered[0].name == "Beta")
        #expect(ordered[1].name == "Charlie")
        #expect(ordered[2].name == "Alpha")
    }

    // MARK: - hiddenSections compute-skip (P20-02)

    /// Default state: every toggleable section reports visible, which drives
    /// the guards in `performCalculation` / `calculateTrendData`.
    @MainActor @Test func visibilityGuard_defaultsToVisible() {
        let vm = PanelViewModel()
        for kind in PanelSectionKind.toggleableSections {
            #expect(vm.isSectionVisible(kind), "\(kind) should default to visible")
        }
    }

    /// Toggling a section into `hiddenSections` flips the guard so its compute
    /// block is skipped in the calculation pipeline.
    @MainActor @Test func visibilityGuard_respectsHiddenSet() {
        let vm = PanelViewModel()
        vm.hiddenSections = [.distribucion, .planificacion]

        #expect(!vm.isSectionVisible(.distribucion))
        #expect(!vm.isSectionVisible(.planificacion))
        #expect(vm.isSectionVisible(.tendencias))
        #expect(vm.isSectionVisible(.tools))
    }

    /// P20-11: `latestRecords` is now toggleable. When the user hides it from
    /// the config sheet, `isSectionVisible` must return false — this is the
    /// contract driving the auto-hide behaviour.
    @MainActor @Test func visibilityGuard_latestRecordsNowToggleable() {
        let vm = PanelViewModel()
        vm.hiddenSections = [.latestRecords]
        #expect(vm.isSectionVisible(.latestRecords) == false)

        // Existing users with empty hiddenSections still see the section.
        vm.hiddenSections = []
        #expect(vm.isSectionVisible(.latestRecords))
    }

    /// P20-11: `toggleableSections` covers every kind — every section has a
    /// row in `PanelSectionsConfigView`. The helper's `canBeHidden` always
    /// returns true.
    @Test func toggleableSections_coversAllSections() {
        let toggleable = PanelSectionKind.toggleableSections
        #expect(toggleable.count == PanelSectionKind.allCases.count)
        for section in PanelSectionKind.allCases {
            #expect(section.canBeHidden)
            #expect(toggleable.contains(section))
        }
    }

    /// Every `PanelSectionKind` case must have a non-empty localized title and
    /// icon so the sections-config sheet never shows a blank row.
    @Test func everySectionHasTitleAndIcon() {
        for kind in PanelSectionKind.allCases {
            #expect(!kind.localizedTitle.isEmpty, "\(kind) missing title")
            #expect(!kind.iconName.isEmpty, "\(kind) missing icon")
        }
    }

    // MARK: - Hero IA (P20-05)
    //
    // Acotados a invariantes sin network: Free/no-consent reset del estado y
    // guard de heroData. El flow Pro+consent+API no se testea aquí — eso vive
    // en `HeroMessageCacheTests` (capa pura) y QA manual con `Yala Dev`.

    /// Sin `heroWidget.data`, `retriggerHeroAI` no toca el estado IA —
    /// precondición del VM antes de armar el contexto.
    @MainActor @Test func retriggerHeroAI_withoutHeroData_isNoOp() {
        let vm = PanelViewModel()
        vm.heroAISubtitle = "texto preseteado"

        vm.retriggerHeroAI()

        #expect(vm.heroAISubtitle == "texto preseteado")
    }

    /// Si el user no tiene consent IA, el VM debe dejar `heroAISubtitle`
    /// en nil (el view cae al fallback rule-based).
    @MainActor @Test func retriggerHeroAI_noConsent_resetsHeroAIState() {
        let vm = PanelViewModel()
        let prefs = AppPreferences(defaults: UserDefaults(suiteName: "retriggerHeroAI.noConsent.\(UUID().uuidString)")!)
        prefs.aiInsightsConsentAccepted = false
        vm.setAppPreferences(prefs)

        vm.heroWidget = PanelHeroData(data: HeroMonthData(
            state: .neutral, income: 4500, expense: 1500,
            daysRemaining: 20, daysElapsed: 10
        ))
        vm.heroAISubtitle = "mensaje viejo"

        vm.retriggerHeroAI()

        #expect(vm.heroAISubtitle == nil)
    }

    /// Desacople consent/feature: si el user tiene consent pero apagó la
    /// feature (`aiInsightsEnabled = false`), el VM también debe resetear
    /// el subtitle IA. Este caso sólo es expresable tras el refactor que
    /// separó consent (sticky) del toggle de feature.
    @MainActor @Test func retriggerHeroAI_consentButFeatureDisabled_resetsHeroAIState() {
        let vm = PanelViewModel()
        let prefs = AppPreferences(defaults: UserDefaults(suiteName: "retriggerHeroAI.disabled.\(UUID().uuidString)")!)
        prefs.aiInsightsConsentAccepted = true
        prefs.aiInsightsEnabled = false
        vm.setAppPreferences(prefs)

        vm.heroWidget = PanelHeroData(data: HeroMonthData(
            state: .neutral, income: 4500, expense: 1500,
            daysRemaining: 20, daysElapsed: 10
        ))
        vm.heroAISubtitle = "mensaje viejo"

        vm.retriggerHeroAI()

        #expect(vm.heroAISubtitle == nil)
    }

    // MARK: - Weekday Bar Widget (P20-07)
    //
    // Tests acotados a los guards que protegen el compute. El cálculo en sí
    // vive en `WeekdaySpendingCalculator` y tiene su propia suite (11 tests).

    /// `weekdayBar` debe pertenecer a la sección Tendencias — define dónde
    /// aparece en el Panel y el sheet de preferencias.
    @Test func weekdayBar_belongsToTendencias() {
        #expect(WidgetType.weekdayBar.panelSection == .tendencias)
        #expect(WidgetType.defaultWidgets(in: .tendencias).contains(.weekdayBar))
    }

    /// Bootstrap: antes de inyectar `AppPreferences`, `isWidgetVisible(.weekdayBar)`
    /// devuelve `true` — fallback permisivo consistente con los demás widgets.
    @MainActor @Test func weekdayBar_bootstrapVisibility_isPermissive() {
        let vm = PanelViewModel()
        #expect(vm.isWidgetVisible(.weekdayBar))
    }

    /// Ocultar el widget individualmente (via `panelTendenciasHidden`) debe
    /// flipear el guard → el compute del widget se saltea.
    @MainActor @Test func weekdayBar_skipsCompute_whenWidgetHidden() {
        let vm = PanelViewModel()
        let suite = "weekdayBar.widgetHidden.\(UUID().uuidString)"
        let prefs = AppPreferences(defaults: UserDefaults(suiteName: suite)!)
        prefs.panelTendenciasHidden = [WidgetType.weekdayBar.rawValue]
        vm.setAppPreferences(prefs)

        #expect(!vm.isWidgetVisible(.weekdayBar))
    }

    /// Ocultar la sección Tendencias entera (via `panelSectionsHidden`) también
    /// debe flipear el guard — el widget no computa aunque no esté en
    /// `panelTendenciasHidden`.
    @MainActor @Test func weekdayBar_skipsCompute_whenSectionHidden() {
        let vm = PanelViewModel()
        let suite = "weekdayBar.sectionHidden.\(UUID().uuidString)"
        let prefs = AppPreferences(defaults: UserDefaults(suiteName: suite)!)
        prefs.panelSectionsHidden = [PanelSectionKind.tendencias.rawValue]
        vm.setAppPreferences(prefs)

        #expect(!vm.isWidgetVisible(.weekdayBar))
    }

    // MARK: - Needs widget membership (PP2-07)

    /// `expensesByNeed` pertenece a Distribución (no a Tendencias) — se
    /// agrupa con los widgets que miran la dimensión "a dónde va tu gasto".
    @Test func expensesByNeed_belongsToDistribucion() {
        #expect(WidgetType.expensesByNeed.panelSection == .distribucion)
        #expect(WidgetType.defaultWidgets(in: .distribucion).contains(.expensesByNeed))
        #expect(!WidgetType.defaultWidgets(in: .tendencias).contains(.expensesByNeed))
    }

    // MARK: - Tags Pie Widget (P20-09)
    //
    // Tests acotados a los guards de visibilidad del widget. El cálculo vive
    // en `TagSpendingCalculator` y tiene su propia suite (15 tests).

    /// `tagsPie` debe pertenecer a Distribución — define dónde aparece en el
    /// Panel y el sheet de preferencias.
    @Test func tagsPie_belongsToDistribucion() {
        #expect(WidgetType.tagsPie.panelSection == .distribucion)
        #expect(WidgetType.defaultWidgets(in: .distribucion).contains(.tagsPie))
    }

    /// Bootstrap: antes de inyectar `AppPreferences`, `isWidgetVisible(.tagsPie)`
    /// devuelve `true` — fallback permisivo consistente con otros widgets.
    @MainActor @Test func tagsPie_bootstrapVisibility_isPermissive() {
        let vm = PanelViewModel()
        #expect(vm.isWidgetVisible(.tagsPie))
    }

    /// Ocultar el widget individualmente (via `panelDistribucionHidden`) debe
    /// flipear el guard → el compute del widget se saltea.
    @MainActor @Test func tagsPie_skipsCompute_whenWidgetHidden() {
        let vm = PanelViewModel()
        let suite = "tagsPie.widgetHidden.\(UUID().uuidString)"
        let prefs = AppPreferences(defaults: UserDefaults(suiteName: suite)!)
        prefs.panelDistribucionHidden = [WidgetType.tagsPie.rawValue]
        vm.setAppPreferences(prefs)

        #expect(!vm.isWidgetVisible(.tagsPie))
    }

    /// Ocultar la sección Distribución entera también flipea el guard.
    @MainActor @Test func tagsPie_skipsCompute_whenSectionHidden() {
        let vm = PanelViewModel()
        let suite = "tagsPie.sectionHidden.\(UUID().uuidString)"
        let prefs = AppPreferences(defaults: UserDefaults(suiteName: suite)!)
        prefs.panelSectionsHidden = [PanelSectionKind.distribucion.rawValue]
        vm.setAppPreferences(prefs)

        #expect(!vm.isWidgetVisible(.tagsPie))
    }

    // MARK: - Pair sync S↔S en Planificación (PP2-07)
    //
    // Invariante: budgets y scheduledPayments deben estar siempre "ambos small"
    // o "ambos no-small" para garantizar un grid ordenado en la sección
    // Planificación (par half-width con small, full-width con M/L).

    /// Bajar `budgets` a `.small` debe arrastrar `scheduledPayments` a `.small`.
    @MainActor @Test func syncPlanificacionPair_budgetsToSmall_scheduledAlsoSmall() {
        let vm = PanelViewModel()
        // Estado inicial: ambos fuera de small.
        vm.setWidgetSize(.budgets, size: .medium)
        vm.setWidgetSize(.scheduledPayments, size: .medium)

        vm.setWidgetSize(.budgets, size: .small)

        #expect(vm.widgetSize(.budgets) == .small)
        #expect(vm.widgetSize(.scheduledPayments) == .small)
    }

    /// Subir `scheduledPayments` desde small a `.medium` debe llevar `budgets`
    /// a su primer tamaño no-small disponible (también `.medium`).
    @MainActor @Test func syncPlanificacionPair_scheduledToMedium_fromSmall_budgetsAlsoMedium() {
        let vm = PanelViewModel()
        // Estado inicial: ambos small.
        vm.setWidgetSize(.budgets, size: .small)
        vm.setWidgetSize(.scheduledPayments, size: .small)

        vm.setWidgetSize(.scheduledPayments, size: .medium)

        #expect(vm.widgetSize(.scheduledPayments) == .medium)
        #expect(vm.widgetSize(.budgets) == .medium)
    }

    /// Subir `budgets` a `.large` cuando `scheduledPayments` está en small
    /// debe mover scheduledPayments a `.medium` (su máximo disponible fuera
    /// de small; no soporta `.large`).
    @MainActor @Test func syncPlanificacionPair_budgetsToLarge_scheduledRaisesToMediumMax() {
        let vm = PanelViewModel()
        vm.setWidgetSize(.budgets, size: .small)
        vm.setWidgetSize(.scheduledPayments, size: .small)

        vm.setWidgetSize(.budgets, size: .large)

        #expect(vm.widgetSize(.budgets) == .large)
        #expect(vm.widgetSize(.scheduledPayments) == .medium)
    }

    /// El sync corre independiente de visibility — si user oculta
    /// `scheduledPayments` y luego cambia `budgets`, el tamaño del oculto
    /// también se actualiza (consistencia al reactivar).
    @MainActor @Test func syncPlanificacionPair_otherHidden_stillSyncs() {
        let vm = PanelViewModel()
        let suite = "pairSync.hidden.\(UUID().uuidString)"
        let prefs = AppPreferences(defaults: UserDefaults(suiteName: suite)!)
        prefs.panelPlanificacionHidden = [WidgetType.scheduledPayments.rawValue]
        vm.setAppPreferences(prefs)

        vm.setWidgetSize(.budgets, size: .medium)
        vm.setWidgetSize(.scheduledPayments, size: .medium)

        vm.setWidgetSize(.budgets, size: .small)

        // Ambos en small aunque scheduledPayments esté oculto.
        #expect(vm.widgetSize(.scheduledPayments) == .small)
    }

    /// Si el otro widget ya está fuera de small, subir uno a otro tamaño
    /// no-small no debe moverlo (evita pisotear una elección previa entre
    /// medium/large cuando ambos ya están paired full-width).
    @MainActor @Test func syncPlanificacionPair_otherAlreadyNonSmall_noChange() {
        let vm = PanelViewModel()
        // Ambos ya en medium (fuera de small).
        vm.setWidgetSize(.budgets, size: .medium)
        vm.setWidgetSize(.scheduledPayments, size: .medium)

        // Subir budgets a large. scheduled ya no está en small →
        // el guard `otherCurrent == .small` hace que no se mueva.
        vm.setWidgetSize(.budgets, size: .large)

        #expect(vm.widgetSize(.budgets) == .large)
        #expect(vm.widgetSize(.scheduledPayments) == .medium)
    }

    /// No recursión: cambiar el tamaño no debe disparar un loop infinito.
    /// Si el test completa (no stack overflow), pasa.
    @MainActor @Test func syncPlanificacionPair_noRecursion() {
        let vm = PanelViewModel()
        vm.setWidgetSize(.budgets, size: .medium)
        vm.setWidgetSize(.scheduledPayments, size: .medium)

        // Cambio que dispara el sync recíproco. Si el guard `isSyncingPair`
        // falla, esto stackovverflow y el test crashea.
        vm.setWidgetSize(.budgets, size: .small)

        #expect(vm.widgetSize(.budgets) == .small)
        #expect(vm.widgetSize(.scheduledPayments) == .small)
    }

}
