//
//  YalaTheme.swift
//  Yala
//
//  Theme palette definitions and environment integration.
//  Each theme is a static instance with all colors needed by the app.
//

import SwiftUI

// MARK: - YalaTheme

struct YalaTheme: Equatable, Sendable {
    let background: Color
    let card: Color
    let cardBorder: Color
    let primaryText: Color
    let secondaryText: Color
    let accent: Color
    /// El color del tema como TEXTO o icono sobre el fondo y las tarjetas del tema (enlaces, «Ver todo», chips
    /// seleccionados, cifras en el color de la app). En los temas oscuros es más claro que `accent`: un mismo color no
    /// puede dar AA al blanco encima del botón y al texto encima del fondo oscuro (card 1c9w). ≥ 4,5:1 en todas las
    /// superficies del tema. En el Claro es el índigo de marca un 5 % más oscuro (#5B5EE4: 4,59 sobre el fondo gris, 5,1 sobre
    /// blanco; 19-nov-2026). Lo fijan `ThemeTokenContrastTests` y `ContrasteModoClaroTests`.
    let accentText: Color
    /// El TEXTO (o icono) encima de un relleno de `accent`: blanco en los temas índigo, negro donde el acento es claro
    /// (Rosa, Teal, Minimalista), para llegar a AA en los ocho temas (card lbcr). Lo fija `ThemeTokenContrastTests`.
    let onAccent: Color
    let accentSecondary: Color
    let income: Color
    let expense: Color
    let tagChip: Color
    let transfer: Color
    let toolbarIcon: Color
    let destructive: Color
    let priorityNeed: Color
    let essentialNeed: Color
    let optionalNeed: Color
    let shadowOpacity: Double
    let hasGradient: Bool
    let baseColorScheme: ColorScheme
    let mapsColorsToGrayscale: Bool
    let usesMaterial: Bool
    /// El contorno de las superficies (`.thCard`: tarjetas, chips, campos y botones blancos) sobre el fondo. Solo en el
    /// tema claro, donde el blanco sobre un fondo casi blanco no dejaba ver qué era un botón (Jürgen, 19-nov-2026). En los
    /// temas oscuros es `nil`: ahí la tarjeta ya se separa del fondo por luminancia. Lo fija `ContrasteModoClaroTests`.
    let surfaceEdge: SurfaceEdge?

    init(
        background: Color,
        card: Color,
        cardBorder: Color,
        primaryText: Color,
        secondaryText: Color,
        accent: Color,
        accentText: Color,
        onAccent: Color,
        accentSecondary: Color,
        income: Color,
        expense: Color,
        tagChip: Color,
        transfer: Color,
        toolbarIcon: Color,
        destructive: Color,
        priorityNeed: Color,
        essentialNeed: Color,
        optionalNeed: Color,
        shadowOpacity: Double,
        hasGradient: Bool,
        baseColorScheme: ColorScheme,
        mapsColorsToGrayscale: Bool = false,
        usesMaterial: Bool = false,
        surfaceEdge: SurfaceEdge? = nil
    ) {
        self.background = background
        self.card = card
        self.cardBorder = cardBorder
        self.primaryText = primaryText
        self.secondaryText = secondaryText
        self.accent = accent
        self.accentText = accentText
        self.onAccent = onAccent
        self.accentSecondary = accentSecondary
        self.income = income
        self.expense = expense
        self.tagChip = tagChip
        self.transfer = transfer
        self.toolbarIcon = toolbarIcon
        self.destructive = destructive
        self.priorityNeed = priorityNeed
        self.essentialNeed = essentialNeed
        self.optionalNeed = optionalNeed
        self.shadowOpacity = shadowOpacity
        self.hasGradient = hasGradient
        self.baseColorScheme = baseColorScheme
        self.mapsColorsToGrayscale = mapsColorsToGrayscale
        self.usesMaterial = usesMaterial
        self.surfaceEdge = surfaceEdge
    }
}

// MARK: - Contorno de las superficies

/// Cómo se despega una superficie blanca del fondo claro: una sombra de medio punto sin desplazamiento, que se lee como
/// un borde finísimo alrededor, y una sombra suave debajo (molde de la referencia «Send money» que eligió Jürgen). Va
/// dentro del propio relleno (`ThemeSurface`), así que todo lo que se pinta con `.thCard` lo hereda sin tocar la vista.
struct SurfaceEdge: Equatable, Sendable {
    /// La línea del contorno.
    let line: Color
    let lineRadius: CGFloat
    /// La sombra suave, la que da volumen. Con opacidad 0 no se pinta.
    let soft: Color
    let softRadius: CGFloat
    let softY: CGFloat
}

// MARK: - Free Themes

extension YalaTheme {

    /// Un color que se marca más con «Aumentar contraste» del sistema.
    private static func contrastAware(_ normal: UIColor, increased: UIColor) -> Color {
        Color(uiColor: UIColor { $0.accessibilityContrast == .high ? increased : normal })
    }

