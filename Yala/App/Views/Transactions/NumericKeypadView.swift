//
//  NumericKeypadView.swift
//  Yala
//
//  Created by Yala - New Transaction Form.
//

import SwiftUI

// MARK: - Numeric Keypad View

/// Teclado numérico personalizado para entrada de montos
struct NumericKeypadView: View {
    let onDigit: (String) -> Void
    let onDelete: () -> Void
    let onClear: () -> Void

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
    ]

    private let buttons: [[KeypadButton]] = [
        [.digit("1"), .digit("2"), .digit("3")],
        [.digit("4"), .digit("5"), .digit("6")],
        [.digit("7"), .digit("8"), .digit("9")],
        [.decimal, .digit("0"), .delete],
    ]

    var body: some View {
        VStack(spacing: DS.Spacing.none) {
            ForEach(0..<buttons.count, id: \.self) { row in
                HStack(spacing: DS.Spacing.none) {
                    ForEach(buttons[row]) { button in
                        KeypadButtonView(button: button) {
                            handleTap(button)
                        }
                    }
                }
            }
        }
        .background(.thCard.opacity(0.95))
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    private func handleTap(_ button: KeypadButton) {
        switch button {
        case .digit(let value):
            onDigit(value)
        case .decimal:
            onDigit(decimalSeparator)
        case .delete:
            onDelete()
        }
    }

    private var decimalSeparator: String {
        Locale.current.decimalSeparator ?? "."
    }
}

// MARK: - Keypad Button Model

enum KeypadButton: Identifiable {
    case digit(String)
    case decimal
    case delete

    var id: String {
        switch self {
        case .digit(let value): return value
        case .decimal: return "decimal"
        case .delete: return "delete"
        }
    }

    var displayText: String? {
        switch self {
        case .digit(let value): return value
        case .decimal: return Locale.current.decimalSeparator ?? "."
        case .delete: return nil
        }
    }

    var systemImage: String? {
        switch self {
        case .delete: return "delete.left.fill"
        default: return nil
        }
    }

    var accessibilityText: String {
        switch self {
        case .digit(let value): return value
        case .decimal: return Locale.current.decimalSeparator ?? "."
        case .delete: return L10n.Action.delete
        }
    }
}

// MARK: - Keypad Button View

struct KeypadButtonView: View {
    let button: KeypadButton
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.yalaTheme) private var theme
    @ScaledMetric(relativeTo: .title) private var digitSize: CGFloat = 28 // A11Y-DT: @ScaledMetric
    @ScaledMetric(relativeTo: .title) private var deleteSize: CGFloat = 22
    @State private var isPressed = false

    var body: some View {
        Button {
            action()
        } label: {
            ZStack {
                if isPressed {
                    RoundedRectangle(cornerRadius: DS.Radius.sm)
                        .fill(theme.accent.opacity(0.15))
                }

                if let text = button.displayText {
                    Text(text)
                        .font(.system(size: digitSize, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary)
                } else if let systemImage = button.systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: deleteSize, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: DS.Button.fabSize)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(button.accessibilityText)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    dsWithAnimation(reduceMotion) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    dsWithAnimation(reduceMotion) {
                        isPressed = false
                    }
                }
        )
        .sensoryFeedback(.impact(flexibility: .soft), trigger: isPressed)
    }
}

#Preview {
    VStack {
        Spacer()
        NumericKeypadView(
            onDigit: { print($0) },
            onDelete: { print("delete") },
            onClear: { print("clear") }
        )
    }
    .background(.thBackground)
}
