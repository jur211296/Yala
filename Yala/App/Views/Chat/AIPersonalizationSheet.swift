//
//  AIPersonalizationSheet.swift
//  Yala
//
//  Settings sheet to customize AI tone and style — accessible from ChatSheetView toolbar.
//  Settings apply globally to Insights, Chat Assistant, and Panel Hero.
//

import SwiftUI

struct AIPersonalizationSheet: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(AppPreferences.self) private var appPreferences

    @State private var showToneDialog = false
    @State private var showFocusDialog = false

    var body: some View {
        @Bindable var prefs = appPreferences

        NavigationStack {
            Form {
                Section {
                    selectionRow(
                        valueName: prefs.insightsTone.displayName,
                        action: { showToneDialog = true }
                    )
                } header: {
                    Text(L10n.AISettings.toneSection)
                }

                Section {
                    selectionRow(
                        valueName: prefs.insightsFocus.displayName,
                        action: { showFocusDialog = true }
                    )
                } header: {
                    Text(L10n.AISettings.styleSection)
                } footer: {
                    Text(L10n.AISettings.appliesHint)
                }
            }
            .navigationTitle(L10n.AISettings.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) { dismiss() }
                }
            }
            .confirmationDialog(L10n.AISettings.toneSection, isPresented: $showToneDialog, titleVisibility: .visible) {
                ForEach(InsightTone.allCases) { item in
                    Button(item.displayName) { prefs.insightsTone = item }
                }
                Button(L10n.Action.cancel, role: .cancel) {}
            }
            .confirmationDialog(L10n.AISettings.styleSection, isPresented: $showFocusDialog, titleVisibility: .visible) {
                ForEach(InsightFocus.allCases) { item in
                    Button(item.displayName) { prefs.insightsFocus = item }
                }
                Button(L10n.Action.cancel, role: .cancel) {}
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .onChange(of: appPreferences.insightsTone) { _, _ in
            InsightsLLMService.shared.invalidateCache()
        }
        .onChange(of: appPreferences.insightsFocus) { _, _ in
            InsightsLLMService.shared.invalidateCache()
        }
    }

    /// Row simple: solo valor seleccionado + chevron primary (no se duplica el label
    /// del Section header ni se muestra descripción inline).
    private func selectionRow(
        valueName: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.md) {
                Text(valueName)
                    .foregroundStyle(.thPrimaryText)

                Spacer()

                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2) // A11Y-DT: chevron icon size
                    .foregroundStyle(.thPrimaryText)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
