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
    @AppStorage("aiInsightsConsentAccepted") private var aiInsightsConsentAccepted = false

    // MARK: - Section Visibility (from Settings)

    @AppStorage("insightsShowQuickStats") private var showQuickStats = true
    @AppStorage("insightsShowPendingPayments") private var showPendingPayments = true
    @AppStorage("insightsShowSubscriptions") private var showSubscriptions = true
    @AppStorage("insightsShowBudgetsAtRisk") private var showBudgetsAtRisk = true
    @AppStorage("insightsShowWeekday") private var showWeekday = true
    @AppStorage("insightsShowNature") private var showNeed = true
    @AppStorage("insightsShowTexts") private var showTexts = true

    // MARK: - Pro State

    @State private var showUpgradeSheet = false
    @State private var showCustomPeriodPicker = false
    @State private var showInsightsConsentAlert = false

    private var isProUser: Bool {
        FeatureGateService.shared.canAccess(.smartInsightsAI)
    }

    // MARK: - Body

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            if let data = viewModel.insightData {
                // Control bar always visible (period selector + filter chips)
                controlBar
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.top, DS.Spacing.sm)

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

                        // Section 1: Period Summary (always visible)
                        periodSummarySection(data.periodSummary)

                        // First-time tip (shown at top for new users)
                        if !hasSeenInsightsIntro {
                            firstTimeTip
                        }

                        // Section 2: Hero Insight / AI Button (Pro) or Rule-based (Free)
                        if isProUser {
                            proHeroSection(data)
                        } else {
                            if let hero = data.ruleBasedInsights.first {
                                InsightCard(insight: hero)
                            }
                            aiInsightsTeaser
                        }

                        // Section 3: Quick Stats Grid
                        if showQuickStats {
                            quickStatsSection(data.quickStats, summary: data.periodSummary)
                        }

                        // Section 4: Commitments
                        if hasCommitmentsData(data.commitments) {
                            commitmentsSection(data.commitments)
                        }

                        // Charts and texts only if >= 5 transactions
                        if data.periodSummary.transactionCount >= 5 {
                            // Section 5: Weekday Spending Chart
                            if showWeekday, data.weekdaySpending.contains(where: { $0.average > 0 }) {
                                weekdayChartSection(data.weekdaySpending)
                            }

                            // Section 6: Need Distribution
                            if showNeed, data.needDistribution.total > 0 {
                                needSection(data.needDistribution)
                            }

                            // Section 7: Observations
                            if showTexts {
                                if isProUser {
                                    proObservationsSection(data)
                                } else {
                                    freeObservationsSection(data)
                                }
                            }

                            // Locked fun fact for Free users
                            if !isProUser {
                                lockedFunFact
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
        .alert(L10n.AIConsent.insightsTitle, isPresented: $showInsightsConsentAlert) {
            Button(L10n.AIConsent.accept) {
                aiInsightsConsentAccepted = true
                Task { await viewModel.triggerAIGeneration() }
            }
            Button(L10n.AIConsent.privacyPolicy) {
                openURL(AppConstants.privacyURL)
            }
            Button(L10n.Action.cancel, role: .cancel) {}
        } message: {
            Text(L10n.AIConsent.insightsMessage)
        }
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        FilterControlBar(
            periodSelector: TrendsPeriodMenu(
                selectedPeriod: trendsViewModel.detailPeriod,
                customDateRange: sessionState.customDateRange,
                onSelect: { period in
                    sessionState.selectedPeriod = period
                },
                onCustomTapped: {
                    showCustomPeriodPicker = true
                }
            )
            .equatable(),
            viewModel: trendsViewModel,
            accounts: accounts,
            categories: categories,
            allSubcategories: allSubcategories,
            tags: tags,
            animationValue: trendsViewModel.detailPeriod
        ) {
            if showVariations && PreviousPeriodHelper.isSelectorVisible(for: trendsViewModel.detailPeriod) {
                VStack(spacing: DS.Spacing.xxs) {
                    ComparisonModeSelector()

                    if let data = viewModel.insightData {
                        Text(data.periodSummary.previousPeriodLabel)
                            .font(DS.Typography.captionSmall)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    private var transactionDateRange: (start: Date, end: Date) {
        let sortedDates = allTransactions.map(\.date).sorted()
        let start = sortedDates.first ?? Date.now
        let end = sortedDates.last ?? Date.now
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

    // MARK: - Pro Hero Section (AI button / loading / hero card)

    @ViewBuilder
    private func proHeroSection(_ data: InsightData) -> some View {
        if viewModel.aiActivated {
            if viewModel.isLoadingAI {
                aiLoadingPlaceholder
            } else if let aiHero = viewModel.aiInsights?.heroText {
                InsightCard(insight: InsightResult(
                    id: "ai_hero",
                    icon: "sparkles",
                    text: markdownAttributed(aiHero),
                    sentiment: .neutral,
                    isProOnly: true
                ))
            } else if let error = viewModel.aiError {
                aiErrorCard(error)
            }
        } else {
            generateAIButton
        }
    }

    // MARK: - Generate AI Button

    private var generateAIButton: some View {
        Button {
            if aiInsightsConsentAccepted {
                Task { await viewModel.triggerAIGeneration() }
            } else {
                showInsightsConsentAlert = true
            }
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "sparkles")
                Text(L10n.Insights.generateAI)
            }
            .font(DS.Typography.label)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.md)
            .background(Color.electricIndigo, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
        }
        .buttonStyle(.plain)
    }

    // MARK: - AI Error Card

    private func aiErrorCard(_ error: String) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(DS.Semantic.warningForeground)
            Text(error)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.lg)
        .yalaCard(padding: 0, shadow: false)
    }

    // MARK: - Pro Observations Section

    @ViewBuilder
    private func proObservationsSection(_ data: InsightData) -> some View {
        VStack(spacing: DS.Spacing.sm) {
            YalaSectionHeader(L10n.Insights.intelligentInsights)

            if viewModel.aiActivated {
                if viewModel.isLoadingAI {
                    aiLoadingPlaceholder
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
                            text: markdownAttributed(card.text),
                            sentiment: sentiment,
                            isProOnly: true,
                            tip: card.tip.map { markdownAttributed($0) }
                        ))
                    }

                    // Fun fact after AI cards
                    if let funFact = viewModel.aiInsights?.funFact {
                        InsightCard(insight: InsightResult(
                            id: "ai_fun_fact",
                            icon: "lightbulb",
                            text: markdownAttributed(funFact),
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
                .padding(DS.Spacing.lg)
                .yalaCard(padding: 0, shadow: false)
            }
        }
    }

    // MARK: - Free Observations Section

    @ViewBuilder
    private func freeObservationsSection(_ data: InsightData) -> some View {
        if data.ruleBasedInsights.count > 1 {
            textInsightsSection(Array(data.ruleBasedInsights.dropFirst()))
        }
    }

    // MARK: - Section 3: Quick Stats Grid

    @ViewBuilder
    private func quickStatsSection(_ stats: QuickStats, summary: PeriodSummary) -> some View {
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
                    .accessibilityHidden(true)

                Text(L10n.Insights.dailyAverage)
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.secondary)
            }

            Text(YalaFormatter.currency(value: stats.dailyAverage, currencyCode: defaultCurrencyCode))
                .font(DS.Typography.headline)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Group {
                if showVariations, let variation = summary.dailyAverageVariation {
                    VariationChip(variation: variation, size: .small, isExpenseContext: true)
                } else {
                    Text(" ")
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, DS.Spacing.xs)
                        .padding(.vertical, DS.Spacing.xxs)
                        .opacity(0)
                }
            }
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
            VStack(spacing: DS.Spacing.xxs) {
                YalaSectionHeader(L10n.Insights.commitments)
                Text(L10n.Insights.commitmentsNote)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

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
                        budgetRow(budget)
                    }
                }
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
                isExceeded: budget.usagePercent >= 100
            )
            .frame(height: 6)
        }
        .padding(DS.Spacing.md)
        .yalaCard(padding: 0, radius: DS.Radius.md, shadow: false)
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
        .padding(DS.Spacing.md)
        .yalaCard(padding: 0, radius: DS.Radius.md, shadow: false)
    }

    // MARK: - Section 5: Weekday Spending Chart

    @ViewBuilder
    private func weekdayChartSection(_ data: [WeekdaySpending]) -> some View {
        VStack(spacing: DS.Spacing.sm) {
            YalaSectionHeader(L10n.Insights.weekdayAverage)

            WeekdayBarChart(data: data, currencyCode: defaultCurrencyCode)
                .yalaCard(padding: DS.Spacing.lg, shadow: false)
        }
    }

    // MARK: - Section 6: Need Distribution

    @ViewBuilder
    private func needSection(_ distribution: NeedDistribution) -> some View {
        VStack(spacing: DS.Spacing.sm) {
            YalaSectionHeader(L10n.Insights.needDistribution)

            NeedBar(distribution: distribution)
                .yalaCard(padding: DS.Spacing.lg, shadow: false)
        }
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
        .padding(DS.Spacing.lg)
        .yalaCard(padding: 0, shadow: false)
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
            .padding(DS.Spacing.lg)
            .yalaCard(padding: 0, shadow: false)
            .opacity(0.7)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showUpgradeSheet) {
            UpgradePromptSheet(feature: .smartInsightsAI, context: .proFeature)
        }
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
            .accessibilityLabel(L10n.Accessibility.close)
        }
        .padding(DS.Spacing.lg)
        .background(DS.Semantic.infoBackground, in: RoundedRectangle(cornerRadius: DS.Radius.xl))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.xl).stroke(Color.white.opacity(DS.Card.borderOpacity), lineWidth: 1))
    }

    // MARK: - Helpers

    private func markdownAttributed(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text)) ?? AttributedString(text)
    }

}
