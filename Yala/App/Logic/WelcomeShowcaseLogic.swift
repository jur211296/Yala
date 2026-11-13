//
//  WelcomeShowcaseLogic.swift
//  Yala
//
//  Bienvenida 2.3 · Y23-01 (vitrina y accesos) y Y23-06 (la puerta de Grupos). Lo que la pantalla decide sin pintar
//  nada: qué funciones enseña cada puerta y en qué orden, cuándo rota sola, a dónde va cada deslizamiento y qué accesos
//  ofrece. La fuente es el prototipo oficial v35 (`07-welcome.js`, configuración «g3»): Grupos va DENTRO de la vitrina.
//

import CoreGraphics
import Foundation

enum WelcomeShowcaseLogic {

    /// Las dos puertas de la bienvenida. «Mis finanzas» es la de siempre; «Grupos» la abre «Dividir gastos con amigos»
    /// desde una función de grupos de la vitrina, y su «Volver» devuelve a «Mis finanzas».
    enum Door: Equatable {
        case finances
        case groups
    }

    /// Las funciones que enseña la vitrina. Cada una es una función real de Yala con su demo de ejemplo.
    enum Demo: String, CaseIterable, Equatable {
        case receipt     // Lee tus tickets (PRO)
        case voice       // Anota con tu voz (PRO)
        case organize    // Ordena tus gastos
        case splitAny    // Divide cualquier gasto (grupos)
        case budget      // Cuida un presupuesto
        case whoOwes     // Quién le debe a quién (grupos)
        case settle      // Salda con un toque (grupos, solo en su puerta)

        /// Foto y voz son de Yala Pro hoy: llevan el rótulo PRO.
        var isPro: Bool { self == .receipt || self == .voice }

        /// Las de grupos (las tres que enseña la puerta de Grupos).
        var isGroups: Bool { self == .splitAny || self == .whoOwes || self == .settle }
    }

    /// Los accesos de cada puerta. Grupos exige una cuenta de Yala: allí no hay iCloud.
    enum Access: Equatable {
        case google
        case apple
        case iCloud
    }

    /// Cuánto se queda cada función antes de pasar a la siguiente (el `--dur` del prototipo).
    static let dwell: Duration = .seconds(5)

    /// Seis en «Mis finanzas», con las dos de grupos intercaladas; tres en la de Grupos.
    static func demos(for door: Door) -> [Demo] {
        switch door {
        case .finances: [.receipt, .voice, .organize, .splitAny, .budget, .whoOwes]
        case .groups: [.splitAny, .whoOwes, .settle]
        }
    }

    /// Sin la entrada a la cuenta de Yala (kill-switch remoto), Google y Apple no se pintan: en «Mis finanzas» queda
    /// iCloud; en Grupos, nada más que la nota de que hace falta una cuenta.
    static func accesses(for door: Door, providersAvailable: Bool = true) -> [Access] {
        let providers: [Access] = providersAvailable ? [.google, .apple] : []
        switch door {
        case .finances: return providers + [.iCloud]
        case .groups: return providers
        }
    }

    /// ¿Se ofrece «Dividir gastos con amigos»? Desde el 13-nov va debajo de los accesos, siempre a la vista en «Mis
    /// finanzas» (antes salía dentro de la vitrina y solo con una función de grupos). Sin entrada a la cuenta de Yala
    /// sería un callejón: Grupos la exige.
    static func offersGroupsDoor(on door: Door, providersAvailable: Bool) -> Bool {
        door == .finances && providersAvailable
    }

    /// Accesibilidad de la ficha «Cómo usar esta especificación»: con Reducir movimiento la página que avanza sola se
    /// queda quieta, y VoiceOver no avanza solo. La pausa de la persona manda igual.
    static func rotatesOnItsOwn(paused: Bool, reduceMotion: Bool, voiceOver: Bool) -> Bool {
        !paused && !reduceMotion && !voiceOver
    }

    /// La siguiente función al terminar su tiempo o al deslizar hacia la izquierda. Da la vuelta al final.
    static func next(after index: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return (index + 1) % count
    }

    /// La anterior al deslizar hacia la derecha. Da la vuelta al principio.
    static func previous(before index: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return (index - 1 + count) % count
    }

    /// Un índice que siga valiendo tras cambiar de puerta (la de Grupos tiene menos funciones): vuelve al principio.
    static func clamped(_ index: Int, count: Int) -> Int {
        (0..<count).contains(index) ? index : 0
    }

    /// Distancia lateral mínima para cambiar de función al deslizar (el umbral del prototipo, 40 pt). La dirección y que
    /// el gesto sea lateral los decide `HorizontalSwipeGesture`, que no le quita el arrastre al scroll de la página.
    static let swipeThreshold: CGFloat = 40
}
