//
//  YalaAIChatLayoutLogic.swift
//  Yala
//
//  Dónde se abre Yala IA según el espacio de la ventana (ADR «Yala se adapta por espacio, no por dispositivo»):
//  columna junto a los datos en ancha, hoja en compacta. Nunca las dos a la vez, y el mismo «abierto» sirve a las dos,
//  así que redimensionar con el chat abierto lo mantiene abierto en la otra forma.
//

import Foundation

enum YalaAIChatLayoutLogic {
    static func showsColumn(isPresented: Bool, isRegularWidth: Bool) -> Bool {
        isPresented && isRegularWidth
    }

    static func showsSheet(isPresented: Bool, isRegularWidth: Bool) -> Bool {
        isPresented && !isRegularWidth
    }
}
