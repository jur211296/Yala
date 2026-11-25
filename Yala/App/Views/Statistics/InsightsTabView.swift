//
//  InsightsTabView.swift
//  Yala
//
//  Smart Insights tab content. Displays personalized KPIs, charts, and insights.
//

import SwiftUI
import SwiftData

struct InsightsTabView: View {

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext
    @Environment(SessionState.self) private var sessionState
    @Environment(\.yalaTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.openURL) private var openURL
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(SceneNavigation.self) private var navigation

    // MARK: - Data (passed from parent)

    let accounts: [Account]
    let categories: [Category]
    let allSubcategories: [Subcategory]
    let tags: [Tag]
    let allTransactions: [TransactionItem]
    /// Recargas del store hechas por el contenedor (`DetailContainerViewModel.dataGeneration`): «Tu dinero hoy» del hero
    /// se recalcula con ellas.
    let dataGeneration: Int
    let budgets: [Budget]
    let scheduledPayments: [ScheduledPayment]
    let defaultCurrencyCode: String

    // MARK: - ViewModel

    @Bindable var viewModel: InsightsViewModel
    @Bindable var trendsViewModel: StatisticsViewModel

    /// Abre el chip Registros solo con los registros de un comercio (opción B: tocar un gasto hormiga). Lo pone
    /// `DetailContainerView`, que es quien tiene la lista.
    var onShowMerchantRecords: (RecordsMerchantFilter) -> Void = { _ in }

    // MARK: - Pro State

    @State private var showUpgradeSheet = false
    @State private var showCustomPeriodPicker = false
    @State private var showInsightsConsentAlert = false
    /// El consentimiento pedido desde el bloque Pro de los gastos hormiga: al aceptar, pide ESE análisis.
    @State private var showAntAIConsentAlert = false

    @ScaledMetric(relativeTo: .largeTitle) private var summaryVerticalPadding: CGFloat = 12
    /// El `ScrollView` tiene poco alto (iPhone girado): la cabecera va en banda (`SummaryHeaderStack`).
    @State private var isShortContainer = false

    // Content split: Detalle (gastos hormiga, cifras, lo que más pesa) vs Observaciones
    @State private var contentMode: InsightsContentMode = .detail
    // «Ponerle un tope» de los gastos hormiga (opción B): el asistente de «Nuevo presupuesto» de Planificación, o el
    // paywall si se llegó al límite del plan.
    @State private var newBudgetWizard = AsistentePresupuestoEstado()
    @State private var showsNewBudget = false
    @State private var showsBudgetsUpgrade = false

    private var isProUser: Bool {
        FeatureGateService.shared.canAccess(.smartInsightsAI)
    }

