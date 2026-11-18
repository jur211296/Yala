//
//  AsistenteCreacionNavegador.swift
//  Yala
//
//  Por dónde va un asistente de creación (`AsistenteCreacionView`), sin vista: qué pregunta se ve, a cuál vuelve
//  «Atrás», cuántas hay para la barra de progreso y a dónde lleva «Siguiente» cuando se entra desde el resumen para
//  cambiar una respuesta. Genérico en el paso: cada asistente pone su `enum` y la lista de pasos que tocan con lo
//  respondido (los pasos pueden aparecer o desaparecer: «Una sola vez» añade las fechas).
//

import Foundation

nonisolated struct AsistenteCreacionNavegador<Paso: Hashable>: Equatable {

    /// La pregunta que se ve.
    private(set) var actual: Paso
    /// Lo que se respondió con «Siguiente», en orden: «Atrás» vuelve por aquí.
    private(set) var historial: [Paso] = []
    /// Las preguntas que ya se pasaron con «Siguiente». Sirve para saber si hay algo respondido y para volver al
    /// resumen sin repetir las que ya se contestaron.
    private(set) var respondidos: Set<Paso> = []
    /// Se entró desde el resumen a cambiar una respuesta: «Siguiente» vuelve ahí en cuanto la siguiente pregunta ya
    /// esté contestada (una que aparece nueva con el cambio, como «¿Cuáles?», sí se pregunta).
    private(set) var vuelveA: Paso?

    init(inicio: Paso) {
        actual = inicio
    }

    /// Se respondió al menos una pregunta: cerrar tiene que preguntar antes de tirar nada.
    var tieneRespuestas: Bool { !respondidos.isEmpty }

    var puedeRetroceder: Bool { !historial.isEmpty }

    /// La posición de la pregunta actual (desde 0) entre las que tocan ahora.
    func indice(en pasos: [Paso]) -> Int {
        pasos.firstIndex(of: actual) ?? 0
    }

    /// «Siguiente». Devuelve `false` si `actual` ya es la última (el que llama crea).
    @discardableResult
    mutating func avanzar(en pasos: [Paso]) -> Bool {
        guard let index = pasos.firstIndex(of: actual), index + 1 < pasos.count else { return false }
        respondidos.insert(actual)
        historial.append(actual)
        var siguiente = pasos[index + 1]
        if let destino = vuelveA, respondidos.contains(siguiente) || siguiente == destino {
            siguiente = destino
            vuelveA = nil
            // Lo de en medio ya se contestó: «Atrás» desde el resumen vuelve a la que se acaba de cambiar.
        }
        actual = siguiente
        return true
    }

    /// «Atrás». Salta lo que ya no toca (una pregunta que desapareció al cambiar otra respuesta). Devuelve `false`
    /// si no hay dónde volver.
    @discardableResult
    mutating func retroceder(en pasos: [Paso]) -> Bool {
        while let anterior = historial.popLast() {
            if pasos.contains(anterior) {
                actual = anterior
                vuelveA = nil
                return true
            }
        }
        return false
    }

    /// Tocar una respuesta del resumen: se va a esa pregunta y «Siguiente» vuelve al resumen.
    mutating func cambiar(_ paso: Paso, desde resumen: Paso) {
        guard paso != actual else { return }
        historial.append(actual)
        vuelveA = resumen
        actual = paso
    }
}
