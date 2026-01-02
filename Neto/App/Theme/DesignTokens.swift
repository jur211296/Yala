//
//  DesignTokens.swift
//  Neto
//
//  Formal design tokens for consistent styling across the app.
//

import SwiftUI

// MARK: - Spacing

/// Consistent spacing values for padding, margins, and gaps.
enum Spacing {
    /// Extra small spacing: 4pt
    static let xs: CGFloat = 4

    /// Small spacing: 8pt
    static let sm: CGFloat = 8

    /// Medium spacing: 16pt (default)
    static let md: CGFloat = 16

    /// Large spacing: 24pt
    static let lg: CGFloat = 24

    /// Extra large spacing: 32pt
    static let xl: CGFloat = 32

    /// Extra extra large spacing: 48pt
    static let xxl: CGFloat = 48
}

// MARK: - Typography

/// Pre-configured font styles for consistent typography.
struct Typography {

    // MARK: - Headlines

    /// Large title: Bold, for main screen headers
    static let titleLarge = Font.largeTitle.weight(.bold)

    /// Title: Semibold, for section headers
    static let title = Font.title.weight(.semibold)

    /// Title 2: Semibold, for subsection headers
    static let title2 = Font.title2.weight(.semibold)

    /// Title 3: Medium, for card titles
    static let title3 = Font.title3.weight(.medium)

    // MARK: - Body

    /// Body large: Regular, for emphasized body text
    static let bodyLarge = Font.body.weight(.medium)

    /// Body: Regular, for standard content
    static let body = Font.body

    /// Body small: Subheadline size
    static let bodySmall = Font.subheadline

    // MARK: - Labels & Captions

    /// Label: Medium weight caption for UI labels
    static let label = Font.caption.weight(.medium)

    /// Label small: Caption 2 for secondary labels
    static let labelSmall = Font.caption2

    /// Mono: Monospaced for numbers and amounts
    static let mono = Font.system(.body, design: .monospaced)

    /// Mono large: Monospaced for large amounts
    static let monoLarge = Font.system(.title2, design: .monospaced).weight(.semibold)
}

// MARK: - Corner Radius

/// Consistent corner radius values for rounded UI elements.
enum CornerRadius {
    /// Small radius: 8pt (buttons, small cards)
    static let sm: CGFloat = 8

    /// Medium radius: 12pt (cards, containers)
    static let md: CGFloat = 12

    /// Large radius: 16pt (sheets, modals)
    static let lg: CGFloat = 16

    /// Extra large radius: 24pt (large cards)
    static let xl: CGFloat = 24

    /// Full radius: 999pt (pills, capsules)
    static let full: CGFloat = 999
}

// MARK: - Animation

/// Consistent animation durations for smooth UI transitions.
enum AnimationDuration {
    /// Fast animation: 0.15s (micro-interactions)
    static let fast: Double = 0.15

    /// Normal animation: 0.25s (standard transitions)
    static let normal: Double = 0.25

    /// Slow animation: 0.4s (emphasis, modals)
    static let slow: Double = 0.4
}

// MARK: - Shadows

/// Pre-configured shadow styles.
enum Shadow {
    /// Small shadow for subtle elevation
    static func small(_ color: Color = .black) -> some View {
        EmptyView().shadow(color: color.opacity(0.08), radius: 4, x: 0, y: 2)
    }

    /// Medium shadow for cards
    static let medium: (Color) -> (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) = {
        color in
        (color.opacity(0.12), 8, 0, 4)
    }

    /// Large shadow for floating elements
    static let large: (Color) -> (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) = {
        color in
        (color.opacity(0.20), 20, 0, 10)
    }
}

// MARK: - View Extensions

extension View {
    /// Apply standard card shadow
    func cardShadow(color: Color = .black) -> some View {
        self.shadow(color: color.opacity(0.12), radius: 8, x: 0, y: 4)
    }

    /// Apply floating element shadow
    func floatingShadow(color: Color = .black) -> some View {
        self.shadow(color: color.opacity(0.20), radius: 20, x: 0, y: 10)
    }
}
