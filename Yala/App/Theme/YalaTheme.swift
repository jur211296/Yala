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
}

// MARK: - Environment Key

extension EnvironmentValues {
    @Entry var yalaTheme: YalaTheme = .light
}
