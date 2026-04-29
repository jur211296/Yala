//
//  WidgetInfoChipView.swift
//  Yala
//
//  Tag visual coloreado para el header de `WidgetInfoSheet`. Resuelve el
//  `tintKey` contra `YalaTheme` (income/expense) o paletas dark-mode safe.
//

import SwiftUI

struct WidgetInfoChipView: View {
    let chip: InfoChip
    @Environment(\.yalaTheme) private var theme

    private var resolvedTint: Color {
        switch chip.tintKey {
        case .income:  return theme.income
        case .expense: return theme.expense
        case .accent:  return Color.blue        // A11Y-DM: blue legible en ambos modos
        case .neutral: return Color.secondary   // SwiftUI semantic — dark-mode safe
        }
    }

    var body: some View {
        HStack(spacing: DS.Spacing.xxs) {
            if let systemImage = chip.systemImage {
                Image(systemName: systemImage)
                    .font(DS.Typography.caption)
            }
            Text(chip.label)
                .font(DS.Typography.labelSmall)
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xxs)
        .background(resolvedTint.opacity(0.15), in: Capsule())
        .foregroundStyle(resolvedTint)
    }
}
