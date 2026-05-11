//
//  DemoBanner.swift
//  Yala
//
//  Banner overlay "Vista previa · Toca para empezar" para Setup Checklist demos.
//  Aparece sobre la View real ejecutándose en `mode: .demo`.
//

import SwiftUI

struct DemoBanner: View {
    let onStartReal: () -> Void

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "eye.fill")
                .font(DS.Typography.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(L10n.SetupChecklist.Demo.bannerLabel)
                .font(DS.Typography.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: DS.Spacing.sm)

            Button(action: onStartReal) {
                Text(L10n.SetupChecklist.Demo.cta)
                    .font(DS.Typography.caption.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .accessibilityHint(L10n.SetupChecklist.Demo.ctaA11yHint)
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .background(.thCard, in: Capsule())
        .overlay(
            Capsule().stroke(Color(.separator), lineWidth: 0.5)
        )
        .padding(.horizontal, DS.Spacing.md)
        .padding(.top, DS.Spacing.md)
        .accessibilityElement(children: .combine)
    }
}
