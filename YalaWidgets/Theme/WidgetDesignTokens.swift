//
//  WidgetDesignTokens.swift
//  YalaWidgets
//
//  Design tokens for widgets - subset of main app's DesignTokens.swift
//  Provides consistent styling across all WidgetKit widgets.
//

import SwiftUI

/// Widget Design System namespace
/// Usage: `WDS.Spacing.sm`, `WDS.Typography.kpi`
enum WDS {

    // MARK: - Spacing

    /// Spacing values optimized for widget constraints
    enum Spacing {
        /// 2pt - Micro gaps
        static let xxs: CGFloat = 2

        /// 4pt - Tight gaps, icon padding
        static let xs: CGFloat = 4

        /// 6pt - Small gaps
        static let sm: CGFloat = 6

        /// 8pt - Standard spacing
        static let md: CGFloat = 8

        /// 12pt - Medium spacing
        static let lg: CGFloat = 12

        /// 16pt - Large spacing (standard padding)
        static let xl: CGFloat = 16
    }

    // MARK: - Corner Radius

    /// Corner radius values for widget elements
    enum Radius {
        /// 4pt - Small elements
        static let xs: CGFloat = 4

        /// 8pt - Buttons, chips
        static let sm: CGFloat = 8

        /// 12pt - Cards, containers
        static let md: CGFloat = 12

        /// 16pt - Large elements
        static let lg: CGFloat = 16

        /// 9999pt - Full capsule
        static let full: CGFloat = 9999
    }

    // MARK: - Typography

    /// Font styles for widgets
    enum Typography {
        // Headers
        /// Widget title (e.g., "Balance")
        static let title = Font.system(.headline, weight: .semibold)

        /// Widget subtitle (e.g., "Este mes")
        static let subtitle = Font.system(.caption)

        // KPI (Key Performance Indicators)
        /// Large KPI for Small widgets
        static let kpiLarge = Font.system(.title, design: .rounded, weight: .bold)

        /// Medium KPI for Medium widgets
        static let kpiMedium = Font.system(.title3, design: .rounded, weight: .bold)

        /// Small KPI for compact displays
        static let kpiSmall = Font.system(.headline, design: .rounded, weight: .semibold)

        // Labels
        /// Category/item labels
        static let label = Font.system(.caption, weight: .medium)

        /// Secondary labels
        static let labelSmall = Font.system(.caption2, weight: .medium)

        // Values
        /// Amount values in lists
        static let value = Font.system(.caption, design: .rounded, weight: .medium)

        /// Small values
        static let valueSmall = Font.system(.caption2, design: .rounded)

        // Misc
        /// Body text
        static let body = Font.system(.caption)

        /// Tiny text (percentages, dates)
        static let tiny = Font.system(.caption2)

        /// Chart axis labels (8pt medium)
        static let axis = Font.system(size: 8, weight: .medium)

        /// Chart axis labels regular weight (8pt)
        static let axisRegular = Font.system(size: 8)

        /// Bar chart value labels (8pt bold)
        static let barValue = Font.system(size: 8, weight: .bold)

        /// Bar chart label icons (10pt bold)
        static let barLabel = Font.system(size: 10, weight: .bold)
    }

    // MARK: - Icon Sizes

    /// Icon dimensions for widgets
    enum Icon {
        /// Small icon (12pt) - inline indicators
        static let sm: CGFloat = 12

        /// Medium icon (16pt) - list items
        static let md: CGFloat = 16

        /// Large icon (24pt) - headers
        static let lg: CGFloat = 24

        /// Extra large (32pt) - quick entry widgets
        static let xl: CGFloat = 32

        /// Badge background size for list items
        static let badgeSize: CGFloat = 28
    }

    // MARK: - Progress Bar

    /// Progress bar dimensions
    enum Progress {
        /// Standard height
        static let height: CGFloat = 6

        /// Compact height
        static let heightCompact: CGFloat = 4
    }

    // MARK: - List Item

    /// Dimensions for list items in widgets
    enum ListItem {
        /// Vertical spacing between items
        static let spacing: CGFloat = 8

        /// Internal horizontal spacing
        static let internalSpacing: CGFloat = 8

        /// Icon badge size
        static let iconSize: CGFloat = 28

        /// Compact icon size for TopCategories/TopSubcategories widgets
        static let iconSizeCompact: CGFloat = 24

        /// Percentage column width for alignment
        static let percentageWidth: CGFloat = 32
    }

    // MARK: - Quick Entry

    /// Dimensions for quick entry action widgets
    enum QuickEntry {
        /// Circle container size for action icons
        static let circleSize: CGFloat = 56
    }
}
