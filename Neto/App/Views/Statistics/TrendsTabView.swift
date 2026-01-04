//
//  TrendsTabView.swift
//  Neto
//
//  Trends tab content extracted from DetailContainerView.
//  Displays trend chart, metric selector, and recent records.
//

import Charts
import SwiftData
import SwiftUI

/// Trends tab content view.
/// This view displays the trend chart, control bar, and recent records section.
struct TrendsTabView: View {

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext
    @Environment(SessionState.self) private var sessionState

    // MARK: - Data Queries

    @Query(sort: \Account.name, order: .forward) private var accounts: [Account]
    @Query(sort: \Category.name, order: .forward) private var categories: [Category]
    @Query(sort: \Tag.name, order: .forward) private var tags: [Tag]

    // MARK: - External Dependencies

    @Bindable var trendsViewModel: StatisticsViewModel
    let defaultCurrencyCode: String
    let onNavigateToRecords: () -> Void

    // MARK: - State

    @Namespace private var metricNamespace

    // MARK: - Body

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                controlBar
                chartCard
                recentRecordsSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        HStack(spacing: 12) {
            periodSelector

            if trendsViewModel.hasActiveFilters {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        if let chipText = accountsChipText {
                            FilterChipView(text: chipText) {
                                trendsViewModel.selectedAccounts.removeAll()
                            }
                        }

                        if let chipText = categoriesChipText {
                            FilterChipView(text: chipText) {
                                trendsViewModel.selectedCategories.removeAll()
                                trendsViewModel.selectedSubcategories.removeAll()
                            }
                        }

                        if let chipText = tagsChipText {
                            FilterChipView(text: chipText) {
                                trendsViewModel.selectedTags.removeAll()
                            }
                        }

                        if let chipText = naturesChipText {
                            FilterChipView(text: chipText) {
                                trendsViewModel.selectedNatures.removeAll()
                            }
                        }

                        if trendsViewModel.activeFilterCount > 1 {
                            Button {
                                withAnimation { trendsViewModel.clearFilters() }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Spacer()
        }
        .animation(nil, value: trendsViewModel.detailPeriod)
    }

    private var periodSelector: some View {
        TrendsPeriodMenu(
            selectedPeriod: trendsViewModel.detailPeriod,
            onSelect: { period in
                sessionState.selectedPeriod = period
            }
        )
        .equatable()
    }

    // MARK: - Chart Card

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            chartHeader

            TrendChartView(
                trendPoints: trendsViewModel.trendPoints,
                yDomain: trendsViewModel.yDomain,
                grouping: .day,
                interval: trendsViewModel.currentInterval,
                currencyCode: defaultCurrencyCode,
                trendType: mapMetricToTrendType(trendsViewModel.selectedMetric),
                focusedDate: $trendsViewModel.focusedDate,
                period: trendsViewModel.detailPeriod,
                chartHeight: 220
            )
            .padding(.top, 8)
        }
        .padding(20)
        .background(Color.netoCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
    }

    private var chartHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(chartTitle)
                    .font(.headline)
                    .foregroundStyle(Color.netoPrimaryText)

                Text(currentKPIValue)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.netoPrimaryText)
                    .padding(.top, 4)
            }

            Spacer()

            metricSelector
        }
    }

    private var metricSelector: some View {
        HStack(spacing: 0) {
            ForEach(TrendMetric.allCases) { metric in
                metricButton(for: metric)
            }
        }
        .padding(3)
        .background(Color.netoSecondaryText.opacity(0.08))
        .clipShape(Capsule())
    }

    private func metricButton(for metric: TrendMetric) -> some View {
        let isSelected = trendsViewModel.selectedMetric == metric

        return Button {
            trendsViewModel.selectedMetric = metric
        } label: {
            HStack(spacing: 4) {
                Image(systemName: metric.iconName)
                    .font(.caption.weight(.semibold))
                if isSelected {
                    Text(metric.rawValue)
                        .font(.caption.weight(.semibold))
                }
            }
            .padding(.horizontal, isSelected ? 12 : 10)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? .white : metric.color)
            .background(
                Group {
                    if isSelected {
                        Capsule()
                            .fill(metric.color)
                            .matchedGeometryEffect(id: "metricSelector", in: metricNamespace)
                    }
                }
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Recent Records Section

    private var recentRecordsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Últimos registros")
                .font(.headline)
                .foregroundStyle(Color.netoPrimaryText)

            if trendsViewModel.recentRecords.isEmpty {
                emptyRecordsState
            } else {
                ForEach(trendsViewModel.recentRecords.prefix(5), id: \.persistentModelID) {
                    record in
                    CompactRecordRow(record: record, currencyCode: defaultCurrencyCode)
                }
            }

            Button {
                onNavigateToRecords()
            } label: {
                HStack {
                    Spacer()
                    Text("Ver todos")
                        .font(.subheadline.weight(.semibold))
                    Image(systemName: "chevron.right")
                        .font(.caption)
                    Spacer()
                }
                .padding(.vertical, 12)
                .foregroundStyle(Color.electricIndigo)
                .background(Color.electricIndigo.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(Color.netoCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
    }

    private var emptyRecordsState: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.title2)
                .foregroundStyle(.tertiary)
            Text("Sin registros")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Helpers

    private var currentKPIValue: String {
        // When scrubbing the chart, show the hovered point value
        if let focusedDate = trendsViewModel.focusedDate,
            let point = trendsViewModel.trendPoints.first(where: {
                Calendar.current.isDate($0.date, inSameDayAs: focusedDate)
            })
        {
            return NetoFormatter.currency(value: point.value, currencyCode: defaultCurrencyCode)
        }

        // Otherwise, show metric-specific KPI (matching TrendWidget behavior)
        let value: Double
        switch trendsViewModel.selectedMetric {
        case .balance:
            // Balance: show TRUE current balance from accounts (matches TrendWidget)
            value = trendsViewModel.currentBalance
        case .income:
            // Income: show TOTAL income for the period
            value = trendsViewModel.totalIncome
        case .expense:
            // Expense: show TOTAL expense for the period
            value = trendsViewModel.totalExpense
        }
        return NetoFormatter.currency(value: value, currencyCode: defaultCurrencyCode)
    }

    private var chartTitle: String {
        switch trendsViewModel.selectedMetric {
        case .balance: return "Tendencia de Saldo"
        case .income: return "Tendencia de Ingresos"
        case .expense: return "Tendencia de Gastos"
        }
    }

    private func mapMetricToTrendType(_ metric: TrendMetric) -> TrendType {
        switch metric {
        case .balance: return .balance
        case .income: return .income
        case .expense: return .expense
        }
    }

    // MARK: - Chip Text Helpers

    private var accountsChipText: String? {
        guard !trendsViewModel.selectedAccounts.isEmpty else { return nil }
        let names =
            accounts
            .filter { trendsViewModel.selectedAccounts.contains($0.persistentModelID) }
            .map { $0.name }
        guard !names.isEmpty else { return nil }
        return names.count == 1 ? names.first : "\(names.first ?? "") +\(names.count - 1)"
    }

    private var categoriesChipText: String? {
        guard
            !trendsViewModel.selectedCategories.isEmpty
                || !trendsViewModel.selectedSubcategories.isEmpty
        else { return nil }
        var names: [String] = []
        for cat in categories
        where trendsViewModel.selectedCategories.contains(cat.persistentModelID) {
            names.append(cat.name)
        }
        let total =
            trendsViewModel.selectedCategories.count + trendsViewModel.selectedSubcategories.count
        if total == 1 { return names.first ?? "Categoría" }
        return "\(names.first ?? "Categorías") +\(total - 1)"
    }

    private var tagsChipText: String? {
        guard !trendsViewModel.selectedTags.isEmpty else { return nil }
        let names = tags.filter { trendsViewModel.selectedTags.contains($0.persistentModelID) }.map
        { $0.name }
        guard !names.isEmpty else { return nil }
        return names.count == 1 ? names.first : "\(names.first ?? "") +\(names.count - 1)"
    }

    private var naturesChipText: String? {
        guard !trendsViewModel.selectedNatures.isEmpty else { return nil }
        let names = trendsViewModel.selectedNatures.map { $0.displayName }
        return names.count == 1 ? names.first : "\(names.first ?? "") +\(names.count - 1)"
    }
}

// MARK: - Compact Record Row

/// Compact record row for the recent records section (simpler than full RecordRowView).
struct CompactRecordRow: View {
    let record: TransactionItem
    let currencyCode: String

    var body: some View {
        HStack(spacing: 12) {
            // Category icon
            ZStack {
                Circle()
                    .fill(subcategoryColor)
                    .frame(width: 40, height: 40)

                Image(systemName: subcategoryIcon)
                    .font(.callout)
                    .foregroundStyle(.white)
            }

            // Details
            VStack(alignment: .leading, spacing: 3) {
                if let note = record.note, !note.isEmpty {
                    Text(note)
                        .font(.subheadline)
                        .foregroundStyle(Color.netoPrimaryText)
                        .lineLimit(1)
                }

                Text(categoryAccountText)
                    .font(.caption)
                    .foregroundStyle(Color.netoSecondaryText)
                    .lineLimit(1)
            }

            Spacer()

            // Amount and date
            VStack(alignment: .trailing, spacing: 3) {
                Text(NetoFormatter.currency(value: record.amount, currencyCode: currencyCode))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(amountColor)

                Text(formattedDate)
                    .font(.caption)
                    .foregroundStyle(Color.netoSecondaryText)
            }
        }
        .padding(.vertical, 4)
    }

    private var subcategoryColor: Color {
        if let hex = record.subcategory?.colorHex {
            return Color(hex: hex)
        }
        if let hex = record.category?.colorHex {
            return Color(hex: hex)
        }
        return .gray
    }

    private var subcategoryIcon: String {
        // Use subcategory icon if available, fallback to category icon, then default tag
        record.subcategory?.iconName
            ?? record.category?.iconName
            ?? "tag.fill"
    }

    private var categoryAccountText: String {
        let category = record.category?.name ?? "Sin categoría"
        let account = record.account?.name ?? ""
        return account.isEmpty ? category : "\(category) • \(account)"
    }

    private var amountColor: Color {
        record.amount >= 0 ? .teal : .hotPink
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es")
        formatter.dateFormat = "d MMM"
        return formatter.string(from: record.date)
    }
}
