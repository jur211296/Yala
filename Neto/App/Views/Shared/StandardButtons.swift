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

// MARK: - Primary Button

/// Botón primario de acción principal (full-width, Electric Indigo)
/// Uso: Confirmar acciones, submit forms, CTAs
struct NetoPrimaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    var isDisabled: Bool = false
    var isLoading: Bool = false

    init(_ title: String, icon: String? = nil, isDisabled: Bool = false, isLoading: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.isDisabled = isDisabled
        self.isLoading = isLoading
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(title)
                    .font(DS.Typography.label)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .foregroundStyle(.white)
            .background(isDisabled ? Color.gray : Color.electricIndigo)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        }
        .disabled(isDisabled || isLoading)
    }
}

// MARK: - Secondary Button

/// Botón secundario (outline, sin fondo)
/// Uso: Acciones secundarias, cancelar, alternativas
struct NetoSecondaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    var isDisabled: Bool = false
    var destructive: Bool = false

    init(_ title: String, icon: String? = nil, isDisabled: Bool = false, destructive: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.isDisabled = isDisabled
        self.destructive = destructive
        self.action = action
    }

    private var foregroundColor: Color {
        if isDisabled { return .gray }
        if destructive { return .red }
        return .primary
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.sm) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                }
                Text(title)
                    .font(DS.Typography.label)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .foregroundStyle(foregroundColor)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .stroke(foregroundColor.opacity(0.3), lineWidth: 1)
            )
        }
        .disabled(isDisabled)
    }
}

// MARK: - Text Button

/// Botón de texto simple (sin fondo ni borde)
/// Uso: Links, acciones terciarias, "Ver más"
struct NetoTextButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    var destructive: Bool = false

    init(_ title: String, icon: String? = nil, destructive: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.destructive = destructive
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.xs) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                }
                Text(title)
                    .font(DS.Typography.label)
            }
            .foregroundStyle(destructive ? .red : Color.electricIndigo)
        }
    }
}

#Preview("Buttons") {
    VStack(spacing: DS.Spacing.xl) {
        // Toolbar buttons
        HStack(spacing: DS.Spacing.xl) {
            NetoToolbarButton(systemName: "chevron.left") {}
            NetoToolbarButton(systemName: "xmark") {}
            NetoToolbarButton(systemName: "plus") {}
            NetoSaveButton(action: {})
            NetoSaveButton(action: {}, isDisabled: true)
        }

        Divider()

        // Primary buttons
        VStack(spacing: DS.Spacing.md) {
            NetoPrimaryButton("Guardar", icon: "checkmark") {}
            NetoPrimaryButton("Cargando...", isLoading: true) {}
            NetoPrimaryButton("Deshabilitado", isDisabled: true) {}
        }
        .padding(.horizontal)

        Divider()

        // Secondary buttons
        VStack(spacing: DS.Spacing.md) {
            NetoSecondaryButton("Cancelar") {}
            NetoSecondaryButton("Eliminar", icon: "trash", destructive: true) {}
        }
        .padding(.horizontal)

        Divider()

        // Text buttons
        HStack(spacing: DS.Spacing.xl) {
            NetoTextButton("Ver más", icon: "chevron.right") {}
            NetoTextButton("Eliminar", destructive: true) {}
        }
    }
    .padding()
    .background(Color.netoBackground)
}
