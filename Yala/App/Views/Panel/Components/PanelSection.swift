//
//  PanelSection.swift
//  Yala
//
//  Reusable container for thematic Panel sections.
//  Header: title + optional subtitle, optional preferences/navigate buttons.
//  Body: arbitrary @ViewBuilder content.
//
//  LazyVStack inside the Panel ScrollView crashes on tab switch — use plain VStack.
//

import SwiftUI

struct PanelSection<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    var onPreferences: (() -> Void)? = nil
    var onNavigate: (() -> Void)? = nil

    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            header
            VStack(spacing: DS.Spacing.lg) { content() }
        }
    }

    @ViewBuilder
    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(title)
                    .font(DS.Typography.title)
                if let subtitle {
                    Text(subtitle)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let onPreferences {
                Button(action: onPreferences) {
                    Image(systemName: "slider.horizontal.3")
                        .font(DS.Typography.body)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.primary)
                }
                .accessibilityLabel(L10n.Accessibility.widgetPreferences)
            }

            if let onNavigate {
                Button(action: onNavigate) {
                    Image(systemName: "chevron.right")
                        .font(DS.Typography.body)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.trailing, DS.Spacing.xxs)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("PanelSection — variants") {
    ScrollView {
        VStack(alignment: .leading, spacing: DS.Spacing.xl) {
            PanelSection(title: "Tendencias") {
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 120)
            }

            PanelSection(
                title: "Distribución",
                subtitle: "A dónde va tu gasto",
                onPreferences: {}
            ) {
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 120)
            }

            PanelSection(
                title: "Últimos registros",
                onNavigate: {}
            ) {
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 80)
            }
        }
        .padding()
    }
}
#endif
