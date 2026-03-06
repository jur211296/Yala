//
//  QuickStatCell.swift
//  Yala
//
//  Mini card for Quick Stats grid: icon + label + value + optional secondary text.
//

import SwiftUI

struct QuickStatCell: View {
    let icon: String
    let label: String
    let value: String
    var secondary: String? = nil

    @Environment(\.yalaTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: icon)
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(theme.accent)

                Text(label)
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(DS.Typography.headline)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(secondary ?? " ")
                .font(DS.Typography.captionSmall)
                .foregroundStyle(.secondary)
                .opacity(secondary != nil ? 1 : 0)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.md)
        .yalaCard(padding: 0, radius: DS.Radius.md, shadow: false)
    }
}
