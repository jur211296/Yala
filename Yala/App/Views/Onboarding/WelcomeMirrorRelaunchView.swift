//
//  WelcomeMirrorRelaunchView.swift
//  Yala
//
//  R2 · el terminal del Welcome cuando el destino elegido necesita el mirror de CloudKit y este proceso
//  montó el store personal NEUTRO. Quién decide es `WelcomeMirrorRelaunchLogic`; esta vista solo lo cuenta.
//
//  COPY PROPIO, y no el `Storage.Relaunch.*` de la migración, porque el hecho que describe es otro: allí el
//  usuario está migrando un corpus que ya existe y la app se lo dice a mitad de una operación larga; aquí
//  acaba de elegir dónde quiere que vivan sus datos y todavía no tiene ninguno. Reusar aquel copy («estamos
//  terminando de mover tus datos») sería mentirle. Tono BRAND-VOICE: segunda persona, motivo antes que
//  instrucción, cero jerga — ni "mirror", ni "CloudKit", ni "contenedor".
//
//  NO auto-exita en background: `RelaunchNetLogic.shouldExitOnBackground` no contempla este terminal, y
//  ampliarlo es el chip R0. Cuando R0 aterrice, esta pantalla hereda el auto-exit y su cuerpo pasa a la
//  variante `bodyAutoExit` — está anotado en el propio chip.
//

import SwiftUI

struct WelcomeMirrorRelaunchView: View {

    var body: some View {
        WelcomeFlowScreen { logoTopSpacing in
            VStack(spacing: 0) {
                Spacer(minLength: logoTopSpacing)

                Image("YalaLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 128)
                    .colorMultiply(.white)
                    .accessibilityHidden(true)

                Spacer(minLength: DS.Spacing.lg)

                VStack(spacing: DS.Spacing.lg) {
                    Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                        .font(.system(size: 44))
                        .foregroundStyle(.white.opacity(0.8))
                        .accessibilityHidden(true)

                    Text(L10n.Welcome.MirrorRelaunch.title)
                        .font(DS.Typography.title2)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DS.Spacing.lg)

                    Text(L10n.Welcome.MirrorRelaunch.body)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DS.Spacing.xl)
                }

                Spacer(minLength: DS.Spacing.xl)
            }
        }
        .accessibilityIdentifier("welcome_mirror_relaunch")
        .interactiveDismissDisabled()
    }
}
