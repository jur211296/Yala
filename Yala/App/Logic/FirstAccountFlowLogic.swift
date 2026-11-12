//
//  FirstAccountFlowLogic.swift
//  Yala
//
//  Y23-07 (bienvenida 2.3, docs/onboarding-2-3/SPEC.md): el paso 1 de Primeros pasos crea la primera cuenta PREGUNTANDO
//  en vez del formulario, con los mismos datos que el formulario de cuenta: tipo, monedas (la principal y hasta tres
//  líneas en otra moneda, ANTES de guardar), nombre, saldo por moneda y, en tarjeta, día de cierre, día de pago y
//  recordatorio 0/1/3/5 (`CreditCardStatementLogic`). Aquí están las reglas, sin efectos; las guarda
//  `FirstAccountCreator` y las pinta `FirstAccountFlowView`.
//

import Foundation

nonisolated enum FirstAccountFlowLogic {

    /// Lo que la persona elige en «¿Cuál creamos primero?», en el orden de la ficha.
    enum Kind: String, CaseIterable, Equatable {
        case cash
        case checking
        case savings
        case creditCard
        /// «Todo junto»: la cuenta General de la app.
        case general

        var accountType: AccountType {
            switch self {
            case .cash: return .cash
            case .checking: return .checking
            case .savings: return .savings
            case .creditCard: return .creditCard
            case .general: return .general
            }
        }

        var isCard: Bool { self == .creditCard }

        /// Corriente, ahorros y tarjeta: la persona escribe el nombre. Efectivo y Todo junto: se le propone uno.
        var writesOwnName: Bool { self == .checking || self == .savings || self == .creditCard }

        /// El color de la cuenta, el del prototipo oficial (v35) para cada tipo.
        var colorHex: String {
            switch self {
            case .general: return "#6063F1"
            case .cash: return "#F59E0B"
            case .checking: return "#00C2CB"
            case .savings: return "#8B5CF6"
            case .creditCard: return "#FF4DA6"
            }
        }
    }

    /// Una pregunta de la conversación.
    enum Step: Equatable {
        case kind
        case currencies
        case name
        /// El saldo en la moneda `index` de la cuenta (0 = la principal).
        case balance(index: Int)
        case statementDay
        case paymentDay
        case reminder
        case done
    }

    /// Una cuenta puede llevar hasta cuatro monedas: la principal y tres líneas (decidido en la ficha Y23-07).
    static let maxCurrencies = 4

    /// La respuesta a «¿Qué día cierra?» o «¿Hasta qué día puedes pagarla?».
    enum DayAnswer: Equatable {
        case day(Int)
        case unknown
        case preferNotToSay

        var day: Int? {
            if case .day(let value) = self { return value }
            return nil
        }
    }

    /// El orden de las preguntas. Una pregunta de saldo por moneda; en tarjeta, cierre y pago, y el recordatorio solo
    /// si se sabe el día de pago (sin día de pago no hay qué recordar: se salta).
    static func steps(kind: Kind?, currencyCount: Int, paymentDay: DayAnswer?) -> [Step] {
        var steps: [Step] = [.kind, .currencies, .name]
        steps += (0..<max(1, currencyCount)).map { Step.balance(index: $0) }
        if kind?.isCard == true {
            steps += [.statementDay, .paymentDay]
            if paymentDay == nil || paymentDay?.day != nil { steps.append(.reminder) }
        }
        steps.append(.done)
        return steps
    }

    /// La pregunta que sigue a `step`.
    static func next(after step: Step, kind: Kind?, currencyCount: Int, paymentDay: DayAnswer?) -> Step {
        let all = steps(kind: kind, currencyCount: currencyCount, paymentDay: paymentDay)
        guard let index = all.firstIndex(of: step), index + 1 < all.count else { return .done }
        return all[index + 1]
    }

    /// Si se puede añadir otra moneda.
    static func canAddCurrency(count: Int) -> Bool { count < maxCurrencies }

    /// El día escrito vale si es del 1 al 31.
    static func isValidDay(_ day: Int) -> Bool { (1...31).contains(day) }

    /// Las opciones de «¿Cuándo te recordamos pagarla?»: el mismo día, 1, 3 o 5 días antes; sin día de cierre, solo el
    /// mismo día (y sin monto), como el formulario de hoy.
    static func reminderOptions(statementDay: Int?) -> [Int] {
        statementDay == nil ? [0] : CreditCardStatementLogic.reminderLeadOptions
    }

    /// El saldo que se guarda. En tarjeta lo que se debe va en negativo, como en el formulario de cuenta; en las demás el
    /// signo lo pone el botón + / − junto al campo.
    static func storedBalance(kind: Kind, magnitude: Double, isNegative: Bool) -> Double {
        let value = abs(magnitude)
        if kind.isCard { return value == 0 ? 0 : -value }
        return isNegative ? -value : value
    }

    /// «No sé, ayúdame a sacarlo» en tarjeta: lo que debes es tu límite menos lo que te queda (nunca menos de cero).
    static func cardDebt(limit: Double, remaining: Double) -> Double {
        max(0, limit - remaining)
    }

    /// «No sé, ayúdame a sacarlo» en las demás: la suma de dónde tienes dinero.
    static func helperTotal(_ parts: [Double]) -> Double {
        parts.reduce(0, +)
    }

    /// La parte usada de la barra de la tarjeta (0…1).
    static func cardUsedFraction(limit: Double, remaining: Double) -> Double {
        guard limit > 0 else { return 0 }
        return min(1, max(0, (limit - remaining) / limit))
    }

    /// El nombre que se guarda: lo escrito, recortado; si quedó vacío, el que se propone o el del tipo.
    static func finalName(typed: String, suggested: String) -> String {
        let trimmed = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? suggested : trimmed
    }

    /// Las monedas sin repetir, en el orden elegido, como mucho cuatro.
    static func normalizedCurrencies(_ codes: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for code in codes {
            let normalized = code.uppercased()
            guard !seen.contains(normalized) else { continue }
            seen.insert(normalized)
            result.append(normalized)
            if result.count == maxCurrencies { break }
        }
        return result
    }

    /// El recordatorio que se guarda: `nil` = «No me lo recuerdes» o sin día de pago.
    static func storedReminder(lead: Int?, paymentDay: DayAnswer?, statementDay: DayAnswer?) -> Int? {
        guard let lead, paymentDay?.day != nil else { return nil }
        return reminderOptions(statementDay: statementDay?.day).contains(lead) ? lead : 0
    }

    /// Si al elegir el recordatorio hay que pedir el permiso de notificaciones (Y23-17): solo si eligió uno.
    static func asksNotificationPermission(lead: Int?) -> Bool { lead != nil }
}

/// Lo que se va contestando, para guardarlo de una vez al final.
struct FirstAccountDraft: Equatable {
    var kind: FirstAccountFlowLogic.Kind?
    /// La principal primero.
    var currencies: [String]
    var name: String = ""
    /// El saldo ya con su signo, por moneda.
    var balances: [String: Double] = [:]
    var statementDay: FirstAccountFlowLogic.DayAnswer?
    var paymentDay: FirstAccountFlowLogic.DayAnswer?
    /// Días antes del pago; `nil` = sin recordatorio.
    var reminderLead: Int?

    init(mainCurrency: String) {
        currencies = [mainCurrency]
    }
}
