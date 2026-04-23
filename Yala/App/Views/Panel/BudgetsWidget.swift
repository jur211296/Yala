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
        case small   // PP2-06b: Top 2, half-pair 192pt
        case medium  // Top 3
        case large   // Top 5
    }

    var size: CardSize = .medium

    private var limit: Int {
        switch size {
        case .small: return 2
        case .medium: return 3
        case .large: return 5
        }
    }

    var body: some View {
        Group {
            if size == .small {
                smallCardContent
            } else {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    headerSection
                    if budgets.isEmpty {
                        emptyState
                    } else {
                        budgetsList
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .solidCard(padding: DS.Card.paddingCompact)
        .frame(height: size == .small ? WidgetSize.smallHeight : nil)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top) {
            Text(L10n.WidgetType.budgets)
                .font(DS.Typography.subheadlineEmphasized)
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

    // MARK: - Small Layout (PP2-06b)

    private var smallCardContent: some View {
        Group {
            if budgets.isEmpty {
                smallEmptyState
            } else {
                // A8: exclude mode oculta el budget excluido (espejo del patrón de TopCategoriesWidget).
                let visibleBudgets: [BudgetSummary] = {
                    if isExcludeMode, let excludedID = selectedBudgetID {
                        return budgets.filter { $0.budget.persistentModelID != excludedID }
                    }
                    return budgets
                }()

                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    PanelSmallWidgetHeader(
                        title: L10n.WidgetType.budgets,
                        accessibilityLabel: L10n.Panel.seeMoreHintBudgets,
                        action: onShowMore
                    )
                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        ForEach(Array(visibleBudgets.prefix(2))) { summary in
                            smallBudgetRow(for: summary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func smallBudgetRow(for summary: BudgetSummary) -> some View {
        let color = Color(hex: summary.color)
        let clampedPercentage = max(0, min(100, summary.percentage))
        let isSelected = selectedBudgetID == summary.budget.persistentModelID
        let isAnySelected = selectedBudgetID != nil
        let shouldDim = isAnySelected && (isExcludeMode ? isSelected : !isSelected)

        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            // Línea 1: ícono + nombre
            HStack(spacing: DS.Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(color)
                        .frame(width: 28, height: 28)

                    Image(systemName: summary.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .accessibilityHidden(true)
                }

                Text(summary.budget.name)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Spacer(minLength: 0)
            }

            // Línea 2: barra (28pt fijo, alineada con el ícono) + monto + %
            HStack(spacing: DS.Spacing.sm) {
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(color.opacity(0.15))

                    Capsule()
                        .fill(color)
                        .frame(width: max(0, 28 * CGFloat(clampedPercentage / 100.0)))
                }
                .frame(width: 28, height: 6)

                Text(YalaFormatter.currency(value: summary.spent, currencyCode: currencyCode))
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: 0)

                Text(String(format: "%.0f%%", clampedPercentage))
                    .font(DS.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(color)
                    .lineLimit(1)
            }
        }
        .opacity(shouldDim ? 0.3 : 1.0)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelectBudget?(summary.budget)
        }
    }

    @ViewBuilder
    private var smallEmptyState: some View {
        if hasBudgetsButNoFavorites {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                PanelSmallWidgetHeader(
                    title: L10n.WidgetType.budgets,
                    accessibilityLabel: L10n.Panel.seeMoreHintBudgets,
                    action: onEditFavorites
                )
                VStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "star")
                        .font(.title3)
                        .foregroundStyle(DS.Semantic.favoriteIcon)
                    Text(L10n.Budgets.Widget.noFavoritesTitle)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .contentShape(Rectangle())
            .onTapGesture { onEditFavorites?() }
        } else {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                PanelSmallWidgetHeader(
                    title: L10n.WidgetType.budgets,
                    accessibilityLabel: L10n.Panel.seeMoreHintBudgets,
                    action: onShowMore
                )
                VStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "chart.pie.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text(L10n.Budgets.emptyTitle)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
