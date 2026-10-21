//
//  GroupNeededForExpenseSheet.swift
//  Yala
//
//  UX 2.2 · L13-8 (decisión B de Jürgen, 2026-10-18). «Grupo» del botón + sin ningún grupo llevaba a la pestaña Grupos
//  con su estado vacío, sin decir por qué: la persona había tocado «Grupo» para apuntar un gasto. Ahora esta hoja explica
//  el paso que falta y ofrece «Crear grupo»; al crearlo, el gasto sigue, avisado («Ahora apunta el gasto»).
//

import SwiftUI

struct GroupNeededForExpenseSheet: View {
    /// «Crear grupo»: quien presenta la hoja la cierra y lleva al formulario.
    var onCreateGroup: () -> Void

    @Environment(\.dismiss) private var dismiss

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

                YalaPrimaryButton(L10n.Groups.Empty.action, icon: "plus") {
                    onCreateGroup()
                }
                .accessibilityIdentifier("group_needed_create")
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
