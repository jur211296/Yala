//
//  FavoriteAmountSelection.swift
//  Yala
//
//  F1 de la revisión 2.3 (decisión 22): tocar un favorito rellena el formulario y deja el importe seleccionado con el
//  teclado abierto. Si hoy costó otra cosa se escribe encima; si no, «Guardar» (la barra de G1 sobre el teclado). Antes
//  había que borrar «12.00» a mano. Lo comparten el importe de Nuevo registro y el de origen de una transferencia entre
//  monedas (`TransferAmountInputView`): el que esté a la vista consume la petición.
//

import SwiftUI

enum FavoriteAmountSelection {
    /// Todo el texto del importe; sin importe (un favorito variable), el cursor sin selección.
    static func all(of text: String) -> TextSelection? {
        text.isEmpty ? nil : TextSelection(range: text.startIndex..<text.endIndex)
    }

    /// Lo que tarda en poder tomar el foco el campo recién pintado (el mismo margen que el foco automático al abrir).
    static let focusDelay: Duration = .milliseconds(50)
}

/// Consume la petición de seleccionar el importe cuando este campo es el que está a la vista. Mira al aparecer, porque un
/// favorito de transferencia entre monedas monta su campo en el mismo toque que hace la petición.
struct SelectsAmountOnRequest: ViewModifier {
    @Binding var request: Bool
    let isActive: Bool
    let select: () -> Void

    func body(content: Content) -> some View {
        content
            .onAppear(perform: consume)
            .onChange(of: request) { _, _ in consume() }
    }

    private func consume() {
        guard request, isActive else { return }
        request = false
        select()
    }
}

extension View {
    func selectsAmountOnRequest(_ request: Binding<Bool>, isActive: Bool, select: @escaping () -> Void) -> some View {
        modifier(SelectsAmountOnRequest(request: request, isActive: isActive, select: select))
    }
}
