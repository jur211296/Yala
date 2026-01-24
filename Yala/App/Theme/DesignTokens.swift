//
//  DesignTokens.swift
//  Yala
//
//  Unified Design System tokens for consistent styling across the app.
//  Single source of truth for spacing, radius, opacity, and animation values.
//

import SwiftUI

// MARK: - DS (Design System)

/// Unified Design System namespace.
/// Usage: `DS.Spacing.lg`, `DS.Radius.xl`, `DS.Opacity.glass`
enum DS {

    // MARK: - Spacing

    /// Consistent spacing values for padding, margins, and gaps.
    enum Spacing {
        /// 2pt - Micro gaps, hairline spacing
        static let xxs: CGFloat = 2

        /// 4pt - Tight gaps, icon padding
        static let xs: CGFloat = 4

        /// 8pt - Standard small spacing
        static let sm: CGFloat = 8

        /// 12pt - Medium spacing
        static let md: CGFloat = 12

        /// 16pt - Standard large spacing (default)
        static let lg: CGFloat = 16

        /// 20pt - Extra large spacing
        static let xl: CGFloat = 20

        /// 24pt - Section spacing
        static let xxl: CGFloat = 24

        /// 32pt - Major section dividers
        static let xxxl: CGFloat = 32

        /// 48pt - Page margins, large gaps
        static let xxxxl: CGFloat = 48

        /// 100pt - Safe bottom padding for scrollable content
        static let safeBottom: CGFloat = 100
    }

    // MARK: - Corner Radius

    /// Consistent corner radius values for rounded UI elements.
    enum Radius {
        /// 4pt - Tiny elements, pills
        static let xs: CGFloat = 4

        /// 8pt - Buttons, small cards, chips
        static let sm: CGFloat = 8

        /// 12pt - Cards, inputs, containers
        static let md: CGFloat = 12

        /// 14pt - Record rows, list items
        static let card: CGFloat = 14

        /// 16pt - Sheets, modals
        static let lg: CGFloat = 16

        /// 24pt - Large cards, hero elements
        static let xl: CGFloat = 24

        /// 9999pt - Full capsule/pill shape
        static let full: CGFloat = 9999
    }

    // MARK: - Opacity

    /// Standard opacity values for consistent transparency.
    enum Opacity {
        /// 0.6 - Glassmorphism backgrounds
        static let glass: Double = 0.6

        /// 0.4 - Overlays, scrims
        static let overlay: Double = 0.4

        /// 0.1 - Subtle backgrounds, hover states
        static let subtle: Double = 0.1

        /// 0.5 - Disabled states
        static let disabled: Double = 0.5

        /// 0.05 - Very subtle, borders
        static let faint: Double = 0.05
    }

    // MARK: - Animation

    /// Consistent animation durations for smooth UI transitions.
    enum Animation {
        /// 0.15s - Micro-interactions, button taps
        static let fast: Double = 0.15

        /// 0.25s - Standard transitions
        static let normal: Double = 0.25

        /// 0.4s - Emphasis, modals, sheets
        static let slow: Double = 0.4
    }

    // MARK: - Shadow

    /// Pre-configured shadow styles.
    enum Shadow {
        /// Small shadow for subtle elevation (cards)
        static let small: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) = (
            .black.opacity(0.05), 10, 0, 5
        )

