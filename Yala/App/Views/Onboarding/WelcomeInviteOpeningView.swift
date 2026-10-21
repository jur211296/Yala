//
//  WelcomeInviteOpeningView.swift
//  Yala
//
//  «Abriendo tu invitación…» (card z81w, 2026-10-20): lo que enseña la bienvenida mientras se abre un enlace de
//  invitación en una instalación nueva, hasta que «Conecta tu cuenta» la releve. **Sin botones, a propósito** (decisión
//  de Jürgen): la bienvenida normal dejaba tocar «Empezar» e irse por otro camino. No es un camino muerto: tiene techo
//  (`InviteOpeningLogic.ceiling`) y después vuelve la bienvenida.
//

import SwiftUI

struct WelcomeInviteOpeningView: View {

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
                    ProgressView()
                        .controlSize(.large)
                        .tint(.white)
                    Text(L10n.Welcome.InviteOpening.title)
                        .font(DS.Typography.title3)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DS.Spacing.xl)
                }
                .accessibilityElement(children: .combine)
                // El id va en el bloque del texto y no en la raíz: en la raíz lo heredaba también el logo.
                .accessibilityIdentifier("welcome_invite_opening")

                Spacer(minLength: DS.Spacing.xl)
            }
        }
        .interactiveDismissDisabled()
        // El techo cuenta desde que esto se ve, no desde que llegó el enlace.
        .onAppear { InviteOpeningState.shared.screenAppeared() }
    }
}
