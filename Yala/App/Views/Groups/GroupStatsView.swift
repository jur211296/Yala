//
//  GroupStatsView.swift
//  Yala
//
//  Estadísticas dentro de un grupo: totales, quién paga más, categorías, tendencia.
//

import SwiftUI
import Charts

struct GroupStatsView: View {

    let expenses: [SplitExpense]
    let shares: [SplitShare]
    let members: [SplitMember]
    let settlements: [SplitSettlement]
    let currentUserMemberID: String?
    let currencyCode: String

    @State private var viewModel = GroupStatsViewModel()
    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences

    var body: some View {
        if expenses.isEmpty {
            YalaEmptyState(
                icon: "chart.pie",
                title: L10n.Groups.Stats.noExpenses
            )
        } else {
            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    periodSelector
                    summaryCards
                    if !viewModel.memberSpending.isEmpty {
                        memberBarChart
                    }
                    if viewModel.allUncategorized {
                        uncategorizedHint
                    } else if !viewModel.categoryBreakdown.isEmpty {
                        categoryPieChart
                    }
                    if viewModel.monthlyTrend.count >= 2 {
                        monthlyTrendChart
                    }
                }
                .padding(.top, DS.Spacing.sm)
                .padding(.bottom, DS.Spacing.safeBottom)
            }
            .scrollViewGlassEdges()
            .onAppear { loadStats() }
            .onChange(of: viewModel.selectedPeriod) { _, _ in
                viewModel.recalculate()
            }
        }
    }

    // MARK: - Period Selector

    private var periodSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.sm) {
                ForEach(GroupStatsPeriod.allCases) { period in
                    Button {
                        viewModel.selectedPeriod = period
                    } label: {
                        Text(period.displayName)
                            .font(DS.Typography.caption)
                            .foregroundStyle(viewModel.selectedPeriod == period ? .white : .primary)
                            .padding(.horizontal, DS.Spacing.md)
                            .padding(.vertical, DS.Spacing.xs)
                            .background(
                                Capsule()
                                    .fill(viewModel.selectedPeriod == period ? theme.accent : Color.secondary.opacity(0.12))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Summary Cards

    private var summaryCards: some View {
        HStack(spacing: DS.Spacing.md) {
            summaryCard(
                title: L10n.Groups.Stats.totalSpent,
                value: appPreferences.currency(viewModel.totalSpent, currencyCode: currencyCode),
                color: .primary
            )

            summaryCard(
                title: L10n.Groups.Stats.myPortion,
                value: appPreferences.currency(viewModel.myPortion, currencyCode: currencyCode),
                color: theme.accent
            )
        }
    }

    private func summaryCard(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(title)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(DS.Typography.headline)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .solidCard(padding: DS.Spacing.lg, radius: DS.Radius.xl)
    }

    // MARK: - Member Bar Chart (Who Pays Most)

    private var memberBarChart: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.Groups.Stats.whoPaysMost)
                .font(DS.Typography.headline)
                .padding(.leading, DS.Spacing.sm)

            Chart(viewModel.memberSpending) { member in
                BarMark(
                    x: .value("amount", member.totalPaid),
                    y: .value("member", member.displayName)
                )
                .foregroundStyle(theme.accent.gradient)
                .cornerRadius(DS.Radius.xs)
                .annotation(position: .trailing) {
                    AmountText(
                        value: member.totalPaid,
                        currencyCode: currencyCode,
                        font: DS.Typography.captionSmall,
                        secondaryFont: DS.Typography.captionSmall,
                        tint: .secondary
                    )
                }
                .accessibilityLabel("\(member.displayName): \(appPreferences.currency(member.totalPaid, currencyCode: currencyCode))")
            }
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(DS.Typography.caption)
                }
            }
            .frame(height: CGFloat(max(viewModel.memberSpending.count, 1)) * 44)
            .solidCard(padding: DS.Spacing.lg, radius: DS.Radius.xl)
        }
    }

    // MARK: - Uncategorized Hint (placeholder en vez del pie chart de 1 segmento)

    private var uncategorizedHint: some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: "chart.pie")
                .font(DS.Typography.title2)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(L10n.Groups.Stats.assignCategoriesHint)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, DS.Spacing.xl)
        .frame(maxWidth: .infinity)
        .solidCard(padding: DS.Spacing.lg, radius: DS.Radius.xl)
    }

    // MARK: - Category Pie Chart

    private var categoryPieChart: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.Groups.Stats.categories)
                .font(DS.Typography.headline)
                .padding(.leading, DS.Spacing.sm)

            VStack(spacing: DS.Spacing.lg) {
                Chart(viewModel.categoryBreakdown) { cat in
                    SectorMark(
                        angle: .value("amount", cat.amount),
                        innerRadius: .ratio(0.5),
                        angularInset: 1
                    )
                    .foregroundStyle(by: .value("category", cat.subcategoryName))
                    .cornerRadius(DS.Radius.xs)
                    .accessibilityLabel("\(cat.subcategoryName): \(appPreferences.currency(cat.amount, currencyCode: currencyCode))")
                }
                .chartLegend(position: .bottom, alignment: .leading, spacing: DS.Spacing.sm)
                .frame(height: 200) // A11Y-DT: fixed chart height for consistent layout
            }
            .solidCard(padding: DS.Spacing.lg, radius: DS.Radius.xl)
        }
    }

    // MARK: - Monthly Trend

    private var monthlyTrendChart: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.Groups.Stats.monthlyTrend)
                .font(DS.Typography.headline)
                .padding(.leading, DS.Spacing.sm)

            Chart(viewModel.monthlyTrend) { point in
                LineMark(
                    x: .value("month", point.month, unit: .month),
                    y: .value("amount", point.totalSpent)
                )
                .foregroundStyle(theme.accent)
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("month", point.month, unit: .month),
                    y: .value("amount", point.totalSpent)
                )
                .foregroundStyle(theme.accent.opacity(0.15))
                .interpolationMethod(.catmullRom)
                .accessibilityHidden(true)
            }
            .accessibilityElement(children: .combine)
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                        .font(DS.Typography.captionSmall)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine()
                    AxisValueLabel()
                        .font(DS.Typography.captionSmall)
                }
            }
            .frame(height: 180) // A11Y-DT: fixed chart height for consistent layout
            .solidCard(padding: DS.Spacing.lg, radius: DS.Radius.xl)
        }
    }

    // MARK: - Helpers

    private func loadStats() {
        viewModel.loadStats(
            expenses: expenses,
            shares: shares,
            members: members,
            settlements: settlements,
            currentUserMemberID: currentUserMemberID,
            currencyCode: currencyCode
        )
    }
}
