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
    @Environment(\.openURL) private var openURL
    @Environment(AppPreferences.self) private var appPreferences

    // MARK: - Data (passed from parent)

    let accounts: [Account]
    let categories: [Category]
    let allSubcategories: [Subcategory]
    let tags: [Tag]
    let allTransactions: [TransactionItem]
    let budgets: [Budget]
    let scheduledPayments: [ScheduledPayment]
    let defaultCurrencyCode: String

    // MARK: - ViewModel

    @Bindable var viewModel: InsightsViewModel
    @Bindable var trendsViewModel: StatisticsViewModel

    // MARK: - Pro State

    @State private var showUpgradeSheet = false
    @State private var showCustomPeriodPicker = false
    @State private var showInsightsConsentAlert = false

    @ScaledMetric(relativeTo: .largeTitle) private var summaryVerticalPadding: CGFloat = 12

    // Content split: bento Detalle (stats + commitments + need) vs Observaciones
    @State private var contentMode: InsightsContentMode = .detail
    @State private var isCommitmentsExpanded: Bool = false
    @State private var isNeedSectionExpanded: Bool = false

    // Coach mark: Pro tour (Phase 3)
    @State private var showProInsightsTour = false
    @State private var proInsightsTourIndex = 0

    private var isProUser: Bool {
        FeatureGateService.shared.canAccess(.smartInsightsAI)
    }

    /// All conditions for Phase 3 tour: phase + anchor exists + tour not done.
    private var insightsTourReady: Bool {
        !ProTourManager.shared.hasCompleted
        && ProTourManager.shared.currentPhase == .insights
        && viewModel.insightData?.periodSummary.transactionCount ?? 0 > 0
        && isProUser
        && !viewModel.aiActivated
    }

    // MARK: - Body

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            if let data = viewModel.insightData {
                VStack(spacing: DS.Spacing.md) {
                    heroSummary(data.periodSummary)
                    filterBarPanel

                    if data.periodSummary.transactionCount == 0 {
                        YalaEmptyState(
                            icon: "sparkles",
                            title: L10n.Insights.emptyTitle,
                            message: L10n.Insights.emptyBody
                        )
                        .padding(.top, DS.Spacing.xxxxl)
                    } else {
                        LazyVStack(spacing: DS.Spacing.xl) {
                            if let score = viewModel.financialScore {
                                financialScoreSection(score)
                            }

                            if isProUser {
                                proHeroSection(data)
                            } else {
                                aiInsightsTeaser
                            }

                            if data.periodSummary.transactionCount >= 5 {
                                contentModePill

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
                            }
                        }
                        .yalaSafeBottomPadding()
                    }
                }
                .padding(.top, DS.Spacing.sm)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 200)
            }
        }
        .scrollViewGlassEdges()
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
        .coachMarkOverlay(
            steps: ProTourSteps.insightsSteps,
            isPresented: $showProInsightsTour,
            currentIndex: $proInsightsTourIndex,
            onComplete: {
                ProTourManager.shared.advancePhase()
            }
        )
        .task(id: insightsTourReady) {
            guard insightsTourReady else { return }
            do { try await Task.sleep(for: .seconds(0.8)) } catch { return }
            guard insightsTourReady, !showProInsightsTour else { return }
            showProInsightsTour = true
        }
        .onChange(of: insightsTourReady) { _, ready in
            if !ready && showProInsightsTour {
                showProInsightsTour = false
                proInsightsTourIndex = 0
            }
        }
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

    @ViewBuilder
    private func heroSummary(_ summary: PeriodSummary) -> some View {
        let hasRecords = summary.transactionCount > 0
        let period = trendsViewModel.detailPeriod

        VStack(alignment: .center, spacing: DS.Spacing.xs) {
            TrendsPeriodMenu(
                selectedPeriod: period,
                customDateRange: sessionState.customDateRange,
                onSelect: { sessionState.selectedPeriod = $0 },
                onCustomTapped: { showCustomPeriodPicker = true }
            )
            .equatable()

            if !sessionState.isExpensesOnlyMode && hasRecords {
                AmountText(
                    value: summary.netBalance,
                    currencyCode: defaultCurrencyCode,
                    font: DS.Typography.heroAmount, secondaryFont: DS.Typography.heroAmountSecondary
                )
            }

            incomeExpenseChips(summary)

            if let sub = RecordsMotivationalLogic.subtitle(forCount: summary.transactionCount) {
                Text(localizedMotivational(sub))
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, summaryVerticalPadding)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isHeader)
    }

    private func localizedMotivational(_ sub: RecordsHeroSubtitle) -> String {
        switch sub {
        case .one: return L10n.Stats.Insights.motivationalOne
        case .many(let n): return L10n.Stats.Insights.motivationalMany(n)
        }
    }

    @ViewBuilder
    private func incomeExpenseChips(_ summary: PeriodSummary) -> some View {
        HStack(spacing: DS.Spacing.md) {
            if !sessionState.isExpensesOnlyMode {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "arrow.up.right")
                        .font(DS.Typography.labelSmall)
                        .foregroundStyle(Color.incomeGraph)
                        .accessibilityHidden(true)
                    AmountText(
                        value: summary.totalIncome,
                        currencyCode: defaultCurrencyCode,
                        font: DS.Typography.subheadline, secondaryFont: DS.Typography.captionSmall,
                        tint: .secondary
                    )
                    .accessibilityIdentifier("stats_kpi_income")
                    if appPreferences.showVariations {
                        VariationChip(variation: summary.incomeVariation, size: .small, isExpenseContext: false)
                    }
                }
            }

            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "arrow.down.right")
                    .font(DS.Typography.labelSmall)
                    .foregroundStyle(Color.expenseGraph)
                    .accessibilityHidden(true)
                AmountText(
                    value: summary.totalExpense,
                    currencyCode: defaultCurrencyCode,
                    font: DS.Typography.subheadline, secondaryFont: DS.Typography.captionSmall,
                    tint: .secondary
                )
                .accessibilityIdentifier("stats_kpi_expense")
                if appPreferences.showVariations {
                    VariationChip(variation: summary.expenseVariation, size: .small, isExpenseContext: true)
                }
            }
        }
    }

    // MARK: - Pro Hero Section (AI button / loading / hero card)

    @ViewBuilder
    private func proHeroSection(_ data: InsightData) -> some View {
        if viewModel.aiActivated {
            if viewModel.isLoadingAI {
                AIInsightCardComponents.loadingPlaceholder(accentColor: theme.accent)
            } else if let aiHero = viewModel.aiInsights?.heroText {
                InsightCard(insight: InsightResult(
                    id: "ai_hero",
                    icon: "sparkles",
                    text: AIInsightCardComponents.markdownAttributed(aiHero),
                    sentiment: .neutral,
                    isProOnly: true
                ))
            } else if let error = viewModel.aiError {
                AIInsightCardComponents.errorCard(error)
            }
        } else {
            generateAIButton
        }
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
                    .foregroundStyle(theme.accent)
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
        .coachMarkAnchor("proAiSummary")
    }

    // MARK: - Pro Observations Section

    @ViewBuilder
    private func proObservationsSection(_ data: InsightData) -> some View {
        VStack(spacing: DS.Spacing.sm) {
            YalaSectionHeader(L10n.Insights.intelligentInsights)

            if viewModel.aiActivated {
                if viewModel.isLoadingAI {
                    AIInsightCardComponents.loadingPlaceholder(accentColor: theme.accent)
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
                } else if viewModel.aiError != nil {
                    // Error already shown in hero section
                    EmptyView()
                }
            } else {
                // Hint to use the button
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.tertiary)
                    Text(L10n.Insights.generateAIHint)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .panelCard()
            }
        }
    }

    // MARK: - Free Observations Section

    @ViewBuilder
    private func freeObservationsSection(_ data: InsightData) -> some View {
        if !data.ruleBasedInsights.isEmpty {
            textInsightsSection(Array(data.ruleBasedInsights.prefix(2)))
        }
    }

    // MARK: - Section 3: Quick Stats Bento

    // MARK: - Section: Salud financiera (header externo, view sin header interno)

    @ViewBuilder
    private func financialScoreSection(_ score: FinancialScore) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            YalaSectionHeader(L10n.Panel.Health.cardTitle)
            FinancialScoreView(
                score: score,
                sessionState: sessionState,
                subtitle: trendsViewModel.detailPeriod.displayName,
                hideHeader: true
            )
        }
    }

    // MARK: - Detail mode (Tus cifras + M/A + bento + commitments + need)

    @ViewBuilder
    private func detailModeContent(_ data: InsightData) -> some View {
        if appPreferences.insightsShowQuickStats {
            VStack(spacing: DS.Spacing.sm) {
                detailModeHeader(summary: data.periodSummary)
                detailModeBody(stats: data.quickStats, summary: data.periodSummary)
            }
        }

        if hasCommitmentsData(data.commitments) {
            commitmentsSection(data.commitments)
        }

        if data.periodSummary.transactionCount >= 5,
           appPreferences.insightsShowNature,
           data.needDistribution.total > 0 {
            needSection(data.needDistribution)
        }
    }

    @ViewBuilder
    private func detailModeHeader(summary: PeriodSummary) -> some View {
        let period = trendsViewModel.detailPeriod
        let showComparison = appPreferences.showVariations
            && PreviousPeriodHelper.isSelectorVisible(for: period)

        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(L10n.Stats.Insights.detailHeader)
                    .font(DS.Typography.title)
                    .foregroundStyle(.primary)
                Text(period.displayName)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: DS.Spacing.sm)

            if showComparison {
                VStack(alignment: .trailing, spacing: DS.Spacing.xxs) {
                    ComparisonModeSelector()
                    Text(summary.previousPeriodLabel)
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
        }
    }

    @ViewBuilder
    private func detailModeBody(stats: QuickStats, summary: PeriodSummary) -> some View {
        dailyAverageCard(stats: stats, summary: summary)

        let columns = [
            GridItem(.flexible(), spacing: DS.Spacing.md),
            GridItem(.flexible(), spacing: DS.Spacing.md)
        ]

        LazyVGrid(columns: columns, spacing: DS.Spacing.md) {
            if let top = stats.topCategory {
                QuickStatCell(
                    icon: "folder.fill",
                    label: L10n.Insights.topCategory,
                    value: top.category.name,
                    secondary: "\(appPreferences.currency(top.amount, currencyCode: defaultCurrencyCode)) · \(Int(top.percentage))%"
                )
            }
            if let topSub = stats.topSubcategory {
                QuickStatCell(
                    icon: "tag.fill",
                    label: L10n.Insights.topSubcategory,
                    value: topSub.subcategoryName,
                    secondary: appPreferences.currency(topSub.amount, currencyCode: defaultCurrencyCode)
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
            if let bestDay = stats.highestAvgWeekday {
                QuickStatCell(
                    icon: "calendar.circle.fill",
                    label: L10n.Insights.highestAvgWeekday,
                    value: bestDay.weekdayName.capitalized,
                    secondary: appPreferences.currency(bestDay.average, currencyCode: defaultCurrencyCode)
                )
            }
        }

        if stats.subscriptionsTotal > 0 {
            subscriptionsCard(stats)
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

    // MARK: - Daily Average Card (full-width hero del bento)

    private func dailyAverageCard(stats: QuickStats, summary: PeriodSummary) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 32))
                .foregroundStyle(theme.accent)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(L10n.Insights.dailyAverage)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)

                AmountText(
                    value: stats.dailyAverage,
                    currencyCode: defaultCurrencyCode,
                    font: DS.Typography.heroAmount, secondaryFont: DS.Typography.heroAmountSecondary
                )

                // Reserva altura constante: evita salto visual al alternar
                // dailyAverageVariation nil ↔ valor (cambio de período).
                Group {
                    if appPreferences.showVariations, summary.dailyAverageVariation != nil {
                        HStack(spacing: DS.Spacing.xs) {
                            VariationChip(variation: summary.dailyAverageVariation, size: .small, isExpenseContext: true)
                            Text("· " + L10n.Stats.Insights.dailyAvgIn(trendsViewModel.detailPeriod.displayName))
                                .font(DS.Typography.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text(" ")
                            .font(DS.Typography.caption)
                            .padding(.vertical, DS.Spacing.xxs)
                            .opacity(0)
                    }
                }
            }
            Spacer()
        }
        .panelCard()
    }

    // MARK: - Subscriptions Card (banner condicional)

    private func subscriptionsCard(_ stats: QuickStats) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "repeat.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(theme.accent)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(L10n.Insights.subscriptions)
                    .font(DS.Typography.subheadlineEmphasized)
                    .foregroundStyle(.primary)
                Text("\(appPreferences.currency(stats.subscriptionsTotal, currencyCode: defaultCurrencyCode)) · \(L10n.Insights.monthly)")
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .panelCard()
    }

    // MARK: - Section 4: Commitments

    private func hasCommitmentsData(_ c: Commitments) -> Bool {
        (appPreferences.insightsShowPendingPayments && c.pendingPaymentsCount > 0) ||
        (appPreferences.insightsShowSubscriptions && c.activeSubscriptionsCount > 0) ||
        (appPreferences.insightsShowBudgetsAtRisk && !c.budgetsAtRisk.isEmpty)
    }

    @ViewBuilder
    private func commitmentsSection(_ c: Commitments) -> some View {
        VStack(spacing: DS.Spacing.sm) {
            CollapsibleSectionHeader(
                title: L10n.Insights.commitments,
                subtitle: L10n.Insights.commitmentsNote,
                isExpanded: isCommitmentsExpanded
            ) {
                dsWithAnimation(reduceMotion) {
                    isCommitmentsExpanded.toggle()
                }
            }

            if isCommitmentsExpanded {
                VStack(spacing: DS.Spacing.md) {
                    if appPreferences.insightsShowPendingPayments, c.pendingPaymentsCount > 0 {
                        commitmentRow(
                            icon: "clock",
                            label: L10n.Insights.pendingPayments,
                            value: "\(c.pendingPaymentsCount)",
                            secondary: appPreferences.currency(c.pendingPaymentsAmount, currencyCode: defaultCurrencyCode)
                        )
                    }

                    if appPreferences.insightsShowSubscriptions, c.activeSubscriptionsCount > 0 {
                        commitmentRow(
                            icon: "repeat",
                            label: L10n.Insights.activeSubscriptions,
                            value: "\(c.activeSubscriptionsCount)",
                            secondary: "\(appPreferences.currency(c.activeSubscriptionsMonthly, currencyCode: defaultCurrencyCode)) \(L10n.Insights.monthly)"
                        )
                    }

                    if appPreferences.insightsShowBudgetsAtRisk {
                        ForEach(c.budgetsAtRisk) { budget in
                            budgetRow(budget)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Budget Row (with icon, no alert colors)

    private func budgetRow(_ budget: BudgetAtRisk) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(spacing: DS.Spacing.md) {
                // Budget icon (compact version of BudgetRowView)
                ZStack {
                    Circle()
                        .fill(Color(hex: budget.colorHex ?? "4A90D9"))
                        .frame(width: 28, height: 28)

                    Image(systemName: budget.icon)
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.white)
                }

                Text(budget.name)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.primary)

                Spacer()

                Text("\(Int(budget.usagePercent))%")
                    .font(DS.Typography.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }

            BudgetProgressBar(
                percentage: budget.usagePercent,
                color: budget.colorHex ?? "4A90D9",
                isExceeded: budget.usagePercent >= 100,
                simplified: true
            )
            .frame(height: 6)
        }
        .panelCard(small: true)
    }

    private func commitmentRow(icon: String, label: String, value: String, secondary: String) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(DS.Typography.body)
                .foregroundStyle(theme.accent)
                .frame(width: 32)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(label)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.primary)
                Text(secondary)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(value)
                .font(DS.Typography.headline)
                .foregroundStyle(.primary)
        }
        .panelCard(small: true)
    }

    // MARK: - Section 6: Need Distribution

    @ViewBuilder
    private func needSection(_ distribution: NeedDistribution) -> some View {
        VStack(spacing: DS.Spacing.sm) {
            CollapsibleSectionHeader(
                title: L10n.Insights.needDistribution,
                isExpanded: isNeedSectionExpanded
            ) {
                dsWithAnimation(reduceMotion) {
                    isNeedSectionExpanded.toggle()
                }
            }

            if isNeedSectionExpanded {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    NeedBar(distribution: distribution)

                    VStack(spacing: DS.Spacing.sm) {
                        needBucketRow(
                            label: L10n.Need.essential,
                            amount: distribution.essential,
                            percent: distribution.essentialPercent,
                            color: Color.essentialNeed,
                            icon: "house.fill"
                        )
                        needBucketRow(
                            label: L10n.Need.priority,
                            amount: distribution.priority,
                            percent: distribution.priorityPercent,
                            color: Color.priorityNeedNew,
                            icon: "star.fill"
                        )
                        needBucketRow(
                            label: L10n.Need.optional,
                            amount: distribution.optional,
                            percent: distribution.optionalPercent,
                            color: Color.optionalNeed,
                            icon: "sparkles"
                        )
                    }

                    if let tip = needContextualTip(distribution) {
                        Text(tip)
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, DS.Spacing.xs)
                    }
                }
                .panelCard()
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func needBucketRow(label: String, amount: Double, percent: Double, color: Color, icon: String) -> some View {
        HStack(spacing: DS.Spacing.md) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(DS.Typography.caption)
                    .foregroundStyle(color)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(label)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.primary)
                Text(L10n.Stats.Insights.needDailyFormat(appPreferences.currency(amount / Double(periodDays), currencyCode: defaultCurrencyCode)))
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: DS.Spacing.xxs) {
                AmountText(
                    value: amount,
                    currencyCode: defaultCurrencyCode,
                    font: DS.Typography.subheadline, secondaryFont: DS.Typography.captionSmall
                )
                Text("\(Int(percent))%")
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Periodo activo en días (mínimo 1) — para promedio diario por bucket.
    private var periodDays: Int {
        let interval = trendsViewModel.detailPeriod.dateInterval(customRange: trendsViewModel.customDateRange)
        let days = Int((interval.duration / 86_400).rounded())
        return max(1, days)
    }

    /// Tip motivacional contextual: reusa la regla `ruleOptionalHigh` ya
    /// localizada (16 locales × 3 tonos). Solo se muestra si optional% > 40.
    private func needContextualTip(_ distribution: NeedDistribution) -> String? {
        guard distribution.total > 0, distribution.optionalPercent > 40 else { return nil }
        return L10n.Insights.ruleOptionalHigh(Int(distribution.optionalPercent), tone: InsightTone.current)
    }


    // MARK: - Section 7: Text Insights (Free users)

    @ViewBuilder
    private func textInsightsSection(_ insights: [InsightResult]) -> some View {
        VStack(spacing: DS.Spacing.sm) {
            YalaSectionHeader(L10n.Insights.intelligentInsights)

            ForEach(insights) { insight in
                InsightCard(insight: insight)
            }
        }
    }

    // MARK: - AI Insights Teaser (Free users)

    private var aiInsightsTeaser: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack {
                Label(L10n.Insights.aiTeaser, systemImage: "sparkles")
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
                TelemetryService.track(.proUpsellTapped, parameters: TelemetryService.upsellParameters(source: "insightsTeaser"))
                showUpgradeSheet = true
            } label: {
                HStack(spacing: DS.Spacing.xs) {
                    YalaSpark(size: .small, animated: false)
                    Text(L10n.FeatureGate.upgradeToPro)
                        .font(DS.Typography.labelSmall)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.sm)
                .background(theme.accent)
                .clipShape(Capsule())
            }
        }
        .panelCard()
        .onAppear {
            TelemetryService.trackOnce(.proUpsellShown, key: "insightsTeaser", parameters: TelemetryService.upsellParameters(source: "insightsTeaser"))
        }
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
        .sheet(isPresented: $showUpgradeSheet) {
            UpgradePromptSheet(feature: .smartInsightsAI, context: .proFeature)
        }
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
