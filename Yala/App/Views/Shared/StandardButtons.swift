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
    @Environment(\.yalaTheme) private var theme
    let action: () -> Void
    var isDisabled: Bool = false
    var disabledHint: String?
    /// Override del identifier de accesibilidad. Útil cuando dos save buttons
    /// coexisten en sheets anidados (evita queries ambiguas en XCUITest).
    var accessibilityID: String = "toolbar_save_button"
    /// Lo que dice VoiceOver. Por defecto «Guardar»; una hoja cuyos cambios ya se aplicaron al tocarlos y donde el ✓ solo
    /// cierra pasa «Listo» (`L10n.Action.done`), como «Configurar Panel».
    var accessibilityName: String? = nil

    var body: some View {
        Button(action: action) {
            Image(systemName: "checkmark")
                .font(DS.Typography.label.weight(.bold))
                // Sobre el relleno del tinte de la app (el acento): negro en Teal, Rosa y Minimalista (card lbcr).
                .foregroundStyle(theme.onAccent)
                .frame(width: 20, height: 20)
        }
        .disabled(isDisabled)
        .buttonStyle(.borderedProminent)

        .buttonBorderShape(.circle)
        .accessibilityLabel(accessibilityName ?? L10n.Action.save)
        .accessibilityIdentifier(accessibilityID)
        .accessibilityHint(isDisabled ? (disabledHint ?? "") : "")
    }
}

// MARK: - Primary Button

/// Botón primario de acción principal (full-width, Electric Indigo)
/// Uso: Confirmar acciones, submit forms, CTAs
struct YalaPrimaryButton: View {
    @Environment(\.yalaTheme) private var theme
    @Environment(\.isEnabled) private var isEnabledInContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let title: String
    let icon: String?
    let action: () -> Void
    var isDisabled: Bool = false
    var isLoading: Bool = false

    var disabledHint: String?
    /// El relleno activo, si no es el acento tal cual (el formulario de registro lo oscurece para que el blanco dé AA,
    /// UX 2.2 · L2-20). `nil` = `theme.accent`.
    var enabledFill: Color?
    /// En una `safeAreaBar`, iOS atenúa más el texto de un botón desactivado (gris 165 → 131 medido en Nuevo registro y el
    /// onboarding, barrido final 2.2). Con `true`, a tamaño normal el texto conserva el tono de fuera de la barra
    /// (decisión de Jürgen, 2026-11-05); con texto de accesibilidad se deja el del sistema.
    var keepsDisabledToneInBar: Bool

    init(
        _ title: String,
        icon: String? = nil,
        isDisabled: Bool = false,
        isLoading: Bool = false,
        disabledHint: String? = nil,
        enabledFill: Color? = nil,
        keepsDisabledToneInBar: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isDisabled = isDisabled
        self.isLoading = isLoading
        self.disabledHint = disabledHint
        self.enabledFill = enabledFill
        self.keepsDisabledToneInBar = keepsDisabledToneInBar
        self.action = action
    }

    /// Dentro de una `safeAreaBar` iOS atenúa más el texto de un botón desactivado, y ni el entorno ni la opacidad de la
    /// etiqueta lo evitan (medido el 2026-11-05: 164 fuera de la barra, 129 dentro, 101 marcando la etiqueta como
    /// habilitada). Lo que se pinta ENCIMA del botón no pasa por ese atenuado: con el tono forzado, el texto va ahí, al 50 %
    /// que le daba `.plain` fuera de la barra (164 = 72 + 183 × 0,50), y el botón sigue desactivado debajo.
    private var drawsDisabledToneOutside: Bool {
        keepsDisabledToneInBar && !dynamicTypeSize.isAccessibilitySize && (isDisabled || isLoading || !isEnabledInContext)
    }

