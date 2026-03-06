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

    // MARK: - Settings

    @AppStorage("showVariations") private var showVariations: Bool = true

    // MARK: - Collapse State

    @AppStorage("insightsQuickStatsExpanded") private var quickStatsExpanded = true
    @AppStorage("insightsComparisonExpanded") private var comparisonExpanded = true
    @AppStorage("insightsWeekdayExpanded") private var weekdayExpanded = true
    @AppStorage("insightsNatureExpanded") private var natureExpanded = true
    @AppStorage("insightsCommitmentsExpanded") private var commitmentsExpanded = true
    @AppStorage("insightsTextsExpanded") private var textsExpanded = true
    @AppStorage("hasSeenInsightsIntro") private var hasSeenInsightsIntro = false
    @AppStorage("aiDataConsentAccepted") private var aiDataConsentAccepted = false
    @AppStorage("dismissedAIInsightsBanner") private var dismissedAIInsightsBanner = false

    // MARK: - Section Visibility (from Settings)

    @AppStorage("insightsShowQuickStats") private var showQuickStats = true
    @AppStorage("insightsShowPendingPayments") private var showPendingPayments = true
    @AppStorage("insightsShowSubscriptions") private var showSubscriptions = true
    @AppStorage("insightsShowBudgetsAtRisk") private var showBudgetsAtRisk = true
    @AppStorage("insightsShowComparison") private var showComparison = true
    @AppStorage("insightsShowWeekday") private var showWeekday = true
    @AppStorage("insightsShowNature") private var showNature = true
    @AppStorage("insightsShowTexts") private var showTexts = true

    // MARK: - Pro State

    @State private var showUpgradeSheet = false

    private var isProUser: Bool {
        FeatureGateService.shared.canAccess(.smartInsightsAI)
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
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
                    LazyVStack(spacing: DS.Spacing.xxl) {
                        // Section 1: Period Summary (always visible)
                        periodSummarySection(data.periodSummary)

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
                            quickStatsSection(data.quickStats)
                        }

                        // Section 4: Commitments
                        if hasCommitmentsData(data.commitments) {
                            commitmentsSection(data.commitments)
                        }

                        // Section 5: Streak Badge
                        if data.streak > 3 {
                            streakBadge(days: data.streak)
                        }

                        // Charts and texts only if >= 5 transactions
                        if data.periodSummary.transactionCount >= 5 {
                            // Section 7: Weekday Spending Chart
                            if showWeekday, data.weekdaySpending.contains(where: { $0.total > 0 }) {
                                weekdayChartSection(data.weekdaySpending)
                            }

                            // Section 8: Nature Distribution
                            if showNature, data.natureDistribution.total > 0 {
                                natureSection(data.natureDistribution)
                            }

                            // Section 9: Year-over-Year
                            if let yoy = data.yearOverYear {
                                yearOverYearSection(yoy)
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

                        // Section 11: First-time tip
                        if !hasSeenInsightsIntro {
                            firstTimeTip
                        }
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.xxl)
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 200)
            }
        }
        .yalaSafeBottomPadding()
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
                    variation: nil,
                    isExpenseContext: false
                )
                countCard(count: summary.transactionCount)
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.lg)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
    }

    private func countCard(count: Int) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(L10n.Insights.records)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)

            Text("\(count)")
                .font(DS.Typography.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)

            Text(L10n.Insights.inThisPeriod)
                .font(DS.Typography.captionSmall)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.lg)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
    }

    // MARK: - Section 3: Quick Stats Grid

    @ViewBuilder
    private func quickStatsSection(_ stats: QuickStats) -> some View {
        VStack(spacing: DS.Spacing.sm) {
            collapsibleHeader(
                title: L10n.Insights.quickStats,
                isExpanded: $quickStatsExpanded
            )

            if quickStatsExpanded {
                let columns = [
                    GridItem(.flexible(), spacing: DS.Spacing.md),
                    GridItem(.flexible(), spacing: DS.Spacing.md)
                ]

                LazyVGrid(columns: columns, spacing: DS.Spacing.md) {
                    QuickStatCell(
                        icon: "chart.bar",
                        label: L10n.Insights.dailyAverage,
                        value: YalaFormatter.currency(value: stats.dailyAverage, currencyCode: defaultCurrencyCode)
                    )

                    if let top = stats.topCategory {
                        QuickStatCell(
                            icon: "folder",
                            label: L10n.Insights.topCategory,
                            value: top.category.name,
                            secondary: "\(YalaFormatter.currency(value: top.amount, currencyCode: defaultCurrencyCode)) · \(Int(top.percentage))%"
                        )
                    }

                    if let topSub = stats.topSubcategory {
                        QuickStatCell(
                            icon: "tag",
                            label: L10n.Insights.topSubcategory,
                            value: topSub.subcategoryName,
                            secondary: YalaFormatter.currency(value: topSub.amount, currencyCode: defaultCurrencyCode)
                        )
                    }

                    if let highest = stats.highestExpense {
                        QuickStatCell(
                            icon: "arrow.up.circle",
                            label: L10n.Insights.highestExpense,
                            value: YalaFormatter.currency(value: highest.amount, currencyCode: defaultCurrencyCode),
                            secondary: highest.note
                        )
                    }

                    if let busiest = stats.busiestDay {
                        QuickStatCell(
                            icon: "calendar",
                            label: L10n.Insights.busiestDay,
                            value: busiest.date.formatted(.dateTime.month(.abbreviated).day()),
                            secondary: YalaFormatter.currency(value: busiest.amount, currencyCode: defaultCurrencyCode)
                        )
                    }

                    if stats.subscriptionsTotal > 0 {
                        QuickStatCell(
                            icon: "repeat",
                            label: L10n.Insights.subscriptions,
                            value: YalaFormatter.currency(value: stats.subscriptionsTotal, currencyCode: defaultCurrencyCode),
                            secondary: L10n.Insights.monthly
                        )
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Section 5: Streak Badge

    @ViewBuilder
    private func streakBadge(days: Int) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "flame.fill")
                .font(DS.Typography.headline)
                .foregroundStyle(.orange)

            Text(L10n.Insights.streakDays(days))
                .font(DS.Typography.subheadline)
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding(DS.Spacing.lg)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
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
            collapsibleHeader(
                title: L10n.Insights.commitments,
                isExpanded: $commitmentsExpanded
            )

            if commitmentsExpanded {
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
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
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
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    // MARK: - Section 9: Year-over-Year

    @ViewBuilder
    private func yearOverYearSection(_ yoy: YearComparison) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "calendar.badge.clock")
                .font(DS.Typography.body)
                .foregroundStyle(theme.accent)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(L10n.Insights.yearOverYear)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)

                Text(L10n.Insights.yearComparison(
                    previous: YalaFormatter.currency(value: yoy.previousYearAmount, currencyCode: defaultCurrencyCode),
                    current: YalaFormatter.currency(value: yoy.currentAmount, currencyCode: defaultCurrencyCode)
                ))
                .font(DS.Typography.subheadline)
                .foregroundStyle(.primary)
            }

            Spacer()

            if let variation = yoy.variation {
                VariationChip(variation: variation, size: .small, isExpenseContext: true)
            }
        }
        .padding(DS.Spacing.lg)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
    }

    // MARK: - Section 7: Weekday Spending Chart

    @ViewBuilder
    private func weekdayChartSection(_ data: [WeekdaySpending]) -> some View {
        VStack(spacing: DS.Spacing.sm) {
            collapsibleHeader(
                title: L10n.Insights.weekdaySpending,
                isExpanded: $weekdayExpanded
            )

            if weekdayExpanded {
                WeekdayBarChart(data: data, currencyCode: defaultCurrencyCode)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Section 8: Nature Distribution

    @ViewBuilder
    private func natureSection(_ distribution: NatureDistribution) -> some View {
        VStack(spacing: DS.Spacing.sm) {
            collapsibleHeader(
                title: L10n.Insights.natureDistribution,
                isExpanded: $natureExpanded
            )

            if natureExpanded {
                NatureBar(distribution: distribution)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Section 10: Text Insights

    @ViewBuilder
    private func textInsightsSection(_ insights: [InsightResult]) -> some View {
        VStack(spacing: DS.Spacing.sm) {
            collapsibleHeader(
                title: L10n.Insights.intelligentInsights,
                isExpanded: $textsExpanded
            )

            if textsExpanded {
                ForEach(insights) { insight in
                    InsightCard(insight: insight)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    @ViewBuilder
    private func aiTextInsightsSection(_ cards: [LLMInsightCard]) -> some View {
        VStack(spacing: DS.Spacing.sm) {
            collapsibleHeader(
                title: L10n.Insights.intelligentInsights,
                isExpanded: $textsExpanded
            )

            if textsExpanded {
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
                .transition(.opacity.combined(with: .move(edge: .top)))
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
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
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
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
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
        .background(DS.Semantic.infoBackground, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
    }

    // MARK: - Section 11: First-Time Tip

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
        .background(DS.Semantic.infoBackground, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
    }

    // MARK: - Collapsible Header

    private func collapsibleHeader(title: String, isExpanded: Binding<Bool>) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                isExpanded.wrappedValue.toggle()
            }
        } label: {
            HStack {
                Text(title)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "chevron.down")
                    .font(DS.Typography.caption)
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(isExpanded.wrappedValue ? 0 : -90))
            }
        }
        .buttonStyle(.plain)
    }
}
