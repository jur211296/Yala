//
//  GroupStatsView.swift
//  Yala
//
//  Estadísticas dentro de un grupo: totales, quién paga más, categorías, tendencia.
//

import SwiftUI
import Charts
import SwiftData

struct GroupStatsView: View {

    let expenses: [SplitExpense]
    let shares: [SplitShare]
    let members: [SplitMember]
    let settlements: [SplitSettlement]
    let currentUserMemberID: String?
    let currencyCode: String

    @State private var viewModel = GroupStatsViewModel()
    @Environment(\.yalaTheme) private var theme
    @Environment(\.modelContext) private var modelContext
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
                    statsSelectors
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
            .onChange(of: viewModel.selectedCurrency) { _, _ in
                viewModel.recalculate()
            }
        }
    }

    // MARK: - Period Selector

    // MARK: - Selectors (moneda + período, estilo menú)

    private var statsSelectors: some View {
        HStack(spacing: DS.Spacing.sm) {
            if viewModel.availableCurrencies.count > 1 {
                currencyMenu
            }
            periodMenu
            Spacer()
        }
        .padding(.horizontal, DS.Spacing.sm)
    }

    private var currencyMenu: some View {
        Menu {
            ForEach(viewModel.availableCurrencies, id: \.self) { code in
                Button {
                    viewModel.selectedCurrency = code
                } label: {
                    HStack {
                        Text(currencyLabel(code))
                        if viewModel.selectedCurrency == code {
                            Image(systemName: "checkmark").accessibilityHidden(true)
                        }
                    }
                }
            }
        } label: {
            statsMenuLabel(icon: nil, text: currencyLabel(viewModel.selectedCurrency))
        }
    }

    private var periodMenu: some View {
        Menu {
            ForEach(GroupStatsPeriod.allCases) { period in
                Button {
                    viewModel.selectedPeriod = period
                } label: {
                    HStack {
                        Text(period.displayName)
                        if viewModel.selectedPeriod == period {
                            Image(systemName: "checkmark").accessibilityHidden(true)
                        }
                    }
                }
            }
        } label: {
            statsMenuLabel(icon: "calendar", text: viewModel.selectedPeriod.displayName)
        }
    }

    private func statsMenuLabel(icon: String?, text: String) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            if let icon {
                Image(systemName: icon).font(DS.Typography.labelSmall)
            }
            Text(text).font(DS.Typography.labelSmall)
            Image(systemName: "chevron.down").font(DS.Typography.labelTiny)
        }
        .foregroundStyle(.thPrimaryText)
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .glassEffect(.regular.interactive(), in: .capsule)
        .contentShape(Capsule())
        .fixedSize()
    }

    /// Símbolo o código de la moneda según la preferencia del usuario.
    private func currencyLabel(_ code: String) -> String {
        switch appPreferences.currencyDisplayFormat {
        case .symbol: return CurrencyCode.symbol(for: code)
        case .code: return code
        }
    }

    // MARK: - Summary Cards

    private var summaryCards: some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            summaryCard(
                title: L10n.Groups.Stats.totalSpent,
                amounts: viewModel.totalsByCurrency,
                color: .primary
            )

            summaryCard(
                title: L10n.Groups.Stats.myPortion,
                amounts: viewModel.myPortionsByCurrency.map { (currencyCode: $0.currencyCode, total: $0.amount) },
                color: theme.accent
            )
        }
    }

    /// Tarjeta de resumen: un monto por moneda apilado (todas las monedas del período).
    private func summaryCard(title: String, amounts: [(currencyCode: String, total: Double)], color: Color) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(title)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)

            if amounts.isEmpty {
                Text(appPreferences.currency(0, currencyCode: viewModel.selectedCurrency))
                    .font(DS.Typography.headline)
                    .foregroundStyle(color)
            } else {
                ForEach(amounts, id: \.currencyCode) { entry in
                    Text(appPreferences.currency(entry.total, currencyCode: entry.currencyCode))
                        .font(DS.Typography.headline)
                        .foregroundStyle(color)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .solidCard(padding: DS.Spacing.lg, radius: DS.Radius.xl)
    }

    // MARK: - Member Bar Chart (Who Pays Most)

    private var memberBarChart: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.Groups.Stats.whoMadeMostPayments)
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
                    // El contenido de `.annotation` se hostea fuera del árbol de
                    // la vista y no propaga environment objects @Observable, así
                    // que aquí NO se puede usar `AmountText` (lee
                    // `@Environment(AppPreferences.self)`). Se formatea con el
                    // `appPreferences` ya resuelto de la vista — mismo patrón que
                    // el resto de annotations de charts en la app.
                    Text(appPreferences.currency(member.totalPaid, currencyCode: viewModel.selectedCurrency))
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("\(member.displayName): \(appPreferences.currency(member.totalPaid, currencyCode: viewModel.selectedCurrency))")
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

            DonutChartView(slices: categorySlices)
                .frame(height: 260) // A11Y-DT: fixed chart height for consistent layout
                .solidCard(padding: DS.Spacing.lg, radius: DS.Radius.xl)
        }
    }

    /// Mapea el desglose por subcategoría al slice genérico del donut compartido.
    private var categorySlices: [DonutSlice] {
        viewModel.categoryBreakdown.map { cat in
            DonutSlice(
                id: cat.subcategoryName,
                name: cat.subcategoryName,
                iconName: cat.iconName,
                colorHex: cat.colorHex,
                amount: cat.amount,
                percentage: cat.percentage
            )
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
        viewModel.setContext(modelContext)
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
