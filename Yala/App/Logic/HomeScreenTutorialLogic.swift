//
//  HomeScreenTutorialLogic.swift
//  Yala
//
//  Y23-16 · Paso 7 de Primeros pasos: «Anota sin abrir Yala» (docs/onboarding-2-3/SPEC.md, prototipo oficial v35,
//  pestaña 8). Una página corta con una parte por manera y, después, un mini tutorial de cada una, todos omitibles, con
//  una pantalla entre uno y otro. Aquí viven las reglas sin efectos: qué maneras se enseñan, cuál sigue, cómo se cuenta
//  lo visto y qué le pasa al paso al salir.
//
//  El correo (Y23-19, «Tu correo, en automático») entra desde el 2026-11-13, con el buzón de yalainbox.com activo, entre
//  compartir y Siri. Solo se enseña a quien puede usarlo: con los datos en la cuenta de Yala (`BankEmailEntryLogic`, la
//  misma regla que la fila de Ajustes). Sin ella, el paso sigue con cuatro maneras.
//

import Foundation

nonisolated enum HomeScreenTutorialLogic {

    /// Una manera de anotar sin abrir Yala, en el orden de la ficha.
    enum Method: String, CaseIterable, Equatable, Sendable {
        case widget
        case applePay
        case share
        case mail
        case siri

        /// Compartir una foto es de Pro (la ficha y el prototipo llevan la insignia). El resto, gratis.
        var isPro: Bool { self == .share }
    }

    /// Cómo terminó un mini tutorial.
    enum Outcome: Equatable, Sendable {
        /// «Listo», «Ya lo configuré», «Entendido»: la app no puede saber si se hizo, se da por hecho al tocarlo.
        case done
        /// «Omitir».
        case skipped
    }

    /// Cómo se sale del paso 7.
    enum Exit: Equatable, Sendable {
        /// «Atrás» desde la primera parte: el mazo sigue en el 7.
        case closed
        /// «Omitir este paso» en la página corta.
        case skippedStep
        /// Se pasó por todas las maneras (vistas u omitidas).
        case finished(anyDone: Bool)
    }

    /// Lo que el paso 7 hace con el mazo al salir.
    enum StepResolution: Equatable, Sendable {
        case completed
        case skipped
    }

    /// Las maneras que se enseñan: cinco con el correo, cuatro sin él. `showsMail` es `BankEmailEntryLogic.showsRow`.
    static func methods(showsMail: Bool) -> [Method] {
        Method.allCases.filter { $0 != .mail || showsMail }
    }

    /// La siguiente que falta, o `nil` si ya se resolvieron todas.
    static func next(after outcomes: [Method: Outcome], in methods: [Method]) -> Method? {
        methods.first { outcomes[$0] == nil }
    }

    /// Cuántas se dieron por hechas: «¡Van N de 5!».
    static func doneCount(_ outcomes: [Method: Outcome], in methods: [Method]) -> Int {
        methods.count { outcomes[$0] == .done }
    }

    /// Lo que pasa tras resolver un mini tutorial: la pantalla de entre medias, o el final si era el último.
    static func exitAfterResolving(_ outcomes: [Method: Outcome], in methods: [Method]) -> Exit? {
        guard next(after: outcomes, in: methods) == nil else { return nil }
        return .finished(anyDone: doneCount(outcomes, in: methods) > 0)
    }

    /// Hecho si vio al menos una manera; omitido si las omitió todas o se saltó el paso; nada si solo cerró.
    static func resolution(of exit: Exit) -> StepResolution? {
        switch exit {
        case .closed: return nil
        case .skippedStep: return .skipped
        case .finished(let anyDone): return anyDone ? .completed : .skipped
        }
    }

    /// Su lugar en la lista, desde 1: «2 de 5 · Apple Pay».
    static func position(of method: Method, in methods: [Method]) -> Int {
        (methods.firstIndex(of: method) ?? 0) + 1
    }
}
