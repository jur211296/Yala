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

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView(ignoredEdges: [])

                ScrollView {
                    VStack(spacing: DS.Spacing.md) {
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

                // Checkmark
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(DS.Typography.headline)
                        .foregroundStyle(.thAccent)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.FormRow.paddingV)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .fill(isSelected ? need.color.opacity(0.1) : theme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .stroke(isSelected ? need.color.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
