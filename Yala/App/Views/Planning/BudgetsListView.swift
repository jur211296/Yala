//
//  BudgetsListView.swift
//  Yala
//
//  Main view for budget management with period filtering and status grouping
//

import SwiftData
import SwiftUI

struct BudgetsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SceneNavigation.self) private var navigation
    @Environment(SessionState.self) private var sessionState
    @Environment(\.yalaTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.scenePhase) private var scenePhase

    // ViewModel
    @State private var viewModel = BudgetsViewModel()
    @State private var selectedSegment: Int = 1  // 0=Weekly, 1=Monthly, 2=Yearly, 3=Unique
    @State private var showPeriodSelector = false
    @State private var showUpgradeSheet = false
    /// El «+» flotante, solo cuando el scroll se lleva «Nuevo presupuesto» de arriba (card kzhe).
    @State private var showFloatingNew = false
    /// Sube al cerrarse el editor: es cuando se pregunta «¿era de prueba?» (UX 2.2 · L5-5).
    @State private var budgetEditorClosedToken = 0

    private var activeBudgetsCount: Int {
        viewModel.activeBudgetsCount
    }

    private var isAtLimit: Bool {
        FeatureGateService.shared.isAtLimit(.budgets, currentCount: activeBudgetsCount)
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xs) {
                    // Limit reached banner
                    if isAtLimit {
                        LimitReachedBanner(
                            feature: .budgets,
                            currentCount: activeBudgetsCount
                        ) {
                            showUpgradeSheet = true
                        }
                    }

                    // La acción principal arriba, como en el Panel; el flotante solo al bajar (card kzhe). A su derecha y en la
                    // misma fila, el selector de tipo (Semanal / Mensual / Anual / Único) con la píldora de calendario de las
                    // demás pantallas, en vez del segmento a lo ancho (Jürgen, 2026-10-28, card ca00).
                    HStack(spacing: DS.Spacing.sm) {
                        TopPrimaryActionPill(
                            title: L10n.Accessibility.newBudget,
                            systemImage: "plus",
                            accessibilityIdentifier: "budgets_create_button",
                            action: createBudget
                        )
                        .revealsFloatingActionWhenScrolledAway($showFloatingNew)

                        Spacer(minLength: 0)

                        periodTypeMenu
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.xs)

                    // PeriodNavigationHeader shared (oculto en .unique mode)
                    if selectedSegment != 3 {
                        PeriodNavigationHeader(
                            currentLabel: viewModel.periodLabel,
                            onPrevious: {
                                viewModel.previousPeriod()
                                recalculatePeriodFilters()
                            },
                            onNext: {
                                viewModel.nextPeriod()
                                recalculatePeriodFilters()
                            },
                            onTapLabel: { showPeriodSelector = true }
                        )
                        .padding(.horizontal, DS.Spacing.lg)
                    }

                    listContent
                }
                .frame(maxWidth: .infinity)
                .padding(.top, DS.Spacing.sm)
            }
            .scrollViewGlassEdges()

            // FAB button for new budget: solo cuando el scroll se lleva el botón de arriba (card kzhe).
            if showFloatingNew {
                newBudgetFAB
                    .transition(.opacity)
            }
        }
        // El flotante entra y sale fundiéndose al desplazar. Implícita: el `withAnimation` de quien lo enciende no
        // anima dentro de una pestaña (card 8atf).
        .animation(reduceMotion ? nil : .easeInOut(duration: DS.Animation.normal), value: showFloatingNew)
        .yalaScreenBackground(.panel)
        .navigationDestination(for: BudgetNavigationID.self) { navID in
            BudgetDetailDestination(budgetID: navID.id, viewModel: viewModel)
                .announcesShownInDetailColumn()
                // En la columna de detalle SwiftUI reutiliza el destino al abrir otro presupuesto, y el resumen
                // (`@State`, calculado en `onAppear`) se quedaba con el gastado del anterior (medido en el iPad el
                // 2026-10-12). Con la identidad del presupuesto, cada uno es una vista nueva.
                .id(navID.id)
        }
        // `editingBudget`: `nil` crea (el FAB y el empty state lo ponen a `nil` antes); un presupuesto lo edita
        // (menú contextual de la fila, fase 3). Hasta entonces nadie lo leía y la hoja creaba siempre.
        .sheet(isPresented: $viewModel.showBudgetEditor, onDismiss: { budgetEditorClosedToken += 1 }) {
            // Un presupuesto nuevo se abre en el tipo de la pestaña que se miraba (UX 2.2 · L9-3).
            BudgetEditorView(budget: viewModel.editingBudget, initialPeriodType: viewModel.selectedPeriodType)
                .onDisappear {
                    viewModel.editingBudget = nil
                    refreshData()
                }
        }
        .sheet(isPresented: $showPeriodSelector) {
            BudgetPeriodSelectorSheet(
                viewModel: viewModel,
                oldestRecordDate: viewModel.oldestTransactionDate,
                onPeriodChange: { refreshData() }
            )
            .yalaSheetDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        // Si compra Pro ahí, al cerrarse se abre el presupuesto nuevo que se quería crear (UX 2.2 · L17-9).
        .proUpgradeSheet(isPresented: $showUpgradeSheet, feature: .budgets, context: .limitReached) {
            viewModel.editingBudget = nil
            viewModel.showBudgetEditor = true
        }
        // Tocar una alerta abre ESE presupuesto, en su tipo y su período actual (UX 2.2 · L9-5).
        .modifier(BudgetAlertOpening(viewModel: viewModel, selectedSegment: $selectedSegment, onPeriodReset: { recalculatePeriodFilters() }))
        // «¿Era de prueba?» del primer presupuesto, al cerrar el editor y aquí mismo (UX 2.2 · L5-5).
        .practiceCleanupPrompt(for: [.firstBudget], editorClosedToken: budgetEditorClosedToken) { refreshData() }
        .appliesPendingRemoteChanges(sessionState)
        .onAppear {
            viewModel.setContext(modelContext)
            viewModel.refreshBudgetData(
                hideInactive: appPreferences.budgetsHideInactive,
                defaultCurrencyCode: appPreferences.defaultCurrencyCode.rawValue
            )

            // Auto-open editor from setup checklist — routed via AppRouter now;
            // drain handler below sets showBudgetEditor on .autoOpenBudgetEditor.
        }
        .onDisappear {
            viewModel.cancelRecalculation()
        }
        .onChange(of: scenePhase) { _, phase in
            viewModel.setBackground(phase != .active)
        }
        .onChange(of: sessionState.dataVersion) { _, _ in
            refreshData()
        }
        // Peek first so we only drain intents this view handles —
        // ScheduledPaymentsView shares the .planning consumer.
        .routerConsumer(.planning) {
            if case .autoOpenBudgetEditor = AppRouter.shared.peekNext(for: .planning, in: navigation.id) {
                _ = AppRouter.shared.drainNext(for: .planning, in: navigation.id)
                viewModel.editingBudget = nil
                viewModel.showBudgetEditor = true
            }
        }
    }

    // MARK: - Period Type Menu

    /// Las cuatro opciones del tipo, en el orden de siempre: 0=Semanal, 1=Mensual, 2=Anual, 3=Único.
    private static let periodTypeOptions: [(tag: Int, key: String, id: String)] = [
        (0, "budgets.period.weekly", "weekly"),
        (1, "budgets.period.monthly", "monthly"),
        (2, "budgets.period.yearly", "yearly"),
        (3, "budgets.period.unique", "unique"),
    ]

    private var periodTypeTitle: String {
        let key = Self.periodTypeOptions.first { $0.tag == selectedSegment }?.key ?? "budgets.period.monthly"
        return NSLocalizedString(key, comment: "")
    }

    /// El mismo selector de período que Panel, Estadísticas o Grupos: píldora de calendario con un menú dentro.
    private var periodTypeMenu: some View {
        Menu {
            ForEach(Self.periodTypeOptions, id: \.tag) { option in
                Button {
                    selectedSegment = option.tag
                } label: {
                    HStack {
                        Text(NSLocalizedString(option.key, comment: ""))
                        if selectedSegment == option.tag {
                            Image(systemName: "checkmark").accessibilityHidden(true)
                        }
                    }
                }
                .accessibilityIdentifier("budgets_period_type_\(option.id)")
            }
        } label: {
            PeriodSelectorLabel(title: periodTypeTitle)
        }
        .accessibilityLabel(L10n.Budgets.periodTypeLabel)
        .accessibilityValue(periodTypeTitle)
        .accessibilityIdentifier("budgets_period_type_picker")
        .onChange(of: selectedSegment) { _, newValue in
            switch newValue {
            case 0: viewModel.selectedPeriodType = .weekly
            case 1: viewModel.selectedPeriodType = .monthly
            case 2: viewModel.selectedPeriodType = .yearly
            case 3: viewModel.selectedPeriodType = .unique
            default: break
            }
            recalculatePeriodFilters()
        }
    }

    // MARK: - List Content

    @ViewBuilder
    private var listContent: some View {
        if viewModel.groupedBudgets.isEmpty {
            emptyState
        } else {
            budgetsList
        }
    }

    // MARK: - Empty State

    /// Sin ningún presupuesto, el vacío de siempre; con presupuestos de otro tipo, el del tipo elegido.
    private var emptyState: some View {
        YalaEmptyState.noBudgets(
            title: viewModel.allBudgets.isEmpty ? nil : L10n.Budgets.emptyTitle(for: viewModel.selectedPeriodType)
        )
        .padding(.top, DS.Spacing.xxxl * 2)
    }

    // MARK: - Budgets List

    private var budgetsList: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            ForEach(viewModel.groupedBudgets, id: \.status) { section in
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    // Section header
                    Text(section.status.localizedName)
                        .font(DS.Typography.subheadlineEmphasized)
                        .foregroundStyle(.primary)

                    // Budget cards. Sin los ya borrados: la lista recarga 150 ms después de borrar y, mientras, leer uno
                    // aborta en iOS 27.x (`BudgetRowView`).
                    ForEach(section.budgets.filter { !$0.budget.isDeleted && $0.budget.modelContext != nil }) { summary in
                        BudgetRowView(
                            summary: summary,
                            currencyCode: summary.budget.currencyCode
                        )
                        // Clic secundario en el iPad, pulsación larga en el iPhone: el editor de siempre.
                        .contextMenu {
                            Button(L10n.Action.edit, systemImage: "pencil") {
                                viewModel.editingBudget = summary.budget
                                viewModel.showBudgetEditor = true
                            }
                            // Elegir lo que sale en el widget desde la propia lista (UX 2.2 · L9-12). Solo activos: el
                            // Panel y Perfil › Presupuestos no enseñan los inactivos.
                            if summary.budget.isActive {
                            Button(
                                summary.budget.isFavorite ? L10n.UXL9.hideFromWidget : L10n.UXL9.showInWidget,
                                systemImage: summary.budget.isFavorite ? "star.slash" : "star"
                            ) {
                                toggleShownInWidget(summary.budget)
                            }
                            }
                        }
                    }
                }
            }
        }
        .padding(.bottom, DS.Spacing.safeBottom)  // Space for FAB
        // Card C3: crear o borrar un presupuesto se anima; cambiar de tipo de período, no. Los ids, con el mismo filtro
        // que las filas (sin los borrados que esperan la recarga).
        .animatesRowEdits(ids: viewModel.groupedBudgets.flatMap { section in
            section.budgets.filter { !$0.budget.isDeleted && $0.budget.modelContext != nil }.map(\.id)
        })
    }

    // MARK: - New Budget FAB

    /// «Nuevo presupuesto», del botón de arriba o del flotante: el editor, o el paywall si se llegó al límite.
    private func createBudget() {
        if FeatureGateService.shared.canCreate(.budgets, currentCount: activeBudgetsCount) {
            viewModel.editingBudget = nil
            viewModel.showBudgetEditor = true
        } else {
            showUpgradeSheet = true
        }
    }

    private var newBudgetFAB: some View {
        VStack {
            Spacer()

            HStack {
                Spacer()

                CircularPlusFAB(
                    tint: theme.accent,
                    accessibilityLabel: L10n.Accessibility.newBudget,
                    accessibilityIdentifier: "budgets_create_fab"
                ) {
                    createBudget()
                }
                .dsFloatingShadow()
            }
            .padding(.trailing, DS.Spacing.xl)
            .padding(.bottom, DS.Spacing.xxl)
        }
    }

    // MARK: - Widget (UX 2.2 · L9-12)

    private func toggleShownInWidget(_ budget: Budget) {
        BudgetWidgetFavoriteLogic.setShownInWidget(
            !budget.isFavorite, for: budget, among: viewModel.allBudgets.filter(\.isActive))
        do {
            try modelContext.save()
            WidgetDataCache.updateCache(context: modelContext)
            sessionState.needsBudgetsWidgetRefresh = true
        } catch {
            #if DEBUG
            print("BudgetsListView: Error saving widget favorite: \(error)")
            #endif
        }
        refreshData()
    }

    // MARK: - Data Management

    /// Reload from DB + recompute. Use when DB mutations could have occurred
    /// (editor dismiss, PeriodSelector, dataVersion bump).
    private func refreshData() {
        viewModel.reloadAndRecalculate(
            hideInactive: appPreferences.budgetsHideInactive,
            defaultCurrencyCode: appPreferences.defaultCurrencyCode.rawValue
        )
    }

    /// Recompute only (no re-fetch). Use when a filter or period changed
    /// but the DB is unchanged.
    private func recalculatePeriodFilters() {
        viewModel.recalculateData(
            hideInactive: appPreferences.budgetsHideInactive,
            defaultCurrencyCode: appPreferences.defaultCurrencyCode.rawValue
        )
    }

}