    static let light = YalaTheme(
        // Gris claro neutro (Jürgen, 19-nov-2026): con el #FAFBFF de antes los campos y botones blancos se fundían con el
        // fondo (1,03:1). Elegido entre cuatro variantes en el simulador, cerca del gris de su referencia. Con «Aumentar
        // contraste», un punto más oscuro.
        background: contrastAware(UIColor(Color(hex: "F4F4F6")), increased: UIColor(Color(hex: "EAEAEE"))),
        card: .white,
        cardBorder: contrastAware(
            UIColor.black.withAlphaComponent(0.08), increased: UIColor.black.withAlphaComponent(0.22)
        ),
        primaryText: Color.primary,
        secondaryText: Color.secondary,
        accent: .electricIndigo,
        // El índigo de marca como TEXTO bajaba a 4,20:1 sobre el gris; un 5 % más oscuro vuelve a AA (4,59). Con «Aumentar
        // contraste» el fondo baja a #EAEAEE y ese tono volvía a 4,20: ahí, un punto más (#5053D9: 4,89; 5,87 sobre blanco).
        accentText: contrastAware(UIColor(Color(hex: "5B5EE4")), increased: UIColor(Color(hex: "5053D9"))),
        onAccent: .white,
        accentSecondary: .hotPink,
        income: .priorityNeed,
        expense: .hotPink,
        tagChip: Color(hex: "0891B2"),
        transfer: Color(.label),
        toolbarIcon: .electricIndigo,
        destructive: .red,
        priorityNeed: .priorityNeed,
        essentialNeed: .essentialNeed,
        optionalNeed: .optionalNeed,
        shadowOpacity: 0.05,
        hasGradient: true,
        baseColorScheme: .light,
        // Borde finísimo + sombra suave en todo lo que se rellena con `.thCard` (chips, campos, botones blancos).
        surfaceEdge: SurfaceEdge(
            line: contrastAware(
                UIColor.black.withAlphaComponent(0.16), increased: UIColor.black.withAlphaComponent(0.4)
            ),
            lineRadius: 0.5,
            soft: contrastAware(
                UIColor.black.withAlphaComponent(0.06), increased: UIColor.black.withAlphaComponent(0.08)
            ),
            softRadius: 6,
            softY: 2
        )
    )

    static let dark = YalaTheme(
        background: Color(hex: "000000"),  // OLED black
        card: Color(red: 0.11, green: 0.11, blue: 0.12),  // #1C1C1E
        cardBorder: Color.white.opacity(0.08),
        primaryText: Color.primary,
        secondaryText: Color.secondary,
        accent: .electricIndigo,
        accentText: .indigoTextOnDark,
        onAccent: .white,
        accentSecondary: .hotPink,
        income: .priorityNeed,
        expense: .hotPink,
        tagChip: .neonCyan,
        transfer: Color(hex: "64748B"),
        toolbarIcon: .electricIndigo,
        destructive: .red,
        priorityNeed: .priorityNeed,
        essentialNeed: .essentialNeed,
        optionalNeed: .optionalNeed,
        shadowOpacity: 0.25,
        hasGradient: false,
        baseColorScheme: .dark
    )
}

// MARK: - PRO Themes

extension YalaTheme {

    static let indigo = YalaTheme(
        background: Color(hex: "0F172A"),
        card: Color(hex: "1E293B"),
        cardBorder: Color.electricIndigo.opacity(0.15),
        primaryText: .white,
        secondaryText: Color(hex: "94A3B8"),  // slate 60%
        accent: .electricIndigo,
        accentText: .indigoTextOnDark,
        onAccent: .white,
        accentSecondary: .hotPink,
        income: .priorityNeed,
        expense: .hotPink,
        tagChip: .neonCyan,
        transfer: Color(hex: "64748B"),
        toolbarIcon: .electricIndigo,
        destructive: .red,
        priorityNeed: .priorityNeed,
        essentialNeed: .essentialNeed,
        optionalNeed: .optionalNeed,
        shadowOpacity: 0.20,
        hasGradient: false,
        baseColorScheme: .dark
    )

    static let rosa = YalaTheme(
        background: Color(hex: "1F0A18"),
        card: Color(hex: "301228"),
        cardBorder: Color.hotPink.opacity(0.15),
        primaryText: .white,
        secondaryText: Color(hex: "C9849E"),  // rose 60%
        accent: .hotPink,
        accentText: .pinkTextOnDark,
        onAccent: .black,
        accentSecondary: .electricIndigo,
        income: .priorityNeed,
        expense: .hotPink,
        tagChip: .neonCyan,
        transfer: Color(hex: "64748B"),
        toolbarIcon: .hotPink,
        destructive: .red,
        priorityNeed: .priorityNeed,
        essentialNeed: .essentialNeed,
        optionalNeed: .optionalNeed,
        shadowOpacity: 0.20,
        hasGradient: false,
        baseColorScheme: .dark
    )

