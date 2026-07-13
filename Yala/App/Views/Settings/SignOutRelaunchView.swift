//
//  SignOutRelaunchView.swift
//  Yala
//
//  Cover TERMINAL del cierre de sesión en `.cloud` (H4): el push-all ya subió todo,
//  la sesión está cerrada y el wipe de boot está ARMADO — solo falta que el usuario
//  cierre Yala del todo y la reabra (relaunch asistido, NUNCA auto-kill; mismo patrón
//  que la relaunchCard de migración/reversa en StorageSettingsView).
//  Sin botones a propósito: no hay nada más que hacer en esta sesión del proceso.
//

import SwiftUI

struct SignOutRelaunchView: View {

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            Spacer()
            Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(L10n.Storage.Relaunch.title)
                .font(DS.Typography.title2)
                .multilineTextAlignment(.center)
            Text(L10n.Storage.Relaunch.body)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.xl)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .yalaScreenBackground(.panel)
        .interactiveDismissDisabled()
        .accessibilityIdentifier("signout_relaunch_screen")
    }
}
