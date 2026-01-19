//
//  ViewModifiers.swift
//  Neto
//
//  Reusable view modifiers for consistent styling across the app.
//  Usage: .netoCard(), .netoFormRow(), .netoSection()
//

import SwiftUI

// MARK: - Card Modifier

/// Aplica estilo de card estándar: background, radius, shadow, border
struct NetoCardModifier: ViewModifier {
    let padding: CGFloat
    let radius: CGFloat
    let hasShadow: Bool

    init(
        padding: CGFloat = DS.Card.padding,
        radius: CGFloat = DS.Card.radius,
        hasShadow: Bool = true
    ) {
        self.padding = padding
        self.radius = radius
        self.hasShadow = hasShadow
    }

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color.netoCard)
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(Color.primary.opacity(DS.Opacity.faint), lineWidth: 1)
            )
            .modifier(ConditionalShadow(hasShadow: hasShadow))
    }
}

private struct ConditionalShadow: ViewModifier {
    let hasShadow: Bool

    func body(content: Content) -> some View {
        if hasShadow {
            content.dsCardShadow()
        } else {
            content
        }
    }
}

extension View {
    /// Aplica estilo de card estándar (widget, panel card)
    func netoCard(
        padding: CGFloat = DS.Card.padding,
        radius: CGFloat = DS.Card.radius,
        shadow: Bool = true
    ) -> some View {
        modifier(NetoCardModifier(padding: padding, radius: radius, hasShadow: shadow))
    }

    /// Aplica estilo de card compacto
    func netoCardCompact(shadow: Bool = true) -> some View {
        modifier(NetoCardModifier(
            padding: DS.Card.paddingCompact,
            radius: DS.Card.radius,
            hasShadow: shadow
        ))
    }

    /// Aplica estilo de list row (RecordRowView style)
    func netoListRow(shadow: Bool = true) -> some View {
        modifier(NetoCardModifier(
            padding: 0,
            radius: DS.ListRow.radius,
            hasShadow: shadow
        ))
        .padding(.vertical, DS.ListRow.paddingV)
        .padding(.horizontal, DS.ListRow.paddingH)
    }
}

// MARK: - Form Row Modifier

/// Aplica estilo de fila de formulario: padding, background, contenido alineado
struct NetoFormRowModifier: ViewModifier {
    let showChevron: Bool
    let hasBackground: Bool

    func body(content: Content) -> some View {
        HStack(spacing: DS.FormRow.iconSpacing) {
            content

            if showChevron {
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: DS.FormRow.chevronSize, weight: .semibold))
                    .foregroundStyle(Color.secondary.opacity(0.5))
            }
        }
        .padding(.horizontal, DS.FormRow.paddingH)
        .padding(.vertical, DS.FormRow.paddingV)
        .frame(minHeight: DS.FormRow.minHeight)
        .background(hasBackground ? Color.netoCard : Color.clear)
    }
}

extension View {
    /// Aplica estilo de fila de formulario
    func netoFormRow(showChevron: Bool = false, hasBackground: Bool = true) -> some View {
        modifier(NetoFormRowModifier(showChevron: showChevron, hasBackground: hasBackground))
    }
}

// MARK: - Section Modifier

/// Aplica estilo de sección con spacing y header opcional
struct NetoSectionModifier: ViewModifier {
    let spacing: CGFloat

    func body(content: Content) -> some View {
        VStack(alignment: .leading, spacing: spacing) {
            content
        }
    }
}

extension View {
    /// Agrupa contenido en una sección con spacing estándar
    func netoSection(spacing: CGFloat = DS.Spacing.md) -> some View {
        modifier(NetoSectionModifier(spacing: spacing))
    }
}

// MARK: - Icon Badge Modifier

/// Aplica estilo de badge con icono (para categorías, subcategorías, etc.)
struct NetoIconBadgeModifier: ViewModifier {
    let size: CGFloat
    let iconSize: CGFloat
    let backgroundColor: Color
    let foregroundColor: Color

    func body(content: Content) -> some View {
        content
            .font(.system(size: iconSize, weight: .medium))
            .foregroundStyle(foregroundColor)
            .frame(width: size, height: size)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.25))
    }
}

extension View {
    /// Aplica estilo de badge pequeño (24pt)
    func netoIconBadgeSmall(background: Color, foreground: Color = .white) -> some View {
        modifier(NetoIconBadgeModifier(
            size: DS.Icon.badgeSmall,
            iconSize: DS.Icon.sizeSmall,
            backgroundColor: background,
            foregroundColor: foreground
        ))
    }

