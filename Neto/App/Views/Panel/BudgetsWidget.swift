//
//  BudgetsWidget.swift
//  Neto
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

    // Interaction callbacks
    var onSelectBudget: ((Budget) -> Void)?
    var onShowMore: (() -> Void)?

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
        VStack(alignment: .leading, spacing: 16) {
            headerSection

            if budgets.isEmpty {
                emptyState
            } else {
                budgetsList
            }
        }
        .padding(DS.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.netoCard)
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
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer()

            if onShowMore != nil {
                Button {
                    onShowMore?()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.headline)
                        .foregroundStyle(Color.gray.opacity(0.7))
                        .padding(.leading, 4)
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
                BudgetWidgetRow(
                    summary: summary,
                    currencyCode: currencyCode
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    onSelectBudget?(summary.budget)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: hasBudgetsButNoFavorites ? "star" : "chart.pie.fill")
                .font(.largeTitle)
                .foregroundStyle(.secondary.opacity(0.5))
                .padding(.bottom, 4)

            if hasBudgetsButNoFavorites {
                Text(NSLocalizedString("budgets.widget.noFavorites.title", comment: ""))
                    .font(.subheadline.weight(.medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)

                Text(NSLocalizedString("budgets.widget.noFavorites.message", comment: ""))
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            } else {
                Text(NSLocalizedString("budgets.empty.title", comment: ""))
                    .font(.subheadline.weight(.medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)

                Text(NSLocalizedString("budgets.empty.message", comment: ""))
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 24)
    }
}
