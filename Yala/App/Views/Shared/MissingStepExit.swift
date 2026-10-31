//
//  MissingStepExit.swift
//  Yala
//
//  La salida de «lo que falta para registrar» fuera del Panel (card 7jfp, 2026-10-31). El Panel ya decía «Crea tu primera
//  cuenta» o «Crear categorías» en la fila del hero (L3-10, card omw5); Estadísticas y Registros —su fila y el botón
//  flotante— se quedaban grises sin explicar nada. Lo que se abre es lo mismo que en el Panel: el alta de cuenta, o
//  Ajustes › Categorías cuando sembrar las de siempre no añadiría nada.
//
//  Una sola hoja por `item`, con un solo dueño en cada pantalla: la fila y el flotante piden, este modificador presenta.
//

import SwiftUI

/// Qué hoja abre la salida.
enum MissingStepExit: String, Identifiable {
    /// Sin ninguna cuenta activa: el alta de cuenta, como «Crea tu primera cuenta» del Panel.
    case createAccount
    /// Con categorías propias pero ninguna subcategoría que elegir: Ajustes › Categorías.
    case categoriesSettings

    var id: String { rawValue }
}

extension View {
    /// Presenta la salida pedida en `request`. `onDismiss` recarga la pantalla que la pidió.
    func missingStepExitSheet(
        _ request: Binding<MissingStepExit?>,
        existingAccountNames: @escaping () -> [String],
        onDismiss: @escaping () -> Void
    ) -> some View {
        sheet(item: request, onDismiss: onDismiss) { exit in
            switch exit {
            case .createAccount:
                AccountFormView(existingNames: existingAccountNames())
            case .categoriesSettings:
                ProfileView(initialDestination: .categories)
            }
        }
    }
}
