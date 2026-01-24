//
//  SubcategoryNatureSelectorView.swift
//  Yala
//
//  Created by Yala Refactoring.
//

import SwiftUI

/// Selector de naturaleza de subcategoría (Esencial, Prioritaria, Opcional, Sin clasificación)
struct SubcategoryNatureSelectorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedNature: SubcategoryNature

    var body: some View {
        ZStack {
            PanelBackgroundView()

            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    SectionBox(title: "") {
                        VStack(spacing: 0) {
                            ForEach(Array(SubcategoryNature.allCases.enumerated()), id: \.element) {
                                index, nature in
                                if index > 0 {
                                    SubsectionDivider()
                                }

                                Button {
                                    selectedNature = nature
                                    dismiss()
                                } label: {
                                    HStack(spacing: DS.Spacing.md) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(nature.displayName)
                                                .font(.body)
                                                .foregroundStyle(.primary)
                                            Text(nature.description)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        if nature == selectedNature {
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(Color.electricIndigo)
                                                .font(.body.weight(.semibold))
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xxl)
            }
        }
        .navigationTitle(L10n.Nature.title)
        .navigationBarTitleDisplayMode(.inline)
        .swipeBack()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                YalaToolbarButton(systemName: "chevron.left") {
                    dismiss()
                }
            }
        }
    }
}
