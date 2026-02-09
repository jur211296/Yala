//
//  ExportColumnsStepView.swift
//  Yala
//
//  Created by Yala Refactoring.
//

import SwiftUI

struct ExportColumnsStepView: View {
    @Environment(\.dismiss) private var dismiss

    // MARK: - Properties

    /// Filtros configurados en el paso anterior (Paso 1).
    let exportFilters: ExportFilters

    /// Estado local de las columnas seleccionadas.
    /// Se inicializa con todas las columnas activas por defecto.
    @State private var exportColumns: ExportColumns = .default

    /// Callback opcional para cuando el usuario termina el asistente.
    let onFinish: (() -> Void)?

    // MARK: - Computed Properties

    private var isValid: Bool {
        exportColumns.hasAtLeastOneActiveColumn
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            PanelBackgroundView()

            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    headerSection

                    columnsListSection
                }
                .padding(.vertical, DS.Spacing.xxl)
                .padding(.horizontal, DS.Spacing.lg)
            }
        }
        .navigationTitle(L10n.Export.selectColumns)
        .navigationBarTitleDisplayMode(.inline)
        // Botón "Atrás" estándar del NavigationStack
        .swipeBack()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                YalaToolbarButton(systemName: "chevron.left", label: "Atrás") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    ExportSummaryStepView(
                        exportFilters: exportFilters,
                        exportColumns: exportColumns,
                        onFinish: onFinish
                    )
                } label: {
                    Text(L10n.Common.next)
                }
                .disabled(!isValid)
                .accessibilityHint(!isValid ? "Selecciona al menos una columna" : "")
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.Export.customizeFile)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)

            Text(L10n.Export.columnsDescription)
            .font(DS.Typography.body)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var columnsListSection: some View {
        SectionBox(title: L10n.Export.availableColumns) {
            VStack(spacing: DS.Spacing.none) {
                ForEach(Array(ExportColumns.defaultOrder.enumerated()), id: \.element.id) {
                    index, column in
                    columnRow(for: column)

                    if index < ExportColumns.defaultOrder.count - 1 {
                        Divider()
                            .padding(.leading, 16)
                    }
                }
            }
        }
    }

    private func columnRow(for column: ExportColumn) -> some View {
        Toggle(
            isOn: Binding(
                get: {
                    exportColumns.activeColumns.contains(column)
                },
                set: { isActive in
                    exportColumns.set(column, isActive: isActive)
                }
            )
        ) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(column.displayName)
                    .font(DS.Typography.bodyBold)
                    .foregroundStyle(.primary)

                Text(column.description)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, DS.Spacing.md)
        }
        .toggleStyle(SwitchToggleStyle(tint: Color.brandPrimary))
        .padding(.horizontal, DS.Spacing.lg)
    }
}

#Preview {
    NavigationStack {
        ExportColumnsStepView(exportFilters: .default, onFinish: nil)
    }
}
