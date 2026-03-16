//
//  FilterBlockedPopover.swift
//  Yala
//
//  Popover that explains why a filter option is blocked.
//  Used when category/nature filters prevent switching to balance/income views.
//

import SwiftUI

/// A popover that explains why a selector option is blocked.
/// Styled consistently with InfoHintButton popovers.
struct FilterBlockedPopover: ViewModifier {
    @Binding var isPresented: Bool
    let title: String
    let message: String

    func body(content: Content) -> some View {
        content
            .popover(isPresented: $isPresented, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    HStack {
                        Image(systemName: "lock.fill")
                            .font(DS.Typography.labelSmall)
                            .foregroundStyle(DS.Semantic.warningForeground)
                            .accessibilityHidden(true)
                        Text(title)
                            .font(DS.Typography.labelSmall)
                            .foregroundStyle(.primary)
                    }

                    Text(message)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xl)
                .frame(maxWidth: 280)
                .presentationCompactAdaptation(.popover)
            }
    }
}

extension View {
    func filterBlockedPopover(
        isPresented: Binding<Bool>,
        title: String,
        message: String
    ) -> some View {
        modifier(FilterBlockedPopover(
            isPresented: isPresented,
            title: title,
            message: message
        ))
    }
}
