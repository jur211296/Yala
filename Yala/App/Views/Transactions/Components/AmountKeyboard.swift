//
//  AmountKeyboard.swift
//  Yala
//
//  El teclado de un importe en Nuevo registro (decisión 68 de la revisión 2.3: «en el iPad, el importe deja de abrir un
//  teclado flotante encima de la hoja; teclado acoplado»).
//

import SwiftUI
import UIKit

extension View {
    /// Teclado decimal en el iPhone; en el iPad, el de números y signos, que sale acoplado abajo.
    ///
    /// Medido el 2026-11-11 en el simulador del iPad Air 11 (iOS 27.2): con `.decimalPad` el iPad abre un teclado numérico
    /// en un globo flotante encima de la hoja, que tapa la descripción y la pregunta del importe, además del teclado de
    /// abajo. Pasar la hoja a tamaño de página no lo quita (medido en el mismo iPad). Con `.numbersAndPunctuation` sale
    /// solo el acoplado, con los números en la fila de arriba. Los campos que lo usan filtran lo que se escribe
    /// (`AmountInputHelper.filterAmountInput`), así que un signo de más no entra en el importe.
    ///
    /// Es el TECLADO, no la forma de la pantalla: por eso decide el aparato y no el ancho. En el iPhone (y en el Duo, que
    /// es un iPhone) no cambia nada. Pin: `KeyboardSaveBar23UITests.test_iPad_amountKeyboardIsDockedNotFloatingOverTheSheet`.
    /// Sin autocorrección: con el teclado de signos el iPad enseña sugerencias («50») que en un importe no sirven.
    func amountKeyboard() -> some View {
        keyboardType(UIDevice.current.userInterfaceIdiom == .pad ? .numbersAndPunctuation : .decimalPad)
            .autocorrectionDisabled()
    }
}
