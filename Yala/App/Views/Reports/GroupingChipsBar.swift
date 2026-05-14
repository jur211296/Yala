//
//  GroupingChipsBar.swift
//  Yala
//
//  Breadcrumb bar for active grouping dimensions + "Drill down" button.
//

import SwiftUI

struct GroupingChipsBar: View {

    @Binding var state: ReportGroupingState

    @State private var showReorderSheet = false

    @Environment(\.yalaTheme) private var theme

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            // Scrollable breadcrumb
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.sm) {
                    ForEach(Array(state.activeDimensions.enumerated()), id: \.element.id) { index, dimension in
                        if index > 0 {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 8, weight: .semibold)) // A11Y-DT: SF Symbol breadcrumb separator
                                .foregroundStyle(.tertiary)
                        }

                        breadcrumbItem(dimension)
                    }
                }
            }

            // Drill down button
            drillDownButton
        }
        .sheet(isPresented: $showReorderSheet) {
            GroupingReorderSheet(state: $state)
                .presentationDetents([.large])
        }
    }

    // MARK: - Breadcrumb Item

    private func breadcrumbItem(_ dimension: ReportGroupingDimension) -> some View {
        Button {
            if !dimension.isMandatory {
                withAnimation(.easeInOut(duration: 0.2)) {
                    state.toggle(dimension)
                }
            }
        } label: {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: dimension.iconName)
                    .font(.caption)

                Text(dimension.displayName)
                    .font(DS.Typography.caption)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.sm)
            .glassEffect(.regular.interactive(), in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(dimension.displayName)
        .accessibilityAddTraits(.isSelected)
    }

    // MARK: - Drill Down Button

    private var drillDownButton: some View {
        Button {
            showReorderSheet = true
        } label: {
            HStack(spacing: DS.Spacing.xs) {
                Text(L10n.Report.Grouping.drillDown)
                    .font(DS.Typography.caption)
                Image(systemName: "chevron.down.2")
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(Capsule().fill(theme.accent))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.Report.Grouping.drillDown)
    }
}
