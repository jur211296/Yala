//
//  TabImplicitAnimationsWiringTests.swift
//  YalaTests
//
//  Card 8atf (opción B de la card 1yhi, Jürgen, 2026-10-30): `ContentView` sigue apagando la animación de toda
//  transacción que cruza las pestañas —contra el parpadeo al cerrar hojas y en la pestaña temporal de Buscar—, y lo que
//  merece animarse dentro de una pestaña lo hace con una animación implícita `.animation(_:value:)`, que actúa por
//  debajo del apagado. Un `withAnimation` ahí no anima nada (regla «Animar dentro de una pestaña» de `swiftui-ds.md`).
//
//  Source-scan: que el apagado siga, y que cada sitio elegido anime con la variable que cambia. Que de verdad anime se
//  vio en vídeo en el simulador (capturas del PR).
//

import Foundation
import Testing

@Suite("Animaciones dentro de las pestañas — cableado (source-scan)")
struct TabImplicitAnimationsWiringTests {

    private static func source(_ relativePath: String, file: StaticString = #filePath) throws -> String {
        let repoRoot = URL(fileURLWithPath: "\(file)").deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: repoRoot.appending(path: relativePath), encoding: .utf8)
    }

    /// Las líneas de código, sin comentarios, para que documentar el patrón no cuente como usarlo.
    private static func codeLines(_ relativePath: String) throws -> [String] {
        try source(relativePath).components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.hasPrefix("//") && !$0.hasPrefix("///") }
    }

    @Test func contentView_keepsTheGlobalSwitchOnTheTabs() throws {
        let code = try Self.codeLines("Yala/App/ContentView.swift")
        let tabStyle = try #require(code.firstIndex(of: ".tabViewStyle(.sidebarAdaptable)"))
        let switchOff = try #require(code.firstIndex(of: ".transaction { $0.animation = nil }"),
                                     "Se quitó el apagado global de ContentView: la decisión 1yhi es mantenerlo.")
        #expect(switchOff > tabStyle && switchOff - tabStyle < 8, "El apagado tiene que colgar de la TabView.")
    }

    /// (fichero, la animación implícita que tiene que llevar). Cada una anima la variable que el toque cambia.
    static let animated: [(path: String, needle: String)] = [
        ("Yala/App/Views/Panel/PanelView.swift",
         ".animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: notices)"),
        ("Yala/App/Views/Panel/PanelView.swift",
         ".animation(reduceMotion ? nil : .easeInOut(duration: DS.Animation.normal), value: showFloatingActions)"),
        ("Yala/App/Views/Panel/Components/PanelNoticeCarousel.swift",
         ".animation(reduceMotion ? nil : .easeInOut(duration: DS.Animation.normal), value: current)"),
        ("Yala/App/Views/Groups/GroupsContainerView.swift",
         ".animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: showNudgeBanner)"),
        ("Yala/App/Views/Groups/GroupsContainerView.swift",
         ".animation(reduceMotion ? nil : .easeInOut(duration: DS.Animation.normal), value: showFloatingActions)"),
        ("Yala/App/Views/Groups/GroupDetailView.swift",
         ".animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: showNudgeBanner)"),
        ("Yala/App/Views/Planning/BudgetsListView.swift",
         ".animation(reduceMotion ? nil : .easeInOut(duration: DS.Animation.normal), value: showFloatingNew)"),
        ("Yala/App/Views/Planning/ScheduledPaymentsView.swift",
         ".animation(reduceMotion ? nil : .easeInOut(duration: DS.Animation.normal), value: showFloatingNew)"),
        ("Yala/App/Views/Reports/CashFlow/CashFlowMonthDetailView.swift",
         ".animation(reduceMotion ? nil : .easeInOut(duration: DS.Animation.fast), value: incomeCollapsed)"),
        ("Yala/App/Views/Reports/CashFlow/CashFlowMonthDetailView.swift",
         ".animation(reduceMotion ? nil : .easeInOut(duration: DS.Animation.fast), value: expenseCollapsed)"),
        ("Yala/App/Views/Reports/CashFlow/CashFlowMonthStrip.swift",
         ".animation(reduceMotion ? nil : .easeInOut(duration: DS.Animation.fast), value: selectedMonthKey)"),
        // Card pjum (pasada de fluidez, 2026-10-31).
        ("Yala/App/Views/Panel/PanelView.swift",
         ".animation(reduceMotion ? nil : DS.Animation.appear, value: appPreferences.panelAccountsCollapsed)"),
        ("Yala/App/Views/Groups/GroupDetailView.swift",
         ".animation(reduceMotion ? nil : StagedTabSelection<GroupDetailTab>.animation, value: selectedTab)"),
        ("Yala/App/Views/Statistics/DetailContainerView.swift",
         ".animation(reduceMotion ? nil : StagedTabSelection<DetailViewTab>.animation, value: selectedTab)"),
        ("Yala/App/Views/Shared/SegmentedPills.swift",
         ".dsAnimation(DS.Animation.selection, value: selection, reduceMotion: reduceMotion)"),
        ("Yala/App/Views/Chat/ChatSheetView.swift",
         ".dsAnimation(DS.Animation.appear, value: viewModel.messages.count, reduceMotion: reduceMotion)"),
        // Cards C1 y C7 (transiciones de contenido, 2026-11-01): las cargas se funden. El esqueleto, en
        // `ContentTransitionsWiringTests`; las filas que entran o se van, con `animatesRowEdits`.
        ("Yala/App/Views/Groups/GroupsContainerView.swift",
         // Card hsqm (2026-11-02): sin fundido si la carga llegó en el mismo `onAppear` (el indicador no se pintó).
         ".animation(reduceMotion || firstLoadArrivedOnAppear ? nil : DS.Animation.appear, value: viewModel.hasLoadedOnce)"),
        ("Yala/App/Views/Statistics/InsightsTabView.swift",
         ".animation(reduceMotion ? nil : DS.Animation.appear, value: viewModel.insightData == nil)"),
        ("Yala/App/Views/Statistics/InsightsTabView.swift",
         ".animation(reduceMotion ? nil : DS.Animation.appear, value: viewModel.isLoadingAI)"),
        ("Yala/App/Views/Statistics/CategoriesTabView.swift",
         ".animation(reduceMotion ? nil : DS.Animation.appear, value: insightsViewModel.isLoadingAI)"),
        ("Yala/App/Views/Statistics/TrendsTabView.swift",
         ".animation(reduceMotion ? nil : DS.Animation.appear, value: trendsAI.phase == .loading)"),
        ("Yala/App/Views/Statistics/RecordsTabView.swift",
         ".animation(reduceMotion ? nil : DS.Animation.appear, value: viewModel.hasAppliedFilters)"),
        ("Yala/App/Views/Chat/ChatGreetingBubble.swift",
         ".animation(reduceMotion ? nil : DS.Animation.appear, value: isPreparing)"),
        // Card C2 (los `withAnimation` / `dsWithAnimation` que no animaban dentro de las pestañas, 2026-11-02).
        ("Yala/App/Views/Panel/HeroMonthView.swift",
         ".animation(reduceMotion ? nil : DS.Animation.selection, value: sessionState.selectedTransactionNatures)"),
        ("Yala/App/Views/Panel/HeroMonthView.swift",
         ".animation(reduceMotion ? nil : DS.Animation.selection, value: selectedPeriod)"),
        ("Yala/App/Views/Panel/HeroMonthView.swift",
         "titleMotion: reduceMotion ? nil : .fade"),
        ("Yala/App/Views/Panel/Components/PanelFilterControlBar.swift",
         ".animation(reduceMotion ? nil : DS.Animation.selection, value: chipLayout)"),
        ("Yala/App/Views/Panel/ScheduledPaymentsWidget.swift",
         ".dsAnimation(DS.Animation.selection, value: filter, reduceMotion: reduceMotion)"),
        ("Yala/App/Views/Panel/TrendsCarouselWidget.swift",
         ".dsAnimation(DS.Animation.selection, value: viewModel.trendType, reduceMotion: reduceMotion)"),
        ("Yala/App/Views/Panel/ExchangeRateWidget.swift",
         ".dsAnimation(DS.Animation.selection, value: filteredCurrency, reduceMotion: reduceMotion)"),
        ("Yala/App/Views/Panel/BudgetsWidget.swift",
         ".dsAnimation(DS.Animation.selection, value: selectedBudgetID, reduceMotion: reduceMotion)"),
        ("Yala/App/Views/Statistics/RecordsTabView.swift",
         ".dsAnimation(DS.Animation.selection, value: viewModel.selectedTransactionNatures, reduceMotion: reduceMotion)"),
        ("Yala/App/Views/Statistics/RecordsTabView.swift",
         ".dsAnimation(DS.Animation.selection, value: viewModel.recordsViewMode, reduceMotion: reduceMotion)"),
        ("Yala/App/Views/Records/Components/RecordsCalendarView.swift",
         ".dsAnimation(DS.Animation.selection, value: selectedDay, reduceMotion: reduceMotion)"),
        ("Yala/App/Views/Records/Components/RecordsCalendarView.swift",
         ".dsAnimation(DS.Animation.appear, value: monthSteps, reduceMotion: reduceMotion)"),
        ("Yala/App/Views/Records/Components/RecordsCalendarView.swift",
         ".transition(monthMotion.transition)"),
        ("Yala/App/Views/Groups/GroupsContainerView.swift",
         ".animation(reduceMotion ? nil : DS.Animation.appear, value: viewModel.showArchived)"),
        ("Yala/App/Views/Groups/GroupsContainerView.swift",
         ".animation(reduceMotion ? nil : DS.Animation.appear, value: notificationsCardDismissals)"),
        ("Yala/App/Views/Groups/GroupNotificationsOptInCard.swift",
         ".animation(reduceMotion ? nil : DS.Animation.appear, value: state)"),
        ("Yala/App/Views/Statistics/InsightsTabView.swift",
         ".animation(reduceMotion ? nil : DS.Animation.appear, value: isToPayExpanded)"),
        ("Yala/App/Views/Statistics/InsightsTabView.swift",
         ".animation(reduceMotion ? nil : DS.Animation.appear, value: budgetsExpandedChoice)"),
        ("Yala/App/Views/Statistics/InsightsTabView.swift",
         ".animation(reduceMotion ? nil : DS.Animation.appear, value: isNeedSectionExpanded)"),
        ("Yala/App/Views/Statistics/TrendsTabView.swift",
         ".animation(reduceMotion ? nil : DS.Animation.appear, value: showsPreviousPeriod)"),
        ("Yala/App/Views/Statistics/TrendsTabView.swift",
         ".dsAnimation(DS.Animation.selection, value: cashFlowViewType, reduceMotion: reduceMotion)"),
        ("Yala/App/Views/Statistics/CategoriesTabView.swift",
         ".dsAnimation(DS.Animation.selection, value: chartsCarouselPosition, reduceMotion: reduceMotion)"),
        ("Yala/App/Views/Statistics/CategoriesTabView.swift",
         ".dsAnimation(DS.Animation.selection, value: selectedSankeyPoolNodeIDs, reduceMotion: reduceMotion)"),
        ("Yala/App/Views/Statistics/CategoriesTabView.swift",
         ".dsAnimation(DS.Animation.selection, value: listViewType, reduceMotion: reduceMotion)"),
        ("Yala/App/Views/Statistics/DetailContainerView.swift",
         ".animation(reduceMotion ? nil : DS.Animation.appear, value: showFloatingActions)"),
        // Registros (página): los flotantes salen al perder de vista la fila de acciones, como en Estadísticas (card rtyu).
        ("Yala/App/Views/Records/RecordsStandaloneView.swift",
         ".animation(reduceMotion ? nil : DS.Animation.appear, value: showFloatingActions)"),
        ("Yala/App/Views/Planning/Components/BudgetProgressBar.swift",
         ".animation(reduceMotion ? nil : DS.Animation.number, value: percentage)"),
        ("Yala/App/Views/Planning/ScheduledPaymentsListView.swift",
         ".animation(reduceMotion ? nil : DS.Animation.number, value: fraction)"),
        ("Yala/App/Views/Planning/ScheduledPaymentsListView.swift",
         ".dsAnimation(DS.Animation.selection, value: viewModel.paymentsViewMode, reduceMotion: reduceMotion)"),
        ("Yala/App/Views/Planning/ScheduledPaymentsListView.swift",
         ".dsAnimation(DS.Animation.selection, value: selectedDay, reduceMotion: reduceMotion)"),
        ("Yala/App/Views/Planning/BudgetChartsView.swift",
         ".animation(reduceMotion ? nil : DS.Animation.selection, value: selectedCategory)"),
        ("Yala/App/Views/Planning/BudgetChartsView.swift",
         ".animation(reduceMotion ? nil : DS.Animation.appear, value: localDateInterval.start)"),
        ("Yala/App/Views/Transactions/NewTransactionView.swift",
         ".animation(reduceMotion ? nil : DS.Animation.number, value: converted)"),
        // Card oxyr (los que la auditoría no listó, 2026-11-03): inventario en el PR.
        ("Yala/App/Views/Panel/CategoriesPieWidget.swift",
         ".animation(reduceMotion ? nil : DS.Animation.appear, value: hoveredItem?.identity)"),
        ("Yala/App/Views/Panel/SubcategoriesPieWidget.swift",
         ".animation(reduceMotion ? nil : DS.Animation.appear, value: hoveredItem?.identity)"),
        ("Yala/App/Views/Panel/TagsPieWidget.swift",
         ".animation(reduceMotion ? nil : DS.Animation.appear, value: hoveredItem?.identity)"),
        ("Yala/App/Views/Shared/DonutChartView.swift",
         ".animation(reduceMotion ? nil : DS.Animation.appear, value: hoveredItem?.id)"),
        ("Yala/App/Views/Statistics/Sankey/SankeyLabelModeToggle.swift",
         ".dsAnimation(DS.Animation.selection, value: mode, reduceMotion: reduceMotion)"),
        ("Yala/App/Views/Groups/GroupStatsView.swift",
         ".animation(reduceMotion ? nil : DS.Animation.selection, value: allCurrenciesPage)"),
        ("Yala/App/Views/Shared/ExpandableFAB.swift",
         ".animation(reduceMotion ? nil : Self.fabSpring, value: showMenu)"),
        ("Yala/App/Views/Shared/FABStackView.swift",
         ".animation(reduceMotion ? nil : Self.fabSpring, value: showFABMenu)"),
        ("Yala/App/Views/Reports/CashFlow/CashFlowSetupView.swift",
         ".animation(reduceMotion ? nil : DS.Animation.appear, value: showVariableLines)"),
        ("Yala/App/Views/Search/GlobalSearchView.swift",
         ".animation(reduceMotion ? nil : DS.Animation.appear, value: isDataReady)"),
        ("Yala/App/Views/Search/GlobalSearchView.swift",
         ".dsAnimation(DS.Animation.selection, value: selectedFilter, reduceMotion: reduceMotion)"),
        ("Yala/App/Views/Reports/ReportComparisonViews.swift",
         ".dsAnimation(DS.Animation.selection, value: sessionState.comparisonMode, reduceMotion: reduceMotion)"),
        ("Yala/App/Views/Statistics/DetailContainerView.swift",
         ".animation(reduceMotion ? nil : DS.Animation.appear, value: statisticsGuidesDismissed)"),
        // Encargo fluidez-subpestanas-duplicados-y-splash (2026-11-03): «Quitar repetidos» (0mzg), las marcas de ayuda
        // del Panel (v84b) y el brillo de los esqueletos (ehsu).
        ("Yala/App/Views/Statistics/RecordsTabView.swift",
         ".animation(reduceMotion ? nil : DS.Animation.appear, value: viewModel.duplicateRemovalCount)"),
        ("Yala/App/Tips/CoachMarkOverlay.swift",
         ".animation(reduceMotion ? nil : DS.Animation.appear, value: isVisible)"),
        ("Yala/App/Tips/CoachMarkOverlay.swift",
         ".animation(reduceMotion ? nil : DS.Animation.appear, value: showTooltip)"),
        ("Yala/App/Tips/CoachMarkOverlay.swift",
         ".animation(reduceMotion ? nil : DS.Animation.selection, value: currentIndex)"),
        ("Yala/App/Views/Shared/SkeletonView.swift",
         ".animation(reduceMotion ? nil : Self.sweep, value: phase)"),
    ]

    /// Card C2: los sitios de la lista ya no envuelven el cambio en un `withAnimation` / `dsWithAnimation`, que dentro de
    /// una pestaña no anima nada y hacía creer que la animación existía. (fichero, el envoltorio que no debe volver).
    static let deadWrappers: [(path: String, needle: String)] = [
        ("Yala/App/Views/Panel/HeroMonthView.swift", "dsWithAnimation("),
        ("Yala/App/Views/Panel/Components/PanelFilterControlBar.swift", "dsWithAnimation("),
        ("Yala/App/Views/Panel/ScheduledPaymentsWidget.swift", "dsWithAnimation("),
        ("Yala/App/Views/Panel/ExchangeRateWidget.swift", "dsWithAnimation("),
        ("Yala/App/Views/Panel/BudgetsWidget.swift", "dsWithAnimation("),
        ("Yala/App/Views/Statistics/RecordsTabView.swift", "dsWithAnimation("),
        ("Yala/App/Views/Records/Components/RecordsCalendarView.swift", "dsWithAnimation("),
        ("Yala/App/Views/Groups/GroupNotificationsOptInCard.swift", "withAnimation"),
        ("Yala/App/Views/Statistics/InsightsTabView.swift", "dsWithAnimation("),
        ("Yala/App/Views/Statistics/TrendsTabView.swift", "dsWithAnimation("),
        ("Yala/App/Views/Planning/ScheduledPaymentsListView.swift", "dsWithAnimation("),
        ("Yala/App/Views/Planning/BudgetChartsView.swift", "withAnimation"),
        // Card oxyr (2026-11-03).
        ("Yala/App/Views/Panel/CategoriesPieWidget.swift", "dsWithAnimation("),
        ("Yala/App/Views/Panel/SubcategoriesPieWidget.swift", "dsWithAnimation("),
        ("Yala/App/Views/Panel/TagsPieWidget.swift", "dsWithAnimation("),
        ("Yala/App/Views/Shared/DonutChartView.swift", "dsWithAnimation("),
        ("Yala/App/Views/Statistics/Sankey/SankeyLabelModeToggle.swift", "dsWithAnimation("),
        ("Yala/App/Views/Groups/GroupStatsView.swift", "dsWithAnimation("),
        ("Yala/App/Views/Shared/ExpandableFAB.swift", "dsWithAnimation("),
        ("Yala/App/Views/Shared/FABStackView.swift", "dsWithAnimation("),
        ("Yala/App/Views/Search/GlobalSearchView.swift", "dsWithAnimation("),
        ("Yala/App/Views/Reports/ReportComparisonViews.swift", "dsWithAnimation("),
        ("Yala/App/Views/Panel/SiriTipCard.swift", "dsWithAnimation("),
        ("Yala/App/Views/Panel/Sections/PanelPanoramaSection.swift", "dsWithAnimation("),
        ("Yala/App/Views/Panel/Components/PanelNoticeCarousel.swift", "dsWithAnimation("),
        ("Yala/App/Views/Shared/TopPrimaryAction.swift", "dsWithAnimation("),
        ("Yala/App/Views/Filters/SegmentFilterChoiceSheet.swift", "dsWithAnimation("),
        ("Yala/App/Views/Filters/FilterChipView.swift", "dsWithAnimation("),
        ("Yala/App/Views/Filters/FilterControlBar.swift", "dsWithAnimation("),
        ("Yala/App/Views/Panel/PanelWidgetSection.swift", "dsWithAnimation("),
        ("Yala/App/Views/Statistics/CategoriesTabView.swift", "dsWithAnimation("),
        ("Yala/App/Views/Shared/PeriodNavigationHeader.swift", "dsWithAnimation("),
        ("Yala/App/Views/Panel/PanelView.swift", "dsWithAnimation("),
        ("Yala/App/Views/Reports/CashFlow/CashFlowSetupView.swift", "withAnimation"),
        ("Yala/App/Views/Groups/GroupsContainerView.swift", "withAnimation"),
        ("Yala/App/Views/Groups/GroupDetailView.swift", "withAnimation"),
        ("Yala/App/Views/Reports/CashFlow/CashFlowMonthDetailView.swift", "withAnimation"),
        ("Yala/App/Views/Reports/CashFlow/CashFlowTableView.swift", "withAnimation"),
        ("Yala/App/Views/Reports/GroupingChipsBar.swift", "withAnimation"),
        ("Yala/App/Views/Shared/ContextualGuideBanner.swift", "withAnimation"),
        // Encargo fluidez-subpestanas-duplicados-y-splash (2026-11-03).
        ("Yala/App/Tips/CoachMarkOverlay.swift", "dsWithAnimation("),
        ("Yala/App/Views/Shared/SkeletonView.swift", "withAnimation"),
    ]

    @Test(arguments: deadWrappers.indices)
    func eachC2AndOxyrSite_dropsTheDeadWrapper(_ index: Int) throws {
        let (path, needle) = Self.deadWrappers[index]
        let code = try Self.codeLines(path)
        #expect(!code.contains { $0.contains(needle) }, "\(path) vuelve a envolver un cambio en «\(needle)».")
    }

    @Test(arguments: animated.indices)
    func eachChosenSite_animatesImplicitly(_ index: Int) throws {
        let (path, needle) = Self.animated[index]
        let code = try Self.codeLines(path)
        #expect(code.contains(needle), "\(path) ya no anima con «\(needle)».")
    }
}
