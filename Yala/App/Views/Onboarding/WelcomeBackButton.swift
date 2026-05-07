//
//  WelcomeBackButton.swift
//  Yala
//
//  Chevron back overlay reusado por las pantallas del flow Welcome
//  (Chooser y Onboarding step 1) — descarta la pantalla actual sin alterar
//  flags persistentes y vuelve a la anterior.
//

import SwiftUI

extension View {
    /// `nil` deja la vista intacta — útil para callbacks opcionales que solo
    /// se setean cuando la pantalla viene del flow Welcome.
    func welcomeBackButton(tint: Color, action: (() -> Void)?) -> some View {
        overlay(alignment: .topLeading) {
            if let action {
                Button {
                    DS.Haptic.selection()
                    action()
                } label: {
                    Image(systemName: "chevron.backward")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(tint)
                        .frame(width: 44, height: 44)
                }
                .padding(.leading, DS.Spacing.sm)
                .padding(.top, DS.Spacing.sm)
                .accessibilityLabel(L10n.Welcome.Invite.back)
            }
        }
    }
}
