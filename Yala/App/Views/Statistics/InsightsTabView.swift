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

    // MARK: - Settings

    @AppStorage("showVariations") private var showVariations: Bool = true

    @AppStorage("hasSeenInsightsIntro") private var hasSeenInsightsIntro = false
    @AppStorage("aiDataConsentAccepted") private var aiDataConsentAccepted = false
    @AppStorage("dismissedAIInsightsBanner") private var dismissedAIInsightsBanner = false

    // MARK: - Section Visibility (from Settings)

    @AppStorage("insightsShowQuickStats") private var showQuickStats = true
    @AppStorage("insightsShowPendingPayments") private var showPendingPayments = true
    @AppStorage("insightsShowSubscriptions") private var showSubscriptions = true
    @AppStorage("insightsShowBudgetsAtRisk") private var showBudgetsAtRisk = true
    @AppStorage("insightsShowWeekday") private var showWeekday = true
    @AppStorage("insightsShowNature") private var showNature = true
    @AppStorage("insightsShowTexts") private var showTexts = true

    // MARK: - Pro State

    @State private var showUpgradeSheet = false
    @State private var showCustomPeriodPicker = false

    private var isProUser: Bool {
        FeatureGateService.shared.canAccess(.smartInsightsAI)
    }

    // MARK: - Body

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            if let data = viewModel.insightData {
                if data.periodSummary.transactionCount == 0 {
                    // Edge case: 0 transactions
                    YalaEmptyState(
                        icon: "sparkles",
                        title: L10n.Insights.emptyTitle,
                        message: L10n.Insights.emptyBody
                    )
                    .padding(.top, DS.Spacing.xxxxl)
                } else {
                    LazyVStack(spacing: DS.Spacing.xl) {
                        // Control bar (period selector + filter chips)
                        controlBar

                        // Section 1: Period Summary (always visible)
                        periodSummarySection(data.periodSummary)

                        // First-time tip (shown at top for new users)
                        if !hasSeenInsightsIntro {
                            firstTimeTip
                        }

                        // Pro AI consent banner
                        if isProUser && !aiDataConsentAccepted && !dismissedAIInsightsBanner {
                            proAIConsentBanner
                        }

                        // Section 2: Hero Insight
                        if viewModel.isLoadingAI {
                            aiLoadingPlaceholder
                        } else if let aiHero = viewModel.aiInsights?.heroText {
                            InsightCard(insight: InsightResult(
                                id: "ai_hero",
                                icon: "sparkles",
                                text: AttributedString(aiHero),
                                sentiment: .neutral,
                                isProOnly: true
                            ))
                        } else if let hero = data.ruleBasedInsights.first {
                            InsightCard(insight: hero)
                        }

                        // Section 3: Quick Stats Grid
                        if showQuickStats {
                            quickStatsSection(data.quickStats, summary: data.periodSummary, streak: data.streak)
                        }

                        // Section 4: Commitments
                        if hasCommitmentsData(data.commitments) {
                            commitmentsSection(data.commitments)
                        }

                        // Charts and texts only if >= 5 transactions
                        if data.periodSummary.transactionCount >= 5 {
                            // Section 7: Weekday Spending Chart
                            if showWeekday, data.weekdaySpending.contains(where: { $0.average > 0 }) {
                                weekdayChartSection(data.weekdaySpending)
                            }

                            // Section 8: Nature Distribution
                            if showNature, data.natureDistribution.total > 0 {
                                natureSection(data.natureDistribution)
                            }

                            // Section 10: Text Insights
                            if showTexts {
                                if let aiCards = viewModel.aiInsights?.cards, !aiCards.isEmpty {
                                    aiTextInsightsSection(aiCards)
                                } else if data.ruleBasedInsights.count > 1 {
                                    textInsightsSection(Array(data.ruleBasedInsights.dropFirst()))
                                }
                            }

                            // Locked fun fact for Free users
                            if !isProUser {
                                lockedFunFact
                            } else if let funFact = viewModel.aiInsights?.funFact {
                                InsightCard(insight: InsightResult(
                                    id: "ai_fun_fact",
                                    icon: "lightbulb",
                                    text: AttributedString(funFact),
                                    sentiment: .positive,
                                    isProOnly: true
                                ))
                            }
                        } else {
                            // Few transactions hint
                            Text(L10n.Insights.fewTransactions)
                                .font(DS.Typography.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, DS.Spacing.lg)
                        }
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.top, DS.Spacing.sm)
                    .yalaSafeBottomPadding()
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 200)
            }
        }
        .sheet(isPresented: $showCustomPeriodPicker) {
            CustomPeriodPickerSheet(
                minDate: transactionDateRange.start,
                maxDate: transactionDateRange.end,
                currentRange: sessionState.customDateRange
            )
        }
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        VStack(alignment: .trailing, spacing: DS.Spacing.xs) {
            HStack(spacing: DS.Spacing.md) {
            TrendsPeriodMenu(
                selectedPeriod: trendsViewModel.detailPeriod,
                customDateRange: sessionState.customDateRange,
                onSelect: { period in
                    sessionState.selectedPeriod = period
                },
                onCustomTapped: {
                    showCustomPeriodPicker = true
                }
            )
            .equatable()

            if trendsViewModel.isExcludeMode {
                ExcludeModeBadge()
            }

            if trendsViewModel.hasActiveFilters {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DS.Spacing.sm) {
                        // Account chips
                        ForEach(selectedAccountChips, id: \.id) { chip in
                            FilterChipView(
                                accountName: chip.name,
                                count: chip.count,
                                onClear: {
                                    trendsViewModel.selectedAccounts.removeAll()
                                }
                            ).excludeMode(trendsViewModel.isExcludeMode)
                        }

                        // Category chip (aggregated)
                        if let catChip = aggregatedCategoryChip(
                            selectedSubcategories: trendsViewModel.selectedSubcategories,
                            allSubcategories: allSubcategories
                        ) {
                            FilterChipView(
                                categoryName: catChip.name,
                                iconName: catChip.iconName,
                                colorHex: catChip.colorHex,
                                count: catChip.count,
                                onClear: {
                                    trendsViewModel.selectedCategories.removeAll()
                                    trendsViewModel.selectedSubcategories.removeAll()
                                }
                            ).excludeMode(trendsViewModel.isExcludeMode)
                        } else if !trendsViewModel.selectedCategories.isEmpty {
                            let selectedCats = categories.filter { trendsViewModel.selectedCategories.contains($0.persistentModelID) }
                            if let firstCat = selectedCats.first {
                                FilterChipView(
                                    categoryName: firstCat.name,
                                    iconName: firstCat.iconName,
                                    colorHex: firstCat.colorHex,
                                    count: selectedCats.count,
                                    onClear: {
                                        trendsViewModel.selectedCategories.removeAll()
                                    }
                                ).excludeMode(trendsViewModel.isExcludeMode)
                            }
                        }

                        // Subcategory chip (aggregated)
                        if let subChip = aggregatedSubcategoryChip(
                            selectedSubcategories: trendsViewModel.selectedSubcategories,
                            allSubcategories: allSubcategories
                        ) {
                            FilterChipView(
                                subcategoryName: subChip.name,
                                iconName: subChip.iconName,
                                colorHex: subChip.colorHex,
                                count: subChip.count,
                                onClear: {
                                    trendsViewModel.selectedSubcategories.removeAll()
                                }
                            ).excludeMode(trendsViewModel.isExcludeMode)
                        }

                        // Tag chips
                        ForEach(selectedTagChips, id: \.id) { chip in
                            FilterChipView(
                                tagName: chip.name,
                                iconName: chip.iconName,
                                colorHex: chip.colorHex,
                                onClear: {
                                    trendsViewModel.selectedTags.remove(chip.tagID)
                                }
                            ).excludeMode(trendsViewModel.isExcludeMode)
                        }

                        // Nature chips
                        ForEach(selectedNatureChips, id: \.nature.rawValue) { chipData in
                            FilterChipView(
                                nature: chipData.nature,
                                onClear: {
                                    trendsViewModel.selectedNatures.remove(chipData.nature)
                                }
                            ).excludeMode(trendsViewModel.isExcludeMode)
                        }

                        // Transaction nature chip
                        if !sessionState.isExpensesOnlyMode,
                            trendsViewModel.selectedTransactionNatures.count == 1,
                            let nature = trendsViewModel.selectedTransactionNatures.first
                        {
                            FilterChipView(
                                transactionNature: nature,
                                onClear: {
                                    trendsViewModel.selectedTransactionNatures.removeAll()
                                }
                            )
                        }

                        // Currency chips
                        ForEach(Array(trendsViewModel.selectedCurrencies), id: \.self) { currency in
                            FilterChipView(
                                currencyCode: currency.rawValue,
                                onClear: {
                                    trendsViewModel.selectedCurrencies.remove(currency)
                                }
                            ).excludeMode(trendsViewModel.isExcludeMode)
                        }

                        // Amount chip
                        if trendsViewModel.amountCondition.isActive {
                            FilterChipView(
                                amountText: trendsViewModel.amountCondition.displayText,
                                onClear: {
                                    trendsViewModel.amountCondition = .any
                                }
                            )
                        }

                        // Search/Note chip
                        if !trendsViewModel.searchText.isEmpty {
                            FilterChipView(
                                noteText: trendsViewModel.searchText,
                                onClear: {
                                    trendsViewModel.searchText = ""
                                }
                            )
                        }

                        if trendsViewModel.activeFilterCount > 1 {
                            Button {
                                dsWithAnimation(reduceMotion) { trendsViewModel.clearFilters() }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .accessibilityLabel(L10n.Action.clearAll)
                        }
                    }
                }
            }

            Spacer()

            if showVariations && PreviousPeriodHelper.isSelectorVisible(for: trendsViewModel.detailPeriod) {
                ComparisonModeSelector()
            }
        }
        .animation(nil, value: trendsViewModel.detailPeriod)

            if showVariations, let data = viewModel.insightData {
                Text(data.periodSummary.previousPeriodLabel)
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Chip Helpers

    private var selectedAccountChips: [AccountChip] {
        guard !trendsViewModel.selectedAccounts.isEmpty else { return [] }
        let selectedAccountsList = accounts.filter { trendsViewModel.selectedAccounts.contains($0.persistentModelID) }
        guard !selectedAccountsList.isEmpty else { return [] }
        if let firstName = selectedAccountsList.first?.name {
            return [AccountChip(name: firstName, count: selectedAccountsList.count)]
        }
        return []
    }

    private var selectedNatureChips: [NatureChipData] {
        trendsViewModel.selectedNatures.map { NatureChipData(nature: $0) }
    }

    private var selectedTagChips: [TagChip] {
        tags.filter { trendsViewModel.selectedTags.contains($0.persistentModelID) }
            .map {
                TagChip(
                    id: $0.persistentModelID,
                    tagID: $0.persistentModelID,
                    name: $0.name,
                    iconName: $0.iconName,
                    colorHex: $0.colorHex
                )
            }
    }

    private var transactionDateRange: (start: Date, end: Date) {
        let sortedDates = allTransactions.map(\.date).sorted()
        let start = sortedDates.first ?? Date()
        let end = sortedDates.last ?? Date()
        return (start, end)
    }

    // MARK: - Section 1: Period Summary

    @ViewBuilder
    private func periodSummarySection(_ summary: PeriodSummary) -> some View {
        VStack(spacing: DS.Spacing.md) {
            // Row 1: Expense + Income
            HStack(spacing: DS.Spacing.md) {
                metricCard(
                    title: L10n.CashFlow.expense,
                    value: summary.totalExpense,
                    variation: summary.expenseVariation,
                    isExpenseContext: true
                )
                metricCard(
                    title: L10n.CashFlow.income,
                    value: summary.totalIncome,
                    variation: summary.incomeVariation,
                    isExpenseContext: false
                )
            }

            // Row 2: Balance + Count
            HStack(spacing: DS.Spacing.md) {
                metricCard(
                    title: L10n.TrendType.balance,
                    value: summary.netBalance,
                    variation: summary.balanceVariation,
                    isExpenseContext: false
                )
                countCard(count: summary.transactionCount, dailyAverage: summary.dailyAverageCount)
            }
        }
    }

    // MARK: - Metric Card

    private func metricCard(
        title: String,
        value: Double,
        variation: Double?,
        isExpenseContext: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(title)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)

            Text(YalaFormatter.currency(value: value, currencyCode: defaultCurrencyCode))
                .font(DS.Typography.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if showVariations {
                VariationChip(
                    variation: variation,
                    size: .small,
                    isExpenseContext: isExpenseContext
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(DS.Spacing.lg)
        .yalaCard(padding: 0, shadow: false)
    }

    private func countCard(count: Int, dailyAverage: Double = 0) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(L10n.Insights.records)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)

            Text("\(count)")
                .font(DS.Typography.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)

            Text("~\(String(format: "%.1f", dailyAverage)) \(L10n.Insights.perDay)")
                .font(DS.Typography.captionSmall)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(DS.Spacing.lg)
        .yalaCard(padding: 0, shadow: false)
    }

    // MARK: - Section 3: Quick Stats Grid

    @ViewBuilder
    private func quickStatsSection(_ stats: QuickStats, summary: PeriodSummary, streak: Int) -> some View {
        VStack(spacing: DS.Spacing.sm) {
            YalaSectionHeader(L10n.Insights.quickStats)

            let columns = [
                GridItem(.flexible(), spacing: DS.Spacing.md),
                GridItem(.flexible(), spacing: DS.Spacing.md)
            ]

            LazyVGrid(columns: columns, spacing: DS.Spacing.md) {
                dailyAverageCell(stats: stats, summary: summary)

                if let top = stats.topCategory {
                    QuickStatCell(
                        icon: "folder.fill",
                        label: L10n.Insights.topCategory,
                        value: top.category.name,
                        secondary: "\(YalaFormatter.currency(value: top.amount, currencyCode: defaultCurrencyCode)) · \(Int(top.percentage))%"
                    )
                }

                if let topSub = stats.topSubcategory {
                    QuickStatCell(
                        icon: "tag.fill",
                        label: L10n.Insights.topSubcategory,
                        value: topSub.subcategoryName,
                        secondary: YalaFormatter.currency(value: topSub.amount, currencyCode: defaultCurrencyCode)
                    )
                }

                if let highest = stats.highestExpense {
                    QuickStatCell(
                        icon: "arrow.up.circle.fill",
                        label: L10n.Insights.highestExpense,
                        value: YalaFormatter.currency(value: highest.amount, currencyCode: defaultCurrencyCode),
                        secondary: highest.note
                    )
                }

                if let bestDay = stats.highestAvgWeekday {
                    QuickStatCell(
                        icon: "calendar.circle.fill",
                        label: L10n.Insights.highestAvgWeekday,
                        value: bestDay.weekdayName.capitalized,
                        secondary: YalaFormatter.currency(value: bestDay.average, currencyCode: defaultCurrencyCode)
                    )
                }

                if stats.subscriptionsTotal > 0 {
                    QuickStatCell(
                        icon: "repeat.circle.fill",
                        label: L10n.Insights.subscriptions,
                        value: YalaFormatter.currency(value: stats.subscriptionsTotal, currencyCode: defaultCurrencyCode),
                        secondary: L10n.Insights.monthly
                    )
                }

                if streak > 3 {
                    QuickStatCell(
                        icon: "flame.fill",
                        label: L10n.Insights.streak,
                        value: "\(streak) \(L10n.Insights.days)",
                        secondary: L10n.Insights.streakCaption
                    )
                }
            }
        }
    }

    // MARK: - Daily Average Cell

    private func dailyAverageCell(stats: QuickStats, summary: PeriodSummary) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "chart.bar.fill")
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(theme.accent)

                Text(L10n.Insights.dailyAverage)
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.secondary)
            }

            Text(YalaFormatter.currency(value: stats.dailyAverage, currencyCode: defaultCurrencyCode))
                .font(DS.Typography.headline)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            VariationChip(
                variation: showVariations ? summary.dailyAverageVariation : nil,
                size: .small,
                isExpenseContext: true
            )
            .opacity(showVariations ? 1 : 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.md)
        .yalaCard(padding: 0, radius: DS.Radius.md, shadow: false)
    }

    // MARK: - Section 4: Commitments

    private func hasCommitmentsData(_ c: Commitments) -> Bool {
        (showPendingPayments && c.pendingPaymentsCount > 0) ||
        (showSubscriptions && c.activeSubscriptionsCount > 0) ||
        (showBudgetsAtRisk && !c.budgetsAtRisk.isEmpty)
    }

    @ViewBuilder
    private func commitmentsSection(_ c: Commitments) -> some View {
        VStack(spacing: DS.Spacing.sm) {
            YalaSectionHeader(L10n.Insights.commitments)

            VStack(spacing: DS.Spacing.md) {
                if showPendingPayments, c.pendingPaymentsCount > 0 {
                    commitmentRow(
                        icon: "clock",
                        label: L10n.Insights.pendingPayments,
                        value: "\(c.pendingPaymentsCount)",
                        secondary: YalaFormatter.currency(value: c.pendingPaymentsAmount, currencyCode: defaultCurrencyCode)
                    )
                }

                if showSubscriptions, c.activeSubscriptionsCount > 0 {
                    commitmentRow(
                        icon: "repeat",
                        label: L10n.Insights.activeSubscriptions,
                        value: "\(c.activeSubscriptionsCount)",
                        secondary: "\(YalaFormatter.currency(value: c.activeSubscriptionsMonthly, currencyCode: defaultCurrencyCode)) \(L10n.Insights.monthly)"
                    )
                }

                if showBudgetsAtRisk {
                    ForEach(c.budgetsAtRisk) { budget in
                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(DS.Typography.captionSmall)
                                    .foregroundStyle(DS.Semantic.warningForeground)

                                Text(budget.name)
                                    .font(DS.Typography.subheadline)
                                    .foregroundStyle(.primary)

                                Spacer()

                                Text("\(Int(budget.usagePercent))%")
                                    .font(DS.Typography.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(budget.usagePercent >= 100 ? DS.Semantic.errorForeground : DS.Semantic.warningForeground)
                            }

                            BudgetProgressBar(
                                percentage: budget.usagePercent,
                                color: budget.colorHex ?? "FF6B6B",
                                isExceeded: budget.usagePercent >= 100
                            )
                            .frame(height: 6)
                        }
                        .padding(DS.Spacing.md)
                        .yalaCard(padding: 0, radius: DS.Radius.md, shadow: false)
                    }
                }
            }
        }
    }

    private func commitmentRow(icon: String, label: String, value: String, secondary: String) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(DS.Typography.body)
                .foregroundStyle(theme.accent)
                .frame(width: 32)

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
        .padding(DS.Spacing.md)
        .yalaCard(padding: 0, radius: DS.Radius.md, shadow: false)
    }

    // MARK: - Section 7: Weekday Spending Chart

    @ViewBuilder
    private func weekdayChartSection(_ data: [WeekdaySpending]) -> some View {
        VStack(spacing: DS.Spacing.sm) {
            YalaSectionHeader(L10n.Insights.weekdayAverage)

            WeekdayBarChart(data: data, currencyCode: defaultCurrencyCode)
                .yalaCard(padding: DS.Spacing.lg, shadow: false)
        }
    }

    // MARK: - Section 8: Nature Distribution

    @ViewBuilder
    private func natureSection(_ distribution: NatureDistribution) -> some View {
        VStack(spacing: DS.Spacing.sm) {
            YalaSectionHeader(L10n.Insights.natureDistribution)

            NatureBar(distribution: distribution)
                .yalaCard(padding: DS.Spacing.lg, shadow: false)
        }
    }

    // MARK: - Section 10: Text Insights

    @ViewBuilder
    private func textInsightsSection(_ insights: [InsightResult]) -> some View {
        VStack(spacing: DS.Spacing.sm) {
            YalaSectionHeader(L10n.Insights.intelligentInsights)

            ForEach(insights) { insight in
                InsightCard(insight: insight)
            }
        }
    }

    @ViewBuilder
    private func aiTextInsightsSection(_ cards: [LLMInsightCard]) -> some View {
        VStack(spacing: DS.Spacing.sm) {
            YalaSectionHeader(L10n.Insights.intelligentInsights)

            ForEach(Array(cards.enumerated()), id: \.offset) { _, card in
                let sentiment: Sentiment = switch card.sentiment {
                case "positive": .positive
                case "attention": .attention
                default: .neutral
                }
                InsightCard(insight: InsightResult(
                    id: "ai_\(card.text.prefix(20))",
                    icon: card.icon,
                    text: AttributedString(card.text),
                    sentiment: sentiment,
                    isProOnly: true
                ))
            }
        }
    }

    // MARK: - AI Loading Placeholder

    private var aiLoadingPlaceholder: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "sparkles")
                .foregroundStyle(theme.accent)
                .symbolEffect(.pulse)
            Text(L10n.Insights.analyzingData)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(DS.Spacing.lg)
        .yalaCard(padding: 0, shadow: false)
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

                Text(L10n.Insights.funFact)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .redacted(reason: .placeholder)

                Spacer()

                Image(systemName: "lock.fill")
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)

                ProBadge(size: .small)
            }
            .padding(DS.Spacing.lg)
            .yalaCard(padding: 0, shadow: false)
            .opacity(0.7)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showUpgradeSheet) {
            UpgradePromptSheet(feature: .smartInsightsAI, context: .proFeature)
        }
    }

    // MARK: - Pro AI Consent Banner

    private var proAIConsentBanner: some View {
        VStack(spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "sparkles")
                    .font(DS.Typography.headline)
                    .foregroundStyle(theme.accent)

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(L10n.Insights.activateAITitle)
                        .font(DS.Typography.subheadline)
                        .fontWeight(.medium)
                    Text(L10n.Insights.activateAIBody)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            HStack(spacing: DS.Spacing.md) {
                Button(L10n.Insights.activate) {
                    aiDataConsentAccepted = true
                }
                .font(DS.Typography.label)
                .foregroundStyle(.white)
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.sm)
                .background(theme.accent, in: Capsule())

                Button(L10n.Insights.notInterested) {
                    dismissedAIInsightsBanner = true
                }
                .font(DS.Typography.label)
                .foregroundStyle(.secondary)
            }
        }
        .padding(DS.Spacing.lg)
        .background(DS.Semantic.infoBackground, in: RoundedRectangle(cornerRadius: DS.Radius.xl))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.xl).stroke(Color.white.opacity(DS.Card.borderOpacity), lineWidth: 1))
    }

    // MARK: - First-Time Tip

    private var firstTimeTip: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "lightbulb")
                .font(DS.Typography.body)
                .foregroundStyle(theme.accent)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(L10n.Insights.firstTimeTitle)
                    .font(DS.Typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                Text(L10n.Insights.firstTimeBody)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                withAnimation { hasSeenInsightsIntro = true }
            } label: {
                Image(systemName: "xmark")
                    .font(DS.Typography.caption)
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(DS.Spacing.lg)
        .background(DS.Semantic.infoBackground, in: RoundedRectangle(cornerRadius: DS.Radius.xl))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.xl).stroke(Color.white.opacity(DS.Card.borderOpacity), lineWidth: 1))
    }

}
