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
                HintPopoverContent(
                    iconName: "lock.fill",
                    iconColor: DS.Semantic.warningForeground,
                    title: title,
                    message: message
                )
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