        /// Medium shadow for floating elements
        static let medium: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) = (
            .black.opacity(0.12), 8, 0, 4
        )

        /// Large shadow for modals, FABs
        static let large: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) = (
            .black.opacity(0.20), 20, 0, 10
        )
    }

    // MARK: - Chip Dimensions

    /// Specific dimensions for filter chips (unified across views)
    enum Chip {
        /// Horizontal padding inside chip
        static let paddingH: CGFloat = 10

        /// Vertical padding inside chip
        static let paddingV: CGFloat = 6

        /// Spacing between chip elements
        static let spacing: CGFloat = 6

        /// Color dot diameter
        static let dotSize: CGFloat = 8

        /// Icon circle diameter
        static let iconCircleSize: CGFloat = 16

        /// Icon font size inside circle
        static let iconSize: CGFloat = 8

        /// Standalone icon size (no circle)
        static let iconOnlySize: CGFloat = 12

        /// Close button size
        static let closeButtonSize: CGFloat = 11

        /// Border opacity
        static let borderOpacity: Double = 0.08
    }

    // MARK: - Card Dimensions

    /// Widget/card styling tokens (unified across Panel, Statistics, etc.)
    enum Card {
        /// Standard internal padding for cards
        static let padding: CGFloat = 20

        /// Compact internal padding for smaller cards
        static let paddingCompact: CGFloat = 16

        /// Standard corner radius for cards
        static let radius: CGFloat = 24

        /// White overlay opacity for borders
        static let borderOpacity: Double = 0.1
    }

    // MARK: - Icon Badge Dimensions

    /// Icon size and badge tokens
    enum Icon {
        /// Small icon badge (categories, etc.)
        static let badgeSmall: CGFloat = 24

        /// Medium icon badge
        static let badgeMedium: CGFloat = 32

        /// Large icon badge (accounts, etc.)
        static let badgeLarge: CGFloat = 40

        /// Small icon size inside badge
        static let sizeSmall: CGFloat = 12

        /// Medium icon size inside badge
        static let sizeMedium: CGFloat = 16

        /// Large icon size inside badge
        static let sizeLarge: CGFloat = 20
    }

    // MARK: - Form Row Dimensions

    /// Standard dimensions for form rows (TransactionFormRow, settings rows, etc.)
    enum FormRow {
        /// Horizontal padding inside form rows
        static let paddingH: CGFloat = 16

        /// Vertical padding inside form rows
        static let paddingV: CGFloat = 14

        /// Icon container width (left side)
        static let iconWidth: CGFloat = 28

        /// Spacing between icon and content
        static let iconSpacing: CGFloat = 12

        /// Chevron size for navigation rows
        static let chevronSize: CGFloat = 14

        /// Minimum row height
        static let minHeight: CGFloat = 52
    }

    // MARK: - List Row Dimensions

    /// Standard dimensions for list items (RecordRowView, etc.)
    enum ListRow {
        /// Horizontal padding
        static let paddingH: CGFloat = 14

        /// Vertical padding
        static let paddingV: CGFloat = 12

        /// Icon/avatar size
        static let iconSize: CGFloat = 40

        /// Spacing between elements
        static let spacing: CGFloat = 12

        /// Corner radius (uses Radius.card)
        static let radius: CGFloat = 14
    }

    // MARK: - Typography

    /// Semantic font styles for consistent typography.
    /// Usage: `.font(DS.Typography.title)` or `Text("Hello").dsFont(.title)`
    enum Typography {
        // MARK: Headings
        /// Screen titles, large headers
        static let largeTitle = Font.largeTitle.weight(.bold)
        /// Section headers
        static let title = Font.title2.weight(.semibold)
        /// Subsection headers
        static let title2 = Font.title2.weight(.semibold)
        /// Card titles, subsections
        static let headline = Font.headline.weight(.semibold)

        // MARK: Body
        /// Primary body text, emphasized
        static let bodyBold = Font.body.weight(.medium)
        /// Alias for bodyBold (legacy compatibility)
        static let bodyLarge = Font.body.weight(.medium)
        /// Standard body text
        static let body = Font.body
        /// Secondary body text
        static let subheadline = Font.subheadline

        // MARK: Labels
        /// UI labels, medium weight
        static let label = Font.subheadline.weight(.medium)
        /// Small labels
        static let labelSmall = Font.caption.weight(.medium)
        /// Tiny labels, badges
        static let labelTiny = Font.caption2.weight(.medium)

        // MARK: Captions
        /// Descriptions, helper text
        static let caption = Font.caption
        /// Smallest text
        static let captionSmall = Font.caption2

        // MARK: Numbers
        /// Large amounts (hero numbers)
        static let amountLarge = Font.system(.title, design: .rounded).weight(.bold)
        /// Standard amounts
        static let amount = Font.system(.body, design: .rounded).weight(.semibold)
        /// Small amounts
        static let amountSmall = Font.system(.subheadline, design: .rounded).weight(.medium)
    }
}

// MARK: - View Extensions

extension View {
    /// Apply standard card shadow (small elevation)
    func dsCardShadow() -> some View {
        let s = DS.Shadow.small
        return self.shadow(color: s.color, radius: s.radius, x: s.x, y: s.y)
    }

    /// Apply floating element shadow (FAB, modals)
    func dsFloatingShadow() -> some View {
        let s = DS.Shadow.large
        return self.shadow(color: s.color, radius: s.radius, x: s.x, y: s.y)
    }
}

// MARK: - Global Typealias

/// Allows using `Typography.title` instead of `DS.Typography.title`
typealias Typography = DS.Typography

// MARK: - Legacy Aliases (Deprecated)

// These provide backwards compatibility during migration.
// Will be removed in a future version.

/// Legacy DesignSystem namespace - use DS instead
@available(*, deprecated, message: "Use DS instead")
enum DesignSystem {

    @available(*, deprecated, message: "Use DS.Spacing instead")
    enum Spacing {
        static var two: CGFloat { DS.Spacing.xxs }
        static var four: CGFloat { DS.Spacing.xs }
        static var standard: CGFloat { DS.Spacing.sm }
        static var medium: CGFloat { DS.Spacing.md }
        static var large: CGFloat { DS.Spacing.lg }
        static var xLarge: CGFloat { DS.Spacing.xl }
        static var xxLarge: CGFloat { DS.Spacing.xxl }
        static var triple: CGFloat { DS.Spacing.xxxl }
    }

    @available(*, deprecated, message: "Use DS.Radius instead")
    enum Radius {
        static var small: CGFloat { DS.Radius.sm }
        static var standard: CGFloat { DS.Radius.md }
        static var large: CGFloat { DS.Radius.lg }
        static var xLarge: CGFloat { DS.Radius.xl }
    }

    @available(*, deprecated, message: "Use DS.Opacity instead")
    enum Opacity {
        static var glass: Double { DS.Opacity.glass }
        static var subtle: Double { DS.Opacity.subtle }
    }
}

