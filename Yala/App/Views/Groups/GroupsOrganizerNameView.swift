//
//  GroupsOrganizerNameView.swift
//  Yala
//
//  G3 de Grupos-first · pasos 6 y 7 de la rama organizador: **el único dato que el alta pide, y el sitio
//  donde por fin se escribe.**
//
//  **Pantalla mínima propia y NO `OnboardingView`**, por lo medido en el spec: reusar aquella para pedir
//  un campo arrastra sus 8 steps, el planner (`skippedSteps` decide por `selectedUsageMode`, que solo se
//  fija en el step `.purpose`), el `OnboardingPrefillResolver` y el gate de la card de propósito; y su
//  `completeGroupsOnlyOnboarding` es un método privado. El molde es `GroupInviteOnboardingView`, que ya
//  pide el nombre igual — pero tampoco se reusa: aquella deriva su step de la fase REAL de un join intent
//  (`GroupJoinIntentTracker`) y aquí no hay ninguna zona a la que unirse.
//
//  **Por qué el nombre y no la divisa.** Decisión del owner (2026-08-11, punto 3): alta organizador solo
//  nombre. La divisa se deriva de la región en silencio —eso lo añade G4 al mismo escritor— y es siempre
//  editable en el grupo.
//
//  El CTA llama a `GroupsOrganizerOnboarding.completeSetup`, su ÚNICO call-site de producción: para
//  llegar hasta aquí ya se pasó la puerta (`GroupsOrganizerGateLogic`), el sign-in y el consent, que es
//  justo lo que el orden del chip exige antes de tocar `onboardingMode`.
//

import SwiftData
import SwiftUI

struct GroupsOrganizerNameView: View {
    @Environment(\.modelContext) private var modelContext

    /// El alta terminó: `ContentView` cierra el cover y pide el formulario de grupo.
    var onComplete: () -> Void

    @State private var userName: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: DS.Spacing.xl) {
                Spacer()

                Image(systemName: "person.2.badge.plus")
                    .font(.system(size: 52)) // A11Y-DT: icono decorativo hero, tamaño fijo (patrón del flujo)
                    .foregroundStyle(DS.Semantic.infoForeground)
                    .accessibilityHidden(true)

                VStack(spacing: DS.Spacing.sm) {
                    Text(L10n.Welcome.Groups.nameTitle)
                        .font(DS.Typography.title2)
                        .multilineTextAlignment(.center)

                    Text(L10n.Welcome.Groups.nameBody)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DS.Spacing.lg)
                }

                TextField(L10n.Groups.Invite.namePlaceholder, text: $userName)
                    .font(DS.Typography.body)
                    .padding(.horizontal, DS.FormRow.paddingH)
                    .padding(.vertical, DS.FormRow.paddingV)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                            .fill(.thCard)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                            .stroke(.thCardBorder, lineWidth: 1)
                    )
                    .padding(.horizontal, DS.Spacing.lg)
                    .accessibilityIdentifier("groups_organizer_name_field")

                Spacer()

                // Sin `isDisabled`: el nombre vacío es legítimo y el escritor lo resuelve al
                // `Profile.defaultName`, igual que hacen las otras dos altas. Un botón muerto aquí sería
                // la regresión del «botón muerto» de 2.0.5.
                YalaPrimaryButton(L10n.Welcome.Groups.nameCta) {
                    complete()
                }
                .accessibilityIdentifier("groups_organizer_name_cta")
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.bottom, DS.Spacing.xxl)
            }
            .dismissKeyboardOnTap()
            .yalaScreenBackground(.panel)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func complete() {
        GroupsOrganizerOnboarding.completeSetup(displayName: userName, context: modelContext)
        onComplete()
    }
}
