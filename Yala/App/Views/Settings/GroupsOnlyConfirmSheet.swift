//
//  GroupsOnlyConfirmSheet.swift
//  Yala
//
//  La ida a «Solo grupos» desde Yala completo (card p0iu): «¿Usar Yala solo para grupos?» con los textos del lienzo.
//  La línea de Pro sale solo a quien tiene Pro: la suscripción sigue cobrándose aunque no vea nada de Pro.
//

import SwiftUI

struct GroupsOnlyConfirmSheet: View {
    @Environment(\.yalaTheme) private var theme

    let showsProLine: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @ScaledMetric(relativeTo: .largeTitle) private var heroSize: CGFloat = 56 // A11Y-DT: @ScaledMetric

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            ScrollView {
                VStack(spacing: DS.Spacing.lg) {
                    Image(systemName: "person.3.fill")
                        .font(DS.Typography.title2)
                        .foregroundStyle(theme.onFill(.orange))
                        .frame(width: heroSize, height: heroSize)
                        .background(Color.orange, in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                        .accessibilityHidden(true)
                        .padding(.top, DS.Spacing.xl)

                    Text(L10n.UsageMode.leaveTitle)
                        .font(DS.Typography.title2.bold())
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)

                    Text(L10n.UsageMode.leaveBody)
                        .font(DS.Typography.body)
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        line(icon: "checkmark", tint: DS.Semantic.successForeground, text: L10n.UsageMode.leaveGroupsStay)
                        line(icon: "pause.fill", tint: Color(uiColor: .secondaryLabel), text: L10n.UsageMode.leavePaused)
                        if showsProLine {
                            line(icon: "star", tint: .orange, text: L10n.UsageMode.leavePro)
                        }
                    }
                    .padding(DS.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.card, in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
                }
                .padding(.horizontal, DS.Spacing.lg)
            }
            .scrollBounceBehavior(.basedOnSize)

            VStack(spacing: DS.Spacing.sm) {
                YalaPrimaryButton(L10n.UsageMode.leaveConfirm) {
                    onConfirm()
                }
                .accessibilityIdentifier("usage_mode_leave_confirm")
                Button(L10n.Action.cancel) {
                    onCancel()
                }
                .font(DS.Typography.body)
                .foregroundStyle(theme.accentText)
                .frame(maxWidth: .infinity, minHeight: 44)
                .accessibilityIdentifier("usage_mode_leave_cancel")
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.md)
        }
        .yalaScreenBackground(.subtle)
        .presentationDragIndicator(.visible)
    }

    private func line(icon: String, tint: Color, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
            Image(systemName: icon)
                .font(DS.Typography.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 20)
                .accessibilityHidden(true)
            Text(text)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
