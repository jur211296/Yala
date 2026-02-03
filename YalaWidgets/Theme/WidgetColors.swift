//
//  WidgetColors.swift
//  YalaWidgets
//
//  Semantic colors for widgets, aligned with main app design system.
//  Mirrors the Yala color palette for consistent brand experience.
//

import SwiftUI

/// Semantic colors for widget UI elements
/// Aligned with main app: electricIndigo, hotPink, priorityNature (teal)
enum WidgetColors {
    // MARK: - Brand Colors (from UIHelpers.swift)

    /// Electric Indigo - Primary accent, balance positive (#6366F1)
    static let electricIndigo = Color(hex: "6366F1")

    /// Hot Pink - Expenses (#FF0080)
    static let hotPink = Color(hex: "FF0080")

    /// Yala Teal - Income (#00C2CB)
    static let yalaTeal = Color(hex: "00C2CB")

    // MARK: - Financial Semantics

    /// Income indicator (teal)
    static let income = yalaTeal

    /// Expense indicator (hot pink)
    static let expense = hotPink

    /// Balance positive (indigo)
    static let balance = electricIndigo

    /// Balance negative / error (red)
    static let negative = Color(hex: "EF4444")

    // MARK: - Status Colors

    /// Warning state (amber)
    static let warning = Color(hex: "F59E0B")

    /// Success state (green)
    static let success = Color(hex: "22C55E")

    /// Accent color (indigo)
    static let accent = electricIndigo

    /// Overdue/error state (red)
    static let overdue = negative

    // MARK: - Helpers

    /// Color for balance based on sign
    static func forBalance(_ value: Double) -> Color {
        value >= 0 ? balance : negative
    }

    /// Color for cash flow based on sign
    static func forCashFlow(_ value: Double) -> Color {
        if value > 0 { return income }
        if value < 0 { return expense }
        return .secondary
    }

    /// Budget progress color based on percentage used
    static func forBudget(percentUsed: Double) -> Color {
        if percentUsed >= 100 { return negative }
        if percentUsed >= 75 { return warning }
        return success
    }

    // MARK: - Trend Charts

    /// Trend line color based on current balance
    static func trendLine(balance: Double) -> Color {
        balance >= 0 ? accent : negative
    }

    /// Trend fill color (with opacity)
    static func trendFill(balance: Double) -> Color {
        trendLine(balance: balance).opacity(0.15)
    }

    /// Income trend line
    static let trendIncome = income

    /// Expense trend line
    static let trendExpense = expense
}