    static let teal = YalaTheme(
        background: Color(hex: "0A1A1A"),
        card: Color(hex: "0F2828"),
        cardBorder: Color.priorityNeed.opacity(0.15),
        primaryText: .white,
        secondaryText: Color(hex: "7BBFBF"),  // teal 60%
        accent: Color.priorityNeed,  // #00C2CB — legible over white icons
        accentText: .priorityNeed,
        onAccent: .black,
        accentSecondary: .hotPink,
        income: .priorityNeed,
        expense: .hotPink,
        tagChip: .priorityNeed,
        transfer: Color(hex: "64748B"),
        toolbarIcon: Color.priorityNeed,
        destructive: .red,
        priorityNeed: .priorityNeed,
        essentialNeed: .essentialNeed,
        optionalNeed: .optionalNeed,
        shadowOpacity: 0.20,
        hasGradient: false,
        baseColorScheme: .dark
    )

    /// Texto o icono encima de un relleno: si el relleno es el acento del tema, `onAccent` (decidido por tema y medido);
    /// si es otro color, `Color.contrastingText(for:)`. Los «+» flotantes elegían por esa fórmula también sobre el
    /// acento, y sobre el turquesa de Teal salía blanco (2,19:1).
    func onFill(_ fill: Color) -> Color {
        fill == accent ? onAccent : Color.contrastingText(for: fill)
    }

    /// Whether this theme forces monochrome profile icons
    var forcesMonochromeIcons: Bool {
        mapsColorsToGrayscale
    }

    static let minimalist = YalaTheme(
        background: .black,
        card: Color(white: 0.1),  // #1A1A1A
        cardBorder: Color.white.opacity(0.1),
        primaryText: .white,
        secondaryText: Color(white: 0.6),
        accent: Color(white: 0.75),  // Gray — visible toggle track vs white thumb
        accentText: Color(white: 0.75),
        onAccent: .black,
        accentSecondary: Color(white: 0.7),
        income: Color(white: 0.85),
        expense: Color(white: 0.45),
        tagChip: Color(white: 0.6),
        transfer: Color(white: 0.5),
        toolbarIcon: .white,
        destructive: Color(white: 0.4),
        priorityNeed: Color(white: 0.8),
        essentialNeed: Color(white: 0.6),
        optionalNeed: Color(white: 0.4),
        shadowOpacity: 0.30,
        hasGradient: false,
        baseColorScheme: .dark,
        mapsColorsToGrayscale: true
    )

    // MARK: Translucent Variants

    private static func makeTranslucent(
        background: Color,
        accent: Color,
        accentText: Color,
        onAccent: Color,
        accentSecondary: Color,
        toolbarIcon: Color,
        tagChip: Color = .neonCyan
    ) -> YalaTheme {
        YalaTheme(
            background: background,
            card: Color.white.opacity(0.04),
            cardBorder: Color.white.opacity(0.1),
            primaryText: .white,
            secondaryText: Color.white.opacity(0.6),
            accent: accent,
            accentText: accentText,
            onAccent: onAccent,
            accentSecondary: accentSecondary,
            income: .priorityNeed,
            expense: .hotPink,
            tagChip: tagChip,
            transfer: Color(hex: "64748B"),
            toolbarIcon: toolbarIcon,
            destructive: .red,
            priorityNeed: .priorityNeed,
            essentialNeed: .essentialNeed,
            optionalNeed: .optionalNeed,
            shadowOpacity: 0.15,
            hasGradient: false,
            baseColorScheme: .dark,
            usesMaterial: true
        )
    }

    static let translucent = makeTranslucent(
        background: Color(hex: "0A0A1A"),
        accent: .electricIndigo, accentText: .indigoTextOnDark, onAccent: .white,
        accentSecondary: .hotPink, toolbarIcon: .electricIndigo
    )
    static let translucentRosa = makeTranslucent(
        background: Color(hex: "1A0A12"),
        accent: .hotPink, accentText: .pinkTextOnDark, onAccent: .black,
        accentSecondary: .electricIndigo, toolbarIcon: .hotPink
    )
    static let translucentTeal = makeTranslucent(
        background: Color(hex: "0A1A18"),
        accent: .priorityNeed, accentText: .priorityNeed, onAccent: .black,
        accentSecondary: .hotPink, toolbarIcon: .priorityNeed,
        tagChip: .priorityNeed
    )

    // MARK: Liquid Glass (Free)

    static let liquidGlass = makeTranslucent(
        background: Color(hex: "060612"),
        accent: .electricIndigo, accentText: .indigoTextOnDark, onAccent: .white,
        accentSecondary: .hotPink, toolbarIcon: .electricIndigo
    )
}

// MARK: - Environment Key

extension EnvironmentValues {
    @Entry var yalaTheme: YalaTheme = .light
}

