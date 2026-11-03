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

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: icon)
                    .font(DS.Typography.captionSmall)
                    // Gris, como su etiqueta: en acento competía con la pestaña elegida y las acciones.
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

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
        .panelCard(small: true)
    }
}
