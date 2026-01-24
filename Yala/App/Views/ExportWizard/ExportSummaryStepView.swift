//
//  ExportSummaryStepView.swift
//  Yala
//
//  Created by Yala Refactoring.
//

import SwiftData
import SwiftUI

struct ExportSummaryStepView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // MARK: - Properties

    let exportFilters: ExportFilters
    let exportColumns: ExportColumns

    /// Callback opcional para cuando el usuario termina el asistente.
    /// El contenedor puede usarlo para volver al inicio (por ejemplo, Ajustes).
    let onFinish: (() -> Void)?

    init(
        exportFilters: ExportFilters,
        exportColumns: ExportColumns,
        onFinish: (() -> Void)? = nil
    ) {
        self.exportFilters = exportFilters
        self.exportColumns = exportColumns
        self.onFinish = onFinish
    }

    // MARK: - State

    @State private var isExporting = false
    @State private var exportError: (any Error)?
    @State private var showErrorAlert = false
    @State private var exportedFileURL: URL?
    @State private var showShareSheet = false
    @State private var showSuccessAlert = false

    // MARK: - Body

    var body: some View {
        ZStack {
            PanelBackgroundView()

            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    headerSection

                    filtersSummarySection

                    columnsSummarySection

                    exportButtonSection
                }
                .padding(.vertical, DS.Spacing.xxl)
                .padding(.horizontal, DS.Spacing.lg)
            }
        }
        .navigationTitle(L10n.Export.summaryAndExport)
        .navigationBarTitleDisplayMode(.inline)
        .alert(L10n.Export.exportError, isPresented: $showErrorAlert, presenting: exportError) { _ in
            Button("OK", role: .cancel) {}
        } message: { error in
            if let localizedError = error as? LocalizedError {
                Text(localizedError.recoverySuggestion ?? localizedError.localizedDescription)
            } else {
                Text(error.localizedDescription)
            }
        }
        .alert(L10n.Export.exportCompleted, isPresented: $showSuccessAlert) {
            Button(L10n.Export.backToSettings) {
                closeToRoot()
            }
        } message: {
            Text(L10n.Export.csvGeneratedSuccess)
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = exportedFileURL {
                ShareSheet(
                    activityItems: [url],
                    onComplete: { completed in
                        // Solo mostramos el mensaje de éxito si realmente se completó
                        // alguna acción (guardar/compartir). Si el usuario cierra con la X,
                        // `completed` será false y no mostraremos la confirmación.
                        if completed {
                            showSuccessAlert = true
                        }
                    }
                )
                .presentationDetents([.medium, .large])
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.Export.confirmExport)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)

            Text(L10n.Export.summaryDescription)
            .font(.body)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var filtersSummarySection: some View {
        SectionBox(title: L10n.Export.filtersSummary) {
            VStack(spacing: DS.Spacing.md) {
                summaryRow(
                    label: L10n.Filters.allAccounts,
                    value: accountsSummaryText
                )

                Divider()

                summaryRow(
                    label: L10n.Export.period,
                    value: periodSummaryText
                )

                Divider()

                summaryRow(
                    label: L10n.Filters.allCategories,
                    value: categoriesSummaryText
                )

                Divider()

                summaryRow(
                    label: L10n.Transaction.tags,
                    value: tagsSummaryText
                )

                Divider()

                summaryRow(
                    label: L10n.Settings.currency,
                    value: currenciesSummaryText
                )
            }
            .padding(.vertical, DS.Spacing.lg)
        }
        .padding(.vertical, DS.Spacing.xs)
    }

    private var columnsSummarySection: some View {
        SectionBox(title: L10n.Export.columnsToExport) {
            Text(columnsSummaryText)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, DS.Spacing.lg)
                .padding(.horizontal, DS.Spacing.lg)
        }
        .padding(.vertical, 4)
    }

    private var exportButtonSection: some View {
        Menu {
            Button {
                performExport(format: .csv)
            } label: {
                Label("CSV", systemImage: "doc.text")
            }

            Button {
                performExport(format: .xlsx)
            } label: {
                Label("Excel (XLSX)", systemImage: "tablecells")
            }
        } label: {
            ZStack {
                if isExporting {
                    ProgressView()
                        .tint(.white)
                } else {
                    Label(L10n.Export.exportBtn, systemImage: "square.and.arrow.up")
                        .font(.headline)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.brandPrimary)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        }
        .disabled(isExporting)
        .padding(.top, 16)
    }

    // MARK: - Helpers UI

    private func summaryRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)
                .frame(width: 100, alignment: .leading)

            Text(value)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, DS.Spacing.lg)
    }

    // MARK: - Summary Text Generators

    private var accountsSummaryText: String {
        if exportFilters.selectedAccounts.isEmpty {
            return L10n.Export.noneSelected
        }
        return L10n.Export.accountsSelected(exportFilters.selectedAccounts.count)
    }

    private var periodSummaryText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .medium

        let from = exportFilters.dateFrom
        let to = exportFilters.dateTo
        return "\(formatter.string(from: from)) - \(formatter.string(from: to))"
    }

    private var categoriesSummaryText: String {
        let catCount = exportFilters.selectedCategories.count
        let subCount = exportFilters.selectedSubcategories.count

        // Sin filtros: interpretamos como "todas las categorías"
        if catCount == 0 && subCount == 0 {
            return L10n.Export.allCategories
        }

        // Si no hay subcategorías seleccionadas en un contexto filtrado,
        // explicitamos que no hay selección a ese nivel.
        if subCount == 0 {
            return L10n.Export.noSubcategorySelected
        }

        // Caso general: mostramos solo el conteo de subcategorías
        return L10n.Export.subcategoriesSelected(subCount)
    }

    private var tagsSummaryText: String {
        if exportFilters.selectedTagNames.isEmpty {
            return L10n.Export.allTags
        }
        return L10n.Export.accountsSelected(exportFilters.selectedTagNames.count)
    }

    private var currenciesSummaryText: String {
        if exportFilters.selectedCurrencies.isEmpty {
            return L10n.Export.allCurrencies
        }
        return exportFilters.selectedCurrencies.map { $0.rawValue }.joined(separator: ", ")
    }

    private var columnsSummaryText: String {
        exportColumns.orderedActiveColumns
            .map { $0.displayName }
            .joined(separator: ", ")
    }

    // MARK: - Actions

    private func closeToRoot() {
        if let onFinish {
            // El contenedor decide cómo cerrar (volver a Ajustes, al Home, etc.)
            onFinish()
        } else {
            // Comportamiento de respaldo: cerramos solo este nivel.
            dismiss()
        }
    }

    private func performExport(format: ExportFormat) {
        isExporting = true

        // Ejecutamos en una Task para no bloquear la UI
        Task {
            // Pequeño delay artificial para que se vea el spinner si es muy rápido
            try? await Task.sleep(nanoseconds: 500_000_000)  // 0.5s

            do {
                let result = try TransactionsExportService.export(
                    format: format,
                    using: exportFilters,
                    columns: exportColumns,
                    in: modelContext
                )

                await MainActor.run {
                    self.isExporting = false
                    self.exportedFileURL = result.fileURL
                    self.showShareSheet = true
                }
            } catch {
                await MainActor.run {
                    self.isExporting = false
                    self.exportError = error
                    self.showErrorAlert = true
                }
            }
        }
    }
}

// MARK: - Share Sheet Helper

struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil
    /// Callback opcional que indica si la actividad se completó (`true`)
    /// o si el usuario canceló (`false`).
    var onComplete: ((Bool) -> Void)? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )

        controller.completionWithItemsHandler = { _, completed, _, _ in
            // Notificamos al contenedor si la actividad se completó o no.
            onComplete?(completed)
        }

        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
