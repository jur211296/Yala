//
//  GroupFormDiscardPresentation.swift
//  Yala
//
//  Decisión 39 de la revisión 2.3 (F1): en «Nuevo gasto», «Saldar» y «Saldo inicial», con algo cambiado, ni la X ni el
//  gesto de bajar la hoja la cierran sin preguntar. Mismo molde que Nuevo registro (`NewTransactionClosePresentations`),
//  en su propio modificador para no alargar el `body` de cada formulario (`swiftui-ds.md`, el compilador del CI).
//

import SwiftUI

struct GroupFormDiscardPresentation: ViewModifier {
    /// Hay algo distinto de lo que había al abrir (`GroupFormDiscardLogic`).
    let hasUnsavedInput: Bool
    let title: String
    @Binding var isPresented: Bool
    let onDiscard: () -> Void

    func body(content: Content) -> some View {
        content
            // Con algo cambiado, el gesto de bajar no cierra: pregunta, igual que la X.
            .onSheetDismissAttempt(isActive: hasUnsavedInput) { isPresented = true }
            // «Seguir editando» es la salida segura y va como `.cancel` (siempre al final en una alerta).
            .alert(title, isPresented: $isPresented) {
                Button(L10n.Alert.discardChanges, role: .destructive) { onDiscard() }
                    .accessibilityIdentifier("group_form_discard_confirm")
                Button(L10n.Alert.keepEditing, role: .cancel) {}
                    .accessibilityIdentifier("group_form_discard_keep")
            }
    }
}

extension View {
    /// Pregunta antes de tirar lo escrito al cerrar con la X (quien la pinta llama `isPresented = true`) o deslizando.
    func asksBeforeDiscardingGroupForm(
        hasUnsavedInput: Bool,
        title: String,
        isPresented: Binding<Bool>,
        onDiscard: @escaping () -> Void
    ) -> some View {
        modifier(GroupFormDiscardPresentation(
            hasUnsavedInput: hasUnsavedInput, title: title, isPresented: isPresented, onDiscard: onDiscard))
    }
}
