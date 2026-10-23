//
//  NewTransactionClosePresentations.swift
//  Yala
//
//  Lo que pasa al cerrar el formulario de registro (lote decidido 2.2 · 02). En su propio modificador, con tres piezas
//  como mucho: el `body` de `NewTransactionView` ya está al límite de lo que el compilador del CI tipa (`swiftui-ds.md`).
//

import SwiftUI

struct NewTransactionClosePresentations: ViewModifier {
    /// Hay algo escrito o elegido a mano (UX 2.2 · L2-4).
    let hasUnsavedInput: Bool
    @Binding var showDiscardAlert: Bool
    /// El permiso de notificaciones antes de cerrar con el aviso breve (L2-5).
    @Binding var showPrimer: Bool
    let onDiscard: () -> Void
    let onPrimerClosed: () -> Void

    func body(content: Content) -> some View {
        content
            // Con algo escrito, el gesto de bajar no cierra: pregunta, igual que la X.
            .onSheetDismissAttempt(isActive: hasUnsavedInput) { showDiscardAlert = true }
            // «Seguir editando» es la salida segura y va como `.cancel` (siempre al final en una alerta).
            .alert(L10n.UXL2.discardTitle, isPresented: $showDiscardAlert) {
                Button(L10n.Alert.discardChanges, role: .destructive) { onDiscard() }
                    .accessibilityIdentifier("new_transaction_discard_confirm")
                Button(L10n.Alert.keepEditing, role: .cancel) {}
                    .accessibilityIdentifier("new_transaction_discard_keep")
            }
            .sheet(isPresented: $showPrimer, onDismiss: onPrimerClosed) {
                NotificationPrimerSheet()
            }
    }
}
