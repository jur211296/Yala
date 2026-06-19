//
//  GroupingReorderSheet.swift
//  Yala
//
//  Sheet for managing and reordering grouping dimensions.
//

import SwiftUI

struct GroupingReorderSheet: View {

    @Binding var state: ReportGroupingState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // Hint
                Section {
                    Text(L10n.Report.Grouping.hint)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                }

                // Active dimensions (reorderable)
                Section(L10n.Report.Grouping.active) {
                    ForEach(state.activeDimensions) { dimension in
                        activeRow(dimension)
                    }
                    .onMove { from, to in
                        state.move(from: from, to: to)
                    }
                }

                // Inactive dimensions (tap to add)
                if !state.inactiveDimensions.isEmpty {
                    Section(L10n.Report.Grouping.available) {
                        ForEach(state.inactiveDimensions) { dimension in
                            Button {
                                withAnimation {
                                    state.toggle(dimension)
                                }
                            } label: {
                                HStack(spacing: DS.Spacing.md) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.body)
                                        .foregroundStyle(DS.Semantic.successForeground)
                                        .frame(width: DS.FormRow.iconWidth)

                                    Image(systemName: dimension.iconName)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                        .frame(width: DS.FormRow.iconWidth)

                                    Text(dimension.displayName)
                                        .font(DS.Typography.body)
                                        .foregroundStyle(.primary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .yalaScreenBackground(.subtle)
            .environment(\.editMode, .constant(.active))
            .navigationTitle(L10n.Report.Grouping.drillDown)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    YalaSaveButton {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Active Row

    private func activeRow(_ dimension: ReportGroupingDimension) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: dimension.isMandatory ? "lock.fill" : "minus.circle.fill")
                .font(.body)
                .foregroundStyle(dimension.isMandatory ? Color.secondary : DS.Semantic.errorForeground)
                .frame(width: DS.FormRow.iconWidth)
                .contentShape(Rectangle())
                .onTapGesture {
                    guard !dimension.isMandatory else { return }
                    withAnimation {
                        state.toggle(dimension)
                    }
                }
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(L10n.Accessibility.remove)
                .accessibilityHidden(dimension.isMandatory)

            Image(systemName: dimension.iconName)
                .font(.body)
                .foregroundStyle(.primary)
                .frame(width: DS.FormRow.iconWidth)

            Text(dimension.displayName)
                .font(DS.Typography.body)
                .foregroundStyle(.primary)
        }
    }
}
