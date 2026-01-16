//
//  NatureSelectorSheet.swift
//  Neto
//
//  Sheet for selecting transaction nature
//

import SwiftUI

// MARK: - Nature Selector Sheet

struct NatureSelectorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedNature: SubcategoryNature

    var body: some View {
        NavigationStack {
            ZStack {
                Color.netoBackground.ignoresSafeArea()

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
                    NetoToolbarButton(systemName: "xmark") {
                        dismiss()
                    }
                }
            }
        }
        .tint(Color.electricIndigo)
    }
}

// MARK: - Nature Option Row

private struct NatureOptionRow: View {
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
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)

                    Text(nature.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                // Checkmark
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.electricIndigo)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .fill(isSelected ? nature.color.opacity(0.1) : Color.netoCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .stroke(isSelected ? nature.color.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
