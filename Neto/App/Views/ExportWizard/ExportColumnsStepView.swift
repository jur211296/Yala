//
//  ExportColumnsStepView.swift
//  Neto
//
//  Created by Neto Refactoring.
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
                VStack(spacing: 24) {
                    headerSection

                    columnsListSection
                }
                .padding(.vertical, 24)
                .padding(.horizontal, 16)
            }
        }
        .navigationTitle("Seleccionar columnas")
        .navigationBarTitleDisplayMode(.inline)
        // Botón "Atrás" estándar del NavigationStack
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    ExportSummaryStepView(
                        exportFilters: exportFilters,
                        exportColumns: exportColumns,
                        onFinish: onFinish
                    )
                } label: {
                    Text("Siguiente")
                }
                .disabled(!isValid)
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Personaliza tu archivo")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)

            Text(
                "Elige qué columnas quieres incluir en el archivo CSV exportado. Debes seleccionar al menos una."
            )
            .font(.body)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var columnsListSection: some View {
        SectionBox(title: "Columnas disponibles") {
            VStack(spacing: 0) {
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
            VStack(alignment: .leading, spacing: 4) {
                Text(column.displayName)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)

                Text(column.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 12)
        }
        .toggleStyle(SwitchToggleStyle(tint: .black))
        .padding(.horizontal, 16)
    }
}

#Preview {
    NavigationStack {
        ExportColumnsStepView(exportFilters: .default, onFinish: nil)
    }
}
