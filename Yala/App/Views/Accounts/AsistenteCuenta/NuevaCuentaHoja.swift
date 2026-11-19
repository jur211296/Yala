//
//  NuevaCuentaHoja.swift
//  Yala
//
//  El contenido de la hoja de «Nueva cuenta» (Ajustes › Cuentas y el Panel): el asistente por pasos o, tras «Usar
//  formulario», el formulario de siempre con lo respondido. Es LA MISMA hoja: cambiar de uno a otro no cierra una para
//  abrir otra. Editar una cuenta que ya existe no pasa por aquí: abre el formulario directo.
//

import SwiftUI

struct NuevaCuentaHoja: View {
    @Bindable var estado: AsistenteCuentaEstado
    /// Los nombres de las cuentas que ya existen, para el formulario (el asistente los tiene en su estado).
    let nombresExistentes: [String]
    /// Se creó o se descartó desde el asistente: quien presenta cierra la hoja. El formulario se cierra solo
    /// (`dismiss()`).
    let alCerrar: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppPreferences.self) private var appPreferences

    var body: some View {
        ZStack {
            switch estado.modo {
            case .asistente:
                AsistenteCuentaView(estado: estado, alCerrar: alCerrar)
                    .transition(.opacity)
            case .formulario(let prefill):
                AccountFormView(existingNames: nombresExistentes, prefill: prefill, openedFromWizard: true)
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : DS.Animation.appear, value: estado.modo)
        // Tamaño de página, como el formulario de cuenta (decisión 7 de la revisión 2.3): en el iPad, el asistente y el
        // formulario ocupan lo mismo y pasar de uno a otro no cambia la hoja. En el iPhone es la hoja de siempre.
        .presentationSizing(.page)
        // Quien presenta puede empezar antes (Ajustes); si no (el Panel, con varios caminos que abren la hoja), se
        // empieza aquí, una vez por presentación.
        .onAppear {
            guard !estado.empezado else { return }
            estado.empezar(monedaPrincipal: appPreferences.defaultCurrencyCode.rawValue,
                           nombresExistentes: nombresExistentes)
        }
    }
}
