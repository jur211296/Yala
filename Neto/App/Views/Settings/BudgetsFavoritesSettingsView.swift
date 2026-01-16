//
//  BudgetsFavoritesSettingsView.swift
//  Neto
//
//  Manage favorite budgets for widget display.
//  Favorite budgets appear in the Budgets widget (top 3 in medium, top 5 in large).
//

import SwiftData
import SwiftUI

struct BudgetsFavoritesSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<Budget> { $0.isActive })
    private var activeBudgets: [Budget]

    @State private var isEditMode = false

    // Group budgets by period type
    private var budgetsByPeriod: [(periodType: BudgetPeriodType, budgets: [Budget])] {
        let grouped = Dictionary(grouping: activeBudgets) { budget in
            BudgetPeriodType(rawValue: budget.periodType) ?? .monthly
        }

        // Return in consistent order: weekly, monthly, yearly, unique
        return BudgetPeriodType.allCases.compactMap { periodType in
            guard let budgets = grouped[periodType], !budgets.isEmpty else { return nil }
            // Sort: favorites first by favoriteOrder, then non-favorites by name
            let sorted = budgets.sorted { a, b in
                if a.isFavorite && b.isFavorite {
                    return a.favoriteOrder < b.favoriteOrder
                } else if a.isFavorite {
                    return true
                } else if b.isFavorite {
                    return false
                } else {
                    return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
                }
            }
            return (periodType, sorted)
        }
    }

    // Only favorite budgets for reordering
    private var favoriteBudgets: [Budget] {
        activeBudgets
            .filter { $0.isFavorite }
            .sorted { $0.favoriteOrder < $1.favoriteOrder }
    }

    var body: some View {
        ZStack {
            PanelBackgroundView()

            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    // Info header
                    infoHeader

                    if activeBudgets.isEmpty {
                        emptyState
                    } else if isEditMode {
                        // Edit mode: show only favorites for reordering
                        reorderSection
                    } else {
                        // Normal mode: show all budgets grouped by period
                        ForEach(budgetsByPeriod, id: \.periodType) { group in
                            periodSection(periodType: group.periodType, budgets: group.budgets)
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xxl)
            }
        }
        .navigationTitle(L10n.Settings.budgetsFavorites)
        .navigationBarTitleDisplayMode(.inline)
        .swipeBack()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NetoToolbarButton(systemName: "chevron.left") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if !favoriteBudgets.isEmpty {
                    NetoToolbarButton(systemName: isEditMode ? "checkmark" : "arrow.up.arrow.down") {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isEditMode.toggle()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Info Header

    private var infoHeader: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "info.circle.fill")
                .font(.body)
                .foregroundStyle(Color.electricIndigo)

            Text(L10n.Settings.budgetsFavoritesInfo)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(Color.electricIndigo.opacity(0.1))
        )
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.lg) {
            Image(systemName: "chart.pie")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text(NSLocalizedString("budgets.empty.title", comment: ""))
                .font(.headline)
                .foregroundStyle(.secondary)

            Text(L10n.Settings.budgetsFavoritesEmptyHint)
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.top, 64)
    }

    // MARK: - Period Section

    private func periodSection(periodType: BudgetPeriodType, budgets: [Budget]) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(periodType.localizedName)
                .font(.headline)
                .foregroundStyle(Color.primary.opacity(0.6))
                .padding(.leading, 6)

            VStack(spacing: 0) {
                ForEach(Array(budgets.enumerated()), id: \.element.persistentModelID) { index, budget in
                    budgetRow(budget)

                    if index < budgets.count - 1 {
                        Divider()
                            .padding(.leading, 52)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .fill(Color.netoCard)
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 6)
        }
    }

    // MARK: - Budget Row

    private func budgetRow(_ budget: Budget) -> some View {
        HStack(spacing: DS.Spacing.md) {
            // Favorite toggle
            Button {
                toggleFavorite(budget)
            } label: {
                Image(systemName: budget.isFavorite ? "star.fill" : "star")
                    .font(.body)
                    .foregroundStyle(budget.isFavorite ? Color.yellow : Color.secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)

            // Budget info
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(budget.name)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(formatAmount(budget.limitAmount, currency: budget.currencyCode))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Order indicator for favorites
            if budget.isFavorite {
                Text("#\(budget.favoriteOrder + 1)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .contentShape(Rectangle())
    }

    // MARK: - Reorder Section (Edit Mode)

    private var reorderSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.Settings.budgetsFavoritesReorder)
                .font(.headline)
                .foregroundStyle(Color.primary.opacity(0.6))
                .padding(.leading, 6)

            List {
                ForEach(Array(favoriteBudgets.enumerated()), id: \.element.persistentModelID) { index, budget in
                    reorderRow(budget, position: index + 1)
                        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                        .listRowBackground(Color.netoCard)
                        .listRowSeparator(
                            index == 0 || index == favoriteBudgets.count - 1 ? .hidden : .visible,
                            edges: index == 0 ? .top : .bottom
                        )
                }
                .onMove(perform: moveBudget)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDisabled(true)
            .frame(height: CGFloat(favoriteBudgets.count) * 52)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .fill(Color.netoCard)
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 6)
            .environment(\.editMode, .constant(.active))
        }
    }

    private func reorderRow(_ budget: Budget, position: Int) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Text("#\(position)")
                .font(.caption.monospacedDigit().bold())
                .foregroundStyle(Color.electricIndigo)
                .frame(width: 28)

            Text(budget.name)
                .font(.body)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer()

            Text(BudgetPeriodType(rawValue: budget.periodType)?.localizedName ?? "")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }

    // MARK: - Actions

    private func toggleFavorite(_ budget: Budget) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            if budget.isFavorite {
                // Remove from favorites
                budget.isFavorite = false
                budget.favoriteOrder = 0
                // Reindex remaining favorites
                reindexFavorites()
            } else {
                // Add to favorites at the end
                let maxOrder = favoriteBudgets.map { $0.favoriteOrder }.max() ?? -1
                budget.isFavorite = true
                budget.favoriteOrder = maxOrder + 1
            }
            try? modelContext.save()
            // Trigger widget refresh in PanelView
            SessionState.shared.needsBudgetsWidgetRefresh = true
        }
    }

    private func moveBudget(from source: IndexSet, to destination: Int) {
        var ordered = favoriteBudgets
        ordered.move(fromOffsets: source, toOffset: destination)

        // Update favorite order
        for (index, budget) in ordered.enumerated() {
            budget.favoriteOrder = index
        }

        try? modelContext.save()
        // Trigger widget refresh in PanelView
        SessionState.shared.needsBudgetsWidgetRefresh = true
    }

    private func reindexFavorites() {
        let sorted = favoriteBudgets.sorted { $0.favoriteOrder < $1.favoriteOrder }
        for (index, budget) in sorted.enumerated() {
            budget.favoriteOrder = index
        }
    }

    // MARK: - Helpers

    private func formatAmount(_ amount: Double, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "\(currency) \(Int(amount))"
    }
}

#Preview {
    NavigationStack {
        BudgetsFavoritesSettingsView()
    }
}
