//
//  ProTrialBadge.swift
//  Yala
//
//  Badge condicional para steps `tryVoiceInput` / `tryImageInput` del setup checklist.
//  Trial activo: capsule amber "Pro · Gratis durante setup" con icon `sparkles`.
//  Trial terminado: capsule theme.accent "Pro" simple.
//

import SwiftUI

struct ProTrialBadge: View {
    let isTrialActive: Bool

    @Environment(\.yalaTheme) private var theme

    var body: some View {
        if isTrialActive {
            HStack(spacing: DS.Spacing.xxs) {
                Image(systemName: "sparkles")
                    .font(DS.Typography.labelTiny)
                Text(L10n.SetupChecklist.Demo.proTrialBadge)
                    .font(DS.Typography.labelTiny.weight(.semibold))
            }
            .foregroundStyle(DS.Semantic.warningForeground)
            .padding(.horizontal, DS.Spacing.xs)
            .padding(.vertical, DS.Spacing.xxs)
            .background(
                Capsule().stroke(DS.Semantic.warningForeground, lineWidth: 1)
            )
        } else {
            Text(L10n.SetupChecklist.Demo.proBadge)
                .font(DS.Typography.labelTiny.weight(.semibold))
                .foregroundStyle(theme.accent)
                .padding(.horizontal, DS.Spacing.xs)
                .padding(.vertical, DS.Spacing.xxs)
                .background(
                    Capsule().stroke(theme.accent, lineWidth: 1)
                )
        }
    }
}
