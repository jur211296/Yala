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

    var body: some View {
        @Bindable var prefs = appPreferences

        NavigationStack {
            Form {
                Section {
                    toneMenu(prefs: prefs)
                } header: {
                    Text(L10n.AISettings.toneSection)
                }

                Section {
                    focusMenu(prefs: prefs)
                } header: {
                    Text(L10n.AISettings.styleSection)
                } footer: {
                    Text(L10n.AISettings.appliesHint)
                }
            }
            .scrollContentBackground(.hidden)
            .yalaScreenBackground(.compact)
            .tint(.primary)
            .navigationTitle(L10n.AISettings.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) { dismiss() }
                }
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

    // MARK: - Subviews

    private func toneMenu(prefs: AppPreferences) -> some View {
        Menu {
            ForEach(InsightTone.allCases) { item in
                Button(item.displayName) { prefs.insightsTone = item }
            }
        } label: {
            menuLabel(value: prefs.insightsTone.displayName)
        }
    }

    private func focusMenu(prefs: AppPreferences) -> some View {
        Menu {
            ForEach(InsightFocus.allCases) { item in
                Button(item.displayName) { prefs.insightsFocus = item }
            }
        } label: {
            menuLabel(value: prefs.insightsFocus.displayName)
        }
    }

    private func menuLabel(value: String) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Text(value)
                .foregroundStyle(.thPrimaryText)

            Spacer()

            Image(systemName: "chevron.up.chevron.down")
                .font(DS.Typography.captionSmall) // A11Y-DT: chevron icon size
                .foregroundStyle(.thPrimaryText)
        }
        .contentShape(Rectangle())
    }
}
