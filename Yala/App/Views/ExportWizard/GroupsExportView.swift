//
//  GroupsExportView.swift
//  Yala
//
//  D6 (§3.3.6): salida de export para quien usa Yala SOLO para grupos (sin sesión privada en este
//  dispositivo). Ese usuario no tiene transacciones personales, así que el wizard personal —que EXIGE
//  seleccionar al menos una cuenta para avanzar (`ExportFiltersStepView.isValid`)— queda
//  inutilizable. Aquí exporta DIRECTAMENTE el CSV de sus grupos (gastos, pagos y su balance)
//  vía `GroupsExportBuilder`, sin pasar por los filtros/columnas de transacciones personales.
//
//  Read-only: NO muta SwiftData ni CloudKit. Reusa `ExportedFile`/`ShareSheet` del wizard.
//

import SwiftData
import SwiftUI

struct GroupsExportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    /// El contenedor decide cómo cerrar (p.ej. volver a Ajustes). Si es `nil`, cierra este nivel.
    let onFinish: (() -> Void)?

    @State private var isExporting = false
    @State private var exportError: (any Error)?
    @State private var showErrorAlert = false
    @State private var exportedFile: ExportedFile?
    /// L19-16 (decisión de Jürgen, 2026-10-18): tras la hoja de compartir, «Listo, tu archivo está en <app>» solo si se
    /// compartió; si se cancela, nada. Antes salía «Exportación completada» también al cancelar.
    @State private var shareResult = ExportShareResult()
    /// Red defensiva (cero silencios): si los grupos desaparecen entre abrir Ajustes y exportar.
    @State private var showEmptyAlert = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    headerSection
                    exportButtonSection
                }
                .padding(.vertical, DS.Spacing.xxl)
                .padding(.horizontal, DS.Spacing.lg)
            }
            .yalaScreenBackground(.subtle)
            .navigationTitle(L10n.Settings.exportData)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        closeToRoot()
                    }
                }
            }
            .alert(L10n.Export.exportError, isPresented: $showErrorAlert, presenting: exportError) { _ in
                Button(L10n.Common.ok, role: .cancel) {}
            } message: { error in
                if let localizedError = error as? LocalizedError {
                    Text(localizedError.recoverySuggestion ?? localizedError.localizedDescription)
                } else {
                    Text(error.localizedDescription)
                }
            }
            .alert(ExportShareResult.title(for: shareResult.shownOutcome), isPresented: $shareResult.isShowingAlert) {
                Button(L10n.Export.backToSettings) { closeToRoot() }
            }
            .alert(L10n.Export.groupsOnlyEmptyTitle, isPresented: $showEmptyAlert) {
                Button(L10n.Common.ok, role: .cancel) { closeToRoot() }
            } message: {
                Text(L10n.Export.groupsOnlyEmpty)
            }
            .sheet(item: $exportedFile, onDismiss: { shareResult.sheetDidClose() }) { file in
                ShareSheet(activityItems: file.urls, onFinish: { completed, activity in
                    shareResult.record(completed: completed, activityType: activity)
                })
                .yalaSheetDetents([.medium, .large])
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.Export.groupsOnlyTitle)
                .font(DS.Typography.title3)
                .foregroundStyle(.primary)

            Text(L10n.Export.groupsOnlyDescription)
                .font(DS.Typography.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// L19-16: el botón de la app (`YalaPrimaryButton`), no un rectángulo propio.
    private var exportButtonSection: some View {
        YalaPrimaryButton(L10n.Export.exportBtn, icon: "square.and.arrow.up", isLoading: isExporting) {
            performExport()
        }
        .accessibilityIdentifier("groups_export_button")
        .accessibilityHint(isExporting ? L10n.Accessibility.exportingHint : "")
        .padding(.top, DS.Spacing.lg)
    }

    // MARK: - Actions

    private func closeToRoot() {
        if let onFinish {
            onFinish()
        } else {
            dismiss()
        }
    }

    private func performExport() {
        isExporting = true

        Task {
            // Pequeño delay para que se vea el spinner si la generación es instantánea.
            try? await Task.sleep(for: .seconds(0.3))

            do {
                if let groupsURL = try GroupsExportBuilder.exportGroupsCSV(in: modelContext) {
                    await MainActor.run {
                        self.isExporting = false
                        self.exportedFile = ExportedFile(urls: [groupsURL])
                    }
                } else {
                    // Sin grupos activos (nada que exportar) — no es un error.
                    await MainActor.run {
                        self.isExporting = false
                        self.showEmptyAlert = true
                    }
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
