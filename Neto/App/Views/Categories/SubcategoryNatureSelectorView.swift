//
//  SubcategoryNatureSelectorView.swift
//  Neto
//
//  Created by Neto Refactoring.
//

import SwiftUI

/// Naturaleza de subcategoría para FIN-45
enum SubcategoryNature: String, CaseIterable, Identifiable {
    case essential = "esencial"
    case priority = "prioritaria"
    case optional = "opcional"
    case unclassified = "sin_clasificacion"

    var id: String { rawValue }

    /// Nombre visible en la UI
    var displayName: String {
        switch self {
        case .essential: return "Esencial"
        case .priority: return "Prioritaria"
        case .optional: return "Opcional"
        case .unclassified: return "Sin clasificación"
        }
    }

    /// Descripción corta para ayudar al usuario
    var description: String {
        switch self {
        case .essential:
            return "Gastos imprescindibles, difíciles de recortar."
        case .priority:
            return "Importantes pero con algo de flexibilidad."
        case .optional:
            return "Gastos discrecionales o de ocio."
        case .unclassified:
            return "Sin etiqueta de naturaleza específica."
        }
    }
}

/// Acceso cómodo a la naturaleza desde el modelo SwiftData
extension Subcategory {
    var nature: SubcategoryNature {
        get {
            SubcategoryNature(rawValue: natureRawValue ?? "") ?? .unclassified
        }
        set {
            natureRawValue = newValue.rawValue
        }
    }
}

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
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                SheetTopButton(systemName: "chevron.left") {
                    dismiss()
                }
            }
        }
    }
}
