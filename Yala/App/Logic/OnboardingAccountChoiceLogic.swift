//
//  OnboardingAccountChoiceLogic.swift
//  Yala
//
//  Pure-logic del paso «¿Dónde está tu dinero?» del onboarding «Llevar el control».
//
//  POR QUÉ UN SOLO PASO (UX 2.2 · L1-9, decisión de Jürgen del 2026-10-13). Hasta 2.2 eran dos pantallas
//  que preguntaban lo mismo: «¿Cómo organizas tu dinero?» (todo junto / cada cuenta por separado) y, solo si
//  elegías «por separado», «¿Cuál es tu primera cuenta?» (corriente / ahorros / tarjeta / efectivo). Ahora
//  es una lista: «Todo junto en una sola cuenta» y los cuatro tipos. El saldo NO se fusiona: sigue siendo su
//  propio paso, porque la persona tiene que entender cómo se rellena (parte de la misma decisión).
//
//  QUÉ GUARDA CADA OPCIÓN, igual que guardaban los dos pasos de antes:
//   · «Todo junto» → modo `.dayToDay`, cuenta `.general`, mentalidad «patrimonial».
//   · Un tipo      → modo `.fullControl`, ese tipo, mentalidad «cashFlow».
//
//  Vive fuera del `body` por la lección de `965a4d86`: un predicado dentro de un `@ViewBuilder` no lo alcanza
//  ningún unitario. La marca de cada opción y el «Siguiente» salen de la MISMA función (`selectedChoice`),
//  para que no vuelvan a divergir como en el bug C5 del paso Propósito.
//

import Foundation

/// Una opción del paso «¿Dónde está tu dinero?».
enum OnboardingAccountChoice: Equatable {
    case single
    case type(AccountType)
}

enum OnboardingAccountChoiceLogic {

    /// Los tipos que se ofrecen además de «Todo junto», en el orden en que se pintan. `.general` no está:
    /// es la cuenta de «Todo junto», no un tipo que se elija.
    static let accountTypes: [AccountType] = [.checking, .savings, .creditCard, .cash]

    /// La opción marcada para un estado dado, o `nil` si ninguna lo está.
    ///
    /// `nil` es el estado de entrada del alta nueva (modo `.fullControl` por defecto con la cuenta `.general`
    /// sin tocar): como en el paso de tipo de cuenta de antes, nada sale elegido y «Siguiente» espera a que
    /// la persona elija. `.expensesOnly` nunca llega aquí (el paso se salta), y por eso también es `nil`.
    static func selectedChoice(mode: OnboardingUsageMode, accountType: AccountType) -> OnboardingAccountChoice? {
        switch mode {
        case .dayToDay:
            return accountType == .general ? .single : nil
        case .fullControl:
            return accountTypes.contains(accountType) ? .type(accountType) : nil
        case .expensesOnly:
            return nil
        }
    }

    /// Lo que guarda tocar una opción: el modo, el tipo de cuenta y la mentalidad financiera.
    static func apply(_ choice: OnboardingAccountChoice)
        -> (mode: OnboardingUsageMode, accountType: AccountType, mindset: String) {
        switch choice {
        case .single:
            return (.dayToDay, .general, "patrimonial")
        case .type(let type):
            return (.fullControl, type, "cashFlow")
        }
    }
}
