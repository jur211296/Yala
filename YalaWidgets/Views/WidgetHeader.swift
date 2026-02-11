//
//  WidgetHeader.swift
//  YalaWidgets
//
//  Reusable header component for widgets.
//  Displays title, optional subtitle, and optional icon.
//

import SwiftUI

/// Standard widget header with title, subtitle, and optional icon
/// Use `inline: true` for Medium widgets (title left, subtitle right on same line)
struct WidgetHeader: View {
    let title: String
    let subtitle: String?
    let icon: String?
    let inline: Bool

    init(title: String, subtitle: String? = nil, icon: String? = nil, inline: Bool = false) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.inline = inline
    }

    var body: some View {
        if inline {
            // Inline layout for Medium widgets: title left, subtitle right
            HStack(spacing: WDS.Spacing.xs) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(title)
                    .font(WDS.Typography.title)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let subtitle = subtitle {
                    Spacer()
                    Text(subtitle)
                        .font(WDS.Typography.subtitle)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        } else {
            // Vertical layout for Small widgets: title above subtitle
            VStack(alignment: .leading, spacing: WDS.Spacing.xxs) {
                HStack(spacing: WDS.Spacing.xs) {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(title)
                        .font(WDS.Typography.title)
                        .foregroundStyle(.primary)
                }

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(WDS.Typography.subtitle)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(alignment: .leading, spacing: WDS.Spacing.xxl) {
        Text("Vertical (Small)").font(.caption).foregroundStyle(.secondary)
        WidgetHeader(title: "Balance", subtitle: "Este mes", icon: "creditcard.fill")
        WidgetHeader(title: "Gastos", subtitle: nil, icon: "arrow.down.circle.fill")

        Divider()

        Text("Inline (Medium)").font(.caption).foregroundStyle(.secondary)
        WidgetHeader(title: "Balance", subtitle: "Este mes", icon: "creditcard.fill", inline: true)
        WidgetHeader(title: "Gastos", subtitle: "Este mes", icon: "arrow.down.circle.fill", inline: true)
    }
    .padding()
}
