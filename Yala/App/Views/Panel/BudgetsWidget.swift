//
//  BudgetsWidget.swift
//  Yala
//
//  Widget displaying top budgets in PanelView
//

import SwiftData
import SwiftUI

struct BudgetsWidget: View {
    let budgets: [BudgetSummary]
    let currencyCode: String

    /// True if user has budgets but none are marked as favorite
    var hasBudgetsButNoFavorites: Bool = false

    /// Currently selected budget ID for highlighting
    var selectedBudgetID: PersistentIdentifier?

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
        .padding(DS.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.yalaCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .stroke(Color.white.opacity(DS.Card.borderOpacity), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(DS.Opacity.faint), radius: 10, x: 0, y: 5)
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

            if onShowMore != nil {
                Button {
                    onShowMore?()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(DS.Typography.headline)
                        .foregroundStyle(Color.gray.opacity(0.7))
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
                let shouldDim = isAnySelected && !isSelected

                BudgetWidgetRow(
                    summary: summary,
                    currencyCode: currencyCode
                )
                .contentShape(Rectangle())
                .opacity(shouldDim ? 0.3 : 1.0)
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        onSelectBudget?(summary.budget)
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: hasBudgetsButNoFavorites ? "star" : "chart.pie.fill")
                .font(DS.Typography.largeTitle)
                .foregroundStyle(.secondary.opacity(0.5))
                .padding(.bottom, DS.Spacing.xs)

            if hasBudgetsButNoFavorites {
                Text(NSLocalizedString("budgets.widget.noFavorites.title", comment: ""))
                    .font(DS.Typography.label)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)

                Text(NSLocalizedString("budgets.widget.noFavorites.message", comment: ""))
                    .font(DS.Typography.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                // Quick action to edit favorites
                if onEditFavorites != nil {
                    Button {
                        onEditFavorites?()
                    } label: {
                        Text(L10n.Budgets.Widget.selectFavorites)
                            .font(DS.Typography.label)
                            .foregroundStyle(Color.electricIndigo)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, DS.Spacing.sm)
                }
            } else {
                Text(NSLocalizedString("budgets.empty.title", comment: ""))
                    .font(DS.Typography.label)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)

                Text(NSLocalizedString("budgets.empty.message", comment: ""))
                    .font(DS.Typography.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, DS.Spacing.xxl)
    }
}
