//
//  BudgetDetailView.swift
//  Yala
//
//  Detail view for a budget showing summary, info, and status.
//  Accessed from BudgetsListView in Planning tab.
//

import SwiftData
import SwiftUI

struct BudgetDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences
    @ScaledMetric(relativeTo: .largeTitle) private var scaledAmountSize: CGFloat = 36 // A11Y-DT: @ScaledMetric

    let budget: Budget
    @Bindable var viewModel: BudgetsViewModel

    // Cached collections para resolver UUIDs del CSV mirror → name display.
    // @Query reactivo: re-render automático tras cambios en SwiftData/CloudKit.
    @Query(sort: \Subcategory.sortOrder) private var allSubcategories: [Subcategory]
    @Query(sort: \Account.name) private var allAccounts: [Account]
    @Query(sort: \Tag.name) private var allTags: [Tag]

    @State private var showEditor = false
    @State private var showCharts = false
    @State private var summary: BudgetSummary?

    private var isBudgetValid: Bool {
        !budget.isDeleted && budget.modelContext != nil
    }

    private func refreshSummary() {
        guard isBudgetValid else { return }
        summary = viewModel.buildSummary(for: budget, defaultCurrencyCode: appPreferences.defaultCurrencyCode.rawValue)
    }

    var body: some View {
        if !isBudgetValid {
            Color.clear
                .onAppear { dismiss() }
        } else {
            mainContent
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        ZStack {
            PanelBackgroundView()

            if let summary {
                ScrollView {
                    VStack(spacing: DS.Spacing.xxl) {
                        summaryCard(summary)
                        infoSection
                        statusSection

                        if summary.status == .exceeded {
                            encouragementNote
                        }
                    }
                    .padding(.vertical, DS.Spacing.xxl)
                }
                .scrollViewGlassEdges()
            }
        }
        .navigationTitle(budget.name)
        .navigationBarTitleDisplayMode(.inline)
        .swipeBack()
        .onAppear { refreshSummary() }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                YalaToolbarButton(systemName: "chevron.left", label: L10n.Action.back) {
                    dismiss()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                YalaToolbarButton(systemName: "chart.bar.fill", label: L10n.BudgetDetail.chartsTitle) {
                    showCharts = true
                }
            }
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
            ToolbarItem(placement: .topBarTrailing) {
                YalaToolbarButton(systemName: "pencil", label: L10n.Action.edit) {
                    showEditor = true
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            BudgetEditorView(budget: budget)
                .onDisappear {
                    guard isBudgetValid else { return }
                    viewModel.loadData()
                    refreshSummary()
                }
        }
        .navigationDestination(isPresented: $showCharts) {
            BudgetChartsView(budget: budget, viewModel: viewModel)
        }
    }

    // MARK: - Summary Card

    private func summaryCard(_ summary: BudgetSummary) -> some View {
        let spentText = appPreferences.currency(summary.spent, currencyCode: budget.currencyCode)
        let limitText = appPreferences.currency(budget.limitAmount, currencyCode: budget.currencyCode)

        return VStack(spacing: DS.Spacing.lg) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color(hex: summary.color))
                    .frame(width: 56, height: 56)

                Image(systemName: summary.icon)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)
            }

            // Amount spent
            VStack(spacing: DS.Spacing.xs) {
                Text(budget.currencyCode)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)

                Text(spentText)
                    .font(DS.Typography.largeTitle)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                    .foregroundStyle(summary.status == .exceeded ? Color.hotPink : .primary)

                Text(String(format: NSLocalizedString("budgets.amount.of", comment: ""), limitText))
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Progress bar
            BudgetProgressBar(
                percentage: summary.percentage,
                color: summary.color,
                isExceeded: summary.status == .exceeded
            )
            .padding(.horizontal, DS.Spacing.xl)

            // Percentage + days remaining
            HStack {
                Text(String(format: NSLocalizedString("budgets.spent.percent", comment: ""), String(format: "%.0f%%", summary.percentage)))
                    .font(DS.Typography.label)
                    .foregroundStyle(summary.status == .exceeded ? Color.hotPink : .secondary)

                Spacer()

                if summary.daysRemaining == -1 {
                    Text(NSLocalizedString("budgets.period.past", comment: ""))
                        .font(DS.Typography.label)
                        .foregroundStyle(.secondary)
                } else {
                    Text(String(format: NSLocalizedString("budgets.days.remaining", comment: ""), "\(summary.daysRemaining)"))
                        .font(DS.Typography.label)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, DS.Spacing.sm)
        }
        .padding(DS.Spacing.xl)
        .solidCard(padding: 0, radius: DS.Panel.widgetRadius)
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.thAccent)
                    .accessibilityHidden(true)
                Text(L10n.BudgetDetail.infoTitle)
                    .font(DS.Typography.subheadlineEmphasized)
                    .foregroundStyle(.primary)
            }
            .padding(.leading, DS.Spacing.xs)

            VStack(spacing: DS.Spacing.none) {
                // Period
                detailRow(
                    icon: "calendar",
                    label: L10n.BudgetDetail.period,
                    value: periodDescription
                )

                SubsectionDivider()

                // Accounts
                detailRow(
                    icon: "creditcard",
                    label: L10n.BudgetDetail.accounts,
                    value: accountsDescription
                )

                SubsectionDivider()

                // Categories
                detailRow(
                    icon: "tag",
                    label: L10n.BudgetDetail.categories,
                    value: categoriesDescription
                )

                SubsectionDivider()

                // Subcategories
                detailRow(
                    icon: "tag.fill",
                    label: L10n.BudgetDetail.subcategories,
                    value: subcategoriesDescription
                )

                if let tagIDs = budget.resolvedTagIDs(), !tagIDs.isEmpty {
                    let resolved = allTags.filter { tagIDs.contains($0.id) }
                    if !resolved.isEmpty {
                        SubsectionDivider()

                        detailRow(
                            icon: "number",
                            label: L10n.BudgetDetail.tags,
                            value: resolved.map(\.name).joined(separator: ", ")
                        )
                    }
                }

                if let naturesString = budget.natures, !naturesString.isEmpty {
                    SubsectionDivider()

                    detailRow(
                        icon: "leaf",
                        label: L10n.BudgetDetail.needs,
                        value: needsDescription
                    )
                }
            }
            .panelCard()
        }
    }

    // MARK: - Status Section

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "gauge.medium")
                    .foregroundStyle(.thAccent)
                    .accessibilityHidden(true)
                Text(L10n.BudgetDetail.statusTitle)
                    .font(DS.Typography.subheadlineEmphasized)
                    .foregroundStyle(.primary)
            }
            .padding(.leading, DS.Spacing.xs)

            VStack(spacing: DS.Spacing.none) {
                // Active/Inactive
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: budget.isActive ? "checkmark.circle.fill" : "pause.circle.fill")
                        .font(DS.Typography.body)
                        .foregroundStyle(budget.isActive ? theme.accent : DS.Semantic.warningForeground)
                        .frame(width: 24)
                        .accessibilityHidden(true)

                    Text(budget.isActive ? BudgetStatus.active.localizedName : BudgetStatus.inactive.localizedName)
                        .font(DS.Typography.label)
                        .foregroundStyle(.primary)

                    Spacer()
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.md)

                if budget.alertEnabled {
                    SubsectionDivider()

                    // Alert thresholds
                    HStack(spacing: DS.Spacing.md) {
                        Image(systemName: "bell.fill")
                            .font(DS.Typography.body)
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                            .accessibilityHidden(true)

                        Text(L10n.BudgetDetail.alerts)
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text(alertThresholdsDescription)
                            .font(DS.Typography.label)
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.md)
                }
            }
            .panelCard()
        }
    }

    // MARK: - Encouragement Note

    private var encouragementNote: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "heart.fill")
                .font(DS.Typography.body)
                .foregroundStyle(Color.hotPink)
                .accessibilityHidden(true)

            Text(NSLocalizedString("budgets.exceeded.encouragement", comment: ""))
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(Color.hotPink.opacity(0.1))
        )
    }

    // MARK: - Detail Row

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(DS.Typography.body)
                .foregroundStyle(.secondary)
                .frame(width: 24)
                .accessibilityHidden(true)

            Text(label)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(DS.Typography.label)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
    }

    // MARK: - Computed Descriptions

    private static let mediumDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    private var periodDescription: String {
        guard let periodType = BudgetPeriodType(rawValue: budget.periodType) else { return "" }
        if periodType == .unique, let start = budget.startDate, let end = budget.endDate {
            return "\(Self.mediumDateFormatter.string(from: start)) – \(Self.mediumDateFormatter.string(from: end))"
        }
        return periodType.localizedName
    }

    private var accountsDescription: String {
        // Display reader (scheduleBackfill: false) — hot path will auto-heal.
        guard let ids = budget.resolvedAccountIDs(), !ids.isEmpty else {
            return L10n.BudgetDetail.allAccounts
        }
        let resolved = allAccounts.filter { ids.contains($0.shortcutID) }
        return resolved.map(\.name).joined(separator: ", ")
    }

    private var categoriesDescription: String {
        guard let ids = budget.resolvedSubcategoryIDs(), !ids.isEmpty else {
            return L10n.BudgetDetail.allCategories
        }
        let resolved = allSubcategories.filter { ids.contains($0.shortcutID) }
        let uniqueNames = Array(Set(resolved.map { $0.safeCategory.name })).sorted()
        return uniqueNames.joined(separator: ", ")
    }

    private var subcategoriesDescription: String {
        guard let ids = budget.resolvedSubcategoryIDs(), !ids.isEmpty else {
            return L10n.BudgetDetail.allSubcategories
        }
        let resolved = allSubcategories.filter { ids.contains($0.shortcutID) }
        return resolved.map(\.name).joined(separator: ", ")
    }

    private var needsDescription: String {
        guard let naturesString = budget.natures else { return "" }
        return naturesString.split(separator: ",")
            .compactMap { SubcategoryNeed(rawValue: String($0).trimmingCharacters(in: .whitespaces)) }
            .map(\.displayName)
            .joined(separator: ", ")
    }

    private var alertThresholdsDescription: String {
        guard let thresholds = budget.alertThresholds, !thresholds.isEmpty else { return "" }
        return thresholds.split(separator: ",").map { "\($0)%" }.joined(separator: ", ")
    }

}

#Preview {
    NavigationStack {
        Text("Preview requires Budget instance")
    }
}
