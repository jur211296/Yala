//
//  GroupsDetachSheet.swift
//  Yala
//
//  La hoja de soltar la cuenta de grupos: lo que pasa igual en las dos salidas arriba, y cada salida con su
//  consecuencia debajo de su botón (decisión 59 de la revisión 2.3, 9-nov). Hasta aquí era un `confirmationDialog`
//  con un párrafo: la diferencia entre conservar y quitar solo se leía si se leía entero.
//
//  Se llega desde «Cambiar de cuenta» (la fila de la cuenta en «¿Dónde viven tus datos?») y desde el aviso de un
//  bloqueo que pide soltar esa cuenta (decisión 55, G1). **No se salta nunca**: soltar la cuenta mueve datos de
//  grupos, y es la única puerta a `CloudSessionSignOut.detachGroupsAccount`.
//
//  Qué hace cada salida, leído en `GroupsAssociationDetach.action(leg:choice:)` el 2026-11-11:
//  - conservar: los gastos que pagaste (pata en una cuenta real) pierden el puntero al grupo y se quedan como registros
//    normales; los de lo que te deben o debes (pata en una cuenta de sistema) se borran.
//  - quitar: se borran las dos patas.
//  En las dos, los grupos salen del dispositivo y siguen en la cuenta.
//
//  Pura: no suelta nada. Devuelve la elección y quien la presenta actúa al cerrarse la hoja (su `onDismiss`), para que
//  el aviso que pueda salir después no choque con la hoja bajando.
//

import SwiftUI

struct GroupsDetachSheet: View {
    /// Lo que «conservar» dejaría en el Panel, con la cifra ya escrita en la moneda de cada gasto. `nil` si no hay
    /// gastos que conservar o no se pudo leer: la consecuencia sale sin cifra.
    let keepCountLine: String?
    var onChoose: (GroupsAssociationDetach.BridgedRowsChoice) -> Void
    var onCancel: () -> Void

    @State private var contentHeight: CGFloat = 0

    /// `.large` hasta medir; después, el alto del contenido (y `.large` para quien la estire). Molde de
    /// `CloudActivationSheet`.
    private var detents: Set<PresentationDetent> {
        guard contentHeight > 0 else { return [.large] }
        return [.height(contentHeight + DS.Spacing.lg), .large]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                Text(L10n.Storage.Groups.changeAccountTitle)
                    .font(DS.Typography.title2)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("storage_groups_detach_sheet")

                Text(L10n.Storage.Groups.changeAccountCommon)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("storage_groups_detach_common")

                // Conservar va primero: es la salida que no destruye nada.
                option(effect: keepCountLine ?? L10n.Storage.Groups.changeAccountKeepEffect,
                       effectID: "storage_groups_detach_keep_effect") {
                    YalaSecondaryButton(L10n.UXL19.detachKeep) { onChoose(.keep) }
                        .accessibilityIdentifier("storage_groups_detach_keep")
                }
                option(effect: L10n.Storage.Groups.changeAccountRemoveEffect,
                       effectID: "storage_groups_detach_remove_effect") {
                    YalaSecondaryButton(L10n.UXL19.detachRemove, destructive: true) { onChoose(.remove) }
                        .accessibilityIdentifier("storage_groups_detach_remove")
                }

                // La salida de no hacer nada, a la vista y sin rol (`.claude/rules/swiftui-ds.md`, confirmationDialog).
                Button(L10n.Common.cancel) { onCancel() }
                    .buttonStyle(.plain)
                    .font(DS.Typography.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.sm)
                    .contentShape(Rectangle())
                    .accessibilityIdentifier("storage_groups_detach_cancel")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.top, DS.Spacing.xxl)
            .padding(.bottom, DS.Spacing.lg)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
        }
        .scrollBounceBehavior(.basedOnSize)
        .yalaScreenBackground(.partialSheet)
        .yalaSheetDetents(detents)
        .presentationDragIndicator(.visible)
    }

    /// Un botón con su consecuencia debajo, en el mismo bloque: la consecuencia se lee pegada a lo que la provoca.
    private func option<Label: View>(effect: String, effectID: String, @ViewBuilder button: () -> Label) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            button()
            Text(effect)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(effectID)
        }
    }
}
