//
//  CashFlowHeaderRow.swift
//  Yala
//
//  Collapsible section header for income/expense sections in the cash flow table.
//

import SwiftUI

struct CashFlowHeaderRow: View {
    let title: String
    @Binding var isCollapsed: Bool

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: DS.Animation.fast)) {
                isCollapsed.toggle()
            }
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                Text(title.uppercased())
                    .font(DS.Typography.labelSmall)
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.down")
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(isCollapsed ? -90 : 0))
                Spacer()
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
