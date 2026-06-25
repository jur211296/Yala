//
//  GroupPickerSheet.swift
//  Yala
//
//  Selector de grupo — al crear un gasto desde el FAB del tab Grupos hay que
//  elegir a qué grupo va. Espeja la estructura de `AccountSelectorSheet`.
//  Recibe los grupos ya cargados (no necesita ModelContext).
//

import SwiftUI

struct GroupPickerSheet: View {

    @Environment(\.dismiss) private var dismiss

    let groups: [SplitGroup]
    let selectedGroupID: UUID
    let memberCount: (SplitGroup) -> Int
    let onSelect: (SplitGroup) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    SectionBox(title: "") {
                        VStack(spacing: DS.Spacing.none) {
                            ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                                if index > 0 {
                                    SubsectionDivider()
                                }
                                GroupPickerRow(
                                    group: group,
                                    subtitle: "\(L10n.Groups.Member.activeCount(memberCount(group))) · \(group.currencyCode)",
                                    isSelected: group.id == selectedGroupID
                                ) {
                                    onSelect(group)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xxl)
            }
            .yalaScreenBackground(.subtle)
            .navigationTitle(L10n.Groups.selectGroup)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Group Picker Row

private struct GroupPickerRow: View {
    let group: SplitGroup
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.md) {
                GroupIconBadge(colorHex: group.colorHex, iconName: group.iconName)

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(group.name)
                        .font(DS.Typography.body)
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(DS.Typography.headline)
                        .foregroundStyle(.thAccent)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("group_picker_row_\(group.id.uuidString)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
