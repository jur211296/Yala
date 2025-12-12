//
//  SheetTopButton.swift
//  Neto
//
//  Created by Neto Refactoring.
//

import SwiftUI

/// Botón circular estándar para las barras de navegación en Sheets.
/// Se usa para acciones como "Cerrar" (xmark), "Atrás" (chevron.left) o "Añadir" (plus).
/// Fuerza el color del icono a .primary (Dark/Light) y evita el tinte morado (Accent).
struct SheetTopButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))  // Standard size/weight
                .foregroundStyle(Color.primary)  // Keep dark/light adaptation, avoid purple tint
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())  // Ensure hit area
        }
        // Using standard button style allows the system to apply correct toolbar appearance
        // (e.g. gray circle if needed, or transparent if in standard bar)
    }
}

// Primitive style allows us to completely take over touch handling
// and bypasses standardized toolbar button rendering

#Preview {
    ZStack {
        Color.gray.opacity(0.1)
        HStack {
            SheetTopButton(systemName: "xmark") {}
            SheetTopButton(systemName: "chevron.left") {}
            SheetTopButton(systemName: "plus") {}
        }
        .padding()
    }
}
