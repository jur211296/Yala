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
//  R0 · AUTO-EXITA en background, y por eso el cuerpo dice «ve a la pantalla de inicio y vuelve» en vez de
//  pedir que mates la app. Quien lo decide es `RelaunchNetLogic.shouldExitOnBackground`, y su testigo es el
//  DESTINO PENDIENTE (`WelcomePendingDestinationStore`), no esta vista: el `handleScenePhase` de `YalaApp`
//  ve el scenePhase agregado del proceso y no puede leer el estado de una pantalla. El destino se persiste
//  en la misma vuelta que monta este step, así que «hay destino» ≡ «este terminal está puesto».
//
//  Solo `.background` — `.inactive` (app switcher, centro de notificaciones) JAMÁS mata el proceso.
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
