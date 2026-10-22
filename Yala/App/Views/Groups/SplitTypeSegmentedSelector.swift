//
//  SplitTypeSegmentedSelector.swift
//  Yala
//
//  Segmented control for SplitType (equal / percentage / exact / shares),
//  rendered with short labels and no icons so the four segments fit one row.
//  Visual pattern matches TransactionTypeSelectorView (custom HStack with
//  animated capsule fill) — chosen over Picker(.segmented) for control over
//  DT XXL fallback and consistent look in iOS 26.
//
//  Lives in the expense form's split card (GroupSplitEditorCard) and at the top of
//  the split sheet of scheduled payments (GroupSplitSelectorView). Theme accent for
//  the selected segment; the track is a neutral tint so it reads on a card too.
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
        .background(Capsule().fill(Color.primary.opacity(0.06)))
    }

    private func pillLabel(for type: SplitType) -> some View {
        Text(type.shortName)
            .font(.footnote.weight(selectedType == type ? .semibold : .regular))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .foregroundStyle(selectedType == type ? .white : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.sm)
            .background(
                Capsule()
                    .fill(selectedType == type ? AnyShapeStyle(.thAccent) : AnyShapeStyle(Color.clear))
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
            .background(Capsule().fill(.thAccent))
        }
        .accessibilityLabel(selectedType.displayName)
    }
}
