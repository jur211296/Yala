//
//  AsistenteGrupoEstado.swift
//  Yala
//
//  Lo respondido en el asistente de «Nuevo grupo» y por dónde va. Lo crea QUIEN PRESENTA la hoja
//  (`GroupsContainerView`) y lo vuelve a empezar cada vez que la abre: el contenido de una hoja puede rehacerse sin
//  cerrarla y su `@State` nace de cero (`swiftui-ds.md`). Cada pregunta llega con el valor sugerido ya elegido.
//

import Foundation
import Observation

@MainActor
@Observable
final class AsistenteGrupoEstado {
    typealias Logica = AsistenteGrupoLogica

    enum Modo: Equatable {
        case asistente
        /// «Usar formulario»: el formulario de siempre, con lo respondido (nada si aún no se respondió nada).
        case formulario(GroupFormPrefill?)
    }

    private(set) var modo: Modo = .asistente
    var navegador = AsistenteCreacionNavegador<Logica.Paso>(inicio: .nombre)
    var respuestas = Logica.Respuestas()
    /// La persona tocó un icono (o eligió uno en «Más iconos y colores»): una idea de nombre ya no lo cambia.
    var iconoElegidoAMano = false
    /// El export de Splitwise o Tricount aceptado en la primera pregunta (se aplica al crear, como en el formulario).
    var importacion: ImportarGrupoSeleccion?

    init() {}

    /// Arranca de cero, con la moneda preferida de la persona para «Todo en una sola moneda» (como el formulario).
    func empezar(moneda: CurrencyCode) {
        modo = .asistente
        navegador = AsistenteCreacionNavegador(inicio: .nombre)
        respuestas = Logica.Respuestas(moneda: moneda)
        iconoElegidoAMano = false
        importacion = nil
    }

    var pasos: [Logica.Paso] { Logica.pasos }

    var puedeSeguir: Bool { Logica.puedeSeguir(en: navegador.actual, respuestas) }

    /// La X y el gesto de bajar preguntan antes de cerrar.
    var tieneAlgo: Bool { Logica.tieneAlgo(respondidas: navegador.tieneRespuestas, respuestas) || importacion != nil }

    func elegir(_ idea: Logica.Idea, nombre: String) {
        Logica.aplicar(idea, nombreIdea: nombre, a: &respuestas, iconoElegidoAMano: iconoElegidoAMano)
    }

    func elegir(icono: String, color: String) {
        respuestas.icono = icono
        respuestas.color = color
        iconoElegidoAMano = true
    }

    /// Lo aceptado en «Traer de Splitwise o Tricount»: propone el nombre si aún no hay uno y la moneda, como el formulario.
    func importar(_ elegido: ImportarGrupoSeleccion) {
        importacion = elegido
        if Logica.nombreLimpio(respuestas.nombre).isEmpty, let sugerido = elegido.snapshot.suggestedName {
            respuestas.nombre = sugerido
        }
        if let moneda = elegido.suggestedCurrency { respuestas.moneda = moneda }
    }

    /// «Usar formulario»: con algo respondido pasa lo respondido; sin nada, el formulario vacío de siempre.
    func usarFormulario() {
        let prefill = tieneAlgo ? Logica.alFormulario(respuestas, importacion: importacion) : nil
        modo = .formulario(prefill)
    }
}
