//
//  BudgetsWidget.swift
//  Yala
//
//  Widget displaying top budgets in PanelView
//

import SwiftData
import SwiftUI

struct BudgetsWidget: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let budgets: [BudgetSummary]
    let currencyCode: String

    /// True if user has budgets but none are marked as favorite
    var hasBudgetsButNoFavorites: Bool = false

    /// Currently selected budget ID for highlighting
    var selectedBudgetID: PersistentIdentifier?
    var isExcludeMode: Bool = false

    // Interaction callbacks
    var onSelectBudget: ((Budget) -> Void)?
    var onShowMore: (() -> Void)?
    var onEditFavorites: (() -> Void)?

    // Layout variants
    enum CardSize {
        case large   // Top 5
        case medium  // Top 3
    }

    var size: CardSize = .medium

    private var limit: Int {
        size == .large ? 5 : 3
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            headerSection

            if budgets.isEmpty {
                emptyState
            } else {
                budgetsList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .glassCard(.regular, radius: DS.Radius.xl, padding: DS.Spacing.xl)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top) {
            Text(L10n.WidgetType.budgets)
                .font(DS.Typography.headline)
                .foregroundStyle(.primary)
                .lineLimit(1)

            InfoHintButton(
                title: L10n.WidgetType.budgets,
                message: L10n.Widget.Hint.budgets
            )

            Spacer()

            if !budgets.isEmpty, let onEditFavorites {
                Button {
                    onEditFavorites()
                } label: {
                    Image(systemName: "star")
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            if onShowMore != nil {
                Button {
                    onShowMore?()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(DS.Typography.headline)
                        .foregroundStyle(.secondary)
                        .padding(.leading, DS.Spacing.xs)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Budgets List

    private var budgetsList: some View {
        VStack(spacing: DS.Spacing.lg) {
            let displayedBudgets = Array(budgets.prefix(limit))

            ForEach(displayedBudgets) { summary in
                let isSelected = selectedBudgetID == summary.budget.persistentModelID
                let isAnySelected = selectedBudgetID != nil
                let shouldDim = isAnySelected && (isExcludeMode ? isSelected : !isSelected)

                Button {
                    dsWithAnimation(reduceMotion, .easeInOut(duration: 0.2)) {
                        onSelectBudget?(summary.budget)
                    }
                } label: {
                    BudgetWidgetRow(
                        summary: summary,
                        currencyCode: currencyCode
                    )
                    .contentShape(Rectangle())
                    .opacity(shouldDim ? 0.3 : 1.0)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        if hasBudgetsButNoFavorites {
            YalaEmptyState(
                icon: "star",
                title: L10n.Budgets.Widget.noFavoritesTitle,
                message: L10n.Budgets.Widget.noFavoritesMessage,
                actionTitle: onEditFavorites != nil ? L10n.Budgets.Widget.selectFavorites : nil,
                action: onEditFavorites,
                style: .widget
            )
        } else {
            YalaEmptyState(
                icon: "chart.pie.fill",
                title: L10n.Budgets.emptyTitle,
                message: L10n.Budgets.emptyMessage,
                style: .widget
            )
        }
    }
}
