//
//  DesignTokens.swift
//  Yala
//
//  Unified Design System tokens for consistent styling across the app.
//  Single source of truth for spacing, radius, opacity, and animation values.
//

import SwiftUI
import UIKit

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

        /// 0pt - Explicit zero spacing
        static let none: CGFloat = 0

        /// 100pt - Safe bottom padding for scrollable content
        static let safeBottom: CGFloat = 100

        /// 64pt - Safe area offset for Settings sheets
        static let sheetTop: CGFloat = 64

        /// 52pt - Form/filter leading indentation
        static let formIndent: CGFloat = 52
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

        // MARK: Spring Parameters

        /// Spring response time (matches FAB animation)
        static let springResponse: Double = 0.25

        /// Spring damping (matches FAB animation)
        static let springDamping: Double = 0.8

        /// Bouncy spring damping for success states
        static let springBouncy: Double = 0.65

        /// Delay between staggered items
        static let staggerDelay: Double = 0.05
    }

    // MARK: - Haptic Feedback

    /// Centralized haptic feedback helpers.
    /// Usage: `DS.Haptic.success()`, `DS.Haptic.selection()`
    enum Haptic {
        /// Success feedback - use after completing important actions (save, confirm)
        static func success() {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }

        /// Selection feedback - use for toggle/selection changes
        static func selection() {
            UISelectionFeedbackGenerator().selectionChanged()
        }

        /// Medium impact - use for opening menus, primary actions
        static func medium() {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }

        /// Light impact - use for subtle interactions
        static func light() {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }

        /// Warning/rigid impact - use for destructive actions (delete)
        static func warning() {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        }
    }

    // MARK: - Colors

    /// Semantic colors for consistent styling.
    /// Use these instead of hardcoded Color.white.opacity() values.
    enum Colors {
        /// Subtle border for cards on dark backgrounds (0.1 opacity white)
        static let borderSubtle = Color.white.opacity(Card.borderOpacity)

        /// Very subtle background for hover/selection states (0.1 opacity white)
        static let backgroundSubtle = Color.white.opacity(Opacity.subtle)

        /// Faint background for very subtle effects (0.05 opacity white)
        static let backgroundFaint = Color.white.opacity(Opacity.faint)

        /// Light mode card borders/strokes (0.05 opacity black)
        static let borderDark = Color.black.opacity(0.05)
    }

    // MARK: - Semantic

    /// Status/state colors for success, warning, error, info states.
    /// Usage: `DS.Semantic.successBackground`, `DS.Semantic.errorForeground`
    enum Semantic {
        // Backgrounds
        static let successBackground = Color.green.opacity(0.15)
        static let warningBackground = Color.orange.opacity(0.15)
        static let errorBackground = Color.red.opacity(0.15)
        static let errorBackgroundSubtle = Color.red.opacity(0.1)
        static let errorBorder = Color.red.opacity(0.2)
        static let infoBackground = Color.blue.opacity(0.1)
        static let neutralBackground = Color.gray.opacity(0.1)
        // Foregrounds
        static let successForeground = Color.green
        static let warningForeground = Color.orange
        static let errorForeground = Color.red
        static let favoriteIcon = Color.yellow
        static let disabledForeground = Color.gray
        static let infoForeground = Color.blue
        static let undoForeground = Color.teal
        static let imageAccent = Color.teal
        // Group expense split-method chip — teal con mejor contraste que infoBackground (azul) en dark mode.
        static let splitMethodBackground = Color.teal.opacity(0.18)
        static let splitMethodForeground = Color.teal
    }

    // MARK: - Shadow

    /// Pre-configured shadow styles.
    enum Shadow {
        /// Subtle shadow for settings cards and containers
        static let subtle: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) = (
            .black.opacity(0.04), 12, 0, 6
        )

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

    // MARK: - Gradients

    /// Pre-defined gradient color arrays for consistent branding.
    /// Usage: `LinearGradient(colors: DS.Gradients.proBadge, ...)`
    enum Gradients {
        static let proBadge: [Color] = [.yellow, .orange]
        static let subscription: [Color] = [.orange, .hotPink]
        static let success: [Color] = [.green, .green.opacity(0.85)]
        static let warning: [Color] = [.orange, .red]

        // MARK: Hero gradients (Panel 2.0 — Salud Financiera, Hero IA)

        /// Calm hero gradient — used when the Financial Score ≥ 80.
        /// Reused by P20-04 (Hero base) and P20-05 (Hero IA).
        static let heroCalm: [Color] = [.indigo, .purple]

        /// Neutral hero gradient — used when the Financial Score is 60–79.
        static let heroNeutral: [Color] = [.purple, .hotPink]

        /// Intense hero gradient — used when the Financial Score < 60.
        /// Paired to contrast clearly against `heroNeutral` (pink → deep indigo)
        /// without relying on red/orange (reserved for `warning`).
        static let heroIntense: [Color] = [.hotPink, .indigo]

        /// Indigo→negro vertical — fondo unificado del flow Welcome (Hero + Chooser).
        static let heroIndigoBlack: [Color] = [.electricIndigo, .black]

        /// Picks the hero gradient for a given 0–100 financial score. `nil`
        /// uses `heroCalm` as a neutral fallback for placeholder/empty states.
        /// Single source of truth for card + detail sheet so thresholds stay
        /// in sync.
        static func heroFor(score: Int?) -> [Color] {
            guard let score else { return heroCalm }
            if score >= 80 { return heroCalm }
            if score >= 60 { return heroNeutral }
            return heroIntense
        }
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

    // MARK: - Panel

    /// Panel-specific visual tokens. These keep the home screen calmer than
    /// larger detail/report surfaces without changing the global card system.
    /// El padding "regular" reusa `DS.Card.paddingCompact` vía el helper
    /// `View.panelCard(small:)`.
    enum Panel {
        static let smallWidgetPadding: CGFloat = 14
        static let widgetRadius: CGFloat = 20
        static let smallWidgetRadius: CGFloat = 18
        /// Botón circular glass al lado de los títulos de sección
        /// (prefs, toggle de panorama).
        static let headerAccessorySize: CGFloat = 30
        /// Chevron `›` inline pegado al título de sección — más pequeño
        /// que `headerAccessorySize` para que se sienta como acento del
        /// título, no como acción protagónica.
        static let headerChevronSize: CGFloat = 24
        /// Botón circular glass al lado de los títulos de widget
        /// (info/help). Más pequeño que `headerAccessorySize` para no
        /// competir con los títulos de sección.
        static let widgetAccessorySize: CGFloat = 22
    }

    // MARK: - Button Dimensions

    /// Standard button size tokens
    enum Button {
        /// FAB (Floating Action Button) diameter - 56pt standard
        static let fabSize: CGFloat = 56

        /// Action button size (toolbar, selection bar) - 44pt HIG minimum
        static let actionSize: CGFloat = 44

        /// FAB menu pill width (sized to fit PRO badge)
        static let fabMenuWidth: CGFloat = 170

        /// Icon size inside FAB menu buttons
        static let fabMenuIconSize: CGFloat = 24
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

    // MARK: - Adaptive Layout

    /// Size class helpers for iPad/iPhone adaptive layouts.
    /// Usage: `DS.Adaptive.isWideScreen(sizeClass)`, `DS.Adaptive.columns(sizeClass)`
    enum Adaptive {
        /// Returns true when horizontal size class is `.regular` (iPad, iPhone landscape)
        static func isWideScreen(_ sizeClass: UserInterfaceSizeClass?) -> Bool {
            sizeClass == .regular
        }

        /// Number of widget columns: 2 on wide screens, 1 on compact
        static func columns(_ sizeClass: UserInterfaceSizeClass?) -> Int {
            isWideScreen(sizeClass) ? 2 : 1
        }

        /// Horizontal padding: 32pt on wide screens, 16pt on compact
        static func horizontalPadding(_ sizeClass: UserInterfaceSizeClass?) -> CGFloat {
            isWideScreen(sizeClass) ? DS.Spacing.xxxl : DS.Spacing.lg
        }

        /// Forces .large detents on iPad and Mac Catalyst where
        /// medium/fixed-height sheets are too small for pickers and complex content.
        static func sheetDetents(_ detents: Set<PresentationDetent>) -> Set<PresentationDetent> {
            let needsLargeSheet = UIDevice.current.userInterfaceIdiom == .pad
                || ProcessInfo.processInfo.isiOSAppOnMac
            return needsLargeSheet ? [.large] : detents
        }
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
        /// Widget titles, secondary emphasis
        static let subheadlineEmphasized = Font.subheadline.weight(.semibold)

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

        // MARK: Badges & Indicators
        /// Badge labels ("PRO", "New", "Overdue")
        static let badgeLabel = Font.caption2.weight(.bold)
        /// Sort/dropdown indicators (chevrons, arrows)
        static let indicator = Font.caption2.weight(.semibold)
        /// Monospaced digits for counters
        static let captionMono = Font.caption.monospacedDigit()
        /// Monospaced digits for counters, bold
        static let captionMonoBold = Font.caption.monospacedDigit().bold()

        // MARK: Icon Fonts
        /// Form row chevrons
        static let chevron = Font.system(size: DS.FormRow.chevronSize, weight: .semibold)
        /// Chip close button
        static let chipClose = Font.system(size: DS.Chip.closeButtonSize, weight: .semibold)
        /// Chip icon
        static let chipIcon = Font.system(size: DS.Chip.iconSize, weight: .semibold)
        /// Chip icon-only variant
        static let chipIconOnly = Font.system(size: DS.Chip.iconOnlySize, weight: .medium)
        /// Icon inside medium badge
        static let iconMedium = Font.system(size: DS.Icon.sizeMedium, weight: .semibold)

        // MARK: Numbers
        /// Large amounts (hero numbers)
        static let amountLarge = Font.system(.title, design: .rounded).weight(.bold)
        /// Standard amounts
        static let amount = Font.system(.body, design: .rounded).weight(.semibold)
        /// Small amounts
        static let amountSmall = Font.system(.subheadline, design: .rounded).weight(.medium)
    }

    // MARK: - Sizing

    /// Dimensiones reusables (heights, widths) que no encajan en `Spacing`/`Radius`.
    enum Sizing {
        /// Altura estándar de dividers verticales en rows con info numérica
        /// (NetFlowSummaryView, PivotRowView).
        static let dividerHeightStandard: CGFloat = 28

        /// Altura de progress bars compactos (CashFlowDetailLineRow, badges).
        static let progressBarHeight: CGFloat = 4
    }
}

// MARK: - View Extensions

extension View {
    /// Apply subtle shadow for settings cards and containers
    func dsSubtleShadow() -> some View {
        let s = DS.Shadow.subtle
        return self.shadow(color: s.color, radius: s.radius, x: s.x, y: s.y)
    }

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

    /// Apply animation respecting accessibility reduce motion preference
    @ViewBuilder
    func dsAnimation(_ animation: Animation?, value: some Equatable, reduceMotion: Bool) -> some View {
        if reduceMotion {
            self
        } else {
            self.animation(animation, value: value)
        }
    }
}

// MARK: - Conditional Animation Helper

/// Executes animation respecting accessibility reduce motion preference
/// Usage: `dsWithAnimation(reduceMotion) { state = newValue }`
func dsWithAnimation(_ reduceMotion: Bool, _ animation: Animation? = .easeInOut(duration: DS.Animation.normal), _ body: () -> Void) {
    if reduceMotion {
        body()
    } else {
        withAnimation(animation) {
            body()
        }
    }
}

// MARK: - Global Typealias

/// Allows using `Typography.title` instead of `DS.Typography.title`
typealias Typography = DS.Typography

