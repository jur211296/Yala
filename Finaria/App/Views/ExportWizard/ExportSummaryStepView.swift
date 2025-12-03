//
//  ExportSummaryStepView.swift
//  Finaria
//
//  Created by Finaria Refactoring.
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
                VStack(spacing: 24) {
                    headerSection

                    filtersSummarySection

                    columnsSummarySection

                    exportButtonSection
                }
                .padding(.vertical, 24)
                .padding(.horizontal, 16)
            }
        }
        .navigationTitle("Resumen y Exportar")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error de exportación", isPresented: $showErrorAlert, presenting: exportError) { _ in
            Button("OK", role: .cancel) {}
        } message: { error in
            if let localizedError = error as? LocalizedError {
                Text(localizedError.recoverySuggestion ?? localizedError.localizedDescription)
            } else {
                Text(error.localizedDescription)
            }
        }
        .alert("Exportación completada", isPresented: $showSuccessAlert) {
            Button("Volver a ajustes") {
                closeToRoot()
            }
        } message: {
            Text("El archivo CSV se ha generado y compartido correctamente.")
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
        VStack(alignment: .leading, spacing: 8) {
            Text("Confirma tu exportación")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)

            Text(
                "Revisa los filtros y columnas seleccionadas antes de generar el archivo CSV."
            )
            .font(.body)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var filtersSummarySection: some View {
        SectionBox(title: "Resumen de filtros") {
            VStack(spacing: 12) {
                summaryRow(
                    label: "Cuentas",
                    value: accountsSummaryText
                )

                Divider()

                summaryRow(
                    label: "Periodo",
                    value: periodSummaryText
                )

                Divider()

                summaryRow(
                    label: "Categorías",
                    value: categoriesSummaryText
                )

                Divider()

                summaryRow(
                    label: "Etiquetas",
                    value: tagsSummaryText
                )

                Divider()

                summaryRow(
                    label: "Moneda",
                    value: currenciesSummaryText
                )
            }
            .padding(.vertical, 16)
        }
        .padding(.vertical, 4)
    }

    private var columnsSummarySection: some View {
        SectionBox(title: "Columnas a exportar") {
            Text(columnsSummaryText)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 16)
                .padding(.horizontal, 16)
        }
        .padding(.vertical, 4)
    }

    private var exportButtonSection: some View {
        Button {
            performExport()
        } label: {
            ZStack {
                if isExporting {
                    ProgressView()
                        .tint(.white)
                } else {
                    Label("Exportar a CSV", systemImage: "square.and.arrow.up")
                        .font(.headline)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.black)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
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
        .padding(.horizontal, 16)
    }

    // MARK: - Summary Text Generators

    private var accountsSummaryText: String {
        if exportFilters.selectedAccounts.isEmpty {
            return "Ninguna"  // No debería pasar por validación previa
        }
        // Aquí no tenemos el total de cuentas fácilmente accesible para comparar con "Todas",
        // pero podemos mostrar el conteo.
        return "\(exportFilters.selectedAccounts.count) seleccionadas"
    }

    private var periodSummaryText: String {
        switch exportFilters.period {
        case .thisYear: return "Este año"
        case .thisMonth: return "Este mes"
        case .thisWeek: return "Esta semana"
        case .last7Days: return "Últimos 7 días"
        case .last30Days: return "Últimos 30 días"
        case .last90Days: return "Últimos 90 días"
        case .custom:
            guard let from = exportFilters.customDateFrom, let to = exportFilters.customDateTo
            else {
                return "Personalizado (Incompleto)"
            }
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return "\(formatter.string(from: from)) - \(formatter.string(from: to))"
        }
    }

    private var categoriesSummaryText: String {
        let catCount = exportFilters.selectedCategories.count
        let subCount = exportFilters.selectedSubcategories.count

        // Sin filtros: interpretamos como "todas las categorías"
        if catCount == 0 && subCount == 0 {
            return "Todas las categorías"
        }

        // Si no hay subcategorías seleccionadas en un contexto filtrado,
        // explicitamos que no hay selección a ese nivel.
        if subCount == 0 {
            return "Ninguna subcategoría seleccionada"
        }

        // Caso general: mostramos solo el conteo de subcategorías,
        // sin mencionar el número de categorías.
        return "\(subCount) subcategorías seleccionadas"
    }

    private var tagsSummaryText: String {
        if exportFilters.selectedTagNames.isEmpty {
            return "Todas las etiquetas"
        }
        return "\(exportFilters.selectedTagNames.count) seleccionadas"
    }

    private var currenciesSummaryText: String {
        if exportFilters.selectedCurrencies.isEmpty {
            return "Todas"
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

    private func performExport() {
        isExporting = true

        // Ejecutamos en una Task para no bloquear la UI
        Task {
            // Pequeño delay artificial para que se vea el spinner si es muy rápido
            try? await Task.sleep(nanoseconds: 500_000_000)  // 0.5s

            do {
                let result = try TransactionsExportService.exportToCSV(
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
