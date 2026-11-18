//
//  NuevoPagoPlanificadoHoja.swift
//  Yala
//
//  El contenido de la hoja de «Nuevo pago planificado» en Planificación: el asistente por pasos o, tras «Usar
//  formulario», el formulario de siempre con lo respondido. Es LA MISMA hoja: cambiar de uno a otro no cierra una para
//  abrir otra. Editar un pago, crearlo desde un registro, desde Nuevo registro o desde una propuesta de pago recurrente
//  no pasa por aquí: abren el formulario directo.
//

import SwiftUI

struct NuevoPagoPlanificadoHoja: View {
    @Bindable var estado: AsistentePagoPlanificadoEstado
    /// La pestaña que se miraba: con «Suscripciones», el pago nace como suscripción (como el formulario).
    let defaultCategory: String?
    let alGuardar: (UUID) -> Void
    /// Se creó o se descartó desde el asistente: quien presenta cierra la hoja. El formulario se cierra solo
    /// (`dismiss()`).
    let alCerrar: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            switch estado.modo {
            case .asistente:
                AsistentePagoPlanificadoView(estado: estado, alGuardar: alGuardar, alCerrar: alCerrar)
                    .transition(.opacity)
            case .formulario(let prefill):
                ScheduledPaymentEditorView(
                    payment: nil,
                    defaultCategory: defaultCategory,
                    onSaved: alGuardar,
                    wizardPrefill: prefill
                )
                .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : DS.Animation.appear, value: estado.modo)
        .onAppear {
            estado.prepararSiHaceFalta(esSuscripcion: defaultCategory == PaymentCategory.subscription.rawValue)
        }
    }
}
