//
//  GroupNeededForExpenseSheet.swift
//  Yala
//
//  UX 2.2 · L13-8 (decisión B de Jürgen, 2026-10-18). «Grupo» del botón + sin ningún grupo llevaba a la pestaña Grupos
//  con su estado vacío, sin decir por qué: la persona había tocado «Grupo» para apuntar un gasto. Ahora esta hoja explica
//  el paso que falta y ofrece «Crear grupo»; al crearlo, el gasto sigue, avisado («Ahora apunta el gasto»).
//
//  Compartido (lote 3, 26-nov-2026): ya no corta el camino. Lo primero es «Apuntarlo con una persona», que lleva a
//  Compartido y abre «¿Con quién?» (escribir un nombre, sin crear un grupo); «Crear grupo» queda como segunda opción.
//

import SwiftUI

struct GroupNeededForExpenseSheet: View {
    /// «Crear grupo»: quien presenta la hoja la cierra y lleva al formulario.
    var onCreateGroup: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(SceneNavigation.self) private var navigation

    var body: some View {
        NavigationStack {
            VStack(spacing: DS.Spacing.lg) {
                ZStack {
                    Circle()
                        .fill(Color.electricIndigo.opacity(0.18))
                        .frame(width: 72, height: 72)
                    Image(systemName: "person.2.fill")
                        .font(DS.Typography.title.weight(.semibold))
                        .foregroundStyle(Color.electricIndigo)
                }
                .accessibilityHidden(true)

                Text(L10n.GroupsCreate.noGroupsTitle)
                    .font(DS.Typography.title2)
                    .foregroundStyle(.thPrimaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("group_needed_title")

                Text(L10n.Compartido.neededMessage)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: DS.Spacing.sm) {
                    YalaPrimaryButton(L10n.Compartido.neededWithPerson, icon: "person.fill") {
                        // Compartido abre «¿Con quién?» al llegar: `pendingNewGroupExpense` sin nadie elegible.
                        dismiss()
                        navigation.navigateToGroupsAndComposeExpense()
                    }
                    .accessibilityIdentifier("group_needed_with_person")

                    YalaSecondaryButton(L10n.Groups.Empty.action) {
                        onCreateGroup()
                    }
                    .accessibilityIdentifier("group_needed_create")
                }
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.vertical, DS.Spacing.lg)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .yalaScreenBackground(.partialSheet)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                    .accessibilityIdentifier("group_needed_close")
                }
            }
        }
    }
}
