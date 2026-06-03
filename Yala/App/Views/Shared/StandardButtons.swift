import SwiftUI

// MARK: - Bouncy Button Style

/// Button style with scale-down animation on press (bouncy effect)
struct BouncyButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .dsAnimation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed, reduceMotion: reduceMotion)
    }
}

// MARK: - Toolbar Button

/// Botón circular estándar para acciones de navegación (Atrás, Cerrar, Más, etc.)
/// Diseño: Icono nativo (Circle, Chevron, XMark) sin fondo adicional.
struct YalaToolbarButton: View {
    let systemName: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .fontWeight(.medium)
                .foregroundStyle(Color.primary)
        }
        .accessibilityLabel(label)
        .buttonBorderShape(.circle)
    }
}

/// Botón circular de confirmación (Check)
/// Diseño: SF Symbol `checkmark.circle.fill` con rendering palette (Blanco + Electric Indigo).
struct YalaSaveButton: View {
    let action: () -> Void
    var isDisabled: Bool = false
    var disabledHint: String?
    /// Override del identifier de accesibilidad. Útil cuando dos save buttons
    /// coexisten en sheets anidados (evita queries ambiguas en XCUITest).
    var accessibilityID: String = "toolbar_save_button"

    var body: some View {
        Button(action: action) {
            Image(systemName: "checkmark")
                .font(DS.Typography.label.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
        }
        .disabled(isDisabled)
        .buttonStyle(.borderedProminent)

        .buttonBorderShape(.circle)
        .accessibilityLabel(L10n.Action.save)
        .accessibilityIdentifier(accessibilityID)
        .accessibilityHint(isDisabled ? (disabledHint ?? "") : "")
    }
}

// MARK: - Primary Button

/// Botón primario de acción principal (full-width, Electric Indigo)
/// Uso: Confirmar acciones, submit forms, CTAs
struct YalaPrimaryButton: View {
    @Environment(\.yalaTheme) private var theme
    let title: String
    let icon: String?
    let action: () -> Void
    var isDisabled: Bool = false
    var isLoading: Bool = false

    var disabledHint: String?

    init(_ title: String, icon: String? = nil, isDisabled: Bool = false, isLoading: Bool = false, disabledHint: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.isDisabled = isDisabled
        self.isLoading = isLoading
        self.disabledHint = disabledHint
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
                        .font(DS.Typography.label)
                        .accessibilityHidden(true)
                }
                Text(title)
                    .font(DS.Typography.label)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .foregroundStyle(.white)
            .background(isDisabled ? DS.Semantic.disabledForeground : theme.accent)
            .clipShape(Capsule())
        }
        .disabled(isDisabled || isLoading)
        .buttonStyle(.plain)
        .accessibilityIdentifier("primary_button")
        .accessibilityHint(isDisabled ? (disabledHint ?? "") : "")
    }
}

// MARK: - Secondary Button

/// Botón secundario (outline, sin fondo)
/// Uso: Acciones secundarias, cancelar, alternativas
struct YalaSecondaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    var isDisabled: Bool = false
    var destructive: Bool = false

    var disabledHint: String?

    init(_ title: String, icon: String? = nil, isDisabled: Bool = false, destructive: Bool = false, disabledHint: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.isDisabled = isDisabled
        self.destructive = destructive
        self.disabledHint = disabledHint
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
                        .font(DS.Typography.labelSmall)
                        .accessibilityHidden(true)
                }
                Text(title)
                    .font(DS.Typography.label)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .foregroundStyle(foregroundColor)
            .background(Color.clear)
            .overlay(
                Capsule()
                    .stroke(foregroundColor.opacity(0.3), lineWidth: 1)
            )
        }
        .disabled(isDisabled)
        .accessibilityHint(isDisabled ? (disabledHint ?? "") : "")
    }
}

#Preview("Buttons") {
    VStack(spacing: DS.Spacing.xl) {
        // Toolbar buttons
        HStack(spacing: DS.Spacing.xl) {
            YalaToolbarButton(systemName: "chevron.left", label: "Atrás") {}
            YalaToolbarButton(systemName: "xmark", label: "Cerrar") {}
            YalaToolbarButton(systemName: "plus", label: "Agregar") {}
            YalaSaveButton(action: {})
            YalaSaveButton(action: {}, isDisabled: true)
        }

        Divider()

        // Primary buttons
        VStack(spacing: DS.Spacing.md) {
            YalaPrimaryButton("Guardar", icon: "checkmark") {}
            YalaPrimaryButton("Cargando...", isLoading: true) {}
            YalaPrimaryButton("Deshabilitado", isDisabled: true) {}
        }
        .padding(.horizontal)

        Divider()

        // Secondary buttons
        VStack(spacing: DS.Spacing.md) {
            YalaSecondaryButton("Cancelar") {}
            YalaSecondaryButton("Eliminar", icon: "trash", destructive: true) {}
        }
        .padding(.horizontal)

    }
    .padding()
    .background(.thBackground)
}
