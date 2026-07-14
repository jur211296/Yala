//
//  SignOutRelaunchView.swift
//  Yala
//
//  Cover TERMINAL del cierre de sesión en `.cloud` (H4) y de la ventana de entrada
//  secundaria (M1): el push-all ya subió todo, la sesión está cerrada y el cleanup de
//  boot está ARMADO. Decisión owner 2026-07-14: basta IR AL INICIO — al pasar a
//  background el proceso termina solo (exit-on-background en ContentView) y el próximo
//  launch aterriza fresco; el copy lo refleja (`bodyAutoExit`, distinto del `body`
//  compartido con la relaunchCard de migración/reversa, que NO auto-exita).
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
            Text(L10n.Storage.Relaunch.bodyAutoExit)
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
