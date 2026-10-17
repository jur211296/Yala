//
//  PanelNoticeQueueLogic.swift
//  Yala
//
//  Los avisos del Panel salen de uno en uno (UX 2.2 · L3-8, opción A): con datos se apilaban hasta cuatro antes de
//  «Tus finanzas» —la sugerencia de Siri, Primeros pasos, la guía «Este es tu resumen», la oferta— y las cuentas
//  quedaban a dos pantallas. Ahora se ve el más importante y un «1 de N» lleva a los demás; ninguno se pierde.
//
//  Fuera de la cola, a propósito, los dos que dicen que algo NO funciona: el de la nube que no sincroniza y el de
//  movimientos sin cuenta. Esos no compiten con una novedad.
//

import Foundation

enum PanelNotice: String, CaseIterable, Equatable {
    /// «Este es tu resumen»: la guía de la primera visita. Primero porque explica la pantalla que se está viendo.
    case panelGuide
    /// Primeros pasos.
    case setupChecklist
    /// Hay una versión nueva en la App Store.
    case updateAvailable
    /// Días de prueba de Yala Pro, u oferta periódica sin Pro.
    case proOffer
    /// Empujón a quien lleva días sin registrar.
    case nudge
    /// Sugerencia de usar Siri.
    case siriTip
}

enum PanelNoticeQueueLogic {

    /// Lo que está encendido de cada aviso, ya resuelto por el Panel con las condiciones de siempre.
    struct Flags: Equatable {
        var panelGuide = false
        var setupChecklist = false
        var updateAvailable = false
        var proOffer = false
        var nudge = false
        var siriTip = false
    }

    /// Los avisos visibles, del más importante al menos.
    static func visible(_ flags: Flags) -> [PanelNotice] {
        PanelNotice.allCases.filter { notice in
            switch notice {
            case .panelGuide: return flags.panelGuide
            case .setupChecklist: return flags.setupChecklist
            case .updateAvailable: return flags.updateAvailable
            case .proOffer: return flags.proOffer
            case .nudge: return flags.nudge
            case .siriTip: return flags.siriTip
            }
        }
    }

    /// El aviso que se enseña: el elegido si sigue en la cola; si se cerró, el que ocupa su sitio; si no queda
    /// ninguno, `nil`. Cerrar el último no deja el índice fuera de rango.
    static func current(in visible: [PanelNotice], selected: PanelNotice?) -> PanelNotice? {
        guard !visible.isEmpty else { return nil }
        if let selected, visible.contains(selected) { return selected }
        return visible.first
    }

    /// El siguiente, dando la vuelta al final.
    static func next(after notice: PanelNotice, in visible: [PanelNotice]) -> PanelNotice? {
        guard let index = visible.firstIndex(of: notice), !visible.isEmpty else { return visible.first }
        return visible[(index + 1) % visible.count]
    }
}
