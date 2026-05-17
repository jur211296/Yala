//
//  PanelSmallBarRow.swift
//  Yala
//
//  Shared row used by the `.small` layouts that render horizontal progress bars
//  (CashFlow, ExpensesByNeed, …). Each row has a trailing amount label, a
//  normalized bar underneath, and an optional inline percentage glyph in the
//  label area. The row reacts to dim/tap for filter-style interactions.
//

import SwiftUI

struct PanelSmallBarRow: View {
    let label: String
    let amount: Double
    let ratio: Double
    let color: Color
    let currencyCode: String

    @Environment(AppPreferences.self) private var appPreferences

    /// When true, the row is rendered at 40% opacity. Callers drive this with
    /// their selection/filter state.
    var dimmed: Bool = false

    /// Optional tap handler. When `nil` the row is not interactive.
    var onTap: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            HStack(spacing: DS.Spacing.xs) {
                Text(label)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.thSecondaryText)
                    .lineLimit(1)
                Spacer(minLength: DS.Spacing.xs)
                AmountText(
                    value: amount,
                    currencyCode: currencyCode,
                    font: DS.Typography.amount,
                    tint: .primary
                )
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.thPrimaryText.opacity(0.05))
                    Capsule()
                        .fill(color)
                        .frame(width: max(geo.size.width * CGFloat(ratio), ratio > 0 ? 4 : 0))
                }
            }
            .frame(height: 6)
        }
        .opacity(dimmed ? 0.4 : 1.0)
        .contentShape(Rectangle())
        .modifier(TapIfPresent(onTap: onTap))
    }
}

/// Adds `.onTapGesture` only when a handler is provided — avoids grabbing taps
/// in passive contexts (e.g. CashFlow `.small` where the bars are read-only).
private struct TapIfPresent: ViewModifier {
    let onTap: (() -> Void)?
    func body(content: Content) -> some View {
        if let onTap {
            content.onTapGesture { onTap() }
        } else {
            content
        }
    }
}