// MARK: - Abrir desde una alerta (UX 2.2 · L9-5)

/// Consume el presupuesto que pidió una alerta en ESTA ventana (`SceneNavigation.pendingBudgetID`): pone su pestaña, vuelve al período actual —el de
/// la alerta— y abre su detalle. En la columna de lista de una ventana ancha, el destino se presenta en la de detalle.
private struct BudgetAlertOpening: ViewModifier {
    @Bindable var viewModel: BudgetsViewModel
    @Binding var selectedSegment: Int
    let onPeriodReset: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(SceneNavigation.self) private var navigation
    @State private var openedBudget: BudgetNavigationID?

    func body(content: Content) -> some View {
        content
            .navigationDestination(item: $openedBudget) { navID in
                BudgetDetailDestination(budgetID: navID.id, viewModel: viewModel)
                    .announcesShownInDetailColumn()
                    .id(navID.id)
            }
            .onAppear { openPendingIfAny() }
            .onChange(of: navigation.pendingBudgetID) { _, _ in openPendingIfAny() }
    }

    private func openPendingIfAny() {
        guard let budgetID = navigation.pendingBudgetID else { return }
        navigation.pendingBudgetID = nil
        // Este `onAppear` puede correr antes que el de la lista, que es quien le da el contexto al ViewModel: sin él no
        // hay presupuestos que buscar y el aviso se perdía (lo cazó `BudgetsLote9UITests`).
        viewModel.setContext(modelContext)
        viewModel.loadData()
        guard let budget = viewModel.allBudgets.first(where: { $0.id == budgetID }) else { return }
        let type = BudgetPeriodType(rawValue: budget.periodType) ?? .monthly
        let calendar = userConfiguredCalendar()
        viewModel.selectedWeek = calendar.startOfWeek(for: Date.now)
        viewModel.selectedMonth = calendar.startOfMonth(for: Date.now)
        viewModel.selectedYear = calendar.component(.year, from: Date.now)
        viewModel.selectedPeriodType = type
        selectedSegment = BudgetAlertOpening.segment(for: type)
        onPeriodReset()
        openedBudget = BudgetNavigationID(id: budget.persistentModelID)
    }

    /// El índice del selector de la lista (0 semanal, 1 mensual, 2 anual, 3 único).
    static func segment(for type: BudgetPeriodType) -> Int {
        switch type {
        case .weekly: return 0
        case .monthly: return 1
        case .yearly: return 2
        case .unique: return 3
        }
    }
}

// MARK: - Budget Detail Destination

/// Helper view that resolves PersistentIdentifier to Budget for navigation
private struct BudgetDetailDestination: View {
    let budgetID: PersistentIdentifier
    @Bindable var viewModel: BudgetsViewModel

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        if let budget = modelContext.model(for: budgetID) as? Budget {
            BudgetDetailView(budget: budget, viewModel: viewModel)
        } else {
            ContentUnavailableView(
                L10n.BudgetDetail.notFound,
                systemImage: "exclamationmark.triangle"
            )
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        BudgetsListView()
    }
    .environment(SceneNavigation())
}
