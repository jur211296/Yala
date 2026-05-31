//
//  SplitTypeSegmentedSelector.swift
//  Yala
//
//  Segmented control for SplitType (percentage / equal / exact / shares).
//  Visual pattern matches TransactionTypeSelectorView (custom HStack with
//  animated capsule fill) — chosen over Picker(.segmented) for control over
//  DT XXL fallback and consistent look in iOS 26.
//
//  Lives anchored at the top of GroupExpenseFormView, replacing the previous
//  chip-menu that was hidden below the amount.
//

import SwiftUI

struct SplitTypeSegmentedSelector: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding var selectedType: SplitType
    var onTypeChange: ((SplitType) -> Void)?

    var body: some View {
        if dynamicTypeSize >= .accessibility1 {
            menuFallback
        } else {
            segmentedRow
        }
    }

    // MARK: - Segmented row (default)

    private var segmentedRow: some View {
        HStack(spacing: DS.Spacing.none) {
            ForEach(SplitType.allCases) { type in
                Button {
                    dsWithAnimation(reduceMotion) {
                        selectedType = type
                    }
                    onTypeChange?(type)
                } label: {
                    pillLabel(for: type)
                }
                .accessibilityAddTraits(selectedType == type ? .isSelected : [])
                .accessibilityLabel(type.displayName)
            }
        }
        .padding(DS.Spacing.xs)
        .background(Capsule().fill(.thCard))
    }

    private func pillLabel(for type: SplitType) -> some View {
        HStack(spacing: DS.Spacing.xxs) {
            Image(systemName: type.iconName)
                .font(.footnote.weight(selectedType == type ? .semibold : .regular))
            Text(type.displayName)
                .font(.footnote.weight(selectedType == type ? .semibold : .regular))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(selectedType == type ? .white : .secondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Chip.paddingV)
        .background(
            Capsule()
                .fill(selectedType == type ? DS.Semantic.splitMethodForeground : Color.clear)
        )
    }

    // MARK: - DT XXL fallback (Menu)

    private var menuFallback: some View {
        Menu {
            ForEach(SplitType.allCases) { type in
                Button {
                    selectedType = type
                    onTypeChange?(type)
                } label: {
                    Label(type.displayName, systemImage: type.iconName)
                }
            }
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: selectedType.iconName)
                Text(selectedType.displayName)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(Capsule().fill(DS.Semantic.splitMethodForeground))
        }
        .accessibilityLabel(selectedType.displayName)
    }
}
