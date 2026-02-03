//
//  WidgetColors.swift
//  YalaWidgets
//
//  Semantic colors for widgets, aligned with main app design system.
//  Centralizes color definitions for consistency across all widgets.
//

import SwiftUI

/// Semantic colors for widget UI elements
enum WidgetColors {
    // MARK: - Financial Semantics

    /// Income indicator color (green)
    static let income = Color(hex: "22C55E")

    /// Expense indicator color (primary text)
    static let expense = Color.primary

    /// Negative balance indicator (red)
    static let negative = Color(hex: "EF4444")

    // MARK: - Status Colors

    /// Warning state (amber/orange)
    static let warning = Color(hex: "F59E0B")

    /// Success state (green)
    static let success = Color(hex: "22C55E")

    /// Accent color (indigo - matches electricIndigo)
    static let accent = Color(hex: "6366F1")

    /// Overdue/error state (red)
    static let overdue = Color(hex: "EF4444")

    // MARK: - Budget Progress

    /// Budget progress color based on percentage used
    static func budgetProgress(percentUsed: Double) -> Color {
        if percentUsed >= 100 {
            return negative  // Over budget
        } else if percentUsed >= 75 {
            return warning   // Warning zone
        } else {
            return success   // Healthy
        }
    }

    // MARK: - Balance Trend

    /// Trend line color based on current balance
    static func trendLine(balance: Double) -> Color {
        balance >= 0 ? success : negative
    }

    /// Trend fill color (with opacity)
    static func trendFill(balance: Double) -> Color {
        trendLine(balance: balance).opacity(0.15)
    }
}
