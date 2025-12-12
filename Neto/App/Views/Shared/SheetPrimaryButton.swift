//
//  SheetPrimaryButton.swift
//  Neto
//
//  Created by Neto Refactoring.
//

import SwiftUI

/// Botón de acción principal para barras de navegación en Sheets.
/// Se usa para acciones de confirmación como "Guardar" o "Hecho".
/// Mantiene un estilo consistente: Fondo Electric Indigo y Texto Blanco.
struct SheetPrimaryButton: View {
    let title: String
    let action: () -> Void
    var isDisabled: Bool = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .fontWeight(.semibold)
                .foregroundStyle(.white)  // Explicitly force white text
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.brandPrimary)
        .disabled(isDisabled)
    }
}

#Preview {
    HStack {
        SheetPrimaryButton(title: "Guardar", action: {})
        SheetPrimaryButton(title: "Hecho", action: {})
        SheetPrimaryButton(title: "Guardar", action: {}, isDisabled: true)
    }
    .padding()
}
