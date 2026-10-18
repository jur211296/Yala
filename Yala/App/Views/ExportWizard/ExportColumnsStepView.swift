//
//  ExportColumnsStepView.swift
//  Yala
//
//  Created by Yala Refactoring.
//

import SwiftData
import SwiftUI

struct ExportColumnsStepView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // MARK: - Properties

    /// Filtros configurados en el paso anterior (Paso 1).
    let exportFilters: ExportFilters

    /// Estado local de las columnas seleccionadas.
    /// Se inicializa con todas las columnas activas por defecto.
    @State private var exportColumns: ExportColumns = .default

    /// G5-D2: incluir un CSV aparte con los grupos del usuario. Default OFF.
    @State private var includeGroups: Bool = false

    /// G5-D2: `true` si hay grupos activos que exportar (gate de visibilidad del toggle).
    /// Los grupos existen HOY vía CloudKit (sin gate por flag — el export es read-only).
    @State private var hasExportableGroups: Bool = false

    /// Tarjeta con varias divisas (entrega 4): la columna de tarjeta solo se ofrece, y sale activada, si lo que se exporta
    /// incluye alguna tarjeta con líneas. Sin tarjetas, el paso y el fichero son los de siempre.
    @State private var hasAccountCards: Bool = false
    @State private var hasMeasuredAccountCards = false

    private var offeredColumns: [ExportColumn] {
        ExportColumns.offeredOrder(hasAccountCards: hasAccountCards)
    }

    /// Callback opcional para cuando el usuario termina el asistente.
    let onFinish: (() -> Void)?

    // MARK: - Computed Properties

    private var isValid: Bool {
        exportColumns.hasAtLeastOneActiveColumn
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.xxl) {
                headerSection

                columnsListSection

                if hasExportableGroups {
                    groupsSection
                }
            }
            .padding(.vertical, DS.Spacing.xxl)
            .padding(.horizontal, DS.Spacing.lg)
        }
        .yalaScreenBackground(.subtle)
        .navigationTitle(L10n.Export.selectColumns)
        .navigationBarTitleDisplayMode(.inline)
        // Botón "Atrás" estándar del NavigationStack
        .swipeBack()
        .onAppear {
            hasExportableGroups = GroupsExportBuilder.hasExportableGroups(in: modelContext)
            measureAccountCards()
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                YalaToolbarButton(systemName: "chevron.left", label: L10n.Action.back) {
                    dismiss()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    ExportSummaryStepView(
                        exportFilters: exportFilters,
                        exportColumns: exportColumns,
                        includeGroups: hasExportableGroups && includeGroups,
                        onFinish: onFinish
                    )
                } label: {
                    Text(L10n.Common.next)
                }
                .disabled(!isValid)
                .accessibilityHint(!isValid ? L10n.Accessibility.selectAtLeastOneColumn : "")
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.Export.customizeFile)
                .font(DS.Typography.title3)
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
                ForEach(Array(offeredColumns.enumerated()), id: \.element.id) {
                    index, column in
                    columnRow(for: column)

                    if index < offeredColumns.count - 1 {
                        Divider()
                            .padding(.leading, DS.Spacing.lg)
                    }
                }
            }
        }
    }

    /// Una sola vez por visita al paso: volver desde el resumen no vuelve a encender una columna que el usuario apagó.
    private func measureAccountCards() {
        guard !hasMeasuredAccountCards else { return }
        hasMeasuredAccountCards = true
        // Lo que se exporta, no todas las cuentas: sin ninguna tarjeta en el filtro, la columna saldría vacía.
        hasAccountCards = AccountCardIndex(accounts: exportFilters.selectedAccounts).hasCards
        if hasAccountCards { exportColumns.activate(.card) }
    }

    /// G5-D2: toggle para añadir un CSV aparte con los grupos del usuario.
    private var groupsSection: some View {
        SectionBox(title: L10n.Tab.groups) {
            Toggle(isOn: $includeGroups) {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(L10n.Export.includeGroups)
                        .font(DS.Typography.bodyBold)
                        .foregroundStyle(.primary)

                    Text(L10n.Export.includeGroupsDescription)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, DS.Spacing.md)
            }
            .toggleStyle(.switch)
            .padding(.horizontal, DS.Spacing.lg)
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
        .toggleStyle(.switch)
        .padding(.horizontal, DS.Spacing.lg)
        .accessibilityIdentifier("export_column_\(column.rawValue)")
    }
}

#Preview {
    NavigationStack {
        ExportColumnsStepView(exportFilters: .default, onFinish: nil)
    }
}
