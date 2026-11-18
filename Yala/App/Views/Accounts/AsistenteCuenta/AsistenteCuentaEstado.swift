//
//  AsistenteCuentaEstado.swift
//  Yala
//
//  Lo respondido en el asistente de «Nueva cuenta» y por dónde va. Lo crea QUIEN PRESENTA la hoja (Ajustes › Cuentas y
//  el Panel) y lo vuelve a empezar al abrirla: el contenido de una hoja puede rehacerse sin cerrarla y su `@State` nace
//  de cero (`swiftui-ds.md`). Cada pregunta llega con el valor sugerido ya elegido.
//

import Foundation
import Observation

@MainActor
@Observable
final class AsistenteCuentaEstado {
    typealias Logica = AsistenteCuentaLogica

    enum Modo: Equatable {
        case asistente
        /// «Usar formulario»: el formulario de siempre, con lo respondido (nada si aún no se respondió nada).
        case formulario(AccountFormPrefill?)
    }

    private(set) var modo: Modo = .asistente
    var navegador = AsistenteCreacionNavegador<Logica.Paso>(inicio: .tipo)

    var tipo: Logica.Tipo = Logica.tipoSugerido
    var moneda = "USD"
    var nombre = ""
    /// La persona escribió el nombre: deja de seguir al del tipo cuando cambia el tipo.
    var nombreEditado = false
    /// El saldo tal cual se escribe (sin signo, con separadores). Vacío = empezar en 0.
    var saldoTexto = ""
    var saldoNegativo = false
    var diaDeCierre: Int?
    var diaDePago: Int?
    var recordatorio: Int? = 1
    /// iOS dejó mandar notificaciones al elegir el recordatorio.
    var avisosPermitidos = false
    /// Los nombres de las cuentas que ya existen: el nombre no puede repetir uno.
    private(set) var nombresExistentes: [String] = []
    /// Ya se empezó para esta presentación: la hoja no vuelve a empezar si su contenido se rehace.
    private(set) var empezado = false

    init() {}

    /// Arranca de cero, con la moneda principal de la persona.
    func empezar(monedaPrincipal: String, nombresExistentes: [String]) {
        modo = .asistente
        navegador = AsistenteCreacionNavegador(inicio: .tipo)
        tipo = Logica.tipoSugerido
        moneda = monedaPrincipal.uppercased()
        nombre = ""
        nombreEditado = false
        saldoTexto = ""
        saldoNegativo = false
        diaDeCierre = nil
        diaDePago = nil
        recordatorio = Logica.recordatorioSugerido(diaDeCierre: nil)
        avisosPermitidos = false
        self.nombresExistentes = nombresExistentes
        empezado = true
    }

    /// Al cerrarse la hoja: se tira lo respondido y la próxima vez empieza de cero.
    func terminar() {
        empezar(monedaPrincipal: moneda, nombresExistentes: [])
        empezado = false
    }

    /// El saldo escrito, leído: vacío vale 0 y lo que no se lee como número da `nil`.
    var saldo: Double? {
        let limpio = saldoTexto.trimmingCharacters(in: .whitespaces)
        guard !limpio.isEmpty else { return 0 }
        guard limpio.contains(where: \.isNumber) else { return nil }
        return abs(AmountInputHelper.parseDecimal(limpio))
    }

    var pasos: [Logica.Paso] { Logica.pasos(tipo: tipo, diaDePago: diaDePago) }

    var respuestas: Logica.Respuestas {
        Logica.Respuestas(tipo: tipo, moneda: moneda, nombre: nombre, saldo: saldo, saldoNegativo: saldoNegativo,
                          diaDeCierre: diaDeCierre, diaDePago: diaDePago, recordatorio: recordatorio)
    }

    var puedeSeguir: Bool {
        Logica.puedeSeguir(en: navegador.actual, respuestas, nombresExistentes: nombresExistentes)
    }

    var nombreRepetido: Bool { Logica.nombreRepetido(nombre, existentes: nombresExistentes) }

    /// El nombre que se propone para el tipo, sin repetir el de otra cuenta.
    func nombrePropuesto(_ base: String) -> String {
        Logica.nombreLibre(base, existentes: nombresExistentes)
    }

    /// Al llegar a «¿Cuándo te recordamos pagarla?»: la primera vez, el sugerido con el día de cierre que se contestó
    /// (un día antes; sin cierre, el mismo día); después, lo elegido, si sigue siendo una de las opciones.
    func prepararRecordatorio() {
        if navegador.respondidos.contains(.recordatorio) {
            ajustarRecordatorio()
        } else {
            recordatorio = Logica.recordatorioSugerido(diaDeCierre: diaDeCierre)
        }
    }

    /// Al cambiar el día de cierre, el recordatorio elegido tiene que ser una de las opciones que quedan.
    func ajustarRecordatorio() {
        guard let actual = recordatorio else { return }
        let opciones = Logica.opcionesDeRecordatorio(diaDeCierre: diaDeCierre)
        if !opciones.contains(actual) { recordatorio = Logica.recordatorioSugerido(diaDeCierre: diaDeCierre) }
    }

    /// El saldo ya se contestó con «Siguiente», o se escribió algo en su pregunta.
    var saldoRespondido: Bool {
        navegador.respondidos.contains(.saldo) || !saldoTexto.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// «Usar formulario»: con algo respondido pasa lo respondido; sin nada, el formulario vacío de siempre.
    func usarFormulario() {
        modo = .formulario(
            navegador.tieneRespuestas ? Logica.alFormulario(respuestas, saldoRespondido: saldoRespondido) : nil)
    }
}
