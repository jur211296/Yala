//
//  NuevoGrupoHoja.swift
//  Yala
//
//  El contenido de la hoja de «Nuevo grupo» en Grupos: el asistente por pasos o, tras «Usar formulario», el formulario
//  de siempre con lo respondido. Es LA MISMA hoja: cambiar de uno a otro no cierra una para abrir otra. Editar un grupo
//  que ya existe no pasa por aquí (abre `GroupFormView` desde Ajustes del grupo).
//
//  El formulario lo construye quien presenta (`formulario`), con la llamada de siempre: lo respondido le llega por el
//  entorno (`\.groupFormPrefill`), no por un parámetro.
//

import SwiftUI

struct NuevoGrupoHoja<Formulario: View>: View {
    @Bindable var estado: AsistenteGrupoEstado
    let alCrear: (SplitGroup) -> Void
    /// Se creó o se descartó desde el asistente: quien presenta cierra la hoja. El formulario se cierra solo.
    let alCerrar: () -> Void
    @ViewBuilder let formulario: () -> Formulario

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            switch estado.modo {
            case .asistente:
                AsistenteGrupoView(estado: estado, alCrear: alCrear, alCerrar: alCerrar)
                    .transition(.opacity)
            case .formulario(let prefill):
                formulario()
                    .environment(\.groupFormPrefill, prefill)
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : DS.Animation.appear, value: estado.modo)
    }
}

extension EnvironmentValues {
    /// Lo respondido en el asistente de «Nuevo grupo» al pasar al formulario (`nil` en cualquier otro formulario).
    @Entry var groupFormPrefill: GroupFormPrefill? = nil
}
