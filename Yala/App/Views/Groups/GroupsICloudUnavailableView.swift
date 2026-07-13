//
//  GroupsICloudUnavailableView.swift
//  Yala
//
//  Estado explícito "Grupos necesita iCloud" (gate proactivo §i.8(c)2). Se muestra
//  en el tab Grupos cuando el device no tiene cuenta iCloud (GroupsICloudAvailability-
//  GateLogic) — en lugar del spinner/empty-state mudo. Plantilla visual de
//  GroupsBetaGateView. El CTA abre los ajustes DE LA APP (openSettingsURLString no
//  puede deep-linkear a la pantalla de iCloud) — el copy indica el camino completo.
//

import SwiftUI
import UIKit

struct GroupsICloudUnavailableView: View {
    @Environment(\.yalaTheme) private var theme
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer()

            Image(systemName: "icloud.slash")
                .font(.system(size: 44, weight: .semibold))  // A11Y-DT: ícono hero del gate
                .foregroundStyle(theme.accent)
                .frame(width: 96, height: 96)
                .background(Circle().fill(theme.accent.opacity(0.12)))

            VStack(spacing: DS.Spacing.sm) {
                Text(L10n.Groups.ICloudGate.title)
                    .font(DS.Typography.title)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text(L10n.Groups.ICloudGate.message)
                    .font(DS.Typography.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            YalaPrimaryButton(L10n.Groups.ICloudGate.openSettings) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            .accessibilityIdentifier("groups_icloud_gate_open_settings")
        }
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.vertical, DS.Spacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .yalaScreenBackground(.panel)
        .accessibilityIdentifier("groups_icloud_gate")
    }
}

#Preview {
    GroupsICloudUnavailableView()
}