    // MARK: - Body

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            if let data = viewModel.insightData {
                VStack(spacing: DS.Spacing.md) {
                    StatsGuideSlot()
                    heroSummary(data.periodSummary)
                    // La acción principal arriba, como en el Panel; el flotante solo al bajar (card kzhe).
                    StatsQuickActionsSlot()
                    filterBarPanel

                    if data.periodSummary.transactionCount == 0 {
                        YalaEmptyState(
                            icon: "sparkles",
                            title: L10n.Insights.emptyTitle,
                            message: L10n.Insights.emptyBody
                        )
                        .padding(.top, DS.Spacing.xxxxl)
                    } else {
                        // Opción B · Decidir (Jürgen, 23-nov-2026): la franja de salud, «Para decidir hoy» y, debajo, el
                        // resumen con IA y el detalle. En ancha, tarjetas en pares (ticket
                        // `ipad-and-duo-panel-and-statistics-use-the-width`).
                        PairedCardsStack(rowSpacing: DS.Spacing.xl) {
                            if let score = viewModel.financialScore {
                                ResumenSaludFranja(
                                    score: score,
                                    sessionState: sessionState,
                                    hasBudgets: budgets.contains { $0.isActive }
                                )
                            }

                            let actions = decideActions(data)
                            if !actions.isEmpty {
                                ResumenDecidirSeccion(actions: actions, onOpen: openDecision)
                            }

                            if isProUser {
                                proHeroSection(data)
                                    .animation(reduceMotion ? nil : DS.Animation.appear, value: viewModel.isLoadingAI)
                            } else {
                                aiInsightsTeaser
                            }

                            if data.periodSummary.transactionCount >= 5 {
                                contentModePill
                                    .spansAllColumns()

                                switch contentMode {
                                case .detail:
                                    detailModeContent(data)
                                case .observations:
                                    observationsModeContent(data)
                                }
                            } else {
                                // < 5 tx: solo modo Detalle implícito (sin pill, sin observations)
                                detailModeContent(data)
                                Text(L10n.Insights.fewTransactions)
                                    .font(DS.Typography.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, DS.Spacing.lg)
                                    .spansAllColumns()
                            }

                            ResumenIrA(onSelect: goTo)
                                .spansAllColumns()
                        }
                        .frame(maxWidth: .infinity)
                        // 12 + 8 = 20 pt sobre la primera sección, el mismo aire que entre tarjetas: con 12 el título
                        // «Tu salud financiera» colgaba de la fila de acciones en vez de encabezar su tarjeta.
                        .padding(.top, DS.Spacing.sm)
                        // Yala IA y «+» flotan encima en las cuatro pestañas de Estadísticas: al final del scroll, la última tarjeta sube
                        // por encima de los dos (mismo margen que `RecordsTabView`).
                        .padding(.bottom, DS.Button.fabStackClearance(buttons: 2))
                    }
                }
                .padding(.top, DS.Spacing.sm)
                .transition(.opacity)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 200)
                    .transition(.loadingPlaceholder)
            }
        }
        // Card C7: la primera carga, del spinner al contenido fundiéndose. «Analizando…» se anima en sus dos tarjetas, no
        // aquí: un recálculo con la IA en curso apaga `isLoadingAI` junto con los datos nuevos y animaría la página entera.
        .animation(reduceMotion ? nil : DS.Animation.appear, value: viewModel.insightData == nil)
        .measuresShortContainer($isShortContainer)
        .scrollViewGlassEdges()
        // Aquí y no en la tarjeta bloqueada de Observaciones: colgada de ella, «Actualizar a Pro» del resumen no abría
        // nada en Detalle (el modo con que se abre la pestaña) y la hoja salía sola al pasar a Observaciones
        // (auditoría UX 2.2 · lote 11 · B9).
        .sheet(isPresented: $showUpgradeSheet) {
            UpgradePromptSheet(feature: .smartInsightsAI, context: .proFeature)
        }
        .sheet(isPresented: $showCustomPeriodPicker) {
            CustomPeriodPickerSheet(
                minDate: transactionDateRange.start,
                maxDate: transactionDateRange.end,
                currentRange: sessionState.customDateRange
            )
        }
        .insightsConsentAlert(isPresented: $showInsightsConsentAlert) {
            Task { await viewModel.triggerAIGeneration() }
        }
        .insightsConsentAlert(isPresented: $showAntAIConsentAlert) {
            Task { await viewModel.triggerAntAI() }
        }
        .modifier(ResumenNewBudgetSheets(
            wizard: newBudgetWizard, showsNewBudget: $showsNewBudget, showsUpgrade: $showsBudgetsUpgrade))
        .onChange(of: viewModel.insightData?.periodSummary.transactionCount) { _, newCount in
            // Reset defensivo: con < 5 tx no se monta el pill ni la rama Observaciones;
            // forzar Detalle para que al volver a >= 5 el bento sea visible de inmediato.
            if let count = newCount, count < 5, contentMode != .detail {
                contentMode = .detail
            }
        }
    }

    // MARK: - Filter Bar (panel style)

    private var filterBarPanel: some View {
        FilterControlBar(
            periodSelector: EmptyView(),
            viewModel: trendsViewModel,
            accounts: accounts,
            categories: categories,
            allSubcategories: allSubcategories,
            tags: tags,
            animationValue: trendsViewModel.detailPeriod,
            panelStyle: true,
            inlinePeriodSelector: false
        )
    }

    private var transactionDateRange: (start: Date, end: Date) {
        let sortedDates = allTransactions.map(\.date).sorted()
        let start = sortedDates.first ?? Date.now
        let end = sortedDates.last ?? Date.now
        return (start, end)
    }

    // MARK: - Hero Summary

    /// El hero compartido de Estadísticas (`StatsHeroView`): «Tu dinero hoy», o el gasto en «Solo gastos», con ingresos y
    /// gastos del período debajo. Con poco alto (iPhone girado) va en banda.
    private func heroSummary(_ summary: PeriodSummary) -> some View {
        let expensesOnly = sessionState.isExpensesOnlyMode
        return StatsHeroView(
            caption: StatsHeroCaptionLogic.insights(expensesOnly: expensesOnly),
            sideFigure: summary.transactionCount > 0
                ? StatsMoneyTodayLogic.Figure(value: summary.totalExpense, isApproximate: summary.expenseAmountsAreApproximate)
                : nil,
            flow: StatsHeroFlow(summary),
            expensesOnlyVariation: expensesOnly && summary.transactionCount > 0 ? .some(summary.expenseVariation) : nil,
            money: StatsHeroMoneySource(accounts: accounts, transactions: allTransactions, dataGeneration: dataGeneration),
            currencyCode: defaultCurrencyCode,
            isShort: isShortContainer,
            verticalPadding: summaryVerticalPadding
        ) {
            StatisticsPeriodControl(onCustomTapped: { showCustomPeriodPicker = true })
        }
    }

    // MARK: - Pro Hero Section (AI button / loading / hero card)

    @ViewBuilder
    private func proHeroSection(_ data: InsightData) -> some View {
        if viewModel.aiActivated {
            if viewModel.isLoadingAI {
                AIInsightCardComponents.loadingPlaceholder(accentColor: theme.accent)
                    .transition(.loadingPlaceholder)
            } else if let aiHero = viewModel.aiInsights?.heroText {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    InsightCard(insight: InsightResult(
                        id: "ai_hero",
                        icon: "sparkles",
                        text: AIInsightCardComponents.markdownAttributed(aiHero),
                        sentiment: .neutral,
                        isProOnly: true
                    ))
                    // Escrito con cifras que ya no son las de ahora: se dice, con su hora y «Actualizar» (opción B de
                    // Jürgen, 2026-11-17). Con las mismas cifras no sale.
                    if let writtenAt = viewModel.aiWrittenWithOlderDataAt {
                        aiStaleMark(writtenAt: writtenAt)
                    }
                }
            } else if let error = viewModel.aiError, contentMode != .observations {
                // En Observaciones el aviso va bajo su título (abajo), que es donde se está mirando.
                AIInsightCardComponents.errorCard(error) {
                    Task { await viewModel.triggerAIGeneration() }
                }
            }
        } else if viewModel.isAwaitingAutoDecision {
            // Pro con la IA aceptada: el resumen sale solo al abrir Estadísticas (encargo `estadisticas-ia-automatica`).
            AIInsightCardComponents.loadingPlaceholder(accentColor: theme.accent)
                .transition(.loadingPlaceholder)
        } else {
            generateAIButton
        }
    }

    // MARK: - Texto de IA con cifras viejas

    /// «Escrito con tus datos de las 18:05 · Actualizar», debajo del resumen. En fila si cabe; con texto grande,
    /// «Actualizar» baja a su línea. Con el techo del día gastado, o si la regeneración falló, dice por qué debajo.
    private func aiStaleMark(writtenAt: Date) -> some View {
        let label = Text(L10n.ResumenIAHora.writtenAt(L10n.ResumenIAHora.time(writtenAt)))
            .font(DS.Typography.caption)
            .foregroundStyle(.secondary)
        let button = Button {
            Task { await viewModel.refreshStaleAI() }
        } label: {
            Text(L10n.ResumenIAHora.refresh)
                .font(DS.Typography.labelSmall)
                .foregroundStyle(theme.accentText)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(L10n.ResumenIAHora.refreshHint)
        .accessibilityIdentifier("insights_ai_stale_refresh")

        return VStack(alignment: .leading, spacing: 0) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: DS.Spacing.xs) {
                    label.fixedSize()
                    Text(verbatim: "·")
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    button.fixedSize()
                }
                VStack(alignment: .leading, spacing: 0) {
                    label.fixedSize(horizontal: false, vertical: true)
                    button
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("insights_ai_stale_mark")
            if let reason = staleRefreshProblem {
                Text(reason)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Semantic.warningForeground)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("insights_ai_stale_problem")
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Por qué «Actualizar» no trajo un texto nuevo: el techo del día o el fallo de la llamada. Nunca en silencio.
    private var staleRefreshProblem: String? {
        if viewModel.staleRefreshBlockedByDailyCap { return L10n.ResumenIAHora.dailyCapReached }
        if let error = viewModel.aiError { return AIInsightCardComponents.message(for: error) }
        return nil
    }

    // MARK: - Generate AI Button

    private var generateAIButton: some View {
        Button {
            if appPreferences.aiInsightsConsentAccepted {
                Task { await viewModel.triggerAIGeneration() }
            } else {
                showInsightsConsentAlert = true
            }
        } label: {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "sparkles")
                    .font(.system(size: 24))
                    .foregroundStyle(theme.accentText)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(L10n.Stats.Insights.aiCardTitle)
                        .font(DS.Typography.subheadlineEmphasized)
                        .foregroundStyle(.primary)
                    Text(L10n.Stats.Insights.aiCardSubtitle)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: DS.Spacing.sm)
                Image(systemName: "chevron.right")
                    .font(DS.Typography.caption)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .panelCard()
    }

    // MARK: - Pro Observations Section

    @ViewBuilder
    private func proObservationsSection(_ data: InsightData) -> some View {
        PairedCardsStack(rowSpacing: DS.Spacing.sm, columnSpacing: DS.Spacing.md) {
            YalaSectionHeader(L10n.Insights.intelligentInsights)
                .spansAllColumns()

            if viewModel.aiActivated {
                if viewModel.isLoadingAI {
                    AIInsightCardComponents.loadingPlaceholder(accentColor: theme.accent)
                        .transition(.loadingPlaceholder)
                        .spansAllColumns()
                } else if let aiCards = viewModel.aiInsights?.cards, !aiCards.isEmpty {
                    ForEach(Array(aiCards.enumerated()), id: \.offset) { _, card in
                        let sentiment: Sentiment = switch card.sentiment {
                        case "positive": .positive
                        case "attention": .attention
                        default: .neutral
                        }
                        InsightCard(insight: InsightResult(
                            id: "ai_\(card.text.prefix(20))",
                            icon: card.icon,
                            text: AIInsightCardComponents.markdownAttributed(card.text),
                            sentiment: sentiment,
                            isProOnly: true,
                            tip: card.tip.map { AIInsightCardComponents.markdownAttributed($0) }
                        ))
                    }

                    // Fun fact after AI cards
                    if let funFact = viewModel.aiInsights?.funFact {
                        InsightCard(insight: InsightResult(
                            id: "ai_fun_fact",
                            icon: "lightbulb",
                            text: AIInsightCardComponents.markdownAttributed(funFact),
                            sentiment: .positive,
                            isProOnly: true
                        ))
                    }
                } else if let error = viewModel.aiError {
                    // Con el resumen que sale solo (UX 2.2 · L11-7), un fallo dejaba el título «Observaciones» sin nada
                    // debajo y el aviso arriba. Ahora el aviso, con «Reintentar», va aquí.
                    AIInsightCardComponents.errorCard(error) {
                        Task { await viewModel.triggerAIGeneration() }
                    }
                    .spansAllColumns()
                }
            } else if viewModel.isAwaitingAutoDecision {
                // Pro con el consentimiento dado: el resumen sale solo al abrir Estadísticas (UX 2.2 · L11-7, encargo
                // `estadisticas-ia-automatica`). Hasta que llega, el mismo «cargando» que tras tocar el botón.
                AIInsightCardComponents.loadingPlaceholder(accentColor: theme.accent)
                    .transition(.loadingPlaceholder)
                    .spansAllColumns()
            } else {
                // Sin consentimiento hace falta un toque: es el que autoriza enviar el resumen al servicio de IA. Con él
                // (y el techo automático del día alcanzado, o una generación que falló), el toque la pide directamente.
                Button {
                    if appPreferences.aiInsightsConsentAccepted {
                        Task { await viewModel.triggerAIGeneration() }
                    } else {
                        showInsightsConsentAlert = true
                    }
                } label: {
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(theme.accentText)
                            .accessibilityHidden(true)
                        Text(L10n.Stats.Insights.aiCardSubtitle)
                            .font(DS.Typography.subheadlineEmphasized)
                            .foregroundStyle(.primary)
                        Spacer(minLength: DS.Spacing.sm)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .panelCard()
                .accessibilityIdentifier("insights_observations_generate_ai")
                .spansAllColumns()
            }
        }
        .spansAllColumns()
        // Lo automático ya no cuelga de aquí: lo decide el contenedor de Estadísticas al abrirla y tras cada recálculo
        // (`DetailContainerView`, `InsightsViewModel.autoRefreshIfNeeded`), así sale también en el hero y en Distribución.
        // Card C7: «Analizando…» → las observaciones de la IA, fundiéndose; solo esta sección.
        .animation(reduceMotion ? nil : DS.Animation.appear, value: viewModel.isLoadingAI)
    }

    // MARK: - Free Observations Section

    @ViewBuilder
    private func freeObservationsSection(_ data: InsightData) -> some View {
        if !data.ruleBasedInsights.isEmpty {
            textInsightsSection(Array(data.ruleBasedInsights.prefix(2)))
        }
    }

    // MARK: - Para decidir hoy · Ir a (opción B)

    /// Lo que pide «Para decidir hoy» con los datos del cálculo y los ajustes de Smart Insights (`ResumenDecidirLogic`).
    private func decideActions(_ data: InsightData) -> [ResumenAccion] {
        let c = data.commitments
        let showsPayments = appPreferences.insightsShowPendingPayments
        let showsSubscriptions = appPreferences.insightsShowSubscriptions
        let input = ResumenDecidirEntrada(
            periodIncludesToday: !PeriodTenseLogic.isClosed(
                period: trendsViewModel.detailPeriod, customRange: sessionState.customDateRange),
            budgets: c.budgets.map { ResumenPresupuesto($0) },
            showsBudgets: appPreferences.insightsShowBudgetsAtRisk,
            toPayAmount: (showsPayments ? c.pendingOtherPaymentsAmount : 0)
                + (showsSubscriptions ? c.pendingSubscriptionsAmount : 0),
            toPayCount: (showsPayments ? c.pendingOtherPaymentsCount : 0)
                + (showsSubscriptions ? c.pendingSubscriptionsCount : 0),
            toPayUntil: c.pendingUntil,
            dailyAverage: data.periodSummary.dailyAverageExpense,
            dailyAverageIsApproximate: data.periodSummary.expenseAmountsAreApproximate,
            dailyVariation: data.periodSummary.dailyAverageVariation,
            showsVariations: appPreferences.showVariations
        )
        return ResumenDecidirLogic.actions(input)
    }

    private func openDecision(_ destination: ResumenDestino) {
        switch destination {
        case .budgets: navigation.navigateToBudgets()
        case .scheduledPayments: navigation.navigateToScheduledPayments()
        case .trends: navigation.navigateToDetail(.trends)
        }
    }

    private func goTo(_ destination: ResumenIrADestino) {
        switch destination {
        case .distribution: navigation.navigateToDetail(.categories)
        case .trends: navigation.navigateToDetail(.trends)
        case .records: navigation.navigateToDetail(.records)
        case .budgets: navigation.navigateToBudgets()
        }
    }

    /// «Ponerle un tope»: el asistente de «Nuevo presupuesto», o el paywall si el plan ya no admite otro.
    private func openNewBudget() {
        let active = budgets.filter(\.isActive).count
        if FeatureGateService.shared.canCreate(.budgets, currentCount: active) {
            newBudgetWizard.empezar(periodo: .monthly)
            showsNewBudget = true
        } else {
            showsBudgetsUpgrade = true
        }
    }

    // MARK: - Detail mode (gastos hormiga · Tus cifras · Lo que más pesa)

    @ViewBuilder
    private func detailModeContent(_ data: InsightData) -> some View {
        if appPreferences.insightsShowQuickStats {
            if let ants = data.quickStats.antExpenses {
                antExpensesCard(ants)
            }

            // En ancha: la cabecera a lo ancho y las cuatro cifras en pares.
            PairedCardsStack(rowSpacing: DS.Spacing.sm, columnSpacing: DS.Spacing.md) {
                detailModeHeader(summary: data.periodSummary)
                    .spansAllColumns()
                figuresGrid(stats: data.quickStats, summary: data.periodSummary)
                    .spansAllColumns()
            }
            .spansAllColumns()
        }

        weightLine(data)
    }

    @ViewBuilder
    private func detailModeHeader(summary: PeriodSummary) -> some View {
        let period = trendsViewModel.detailPeriod
        let showComparison = appPreferences.showVariations
            && PreviousPeriodHelper.isSelectorVisible(for: period)

        // Con qué se compara, en una frase bajo el título (UX 2.2 · L11-4). Antes eran «P-1 / A-1» a la derecha y
        // «vs Set 26» debajo.
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                // `headline`, como «Tu salud financiera» y «Tus presupuestos»: un solo estilo de título de sección.
                Text(L10n.Stats.Insights.detailHeader)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.primary)
                Text(period.displayName)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }

            if showComparison {
                ComparisonModeSelector(period: period, customRange: sessionState.customDateRange)
                    // Medido en XCUITest el 2026-11-25 (iOS 27.2, en local y en la nocturna, 3 de 3): al tocar «Con
                    // noviembre de 2025» la frase pasaba al año anterior y el chip elegido seguía siendo «el mes
                    // anterior», también para VoiceOver; con el consejo fuera de los chips se invertía (chip al día, frase
                    // vieja). Atado al modo, el selector se rehace con cada cambio, como en Tendencias. Causa sin aislar.
                    .id(sessionState.comparisonMode)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// «Tus cifras»: cuatro celdas chicas (opción B). «Promedio diario» deja la caja ancha; «Categoría principal» y
    /// «Subcategoría principal» se van (Mayor gasto ya nombra lo que más costó y «Lo que más pesa» la categoría).
    private func figuresGrid(stats: QuickStats, summary: PeriodSummary) -> some View {
        // Con el texto al máximo, una ficha por fila: una cifra no se corta (barrido final 2.2).
        let columns = dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible(), spacing: DS.Spacing.md)]
            : [GridItem(.flexible(), spacing: DS.Spacing.md), GridItem(.flexible(), spacing: DS.Spacing.md)]

        return LazyVGrid(columns: columns, spacing: DS.Spacing.md) {
            dailyAverageCell(stats: stats, summary: summary)
            if let bestDay = stats.highestAvgWeekday {
                QuickStatCell(
                    icon: "calendar.circle.fill",
                    label: L10n.Insights.highestAvgWeekday,
                    value: bestDay.weekdayName.capitalized,
                    secondary: appPreferences.currency(bestDay.average, currencyCode: defaultCurrencyCode)
                )
            }
            if let highest = stats.highestExpense {
                QuickStatCell(
                    icon: "arrow.up.circle.fill",
                    label: L10n.Insights.highestExpense,
                    value: appPreferences.currency(highest.amount, currencyCode: defaultCurrencyCode),
                    secondary: highest.note
                )
            }
            if stats.subscriptionsTotal > 0 {
                QuickStatCell(
                    icon: "repeat.circle.fill",
                    label: L10n.Insights.subscriptions,
                    value: appPreferences.currency(stats.subscriptionsTotal, currencyCode: defaultCurrencyCode),
                    secondary: L10n.Insights.monthly
                )
            }
        }
        .accessibilityIdentifier("insights_figures")
    }

    /// «Promedio diario» en celda chica, con su variación debajo si la hay.
    private func dailyAverageCell(stats: QuickStats, summary: PeriodSummary) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "chart.bar.fill")
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text(L10n.Insights.dailyAverage)
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.secondary)
            }

            AmountText(
                value: stats.dailyAverage,
                currencyCode: defaultCurrencyCode,
                font: DS.Typography.headline, secondaryFont: DS.Typography.captionSmall,
                // `dailyAverage` es `cashFlow.totalExpense` dividido entre un entero exacto: el cociente aproximado/total
                // que mide `ApproximateMarkThreshold` no cambia al dividir, así que la marca del gasto es la suya.
                isEstimate: summary.expenseAmountsAreApproximate
            )
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
            .minimumScaleFactor(0.7)

            // Reserva su alto aunque no haya variación: cambiar de período no hace saltar la cuadrícula.
            Group {
                if appPreferences.showVariations, summary.dailyAverageVariation != nil {
                    VariationChip(variation: summary.dailyAverageVariation, size: .small, isExpenseContext: true)
                } else {
                    Text(verbatim: " ")
                        .font(DS.Typography.captionSmall)
                        .opacity(0)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelCard(small: true)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("insights_daily_average")
    }

    /// «Lo que más pesa: Hogar · 38 %» con la barra de necesidad y salida a Distribución. Sustituye a «Categoría
    /// principal» y a la sección plegable de la necesidad.
    @ViewBuilder
    private func weightLine(_ data: InsightData) -> some View {
        let top = appPreferences.insightsShowQuickStats ? data.quickStats.topCategory : nil
        let need = data.needDistribution
        let showsNeed = data.periodSummary.transactionCount >= 5 && appPreferences.insightsShowNature && need.total > 0
        if top != nil || showsNeed {
            Button {
                navigation.navigateToDetail(.categories)
            } label: {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    // Con el texto al máximo, «Distribución ›» baja a su línea (al lado partía las dos cosas).
                    AdaptiveRowStack {
                        Text(top.map {
                            ResumenOpcionBText.Figures.weight($0.name, percent: L10n.UXL11D.percent($0.percentage))
                        } ?? L10n.Insights.needDistribution)
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    } trailing: {
                        HStack(spacing: DS.Spacing.xxs) {
                            Text(DetailViewTab.categories.title)
                                .font(DS.Typography.caption)
                                .foregroundStyle(theme.accentText)
                            Image(systemName: "chevron.right")
                                .font(DS.Typography.captionSmall)
                                .foregroundStyle(theme.accentText)
                                .accessibilityHidden(true)
                        }
                    }
                    if showsNeed {
                        // Con su leyenda (Esencial, Prioritaria, Opcional y su parte), la de Distribución.
                        NeedBar(distribution: need)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .panelCard()
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("insights_weight_line")
        }
    }

    // MARK: - Gastos hormiga, el bloque protagonista (opción B)

    /// Compras pequeñas que se repiten: el total grande, el ritmo del mes, una fila por comercio con un punto por compra
    /// (tocarla abre sus registros), la franja de Yala IA (Pro) y dos salidas. La regla vive en `AntExpensesCalculator`.
    private func antExpensesCard(_ ants: AntExpensesSummary) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // Con el texto al máximo, las compras bajan bajo el título: al lado, «Gastos hormiga» se partía en sílabas.
            AdaptiveRowStack {
                HStack(alignment: .center, spacing: DS.Spacing.sm) {
                    ZStack {
                        Circle()
                            .fill(DS.Semantic.warningBackground)
                            .frame(width: 32, height: 32)
                        Image(systemName: "ant.fill")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Semantic.warningForeground)
                    }
                    .accessibilityHidden(true)
                    Text(L10n.Insights.antExpensesTitle)
                        .font(DS.Typography.headline)
                        .foregroundStyle(.primary)
                }
            } trailing: {
                Text(ResumenOpcionBText.Ant.purchases(ants.count))
                    .font(DS.Typography.captionSmall)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.xxs)
                    .background(DS.Semantic.warningBackground, in: Capsule())
            }

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                AmountText(
                    value: ants.total,
                    currencyCode: defaultCurrencyCode,
                    font: DS.Typography.cardHeroAmount, secondaryFont: DS.Typography.cardHeroAmountSecondary
                )
                Text(ResumenOpcionBText.Ant.caption(
                    threshold: appPreferences.currency(ants.threshold, currencyCode: defaultCurrencyCode)))
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let pace = antPaceText(ants) {
                    Text(pace)
                        .font(DS.Typography.subheadlineEmphasized)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("insights_ant_expenses_pace")
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(antSummaryLabel(ants))
            .accessibilityIdentifier("insights_ant_expenses_summary")

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                ForEach(ants.groups.prefix(3), id: \.key) { group in
                    antRow(group)
                }
            }

            // Pro: la franja de Yala IA, aparte de la lista. Free no ve nada nuevo.
            if isProUser {
                antExpensesAIBlock
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: DS.Spacing.sm) { antButtons(ants) }
                VStack(spacing: DS.Spacing.sm) { antButtons(ants) }
            }
        }
        .panelCard()
        .animation(reduceMotion ? nil : DS.Animation.appear, value: viewModel.antAI)
        // `.contain`: la tarjeta tiene su id sin pisar los de su resumen y sus filas.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("insights_ant_expenses_card")
    }

    /// «A este ritmo cierras el mes en S/ 410» o «A este ritmo, unos S/ 300 al mes». Sin ritmo, nada.
    private func antPaceText(_ ants: AntExpensesSummary) -> String? {
        switch ants.pace {
        case .closesMonth(let amount):
            return ResumenOpcionBText.Ant.closesMonth(appPreferences.currency(amount, currencyCode: defaultCurrencyCode))
        case .perMonth(let amount):
            return ResumenOpcionBText.Ant.perMonth(appPreferences.currency(amount, currencyCode: defaultCurrencyCode))
        case nil:
            return nil
        }
    }

    /// Lo que oye VoiceOver del total: la frase de siempre («S/ 567 en 24 compras pequeñas») y el ritmo.
    private func antSummaryLabel(_ ants: AntExpensesSummary) -> String {
        let summary = L10n.Insights.antExpensesSummary(
            total: appPreferences.currency(ants.total, currencyCode: defaultCurrencyCode), count: ants.count)
        return [summary, antPaceText(ants)].compactMap { $0 }.joined(separator: ". ")
    }

    /// Una fila por comercio: nombre, un punto por compra y el total. Tocarla abre sus registros.
    private func antRow(_ group: AntExpenseGroup) -> some View {
        let total = appPreferences.currency(group.total, currencyCode: defaultCurrencyCode)
        return Button {
            onShowMerchantRecords(RecordsMerchantFilter(label: group.label, keys: [group.key]))
        } label: {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        Text(group.label)
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(.primary)
                        HStack(spacing: DS.Spacing.sm) {
                            AntFrequencyDots(count: group.count)
                            Spacer(minLength: DS.Spacing.sm)
                            Text(total)
                                .font(DS.Typography.subheadlineEmphasized)
                                .foregroundStyle(.primary)
                        }
                    }
                } else {
                    HStack(alignment: .center, spacing: DS.Spacing.sm) {
                        Text(group.label)
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .layoutPriority(1)
                        Spacer(minLength: DS.Spacing.sm)
                        AntFrequencyDots(count: group.count)
                        Text(total)
                            .font(DS.Typography.subheadlineEmphasized)
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .fixedSize()
                        Image(systemName: "chevron.right")
                            .font(DS.Typography.captionSmall)
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
                }
            }
            .padding(.vertical, DS.Spacing.xxs)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(group.label), \(L10n.Insights.antExpensesRow(count: group.count, total: total))")
        .accessibilityHint(ResumenOpcionBText.Ant.rowHint)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("insights_ant_expenses_row")
    }

    @ViewBuilder
    private func antButtons(_ ants: AntExpensesSummary) -> some View {
        Button {
            onShowMerchantRecords(RecordsMerchantFilter(
                label: L10n.Insights.antExpensesTitle,
                keys: Set(ants.groups.map(\.key)).union(viewModel.antAI?.mergedGroups.flatMap(\.keys) ?? [])))
        } label: {
            antButtonLabel(ResumenOpcionBText.Ant.seePurchases, systemImage: "list.bullet")
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("insights_ant_see_purchases")

        Button {
            openNewBudget()
        } label: {
            antButtonLabel(ResumenOpcionBText.Ant.setCap, systemImage: "gauge.with.dots.needle.bottom.50percent")
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("insights_ant_set_cap")
    }

    private func antButtonLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(DS.Typography.labelSmall)
            .foregroundStyle(.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(.thBackground, in: Capsule())
            .contentShape(Capsule())
    }

    /// La franja de Yala IA de los gastos hormiga (Pro): las tiendas que juntó (cada una abre sus registros, todas sus
    /// grafías) y el consejo. Sin consentimiento, un toque lo pide; con él, sale solo
    /// (`InsightsViewModel.autoRefreshAntAIIfNeeded`). Un fallo no enseña nada: el bloque gratis sigue igual.
    @ViewBuilder
    private var antExpensesAIBlock: some View {
        if let insight = viewModel.antAI, !insight.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                if !insight.mergedGroups.isEmpty {
                    Label(ResumenOpcionBText.Ant.aiMerged, systemImage: "sparkles")
                        .font(DS.Typography.subheadlineEmphasized)
                        .foregroundStyle(theme.accentText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                ForEach(Array(insight.mergedGroups.prefix(3).enumerated()), id: \.offset) { _, group in
                    Button {
                        onShowMerchantRecords(RecordsMerchantFilter(label: group.label, keys: group.keys))
                    } label: {
                        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
                                Text(group.label)
                                    .font(DS.Typography.subheadline)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Spacer(minLength: DS.Spacing.sm)
                                Text(L10n.Insights.antExpensesRow(
                                    count: group.count,
                                    total: appPreferences.currency(group.total, currencyCode: defaultCurrencyCode)))
                                    .font(DS.Typography.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Text(L10n.Insights.antExpensesAIAlsoWritten(group.otherLabels.map { "«\($0)»" }
                                .formatted(.list(type: .and))))
                                .font(DS.Typography.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityHint(ResumenOpcionBText.Ant.rowHint)
                    .accessibilityIdentifier("insights_ant_expenses_ai_merge")
                }

                if let total = insight.combinedTotal, let count = insight.combinedCount {
                    Text(L10n.Insights.antExpensesAICombined(
                        total: appPreferences.currency(total, currencyCode: defaultCurrencyCode), count: count))
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("insights_ant_expenses_ai_combined")
                }

                if let tip = insight.tip {
                    Text(AIInsightCardComponents.markdownAttributed(tip))
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("insights_ant_expenses_ai_tip")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DS.Spacing.md)
            .background(.thBackground, in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("insights_ant_expenses_ai")
        } else if viewModel.isLoadingAntAI {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "sparkles")
                    .foregroundStyle(theme.accentText)
                    .symbolEffect(.pulse)
                    .accessibilityHidden(true)
                Text(L10n.Insights.analyzingData)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DS.Spacing.md)
            .background(.thBackground, in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
            .transition(.loadingPlaceholder)
        } else if !appPreferences.hasCurrentAIInsightsConsent {
            // Sin el permiso con el texto vigente hace falta un toque: es el que autoriza enviar los nombres de las compras
            // pequeñas. También a quien aceptó el texto anterior (decisión A de Jürgen, 2026-11-06); su resumen de
            // siempre sigue saliendo solo.
            Button {
                showAntAIConsentAlert = true
            } label: {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(theme.accentText)
                        .accessibilityHidden(true)
                    Text(L10n.Insights.antExpensesAICta)
                        .font(DS.Typography.subheadlineEmphasized)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: DS.Spacing.sm)
                }
                .padding(DS.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.thBackground, in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("insights_ant_expenses_ai_cta")
        }
    }

    // MARK: - Observations mode

    @ViewBuilder
    private func observationsModeContent(_ data: InsightData) -> some View {
        if appPreferences.insightsShowTexts {
            if isProUser {
                proObservationsSection(data)
            } else {
                freeObservationsSection(data)
            }
        }
        if !isProUser { lockedFunFact }
    }

    // MARK: - Section 7: Text Insights (Free users)

    @ViewBuilder
    private func textInsightsSection(_ insights: [InsightResult]) -> some View {
        PairedCardsStack(rowSpacing: DS.Spacing.sm, columnSpacing: DS.Spacing.md) {
            YalaSectionHeader(L10n.Insights.intelligentInsights)
                .spansAllColumns()

            ForEach(insights) { insight in
                InsightCard(insight: insight)
            }
        }
        .spansAllColumns()
    }

    // MARK: - AI Insights Teaser (Free users)

    private var aiInsightsTeaser: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack {
                // El mismo nombre que ve quien es Pro («Resumen inteligente»), no «Insights con IA» (lote 11 · B8).
                Label(L10n.Stats.Insights.aiCardTitle, systemImage: "sparkles")
                    .font(DS.Typography.headline)
                    .foregroundStyle(.thPrimaryText)
                Spacer()
                ProBadge(size: .small)
            }

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(L10n.Insights.aiTeaserPlaceholder1)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .redacted(reason: .placeholder)
                    .blur(radius: 3)

                Text(L10n.Insights.aiTeaserPlaceholder2)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .redacted(reason: .placeholder)
                    .blur(radius: 3)
            }

            Button {
                showUpgradeSheet = true
            } label: {
                HStack(spacing: DS.Spacing.xs) {
                    YalaSpark(size: .small, animated: false)
                    // «Probar Pro gratis» o «Pasarme a Pro» (UX 2.2 · L17-4).
                    Text(ProPresentation.upgradeButtonTitle)
                        .font(DS.Typography.labelSmall)
                }
                .foregroundStyle(.thOnAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.sm)
                .background(theme.accent)
                .clipShape(Capsule())
            }
        }
        .panelCard()
    }

    // MARK: - Locked Fun Fact

    private var lockedFunFact: some View {
        Button {
            showUpgradeSheet = true
        } label: {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "lightbulb")
                    .font(DS.Typography.body)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                Text(L10n.Insights.funFact)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .redacted(reason: .placeholder)

                Spacer()

                Image(systemName: "lock.fill")
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                ProBadge(size: .small)
            }
            .panelCard()
            .opacity(0.7)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Content Mode Pill (standalone, full-width iOS 26 Liquid Glass)

    private var contentModePill: some View {
        GenericSegmentedPill(
            options: InsightsContentMode.allCases,
            selection: $contentMode,
            labelProvider: { $0.label },
            selectedFillColorProvider: { _ in theme.accent }
        )
    }

}

// MARK: - InsightsContentMode

private enum InsightsContentMode: String, CaseIterable {
    case detail
    case observations

    var label: String {
        switch self {
        case .detail:       return L10n.Stats.Insights.modeDetail
        case .observations: return L10n.Insights.intelligentInsights
        }
    }
}

// MARK: - «Ponerle un tope» (opción B)

/// Las dos hojas de «Ponerle un tope» de los gastos hormiga: el asistente de «Nuevo presupuesto» de Planificación y el
/// paywall del límite de presupuestos. En su propio modificador: el `body` de la pestaña ya va cargado de presentaciones
/// (regla del compilador del CI en `swiftui-ds.md`).
private struct ResumenNewBudgetSheets: ViewModifier {
    let wizard: AsistentePresupuestoEstado
    @Binding var showsNewBudget: Bool
    @Binding var showsUpgrade: Bool

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showsNewBudget, onDismiss: { wizard.empezar(periodo: .monthly) }) {
                NuevoPresupuestoHoja(estado: wizard) { showsNewBudget = false }
            }
            // Como Planificación: al pasarse a Pro, el asistente se abre solo.
            .proUpgradeSheet(isPresented: $showsUpgrade, feature: .budgets, context: .limitReached) {
                wizard.empezar(periodo: .monthly)
                showsNewBudget = true
            }
    }
}
