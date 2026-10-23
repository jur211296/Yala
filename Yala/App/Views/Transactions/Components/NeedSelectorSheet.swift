//
//  NeedSelectorSheet.swift
//  Yala
//
//  Sheet for selecting transaction nature
//

import SwiftUI

// MARK: - Nature Selector Sheet

struct NeedSelectorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.yalaTheme) private var theme
    @Binding var selectedNeed: SubcategoryNeed

    /// Desde el formulario de registro abre con `SelectorSheetSizing` (UX 2.2 · L2-22): material grueso a media altura, el
    /// mismo criterio que cuenta, categoría y etiquetas. `nil` = quien presenta pone los detents, como antes.
    var sizing: SelectorSheetSizing?
    @State private var selectedDetent: PresentationDetent = .medium
    @Environment(\.usesLargeSheets) private var usesLargeSheets
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var sheetBackground: YalaBackgroundVariant {
        guard let sizing else { return .partialSheet }
        return sizing.background(
            selectedDetent: selectedDetent,
            usesLargeSheets: usesLargeSheets,
            dynamicTypeSize: dynamicTypeSize
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    // El para qué (UX 2.2 · L2-9): la hoja no decía qué cambia al elegir.
                    Text(L10n.UXL2B.needPurpose)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, DS.Spacing.xs)
                        .accessibilityIdentifier("need_selector_purpose")

                    ForEach(SubcategoryNeed.allCases) { need in
                        NeedOptionRow(
                            need: need,
                            isSelected: selectedNeed == need
                        ) {
                            selectedNeed = need
                            dismiss()
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(L10n.Category.need)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }
            }
            .yalaScreenBackground(sheetBackground, ignoredEdges: [])
        }
        .modifier(OptionalSelectorSheetSizing(sizing: sizing, selectedDetent: $selectedDetent))
    }
}

/// `selectorSheetSizing` solo si hay `sizing`.
private struct OptionalSelectorSheetSizing: ViewModifier {
    let sizing: SelectorSheetSizing?
    @Binding var selectedDetent: PresentationDetent

    @ViewBuilder
    func body(content: Content) -> some View {
        if let sizing {
            content.selectorSheetSizing(sizing, selectedDetent: $selectedDetent)
        } else {
            content
        }
    }
}

// MARK: - Nature Option Row

private struct NeedOptionRow: View {
    @Environment(\.yalaTheme) private var theme
    let need: SubcategoryNeed
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DS.Spacing.md) {
                // Color indicator
                Circle()
                    .fill(need.color)
                    .frame(width: 12, height: 12)

                // Text content
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(need.displayName)
                        .font(DS.Typography.label)
                        .foregroundStyle(.primary)

                    Text(need.description)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                // Lo elegido, tintado y con ✓ relleno (UX 2.2 · L2-19), como la rejilla de categorías.
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(DS.Typography.headline)
                        .foregroundStyle(Color.selectedFill(need.color))
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.FormRow.paddingV)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .fill(isSelected ? need.color.opacity(0.22) : theme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .stroke(isSelected ? need.color.opacity(0.5) : Color.clear, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("need_selector_row_\(need.rawValue)")
    }
}
