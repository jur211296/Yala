//
//  NuevoFavoritoHoja.swift
//  Yala
//
//  El contenido de la hoja de «Nuevo favorito» en Ajustes › Favoritos: el asistente por pasos o, tras «Usar
//  formulario», el formulario de siempre con lo respondido. Es LA MISMA hoja: cambiar de uno a otro no cierra una para
//  abrir otra. Editar un favorito y «Guardar como favorito» desde un registro no pasan por aquí.
//

import SwiftUI

struct NuevoFavoritoHoja: View {
    @Bindable var estado: AsistenteFavoritoEstado
    /// Se creó o se descartó desde el asistente: quien presenta cierra la hoja. El formulario se cierra solo
    /// (`dismiss()`).
    let alCerrar: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            switch estado.modo {
            case .asistente:
                AsistenteFavoritoView(estado: estado, alCerrar: alCerrar)
                    .transition(.opacity)
            case .formulario(let prefill):
                FavoriteEditorView(favorite: nil, wizardPrefill: prefill)
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : DS.Animation.appear, value: estado.modo)
    }
}