    private var labelRow: some View {
        HStack(spacing: DS.Spacing.sm) {
            if isLoading {
                ProgressView()
                    .tint(primaryForeground)
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
        .foregroundStyle(primaryForeground)
    }

    var body: some View {
        Button(action: action) {
            labelRow
                .opacity(drawsDisabledToneOutside ? 0 : 1)
                .background(isDisabled ? DS.Semantic.disabledForeground : (enabledFill ?? theme.accent))
                .clipShape(Capsule())
        }
        .disabled(isDisabled || isLoading)
        .buttonStyle(.plain)
        .overlay {
            if drawsDisabledToneOutside {
                labelRow
                    .opacity(0.5)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityLabel(Text(title))
        .accessibilityIdentifier("primary_button")
        .accessibilityHint(isDisabled ? (disabledHint ?? "") : "")
    }

    /// El texto sobre el relleno: `onAccent` sobre el acento (negro en Teal, Rosa y Minimalista, card lbcr); sobre un
    /// relleno propio, el que contraste; apagado, blanco como siempre.
    private var primaryForeground: Color {
        isDisabled ? .white : theme.onFill(enabledFill ?? theme.accent)
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
        if isDisabled { return DS.Semantic.disabledForeground }
        if destructive { return DS.Semantic.errorForeground }
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

// MARK: - Floating Action Button (FAB)

/// Superficie circular compartida de los FAB. Bifurca por `theme.usesMaterial`:
/// - Temas de material (Liquid Glass / Translucent): `.glassEffect` interactivo
///   con tint translúcido — coherente con un lienzo donde todo es cristal.
/// - Temas opacos (light, dark, indigo, rosa, teal, minimalist): gradiente
///   ligero del color base. Un cristal lavado se perdía sobre fondos sólidos.
///
/// No aplica `.frame()`: cada callsite conserva el suyo (preserva el orden de
/// modifiers y evita un frame anidado). Aplica siempre `.contentShape(Circle())`
/// para que toda el área del círculo sea tappable.
struct FABSurfaceModifier: ViewModifier {
    @Environment(\.yalaTheme) private var theme
    /// Color base del FAB (accent del tema, naranja de IA, gris deshabilitado…).
    let base: Color
    /// Opacidad del tint en la rama glass (los "+" usan 0.6; IA 0.5; locked 0.4).
    var glassTintOpacity: Double = 0.6
    /// Override del gradiente sólido (ej. proBadge en el FAB de IA). Si es `nil`
    /// se deriva del `base` (base → base mezclado con negro).
    var solidGradient: [Color]? = nil

    func body(content: Content) -> some View {
        Group {
            if theme.usesMaterial {
                content.glassEffect(
                    .regular.interactive().tint(base.opacity(glassTintOpacity)),
                    in: Circle()
                )
            } else {
                content
                    .background(
                        LinearGradient(
                            colors: solidGradient ?? [base, base.mix(with: .black, by: 0.18)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .clipShape(Circle())
            }
        }
        .contentShape(Circle())
    }
}

extension View {
    /// Press feedback del FAB sin doblar animación: en temas de material el
    /// `.interactive()` del glass ya anima la presión, así que usa `.plain`; en
    /// temas opacos usa `BouncyButtonStyle` (que respeta Reduce Motion).
    @ViewBuilder
    func fabButtonStyle(usesMaterial: Bool) -> some View {
        if usesMaterial {
            buttonStyle(.plain)
        } else {
            buttonStyle(BouncyButtonStyle())
        }
    }
}

extension Color {
    /// Color del símbolo "+" del FAB. En material siempre blanco (sobre el tint
    /// translúcido). En sólido, contraste calculado sobre el `base` — necesario
    /// porque accents claros (teal, minimalist) lavarían un blanco fijo.
    static func fabPlusForeground(base: Color, usesMaterial: Bool, theme: YalaTheme) -> Color {
        usesMaterial ? .white : theme.onFill(base)
    }
}

/// FAB circular "+" estándar (crear gasto, presupuesto, grupo, pago). Encapsula
/// símbolo + superficie (glass/sólido) + press feedback + tap target. El caller
/// pone el posicionamiento (`VStack/HStack/Spacer/.padding`) y `.dsFloatingShadow()`.
struct CircularPlusFAB: View {
    @Environment(\.yalaTheme) private var theme

    var systemName: String = "plus"
    let tint: Color
    let accessibilityLabel: String
    var accessibilityIdentifier: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(DS.Typography.title)
                .foregroundStyle(Color.fabPlusForeground(base: tint, usesMaterial: theme.usesMaterial, theme: theme))
                .frame(width: DS.Button.fabSize, height: DS.Button.fabSize)
                .modifier(FABSurfaceModifier(base: tint))
        }
        .fabButtonStyle(usesMaterial: theme.usesMaterial)
        .accessibilityLabel(accessibilityLabel)
        .modifier(OptionalAccessibilityIdentifier(identifier: accessibilityIdentifier))
    }
}

/// Aplica `accessibilityIdentifier` solo cuando está presente (algunos FAB no lo tienen).
private struct OptionalAccessibilityIdentifier: ViewModifier {
    let identifier: String?
    func body(content: Content) -> some View {
        if let identifier {
            content.accessibilityIdentifier(identifier)
        } else {
            content
        }
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
