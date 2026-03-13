//
//  ComparisonModeSelector.swift
//  Yala
//
//  P-1 / A-1 toggle for comparison mode. Used by TrendsTabView and InsightsTabView.
//

import SwiftUI
import TipKit

struct ComparisonModeSelector: View {
    @Environment(SessionState.self) private var sessionState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.yalaTheme) private var theme
    @Namespace private var namespace

    private let comparisonTip = ComparisonTip()

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            ForEach(ComparisonMode.allCases) { mode in
                selectorButton(for: mode)
            }
        }
        .popoverTip(comparisonTip)
        .onAppear {
            ComparisonTip.hasVisitedStatistics = true
        }
    }

    private func selectorButton(for mode: ComparisonMode) -> some View {
        let isSelected = sessionState.comparisonMode == mode

        return Button {
            dsWithAnimation(reduceMotion) {
                sessionState.comparisonMode = mode
            }
        } label: {
            Text(mode.shortName)
                .font(DS.Typography.labelSmall)
                .fontWeight(.semibold)
                .foregroundStyle(isSelected ? Color.white : theme.secondaryText)
                .frame(width: 32, height: 32)
                .background {
                    if isSelected {
                        Circle()
                            .fill(theme.accent)
                            .matchedGeometryEffect(id: "comparisonSelector", in: namespace)
                    } else {
                        Circle()
                            .fill(.thSecondaryText.opacity(0.08))
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mode.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
