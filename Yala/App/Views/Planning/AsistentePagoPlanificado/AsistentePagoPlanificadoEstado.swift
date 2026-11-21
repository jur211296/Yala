//
//  AsistentePagoPlanificadoEstado.swift
//  Yala
//
//  Lo respondido en el asistente de «Nuevo pago planificado» y por dónde va. Lo crea QUIEN PRESENTA la hoja
//  (`ScheduledPaymentsView`) y lo olvida en su `onDismiss`: el contenido de una hoja puede rehacerse sin cerrarla y su
//  `@State` nace de cero (`swiftui-ds.md`). Cada pregunta de opción llega con lo sugerido ya elegido.
//

import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class AsistentePagoPlanificadoEstado {
    typealias Logica = AsistentePagoPlanificadoLogica

    enum Modo: Equatable {
        case asistente
        /// «Usar formulario»: el formulario de siempre, con lo respondido (nada si aún no se respondió nada).
        case formulario(ScheduledPaymentWizardPrefill?)
    }

    private(set) var modo: Modo = .asistente
    var navegador = AsistenteCreacionNavegador<Logica.Paso>(inicio: .tipo)
    /// Las respuestas, en el mismo borrador que Primeros pasos: se guarda por el mismo camino.
    var draft = Logica.borradorInicial(esSuscripcion: false)
    /// El monto tal cual se escribe (con separadores).
    var montoTexto = ""
    /// La persona escribió el nombre: deja de seguir al propuesto cuando cambia el tipo.
    var nombreEditado = false
    /// Lo compartido: grupo, moneda y división (encargo del 21-nov). Sin grupo, el pago es solo tuyo.
    var reparto = AsistentePagoPlanificadoReparto()
    /// «¿Algo más?»: cuenta, descripción, etiquetas, fecha de fin y activo, con lo de un pago nuevo ya puesto.
    var extras = ScheduledPaymentWizardExtras()
    /// La persona tiene algún grupo activo: solo entonces se pregunta si es compartido. Lo lee la vista al cargar (no
    /// es una respuesta, y por eso empezar de nuevo no lo toca).
    var tieneGrupos = false
    /// Ya se preparó para esta apertura de la hoja: un contenido rehecho no vuelve a empezar.
    private(set) var preparado = false

    init() {}

    /// Arranca de cero con lo sugerido. `esSuscripcion`: se abrió desde la pestaña Suscripciones.
    func empezar(esSuscripcion: Bool, hoy: Date = .now, calendar: Calendar = .current) {
        modo = .asistente
        navegador = AsistenteCreacionNavegador(inicio: .tipo)
        draft = Logica.borradorInicial(esSuscripcion: esSuscripcion, hoy: hoy, calendar: calendar)
        montoTexto = ""
        nombreEditado = false
        reparto = AsistentePagoPlanificadoReparto()
        extras = ScheduledPaymentWizardExtras()
        preparado = true
    }

    /// Al aparecer la hoja: empieza solo si esta apertura aún no empezó (un contenido rehecho conserva lo respondido).
    func prepararSiHaceFalta(esSuscripcion: Bool) {
        guard !preparado else { return }
        empezar(esSuscripcion: esSuscripcion)
    }

    /// Al cerrarse la hoja: lo respondido se tira ya (la próxima apertura no lo enseña ni un instante) y esa apertura
    /// vuelve a empezar con lo de su pestaña.
    func olvidar() {
        empezar(esSuscripcion: false)
        preparado = false
    }

    var monto: Double? {
        let valor = AmountInputHelper.parseDecimal(montoTexto)
        return valor > 0 ? valor : nil
    }

    var respuestas: Logica.Respuestas {
        Logica.Respuestas(tieneTipo: draft.subcategoryID != nil, nombre: draft.name, monto: monto,
                          frecuencia: draft.frequency, diaDelMes: draft.dayOfMonth, fecha: draft.date,
                          conGrupo: reparto.grupoZona != nil, repartoListo: reparto.listo, fin: extras.endDate)
    }

    /// Las preguntas que tocan con lo respondido (lo compartido aparece y desaparece).
    var pasos: [Logica.Paso] {
        Logica.pasos(tieneGrupos: tieneGrupos, conGrupo: reparto.grupoZona != nil)
    }

    var puedeSeguir: Bool { Logica.puedeSeguir(en: navegador.actual, respuestas) }

    /// El pago compartido que se guarda, o `nil` si es solo tuyo.
    var compartido: ScheduledPaymentGroupPrefill? { Logica.compartido(reparto, monto: monto) }

    /// «Usar formulario»: con algo respondido pasa lo respondido; sin nada, el formulario vacío de siempre.
    func usarFormulario() {
        let prefill = navegador.tieneRespuestas
            ? Logica.alFormulario(draft, monto: monto, respondidos: navegador.respondidos,
                                  compartido: compartido, extras: extras)
            : nil
        modo = .formulario(prefill)
    }
}

/// Lo elegido en «¿Es un gasto compartido?» y «¿Cómo lo dividen?»: el grupo, la moneda y la división tal como la guarda
/// `ScheduledPayment` (valor crudo por participante según el modo), y la parte propia que sale de ella. Quién paga no
/// se pregunta: se elige al registrar cada pago desde la Bandeja (decisión de Jürgen del 21-nov, opción A).
struct AsistentePagoPlanificadoReparto: Equatable {
    /// `nil`: es solo tuyo.
    var grupoZona: String?
    var moneda = ""
    var tipo: SplitType = .equal
    var participantes: [UUID] = []
    var valores: [UUID: Double] = [:]
    var miParte: Double = 0
    /// La división cuadra y te incluye (lo mismo que exige el formulario para guardar).
    var listo = false
}
