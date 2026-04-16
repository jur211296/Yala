//
//  SiriTipCard.swift
//  Yala
//
//  Siri tip card extracted from PanelView.
//

import SwiftUI

struct SiriTipCard: View {
    @Binding var isVisible: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "mic.badge.plus")
                .font(DS.Typography.title)
                .foregroundStyle(.tint)
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(L10n.Tips.Siri.title)
                    .font(DS.Typography.headline)

                Text(L10n.Tips.Siri.detail)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Button {
                dsWithAnimation(reduceMotion) {
                    isVisible = false
                }
            } label: {
                Image(systemName: "xmark")
                    .font(DS.Typography.caption)
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.Tips.Siri.close)
        }
        .solidCard(padding: DS.Spacing.lg, radius: DS.Radius.lg)
        .transition(.asymmetric(
            insertion: .scale(scale: 0.95).combined(with: .opacity),
            removal: .scale(scale: 0.95).combined(with: .opacity)
        ))
    }
}
