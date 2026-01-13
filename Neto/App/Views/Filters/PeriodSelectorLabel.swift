//
//  PeriodSelectorLabel.swift
//  Neto
//
//  Shared period selector label component.
//

import SwiftUI

/// Period selector dropdown label used in control bars.
/// Animation explicitly disabled to prevent clipping issues during period changes.
struct PeriodSelectorLabel: View {
    let title: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "calendar")
                .font(.caption.weight(.medium))
            Text(title)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .foregroundStyle(Color.netoPrimaryText)
        .background(
            Capsule()
                .fill(Color.netoSecondaryText.opacity(0.08))
        )
        // Ensure entire capsule is tappable
        .contentShape(Capsule())
        // CRITICAL: Prevent truncation even if parent animates/constrains width
        .fixedSize()
        // CRITICAL: Disable animation to prevent clipping during period changes
        .transaction { $0.animation = nil }
    }
}

#Preview {
    VStack(spacing: 16) {
        PeriodSelectorLabel(title: "Este mes")
        PeriodSelectorLabel(title: "Últimos 30 días")
    }
    .padding()
    .background(Color.netoCard)
}
