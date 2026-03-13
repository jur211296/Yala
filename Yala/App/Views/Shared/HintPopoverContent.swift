//
//  HintPopoverContent.swift
//  Yala
//
//  Shared content for hint/info popovers (InfoHintButton, FilterBlockedPopover).
//

import SwiftUI

/// Reusable popover content with icon + title + message.
struct HintPopoverContent: View {
    let iconName: String
    let iconColor: Color
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Label {
                Text(title)
                    .font(DS.Typography.labelSmall)
                    .foregroundStyle(.primary)
            } icon: {
                Image(systemName: iconName)
                    .font(DS.Typography.caption)
                    .foregroundStyle(iconColor)
            }

            Text(message)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(DS.Spacing.xxs)
        }
        .padding(DS.Spacing.lg)
        .frame(width: 280, alignment: .leading)
    }
}