    /// Aplica estilo de badge mediano (32pt)
    func netoIconBadgeMedium(background: Color, foreground: Color = .white) -> some View {
        modifier(NetoIconBadgeModifier(
            size: DS.Icon.badgeMedium,
            iconSize: DS.Icon.sizeMedium,
            backgroundColor: background,
            foregroundColor: foreground
        ))
    }

    /// Aplica estilo de badge grande (40pt)
    func netoIconBadgeLarge(background: Color, foreground: Color = .white) -> some View {
        modifier(NetoIconBadgeModifier(
            size: DS.Icon.badgeLarge,
            iconSize: DS.Icon.sizeLarge,
            backgroundColor: background,
            foregroundColor: foreground
        ))
    }
}

// MARK: - Safe Area Bottom Padding

extension View {
    /// Añade padding inferior seguro para scroll views
    func netoSafeBottomPadding() -> some View {
        self.padding(.bottom, DS.Spacing.safeBottom)
    }
}

// MARK: - Skeleton Placeholder

/// Modifier para mostrar placeholder skeleton mientras carga
struct NetoSkeletonModifier: ViewModifier {
    let isLoading: Bool

    func body(content: Content) -> some View {
        if isLoading {
            content
                .redacted(reason: .placeholder)
                .shimmer()
        } else {
            content
        }
    }
}

extension View {
    /// Muestra skeleton loading mientras isLoading es true
    func netoSkeleton(_ isLoading: Bool) -> some View {
        modifier(NetoSkeletonModifier(isLoading: isLoading))
    }
}

// MARK: - Dismiss Keyboard on Tap

/// Global function to dismiss keyboard from anywhere
func dismissKeyboard() {
    UIApplication.shared.sendAction(
        #selector(UIResponder.resignFirstResponder),
        to: nil,
        from: nil,
        for: nil
    )
}

/// Modifier that dismisses keyboard when tapping outside text fields
struct DismissKeyboardOnTapModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onTapGesture {
                dismissKeyboard()
            }
    }
}

extension View {
    /// Dismisses keyboard when tapping anywhere on this view
    func dismissKeyboardOnTap() -> some View {
        modifier(DismissKeyboardOnTapModifier())
    }

    /// Hides the keyboard programmatically
    func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

// MARK: - Previews

#Preview("Card Modifiers") {
    ScrollView {
        VStack(spacing: 20) {
            // Standard card
            Text("Card estándar")
                .frame(maxWidth: .infinity)
                .netoCard()

            // Compact card
            Text("Card compacto")
                .frame(maxWidth: .infinity)
                .netoCardCompact()

            // List row style
            HStack {
                Image(systemName: "cart.fill")
                    .netoIconBadgeMedium(background: .blue)
                VStack(alignment: .leading) {
                    Text("Supermercado")
                    Text("Alimentación")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("-S/ 150.00")
                    .foregroundStyle(.red)
            }
            .netoListRow()

            // No shadow
            Text("Sin sombra")
                .frame(maxWidth: .infinity)
                .netoCard(shadow: false)
        }
        .padding()
    }
    .background(Color.netoBackground)
}

#Preview("Form Row Modifiers") {
    VStack(spacing: 1) {
        HStack {
            Image(systemName: "creditcard")
                .frame(width: DS.FormRow.iconWidth)
            Text("Cuenta")
            Spacer()
            Text("Banco Principal")
                .foregroundStyle(.secondary)
        }
        .netoFormRow(showChevron: true)

        HStack {
            Image(systemName: "calendar")
                .frame(width: DS.FormRow.iconWidth)
            Text("Fecha")
            Spacer()
            Text("15 Ene 2026")
                .foregroundStyle(.secondary)
        }
        .netoFormRow(showChevron: true)

        HStack {
            Image(systemName: "tag")
                .frame(width: DS.FormRow.iconWidth)
            Text("Etiquetas")
            Spacer()
        }
        .netoFormRow(showChevron: true)
    }
    .background(Color.netoBackground)
}

#Preview("Icon Badges") {
    HStack(spacing: 20) {
        Image(systemName: "cart.fill")
            .netoIconBadgeSmall(background: .blue)

        Image(systemName: "fork.knife")
            .netoIconBadgeMedium(background: .orange)

        Image(systemName: "car.fill")
            .netoIconBadgeLarge(background: .green)
    }
    .padding()
    .background(Color.netoBackground)
}
