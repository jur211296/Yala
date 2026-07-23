//
//  ForceUpdateView.swift
//  Yala
//
//  Pantalla BLOQUEANTE TERMINAL del forzado de actualización (min-version). Sin dismiss: la única
//  salida es actualizar en el App Store (o que el server baje el umbral). La presenta
//  `ForceUpdateNetModifier` en ContentView (molde `SignOutRelaunchNetModifier`), y es el blocker
//  de MÁXIMA severidad en la matriz de readiness. DARK: en prod nunca se presenta (el fetch de
//  `/config` no corre → `ForceUpdateGate.isUpdateRequired` = false).
//

import SwiftUI

struct ForceUpdateView: View {

    @Environment(\.yalaTheme) private var theme

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            Spacer()
            // A11Y-DT: icono decorativo (accessibilityHidden), tamaño fijo — molde SignOutRelaunchView.
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(theme.accent)
                .accessibilityHidden(true)
            Text(L10n.AppUpdate.Force.title)
                .font(DS.Typography.title2)
                .multilineTextAlignment(.center)
            Text(L10n.AppUpdate.Force.message)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.xl)
            Spacer()
            YalaPrimaryButton(L10n.AppUpdate.Force.updateButton, icon: "arrow.up.circle") {
                openAppStore()
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.bottom, DS.Spacing.xl)
        }
        .frame(maxWidth: .infinity)
        .yalaScreenBackground(.panel)
        .interactiveDismissDisabled()
        .accessibilityIdentifier("force_update_screen")
        .task {
            // Si el lookup aún no pobló la URL del store (nunca corrió), dispararlo para que el
            // botón "Actualizar ahora" funcione. Idempotente (cache de 24h).
            if AppUpdateService.shared.appStoreURL == nil {
                await AppUpdateService.shared.checkForUpdate()
            }
        }
    }

    private func openAppStore() {
        if let url = AppUpdateService.shared.appStoreURL {
            UIApplication.shared.open(url)
        }
    }
}
