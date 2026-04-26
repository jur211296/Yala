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
                    Picker(L10n.AISettings.toneSection, selection: $prefs.insightsTone) {
                        ForEach(InsightTone.allCases) { item in
                            Text(item.displayName).tag(item)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                } header: {
                    Text(L10n.AISettings.toneSection)
                }

                Section {
                    Picker(L10n.AISettings.styleSection, selection: $prefs.insightsFocus) {
                        ForEach(InsightFocus.allCases) { item in
                            Text(item.displayName).tag(item)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
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
}
