//
//  NatureSelectorSheet.swift
//  Yala
//
//  Sheet for selecting transaction nature
//

import SwiftUI

// MARK: - Nature Selector Sheet

struct NatureSelectorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.yalaTheme) private var theme
    @Binding var selectedNature: SubcategoryNature

    var body: some View {
        NavigationStack {
            ZStack {
                theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: DS.Spacing.md) {
                        ForEach(SubcategoryNature.allCases) { nature in
                            NatureOptionRow(
                                nature: nature,
                                isSelected: selectedNature == nature
                            ) {
                                selectedNature = nature
                                dismiss()
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(L10n.Category.nature)
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

private struct NatureOptionRow: View {
    @Environment(\.yalaTheme) private var theme
    let nature: SubcategoryNature
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DS.Spacing.md) {
                // Color indicator
                Circle()
                    .fill(nature.color)
                    .frame(width: 12, height: 12)

                // Text content
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(nature.displayName)
                        .font(DS.Typography.label)
                        .foregroundStyle(.primary)

                    Text(nature.description)
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
                    .fill(isSelected ? nature.color.opacity(0.1) : theme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .stroke(isSelected ? nature.color.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
