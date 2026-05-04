//
//  PanelSection.swift
//  Yala
//
//  Reusable container for thematic Panel sections.
//  Header: title + optional subtitle, optional preferences button.
//  Body: arbitrary @ViewBuilder content.
//  Footer: optional @ViewBuilder (P20-11 "Ver más en X" CTAs).
//
//  LazyVStack inside the Panel ScrollView crashes on tab switch — use plain VStack.
//
//  P20-11:
//   - Replaced legacy `onNavigate` chevron with an optional `footer` slot — CTAs
//     now live *after* the content, not in the header.
//   - Uses a compact grid button for widget/layout preferences.
//   - Expanded title↔content spacing to `xl` and added vertical header padding
//     for visual breathing room between sections.
//

import SwiftUI

struct PanelSection<Content: View, Footer: View>: View {
    let title: String
    var subtitle: String? = nil
    var onPreferences: (() -> Void)? = nil
    /// Acción inline "ver más" mostrada como chevron glass al lado del título.
    /// Mismo lenguaje visual que el toggle de "Tus finanzas" (`minus`/`plus`)
    /// — permite navegar al detalle sin un footer aparte.
    var onSeeMore: (() -> Void)? = nil
    var seeMoreAccessibilityLabel: String? = nil
    var seeMoreAccessibilityHint: String? = nil

    @ViewBuilder var content: () -> Content
    @ViewBuilder var footer: () -> Footer

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            header
            VStack(spacing: DS.Spacing.lg) { content() }
            footer()
        }
    }

    @ViewBuilder
    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                HStack(spacing: DS.Spacing.xs) {
                    Text(title)
                        .font(DS.Typography.title)
                    if let onSeeMore {
                        seeMoreButton(action: onSeeMore)
                    }
                }
                if let subtitle {
                    Text(subtitle)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let onPreferences {
                preferencesButton(action: onPreferences)
            }
        }
        .padding(.trailing, DS.Spacing.xxs)
        .padding(.vertical, DS.Spacing.xs)
    }

    private func seeMoreButton(action: @escaping () -> Void) -> some View {
        Button {
            DS.Haptic.light()
            action()
        } label: {
            Image(systemName: "chevron.right")
                .font(DS.Typography.label)
                .fontWeight(.semibold)
                .foregroundStyle(Color.primary)
                .frame(width: DS.Panel.headerAccessorySize, height: DS.Panel.headerAccessorySize)
                .glassEffect(.regular.interactive(), in: Circle())
        }
        .accessibilityLabel(seeMoreAccessibilityLabel ?? "")
        .accessibilityHint(seeMoreAccessibilityHint ?? "")
    }

    private func preferencesButton(action: @escaping () -> Void) -> some View {
        Button {
            DS.Haptic.light()
            action()
        } label: {
            Image(systemName: "square.grid.2x2")
                .font(DS.Typography.label)
                .fontWeight(.medium)
                .foregroundStyle(Color.primary)
                .frame(width: DS.Panel.headerAccessorySize, height: DS.Panel.headerAccessorySize)
                .glassEffect(.regular.interactive(), in: Circle())
        }
        .accessibilityLabel(L10n.Accessibility.widgetPreferences)
    }
}

// MARK: - Footer-less convenience initializer

extension PanelSection where Footer == EmptyView {
    init(
        title: String,
        subtitle: String? = nil,
        onPreferences: (() -> Void)? = nil,
        onSeeMore: (() -> Void)? = nil,
        seeMoreAccessibilityLabel: String? = nil,
        seeMoreAccessibilityHint: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.onPreferences = onPreferences
        self.onSeeMore = onSeeMore
        self.seeMoreAccessibilityLabel = seeMoreAccessibilityLabel
        self.seeMoreAccessibilityHint = seeMoreAccessibilityHint
        self.content = content
        self.footer = { EmptyView() }
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
                onPreferences: nil,
                content: {
                    RoundedRectangle(cornerRadius: DS.Radius.md)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 80)
                },
                footer: {
                    Text("Footer CTA").foregroundStyle(.tint)
                }
            )
        }
        .padding()
    }
}
#endif
