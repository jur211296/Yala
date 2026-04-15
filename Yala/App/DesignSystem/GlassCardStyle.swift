//
//  GlassCardStyle.swift
//  Yala
//
//  iOS 26 Liquid Glass card modifier. Reemplaza .background(.thCard) + stroke + shadow
//  con .glassEffect(_:in:) nativo + borde sutil del tema activo.
//
//  Uso:
//      SomeView()
//          .glassCard()                         // regular, DS.Radius.xl, DS.Card.padding
//          .glassCard(.thin, radius: DS.Radius.md)
//          .glassCard(.ultraThin, padding: DS.Spacing.sm)
//
//  Variantes semánticas (la API nativa de iOS 26 `Glass` solo expone `.regular` y `.clear`
//  hoy; `.thin` se mapea a `.regular` para preservar la semántica del callsite):
//  - .regular:   widgets y cards principales
//  - .thin:      cards secundarias, sticky headers (semánticamente distinto del regular;
//                visualmente idéntico hasta que Apple expanda la API)
//  - .ultraThin: accents, nudge banners (mapeado a Glass.clear)
//
//  NO añade shadow (el glass tiene ambient shading propio).
//

import SwiftUI

// MARK: - Variant

/// Intensidad semántica del efecto glass aplicado por `.glassCard(...)`.
///
/// La API nativa de iOS 26 `Glass` actualmente solo expone `.regular` y `.clear`.
/// Este enum introduce un nivel intermedio semántico (`.thin`) para que los callsites
/// puedan expresar intención (sticky header vs card principal) y beneficiarse
/// automáticamente si Apple expande la API en el futuro.
enum GlassCardVariant {
    case regular
    case thin
    case ultraThin

    /// Mapea a la instancia nativa de `Glass` de iOS 26.
    var glass: Glass {
        self == .ultraThin ? .clear : .regular
    }
}

// MARK: - Modifier

struct GlassCardModifier: ViewModifier {
    @Environment(\.yalaTheme) private var theme

    let variant: GlassCardVariant
    let radius: CGFloat
    let padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .glassEffect(
                variant.glass,
                in: RoundedRectangle(cornerRadius: radius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(theme.cardBorder, lineWidth: 1)
            )
    }
}

// MARK: - Extension

extension View {
    /// iOS 26 Liquid Glass card. Reemplaza `.background(.thCard)` + stroke + shadow manual.
    ///
    /// Respeta el borde del tema activo (`theme.cardBorder`) para cohesión visual con
    /// cards no migradas todavía. No aplica shadow — el glass tiene ambient shading propio.
    ///
    /// - Parameters:
    ///   - variant: `.regular` (widgets principales), `.thin` (secundarios/sticky),
    ///              `.ultraThin` (accents/nudges). Default `.regular`.
    ///   - radius: Corner radius de la card. Default `DS.Radius.xl`.
    ///   - padding: Padding interno antes del glass. Default `DS.Card.padding`.
    func glassCard(
        _ variant: GlassCardVariant = .regular,
        radius: CGFloat = DS.Radius.xl,
        padding: CGFloat = DS.Card.padding
    ) -> some View {
        modifier(GlassCardModifier(variant: variant, radius: radius, padding: padding))
    }
}

// MARK: - Preview (4 temas × 3 variantes = 12 celdas)

#if DEBUG
#Preview("GlassCard — 4 temas × 3 variantes") {
    ScrollView {
        VStack(spacing: DS.Spacing.xl) {
            GlassCardPreviewRow(themeName: "Indigo",       theme: .indigo)
            GlassCardPreviewRow(themeName: "Rosa",         theme: .rosa)
            GlassCardPreviewRow(themeName: "Teal",         theme: .teal)
            GlassCardPreviewRow(themeName: "Liquid Glass", theme: .liquidGlass)
        }
        .padding(.vertical, DS.Spacing.lg)
    }
    .background(Color.black)
}

private struct GlassCardPreviewRow: View {
    let themeName: String
    let theme: YalaTheme

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(themeName)
                .font(DS.Typography.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, DS.Spacing.lg)

            VStack(spacing: DS.Spacing.md) {
                GlassCardPreviewSample(label: "Regular",    variant: .regular,   theme: theme)
                GlassCardPreviewSample(label: "Thin",       variant: .thin,      theme: theme)
                GlassCardPreviewSample(label: "Ultra Thin", variant: .ultraThin, theme: theme)
            }
            .padding(.horizontal, DS.Spacing.lg)
        }
        .padding(.vertical, DS.Spacing.md)
        .frame(maxWidth: .infinity)
        .background(theme.background)
        .environment(\.yalaTheme, theme)
    }
}

private struct GlassCardPreviewSample: View {
    let label: String
    let variant: GlassCardVariant
    let theme: YalaTheme

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(label)
                .font(DS.Typography.labelSmall)
                .foregroundStyle(theme.secondaryText)
            Text("Balance: $1,234.56")
                .font(DS.Typography.amount)
                .foregroundStyle(theme.primaryText)
            Text("Texto de ejemplo para verificar legibilidad del contenido.")
                .font(DS.Typography.caption)
                .foregroundStyle(theme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(variant, radius: DS.Radius.lg, padding: DS.Spacing.lg)
    }
}
#endif
