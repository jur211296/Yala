//
//  WidgetHeader.swift
//  YalaWidgets
//
//  Reusable header component for widgets.
//  Displays title, optional subtitle, and optional icon.
//

import SwiftUI

/// Standard widget header with title, subtitle, and optional icon
struct WidgetHeader: View {
    let title: String
    let subtitle: String?
    let icon: String?

    init(title: String, subtitle: String? = nil, icon: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
    }

    var body: some View {
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

// MARK: - Preview

#Preview {
    VStack(alignment: .leading, spacing: 20) {
        WidgetHeader(title: "Balance", subtitle: "Este mes", icon: "creditcard.fill")
        WidgetHeader(title: "Gastos", subtitle: nil, icon: "arrow.down.circle.fill")
        WidgetHeader(title: "Presupuestos")
    }
    .padding()
}
