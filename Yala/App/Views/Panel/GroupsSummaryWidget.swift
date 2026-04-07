//
//  GroupsSummaryWidget.swift
//  Yala
//
//  Panel widget showing group balance summary: owed to me, I owe, pending settlements.
//

import SwiftUI

struct GroupsSummaryWidget: View {

    let summary: GroupGlobalSummary
    let currencyCode: String

    var onShowMore: (() -> Void)?

    @Environment(\.yalaTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            headerSection
            balanceSection
            if summary.pendingSettlements > 0 {
                pendingRow
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .solidCard(padding: DS.Spacing.xl, radius: DS.Radius.xl)
    }

    // MARK: - Header

    private var headerSection: some View {
        Button {
            onShowMore?()
        } label: {
            HStack {
                Image(systemName: "person.2.fill")
                    .font(DS.Typography.caption)
                    .foregroundStyle(theme.accent)

                Text(L10n.Groups.title)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Balance Section

    private var balanceSection: some View {
        HStack(spacing: DS.Spacing.lg) {
            // Owed to me
            let owedTotal = summary.totalOwedToMe.values.reduce(0, +)
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(L10n.Groups.Summary.owedToMe)
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.secondary)
                Text(YalaFormatter.currency(value: owedTotal, currencyCode: currencyCode))
                    .font(DS.Typography.headline)
                    .foregroundStyle(DS.Semantic.successForeground)
            }

            Spacer()

            // I owe
            let iOweTotal = summary.totalIOwe.values.reduce(0, +)
            VStack(alignment: .trailing, spacing: DS.Spacing.xxs) {
                Text(L10n.Groups.Summary.iOwe)
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.secondary)
                Text(YalaFormatter.currency(value: iOweTotal, currencyCode: currencyCode))
                    .font(DS.Typography.headline)
                    .foregroundStyle(Color.hotPink)
            }
        }
    }

    // MARK: - Pending Settlements

    private var pendingRow: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: "clock.fill")
                .font(DS.Typography.captionSmall)
                .foregroundStyle(.secondary)

            Text(L10n.Groups.Summary.pendingSettlements)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)

            Text("\(summary.pendingSettlements)")
                .font(DS.Typography.caption)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
        }
    }
}
