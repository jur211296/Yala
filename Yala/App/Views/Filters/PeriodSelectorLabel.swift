//
//  PeriodSelectorLabel.swift
//  Yala
//
//  Shared period selector label component.
//

import SwiftUI

/// Period selector dropdown label used in control bars.
/// Animation explicitly disabled to prevent clipping issues during period changes.
struct PeriodSelectorLabel: View {
    let title: String

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: "calendar")
                .font(.caption.weight(.medium))
            Text(title)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .foregroundStyle(Color.yalaPrimaryText)
        .glassEffect(.regular.interactive(), in: .capsule)
        // Ensure entire capsule is tappable
        .contentShape(Capsule())
        // CRITICAL: Prevent truncation even if parent animates/constrains width
        .fixedSize()
        // CRITICAL: Disable animation to prevent clipping during period changes
        .transaction { $0.animation = nil }
    }
}

#Preview {
    VStack(spacing: DS.Spacing.lg) {
        PeriodSelectorLabel(title: "Este mes")
        PeriodSelectorLabel(title: "Últimos 30 días")
    }
    .padding()
    .background(Color.yalaCard)
}
