//
//  ExcludeModeBadge.swift
//  Yala
//
//  Shared badge indicating exclude mode is active.
//

import SwiftUI

struct ExcludeModeBadge: View {
    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: "minus.circle.fill")
                .font(DS.Typography.chipIconOnly)
                .foregroundStyle(DS.Semantic.errorForeground)
                .accessibilityHidden(true)
            Text(L10n.Filters.excludeMode)
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Semantic.errorForeground)
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xs)
        .background(DS.Semantic.errorBackgroundSubtle, in: Capsule())
    }
}
