//
//  CashFlowLineNameRow.swift
//  Yala
//
//  Sticky left column row showing line name with category icon.
//  Design matches PivotRowView: .subheadline font, DS.Spacing.lg leading padding.
//

import SwiftUI

struct CashFlowLineNameRow: View {
    let lineResult: CashFlowLineResult
    let line: CashFlowLine?
    let isOtherExpenses: Bool
    let height: CGFloat
    var compactMode: Bool = false

    var body: some View {
        HStack(spacing: compactMode ? DS.Spacing.none : DS.Spacing.sm) {
            if isOtherExpenses {
                Image(systemName: "ellipsis.circle")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(width: DS.Chip.dotSize)
            } else {
                let iconName = line?.subcategory?.iconName ?? line?.category?.iconName
                let colorHex = line?.subcategory?.colorHex ?? line?.category?.colorHex
                if let iconName, let colorHex {
                    ZStack {
                        Circle()
                            .fill(Color(hex: colorHex))
                            .frame(width: DS.Icon.badgeSmall, height: DS.Icon.badgeSmall)
                        Image(systemName: iconName)
                            .font(.system(size: DS.Icon.sizeSmall, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
            }

            if !compactMode {
                Text(lineResult.name)
                    .font(DS.Typography.caption)
                    .foregroundStyle(isOtherExpenses ? .secondary : .primary)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, compactMode ? DS.Spacing.sm : DS.Spacing.lg)
        .frame(height: height)
        .contentShape(Rectangle())
    }
}
