//
//  AsistentePresupuestoEstado.swift
//  Yala
//
//  Lo respondido en el asistente de «Nuevo presupuesto» y por dónde va. Lo crea QUIEN PRESENTA la hoja
//  (`BudgetsListView`) y lo tira en su `onDismiss`: el contenido de una hoja puede rehacerse sin cerrarla y su `@State`
//  nace de cero (`swiftui-ds.md`). Cada pregunta llega con el valor sugerido ya elegido.
//

import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class AsistentePresupuestoEstado {
    typealias Logica = AsistentePresupuestoLogica

    enum Modo: Equatable {
        case asistente
        /// «Usar formulario»: el formulario de siempre, con lo respondido (nada si aún no se respondió nada).
        case formulario(BudgetEditorPrefill?)
    }

    private(set) var modo: Modo = .asistente
    var navegador = AsistenteCreacionNavegador<Logica.Paso>(inicio: .alcance)

    var alcance: Logica.Alcance = .all
    /// Las categorías elegidas en «¿Cuáles?», en el orden en que se tocaron (el nombre propuesto usa las dos primeras).
    var categorias: [PersistentIdentifier] = []
    var periodo: BudgetPeriodType = .monthly
    var inicio: Date = .now
    var fin: Date = .now
    /// El tope tal cual se escribe (con separadores).
    var topeTexto = ""
    var nombre = ""
    /// La persona escribió el nombre: deja de seguir al propuesto cuando cambian las categorías o el período.
    var nombreEditado = false
    var aviso: Logica.Aviso = FirstBudgetFlowLogic.proposedAlert
    /// iOS dejó mandar notificaciones al elegir el aviso: al crear se enciende el interruptor general.
    var avisosPermitidos = false

    init() {}

    /// Arranca de cero, con el tipo de la pestaña que se miraba (como el formulario, UX 2.2 · L9-3) y las fechas de
    /// «Una sola vez» de hoy a dentro de dos semanas.
    func empezar(periodo: BudgetPeriodType, calendar: Calendar = .current) {
        modo = .asistente
        navegador = AsistenteCreacionNavegador(inicio: .alcance)
        alcance = .all
        categorias = []
        self.periodo = periodo
        let hoy = calendar.startOfDay(for: .now)
        inicio = hoy
        fin = calendar.date(byAdding: .day, value: 14, to: hoy) ?? hoy
        topeTexto = ""
        nombre = ""
        nombreEditado = false
        aviso = FirstBudgetFlowLogic.proposedAlert
        avisosPermitidos = false
    }

    var tope: Double? {
        let valor = AmountInputHelper.parseDecimal(topeTexto)
        return valor > 0 ? valor : nil
    }

    var pasos: [Logica.Paso] { Logica.pasos(alcance: alcance, periodo: periodo) }

    var respuestas: Logica.Respuestas {
        Logica.Respuestas(alcance: alcance, categoriasElegidas: categorias.count, periodo: periodo, inicio: inicio,
                          fin: fin, tope: tope, nombre: nombre)
    }

    var puedeSeguir: Bool { Logica.puedeSeguir(en: navegador.actual, respuestas) }

    /// «Usar formulario»: con algo respondido pasa lo respondido; sin nada, el formulario vacío de siempre.
    func usarFormulario(subcategorias: [UUID]) {
        let prefill = navegador.tieneRespuestas
            ? Logica.alFormulario(respuestas, subcategorias: subcategorias, aviso: aviso)
            : nil
        modo = .formulario(prefill)
    }
}
