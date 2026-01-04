import SwiftUI

/// Botón circular estándar para acciones de navegación (Atrás, Cerrar, Más, etc.)
/// Diseño: Icono nativo (Circle, Chevron, XMark) sin fondo adicional.
struct NetoToolbarButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))  // Standard size
                .foregroundStyle(Color.primary)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())  // Ensure touch area captures taps
        }
    }
}

/// Botón circular de confirmación (Check)
/// Diseño: SF Symbol `checkmark.circle.fill` con rendering palette (Blanco + Electric Indigo).
struct NetoSaveButton: View {
    let action: () -> Void
    var isDisabled: Bool = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "checkmark")
                .font(.system(size: 17, weight: .bold))  // Bolder checkmark for better visibility
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)  // Smaller frame inside prominent button to prevent huge pill
        }
        .disabled(isDisabled)
        .buttonStyle(.borderedProminent)
        .tint(Color.electricIndigo)
        .buttonBorderShape(.circle)  // Explicitly request circle shape
    }
}

#Preview {
    ZStack {
        Color.netoBackground
        HStack(spacing: 20) {
            NetoToolbarButton(systemName: "chevron.left") {}
            NetoToolbarButton(systemName: "xmark") {}
            NetoToolbarButton(systemName: "plus") {}
            NetoSaveButton(action: {})
            NetoSaveButton(action: {}, isDisabled: true)
        }
    }
}
