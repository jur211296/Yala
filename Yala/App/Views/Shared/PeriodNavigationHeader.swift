//
//  PeriodNavigationHeader.swift
//  Yala
//
//  Componente shared para navegación de períodos (chevron ← label tap → chevron)
//  con swipe horizontal desde los bordes laterales.
//
//  Reusado por: BudgetsListView, ScheduledPaymentsListView (Planning polish
//  Bloques B/C). El label tap dispara `onTapLabel` (sheet bottom existente como
//  BudgetPeriodSelectorSheet/ScheduledPaymentPeriodSelectorSheet, NO Menu plano
//  — preserva la UI rica de history multi-year).
//
//  Swipe gestures: usan `.simultaneousGesture` para cohabitar con scroll vertical
//  del ScrollView padre. Disambiguation horizontal vs vertical evita falsos
//  positivos en drag diagonal vertical-dominante.
//

import SwiftUI

struct PeriodNavigationHeader: View {
    let currentLabel: String
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onTapLabel: () -> Void
    var canGoPrevious: Bool = true
    var canGoNext: Bool = true
    var previousAccessibilityLabel: String = L10n.Accessibility.previousPeriod
    var nextAccessibilityLabel: String = L10n.Accessibility.nextPeriod

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack {
            chevronButton(
                systemName: "chevron.left",
                action: onPrevious,
                enabled: canGoPrevious,
                label: previousAccessibilityLabel
            )

            Spacer()

            Button(action: onTapLabel) {
                HStack(spacing: DS.Spacing.xs) {
                    Text(currentLabel)
                        .font(DS.Typography.headline)
                        .foregroundStyle(.primary)

                    Image(systemName: "chevron.down")
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            chevronButton(
                systemName: "chevron.right",
                action: onNext,
                enabled: canGoNext,
                label: nextAccessibilityLabel
            )
        }
        .padding(.vertical, DS.Spacing.sm)
        .simultaneousGesture(edgeAnchoredSwipeGesture)
    }

    @ViewBuilder
    private func chevronButton(
        systemName: String,
        action: @escaping () -> Void,
        enabled: Bool,
        label: String
    ) -> some View {
        Button {
            dsWithAnimation(reduceMotion) { action() }
        } label: {
            Image(systemName: systemName)
                .font(DS.Typography.headline)
                .foregroundStyle(enabled ? .secondary : .tertiary)
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    /// Gesture horizontal con disambiguation explícita vs scroll vertical.
    /// Solo dispara si el drag es dominantemente horizontal (`width > height * 1.5`)
    /// y supera el threshold de 60pt. Previene falsos positivos al hacer scroll
    /// vertical con leve drift horizontal.
    private var edgeAnchoredSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 60)
            .onEnded { value in
                guard abs(value.translation.width) > 60 else { return }
                guard abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
                if value.translation.width > 0 {
                    onPrevious()
                } else {
                    onNext()
                }
            }
    }
}

#Preview {
    VStack(spacing: 20) {
        PeriodNavigationHeader(
            currentLabel: "Diciembre 2025",
            onPrevious: { print("prev") },
            onNext: { print("next") },
            onTapLabel: { print("tap") }
        )
        .padding()

        PeriodNavigationHeader(
            currentLabel: "2024",
            onPrevious: { print("prev") },
            onNext: { print("next") },
            onTapLabel: { print("tap") },
            canGoNext: false
        )
        .padding()
    }
}
