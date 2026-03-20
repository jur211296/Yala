//
//  CashFlowHeaderRow.swift
//  Yala
//
//  Collapsible section header for income/expense sections in the cash flow table.
//

import SwiftUI

struct CashFlowHeaderRow: View {
    let title: String
    let isIncome: Bool
    @Binding var isCollapsed: Bool
    var compactMode: Bool = false

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: DS.Animation.fast)) {
                isCollapsed.toggle()
            }
        } label: {
            HStack(spacing: compactMode ? DS.Spacing.none : DS.Spacing.sm) {
                if compactMode {
                    ZStack {
                        Circle()
                            .fill(isIncome ? Color.electricIndigo : Color.hotPink)
                            .frame(width: DS.Icon.badgeSmall, height: DS.Icon.badgeSmall)
                        Image(systemName: isIncome ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: DS.Icon.sizeSmall, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                } else {
                    Image(systemName: isIncome ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption2)
                        .foregroundStyle(isIncome ? Color.electricIndigo : Color.hotPink)
                        .frame(width: DS.Chip.dotSize)

                    Text(title)
                        .font(DS.Typography.label)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    Image(systemName: "chevron.down")
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isCollapsed ? -90 : 0))
                }

                Spacer()
            }
            .padding(.horizontal, compactMode ? DS.Spacing.sm : DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
