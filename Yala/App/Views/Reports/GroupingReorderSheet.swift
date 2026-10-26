//
//  GroupingReorderSheet.swift
//  Yala
//
//  Sheet for managing and reordering grouping dimensions.
//
//  UX 2.2 · L18-4 (opción C): «Desglosar» y no «Profundizar». El nivel fijo «Ingresos y gastos» ya no sale como una fila
//  con candado y un asa que no arrastra: en su sitio, un ejemplo de cómo quedará la tabla con los niveles elegidos
//  («Gastos › Alimentación › Supermercados»), que cambia al añadir, quitar o reordenar.
//

import SwiftUI

struct GroupingReorderSheet: View {

    @Binding var state: ReportGroupingState
    @Environment(SessionState.self) private var sessionState
    @Environment(\.dismiss) private var dismiss

    /// «Gastos › Alimentación › Supermercados» con los niveles activos, en su orden.
    private var exampleText: String {
        state.activeDimensions.map(\.exampleValue).joined(separator: " › ")
    }

    var body: some View {
        NavigationStack {
            List {
                // Hint + ejemplo del resultado
                Section {
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        Text(L10n.Report.Grouping.hint)
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)
                        Text(L10n.UXL18.exampleTitle)
                            .font(DS.Typography.captionSmall.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.top, DS.Spacing.xs)
                        Text(exampleText)
                            .font(DS.Typography.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("report_grouping_example")
                    }
                    .listRowBackground(Color.clear)
                }

                // Active dimensions (reorderable). El fijo no se pinta.
                Section(L10n.Report.Grouping.active) {
                    if state.optionalDimensions.isEmpty {
                        Text(L10n.UXL18.onlyIncomeAndExpenses)
                            .font(DS.Typography.body)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(state.optionalDimensions) { dimension in
                            activeRow(dimension)
                        }
                        .onMove { from, to in
                            state.moveOptional(from: from, to: to)
                        }
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

                                    Text(dimension.displayName(expensesOnly: sessionState.isExpensesOnlyMode))
                                        .font(DS.Typography.body)
                                        .foregroundStyle(.primary)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("report_grouping_add_\(dimension.rawValue)")
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
            Image(systemName: "minus.circle.fill")
                .font(.body)
                .foregroundStyle(DS.Semantic.errorForeground)
                .frame(width: DS.FormRow.iconWidth)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation {
                        state.toggle(dimension)
                    }
                }
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(L10n.Accessibility.remove)

            Image(systemName: dimension.iconName)
                .font(.body)
                .foregroundStyle(.primary)
                .frame(width: DS.FormRow.iconWidth)

            Text(dimension.displayName(expensesOnly: sessionState.isExpensesOnlyMode))
                .font(DS.Typography.body)
                .foregroundStyle(.primary)
        }
        .accessibilityIdentifier("report_grouping_active_\(dimension.rawValue)")
    }
}
