//
//  CashFlowLineNameRow.swift
//  Yala
//
//  Sticky left column row showing line name with category icon.
//

import SwiftUI

struct CashFlowLineNameRow: View {
    let lineResult: CashFlowLineResult
    let line: CashFlowLine?
    let isOtherExpenses: Bool
    let height: CGFloat

    @Environment(\.yalaTheme) private var theme

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            if isOtherExpenses {
                Image(systemName: "ellipsis.circle")
                    .font(DS.Typography.caption)
                    .foregroundStyle(.tertiary)
                    .frame(width: 20)
            } else {
                let iconName = line?.subcategory?.iconName ?? line?.category?.iconName
                let colorHex = line?.subcategory?.colorHex ?? line?.category?.colorHex
                if let iconName, let colorHex {
                    Image(systemName: iconName)
                        .font(DS.Typography.caption)
                        .foregroundStyle(Color(hex: colorHex))
                        .frame(width: 20)
                }
            }

            Text(lineResult.name)
                .font(DS.Typography.caption)
                .foregroundStyle(isOtherExpenses ? .secondary : .primary)
                .lineLimit(1)

            Spacer(minLength: 0)

            if !isOtherExpenses {
                Image(systemName: "chevron.right")
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.quaternary)
            }
        }
        .padding(.horizontal, DS.Spacing.md)
        .frame(height: height)
        .contentShape(Rectangle())
    }
}
