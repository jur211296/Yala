//
//  AIPersonalizationSheet.swift
//  Yala
//
//  «Tono de Yala IA»: cómo habla Yala IA (tono) y en qué se fija (estilo). Se abre desde el botón de ajustes del chat
//  y desde Ajustes › Personalización (UX 2.2 · L14-10, opción C elegida por Jürgen el 2026-10-18). Reusa el paso
//  «Hazla a tu manera» de la presentación —opciones rellenas, su descripción y un ejemplo que junta las dos— en vez de
//  los dos menús sin explicación que había.
//

import SwiftUI

struct AIPersonalizationSheet: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(AppPreferences.self) private var appPreferences

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    YalaAIPersonalizeForm()

                    // Dónde se nota lo elegido. Medido: el tono y el estilo los leen el chat, el Resumen con IA y
                    // Tendencias de Estadísticas; el Panel no (la nota vieja decía «Hero del Panel»).
                    Text(L10n.AISettings.appliesHint)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.thSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("ai_settings_applies_hint")
                }
                .padding(DS.Spacing.lg)
            }
            .scrollIndicators(.hidden)
            .yalaScreenBackground(.subtle)
            .navigationTitle(L10n.AISettings.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onChange(of: appPreferences.insightsTone) { _, _ in
            InsightsLLMService.shared.invalidateCache()
        }
        .onChange(of: appPreferences.insightsFocus) { _, _ in
            InsightsLLMService.shared.invalidateCache()
        }
    }
}
