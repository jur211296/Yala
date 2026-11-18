//
//  NuevoPresupuestoHoja.swift
//  Yala
//
//  El contenido de la hoja de «Nuevo presupuesto» en Planificación: el asistente por pasos o, tras «Usar formulario»,
//  el formulario de siempre con lo respondido. Es LA MISMA hoja: cambiar de uno a otro no cierra una para abrir otra.
//  Editar un presupuesto que ya existe no pasa por aquí: abre el formulario directo.
//

import SwiftUI

struct NuevoPresupuestoHoja: View {
    @Bindable var estado: AsistentePresupuestoEstado
    /// Se creó o se descartó desde el asistente: quien presenta cierra la hoja. El formulario se cierra solo
    /// (`dismiss()`).
    let alCerrar: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            switch estado.modo {
            case .asistente:
                AsistentePresupuestoView(estado: estado, alCerrar: alCerrar)
                    .transition(.opacity)
            case .formulario(let prefill):
                BudgetEditorView(budget: nil, initialPeriodType: estado.periodo, prefill: prefill)
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : DS.Animation.appear, value: estado.modo)
    }
}
