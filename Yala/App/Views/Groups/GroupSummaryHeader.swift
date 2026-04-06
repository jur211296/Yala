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
    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCode: String = "PEN"

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.lg) {
            // Te deben
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text(L10n.Groups.Summary.owedToMe)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)

                if summary.totalOwedToMe.isEmpty {
                    Text(YalaFormatter.currency(value: 0, currencyCode: defaultCurrency))
                        .font(DS.Typography.headline)
                        .foregroundStyle(DS.Semantic.successForeground)
                } else {
                    ForEach(sortedOwedToMe, id: \.key) { code, amount in
                        Text(YalaFormatter.currency(value: amount, currencyCode: code))
                            .font(DS.Typography.headline)
                            .foregroundStyle(DS.Semantic.successForeground)
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
                    Text(YalaFormatter.currency(value: 0, currencyCode: defaultCurrency))
                        .font(DS.Typography.headline)
                        .foregroundStyle(Color.hotPink)
                } else {
                    ForEach(sortedIOwe, id: \.key) { code, amount in
                        Text(YalaFormatter.currency(value: amount, currencyCode: code))
                            .font(DS.Typography.headline)
                            .foregroundStyle(Color.hotPink)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(DS.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .fill(.thCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .stroke(.thCardBorder, lineWidth: 1)
        )
        .dsSubtleShadow()
    }

    // MARK: - Helpers

    private var defaultCurrency: String {
        defaultCurrencyCode
    }

    private var sortedOwedToMe: [(key: String, value: Double)] {
        summary.totalOwedToMe.sorted { $0.key < $1.key }
    }

    private var sortedIOwe: [(key: String, value: Double)] {
        summary.totalIOwe.sorted { $0.key < $1.key }
    }
}
