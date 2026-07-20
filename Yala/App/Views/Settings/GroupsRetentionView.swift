//
//  GroupsRetentionView.swift
//  Yala
//
//  D1 — Retención «Seguir con mis grupos» (estudio MODO-NUBE-GESTION-DATOS-UX.md §3.3.2).
//  Pantalla de éxito tras «Vaciar mis datos» CON grupos vivos: el usuario elige seguir usando
//  Yala solo para sus grupos (shell reducida vía `usageFocus == .groupsOnly`) o empezar de cero
//  (comportamiento actual: Welcome/onboarding). Presentada como `fullScreenCover` desde ContentView.
//
//  Tono: cálido, JAMÁS dark pattern — ambas salidas son cards completas y accesibles. Con deudas
//  pendientes se DESTACA «Solo mis grupos» (protege a terceros de «desaparecer debiendo»).
//

import SwiftUI

struct GroupsRetentionView: View {
    /// El usuario tenía saldos pendientes en sus grupos → destaca «Solo mis grupos».
    let hasDebt: Bool
    /// Señal «Solo mis grupos» hacia ContentView (setea la acción pendiente + cierra el cover).
    /// El write de `usageFocus = .groupsOnly` lo hace ESTA vista (tiene el env); la navegación
    /// (tab Grupos + montar MainTabView) corre en el `onDismiss` del cover (anti-carrera).
    let onGroupsOnly: () -> Void
    /// Señal «Empezar de cero» hacia ContentView. El write de `usageFocus = .full` lo hace esta vista;
    /// el ruteo a Welcome/onboarding corre en el `onDismiss`.
    let onStartFresh: () -> Void

    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences

    var body: some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer(minLength: DS.Spacing.xxl)

            Image(systemName: "person.2.fill")
                .font(.system(size: 56))  // A11Y-DT: icono decorativo de héroe, escala fija intencional
                .foregroundStyle(theme.accent)
                .accessibilityHidden(true)

            VStack(spacing: DS.Spacing.md) {
                Text(L10n.Settings.retentionTitle)
                    .font(DS.Typography.title)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(L10n.Settings.retentionQuestion)
                    .font(DS.Typography.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, DS.Spacing.lg)

            Spacer(minLength: DS.Spacing.lg)

            VStack(spacing: DS.Spacing.md) {
                choiceCard(
                    title: L10n.Settings.retentionGroupsOnly,
                    subtitle: L10n.Settings.retentionGroupsOnlySubtitle,
                    icon: "person.2.fill",
                    emphasized: hasDebt,
                    identifier: "retention_groups_only",
                    action: {
                        // Write directo (seguro: MainTabView no está montado, no presenta nada).
                        appPreferences.usageFocus = .groupsOnly
                        onGroupsOnly()
                    })

                if hasDebt {
                    Text(L10n.Settings.retentionDebtNote)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, DS.Spacing.sm)
                }

                choiceCard(
                    title: L10n.Settings.retentionStartFresh,
                    subtitle: L10n.Settings.retentionStartFreshSubtitle,
                    icon: "sparkles",
                    emphasized: false,
                    identifier: "retention_start_fresh",
                    action: {
                        appPreferences.usageFocus = .full
                        onStartFresh()
                    })
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.xxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .yalaScreenBackground(.subtle)
    }

    /// Card tappable título + subtítulo. `emphasized` la tiñe con el acento (destaca «Solo mis
    /// grupos» con deudas); si no, card neutra — ambas igual de tocables (no dark pattern).
    @ViewBuilder
    private func choiceCard(
        title: String, subtitle: String, icon: String,
        emphasized: Bool, identifier: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: DS.FormRow.iconSpacing) {
                Image(systemName: icon)
                    .font(DS.Typography.label)
                    .foregroundStyle(emphasized ? .white : theme.accent)
                    .frame(width: DS.FormRow.iconWidth, height: DS.FormRow.iconWidth)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(emphasized ? theme.accent : theme.accent.opacity(0.12))
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(title)
                        .font(DS.Typography.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }
            .padding(.horizontal, DS.FormRow.paddingH)
            .padding(.vertical, DS.FormRow.paddingV)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .solidCard(radius: DS.Radius.xl)
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl)
                .strokeBorder(emphasized ? theme.accent : Color.clear, lineWidth: emphasized ? 1.5 : 0)
        )
        .dsSubtleShadow()
        .accessibilityIdentifier(identifier)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle)")
    }
}
