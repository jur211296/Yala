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
        List {
            ForEach(SubcategoryNature.allCases) { nature in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(nature.displayName)
                        Spacer()
                        if nature == selectedNature {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                    Text(nature.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedNature = nature
                    dismiss()
                }
            }
        }
        .navigationTitle("Naturaleza")
    }
}
