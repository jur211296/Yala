//
//  SubcategoryNatureSelectorView.swift
//  Neto
//
//  Created by Neto Refactoring.
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
                VStack(spacing: 24) {
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
                                    HStack(spacing: 12) {
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
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 24)
            }
        }
        .navigationTitle("Naturaleza")
        .navigationBarTitleDisplayMode(.inline)
        .swipeBack()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NetoToolbarButton(systemName: "chevron.left") {
                    dismiss()
                }
            }
        }
    }
}
