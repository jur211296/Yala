//
//  GroupSummaryHeader.swift
//  Yala
//
//  Card de resumen global: "Te deben" / "Debes" multi-currency.
//

import SwiftUI

struct GroupSummaryHeader: View {

    let summary: GroupGlobalSummary

    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.lg) {
            // Te deben
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text(L10n.Groups.Summary.owedToMe)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)

                if summary.totalOwedToMe.isEmpty {
                    AmountText(
                        value: 0,
                        currencyCode: defaultCurrency,
                        font: DS.Typography.headline, secondaryFont: DS.Typography.caption,
                        tint: .color(DS.Semantic.successForeground)
                    )
                } else {
                    ForEach(sortedOwedToMe, id: \.key) { code, amount in
                        AmountText(
                            value: amount,
                            currencyCode: code,
                            font: DS.Typography.headline, secondaryFont: DS.Typography.caption,
                            tint: .color(DS.Semantic.successForeground)
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Debes
            VStack(alignment: .trailing, spacing: DS.Spacing.sm) {
                Text(L10n.Groups.Summary.iOwe)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)

                if summary.totalIOwe.isEmpty {
                    AmountText(
                        value: 0,
                        currencyCode: defaultCurrency,
                        font: DS.Typography.headline, secondaryFont: DS.Typography.caption,
                        tint: .color(Color.hotPink)
                    )
                } else {
                    ForEach(sortedIOwe, id: \.key) { code, amount in
                        AmountText(
                            value: amount,
                            currencyCode: code,
                            font: DS.Typography.headline, secondaryFont: DS.Typography.caption,
                            tint: .color(Color.hotPink)
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .solidCard(padding: DS.Spacing.lg, radius: DS.Radius.xl)
        .dsSubtleShadow()
    }

    // MARK: - Helpers

    private var defaultCurrency: String {
        appPreferences.defaultCurrencyCode.rawValue
    }

    private var sortedOwedToMe: [(key: String, value: Double)] {
        summary.totalOwedToMe.sorted { $0.key < $1.key }
    }

    private var sortedIOwe: [(key: String, value: Double)] {
        summary.totalIOwe.sorted { $0.key < $1.key }
    }
}
