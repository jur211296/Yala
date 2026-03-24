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

    init(
        background: Color,
        card: Color,
        cardBorder: Color,
        primaryText: Color,
        secondaryText: Color,
        accent: Color,
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
        usesMaterial: Bool = false
    ) {
        self.background = background
        self.card = card
        self.cardBorder = cardBorder
        self.primaryText = primaryText
        self.secondaryText = secondaryText
        self.accent = accent
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
    }
}

// MARK: - Free Themes

extension YalaTheme {

    static let light = YalaTheme(
        background: Color(red: 0.98, green: 0.984, blue: 1.0),  // #FAFBFF
        card: .white,
        cardBorder: Color.primary.opacity(0.05),
        primaryText: Color.primary,
        secondaryText: Color.secondary,
        accent: .electricIndigo,
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
        baseColorScheme: .light
    )

    static let dark = YalaTheme(
        background: Color(hex: "000000"),  // OLED black
        card: Color(red: 0.11, green: 0.11, blue: 0.12),  // #1C1C1E
        cardBorder: Color.white.opacity(0.08),
        primaryText: Color.primary,
        secondaryText: Color.secondary,
        accent: .electricIndigo,
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

    /// Whether this theme forces monochrome profile icons
    var forcesMonochromeIcons: Bool {
        mapsColorsToGrayscale || usesMaterial
    }

    static let minimalist = YalaTheme(
        background: .black,
        card: Color(white: 0.1),  // #1A1A1A
        cardBorder: Color.white.opacity(0.1),
        primaryText: .white,
        secondaryText: Color(white: 0.6),
        accent: Color(white: 0.75),  // Gray — visible toggle track vs white thumb
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
        accentSecondary: Color,
        toolbarIcon: Color,
        tagChip: Color = .neonCyan
    ) -> YalaTheme {
        YalaTheme(
            background: background,
            card: Color.white.opacity(0.06),
            cardBorder: Color.white.opacity(0.1),
            primaryText: .white,
            secondaryText: Color.white.opacity(0.6),
            accent: accent,
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
        accent: .electricIndigo, accentSecondary: .hotPink, toolbarIcon: .electricIndigo
    )
    static let translucentRosa = makeTranslucent(
        background: Color(hex: "1A0A12"),
        accent: .hotPink, accentSecondary: .electricIndigo, toolbarIcon: .hotPink
    )
    static let translucentTeal = makeTranslucent(
        background: Color(hex: "0A1A18"),
        accent: .priorityNeed, accentSecondary: .hotPink, toolbarIcon: .priorityNeed,
        tagChip: .priorityNeed
    )
}

// MARK: - Environment Key

extension EnvironmentValues {
    @Entry var yalaTheme: YalaTheme = .light
}
