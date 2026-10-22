//
//  GroupsAccountIsCompleteBlockView.swift
//  Yala
//
//  **Bloque [I]** · el bloqueo de la fila 4 de la tabla del ADR 2026-09-09 §7: hay una sesión privada
//  viva en este dispositivo y la cuenta que acaba de firmar lleva **Yala completo**.
//
//  POR QUÉ SE BLOQUEA Y NO SE RESUELVE. Aceptarla sería juntar dos datasets personales —el privado de
//  este móvil y el que esa cuenta ya tiene en la nube— y esa fusión no existe en el modelo: el ADR la
//  descartó explícitamente («se descartó migrar una sesión privada sobre una cuenta en la nube que ya
//  tiene datos porque sería una fusión de dos datasets personales, que no existe y no conviene
//  construir»). Lo único honesto es pararlo y contar por qué.
//
//  LO QUE ESTA PANTALLA NO HACE, Y ES EL CRITERIO DE ACEPTACIÓN: **ninguna escritura**. Ni el latch de
//  historial de Grupos, ni el desarme del boot-wipe, ni el registro del consent. Los arma el closure de
//  éxito de `GroupsBackendInviteModifier`, que corta antes de llegar a ellos.
//
//  LA SEGUNDA SALIDA es texto y no botón, a propósito y con su motivo medido: «usar esa cuenta como mi
//  Yala» se decide en Ajustes → «¿Dónde viven tus datos?», y hoy no hay ningún intent de router que
//  navegue hasta esa fila (es un `NavigationLink(value:)` dentro de `ProfileView`). Cablearlo pide un
//  intent nuevo y tocar Ajustes, que es alcance de otro paso; tiene ticket propio. Mandar a la persona
//  con una instrucción exacta es mejor que un botón que no lleva a donde dice.
//

import SwiftUI

struct GroupsAccountIsCompleteBlockView: View {
    /// Soltar la cuenta rechazada y volver a ofrecer el sign-in.
    var onUseAnotherAccount: () -> Void
    /// Cerrar sin hacer nada. El recorrido se detuvo a propósito.
    var onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    Spacer(minLength: DS.Spacing.xxl)

                    Image(systemName: "person.crop.circle.badge.exclamationmark")
                        .font(.system(size: 52)) // A11Y-DT: icono decorativo hero, tamaño fijo intencional (patrón GroupsSignInView)
                        .foregroundStyle(DS.Semantic.warningForeground)
                        .accessibilityHidden(true)

                    VStack(spacing: DS.Spacing.sm) {
                        Text(L10n.Groups.AccountIsComplete.title)
                            .font(DS.Typography.title2)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)
                        Text(L10n.Groups.AccountIsComplete.body)
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, DS.Spacing.lg)
                    }

                    VStack(spacing: DS.Spacing.md) {
                        YalaPrimaryButton(L10n.Groups.AccountIsComplete.useAnotherAccount) {
                            DS.Haptic.selection()
                            onUseAnotherAccount()
                        }
                        .accessibilityIdentifier("groups_account_complete_use_another")

                        Button(L10n.Common.understood) {
                            onDismiss()
                        }
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("groups_account_complete_dismiss")
                    }
                    .padding(.horizontal, DS.Spacing.xl)

                    // La otra salida del ADR: dónde se decide usar esa cuenta como tu Yala.
                    Text(L10n.Groups.AccountIsComplete.settingsHint)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DS.Spacing.xl)

                    Spacer(minLength: DS.Spacing.xxl)
                }
                .padding(.vertical, DS.Spacing.xxl)
            }
            .yalaScreenBackground(.subtle)
            .navigationTitle(L10n.Groups.AccountIsComplete.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.Action.close) { onDismiss() }
                        .accessibilityIdentifier("groups_account_complete_close")
                }
            }
        }
        .accessibilityIdentifier("groups_account_complete_block")
    }
}
