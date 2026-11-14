//
//  WelcomeConversationLogic.swift
//  Yala
//
//  Bienvenida 2.3 · Y23-04 · la conversación de tres preguntas. Yala pregunta en un chat y la tarjeta «Tu Yala» se
//  llena arriba: 1) nombre (propone el de Google o Apple; con iCloud se escribe), 2) moneda, 3) qué llevar: «Gastos e
//  ingresos» o «Solo gastos». Las categorías van siempre por defecto (sale «Prefiero crearlas yo») y ya no se pregunta
//  dónde está el dinero ni cuánto hay: la primera cuenta es el paso 1 de «Primeros pasos». Termina en la llegada.
//
//  Fuente: prototipo oficial v35 (`08b-chat.js`, pasos `nombre`, `moneda`, `lleva`, `fin`).
//

import Foundation

enum WelcomeConversationLogic {

    enum Step: Int, CaseIterable, Equatable {
        case name
        case currency
        case tracking
        case done

        /// El nombre del paso en el embudo del alta (`MetricsUseFeature.onboardingStep`). Reusa los del onboarding de
        /// ocho pasos para que el embudo siga siendo comparable: nombre, moneda, propósito y confirmación.
        var trackingName: String {
            switch self {
            case .name: "name"
            case .currency: "currencyName"
            case .tracking: "purpose"
            case .done: "confirmation"
            }
        }
    }

    /// Lo que la persona lleva en Yala. Los dos modos de hoy («Llevar el control» y «Solo anotar») con su texto nuevo.
    enum Tracking: Equatable {
        /// «Gastos e ingresos»: lo que entra y lo que sale.
        case incomeAndExpenses
        /// «Solo gastos»: solo lo que se gasta.
        case expensesOnly

        /// El modo de uso que guarda el alta (`OnboardingUsageMode`). «Gastos e ingresos» es el día a día de una sola
        /// mirada; «Solo gastos» es el de siempre.
        var usageMode: OnboardingUsageMode {
            switch self {
            case .incomeAndExpenses: .dayToDay
            case .expensesOnly: .expensesOnly
            }
        }

        /// La mentalidad financiera que el alta de siempre guarda con cada modo (`OnboardingAccountChoiceLogic`).
        var mindset: String {
            switch self {
            case .incomeAndExpenses: "patrimonial"
            case .expensesOnly: "cashFlow"
            }
        }

        /// Con «Solo gastos» Yala crea sola la cuenta de gastos («Gastos Soles»), como hoy; con «Gastos e ingresos» la
        /// primera cuenta la crea la persona en el paso 1 de «Primeros pasos».
        var createsExpensesAccount: Bool { self == .expensesOnly }
    }

    /// El primer nombre de lo que trae Google o Apple («Ana García» → «Ana»). `nil` si no trae nada útil: entonces se
    /// pregunta «¿Cómo te llamo?» con el campo, como con iCloud.
    static func proposedName(fromProviderName fullName: String?) -> String? {
        guard let fullName else { return nil }
        let first = fullName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: { $0.isWhitespace })
            .first
            .map(String.init)
        guard let first, !first.isEmpty, !first.contains("@") else { return nil }
        return naturalCase(first)
    }

    /// Card luc1 (13-nov-2026): Apple entrega el nombre tal como está en el Apple ID, y «¿Te llamo JURGEN?» se lee a gritos.
    /// Un nombre todo en mayúsculas o todo en minúsculas sale con mayúscula inicial; uno con mayúsculas propias («McKenzie»,
    /// «DeAndre») se respeta tal cual.
    static func naturalCase(_ name: String) -> String {
        guard name.contains(where: \.isLetter) else { return name }
        guard name == name.uppercased() || name == name.lowercased() else { return name }
        return name.lowercased().capitalized
    }

    /// El nombre que se propone. El que trae Google o Apple, por su primer nombre; el que ya tenía la persona en su
    /// iCloud (resumen de una restauración), entero: es su nombre en Yala, no uno que haya que adivinar.
    static func proposedName(providerName: String?, restoredName: String?) -> String? {
        if let restored = restoredName?.trimmingCharacters(in: .whitespacesAndNewlines), !restored.isEmpty {
            return String(restored.prefix(maxNameLength))
        }
        return proposedName(fromProviderName: providerName)
    }

    /// La moneda propuesta: la del iCloud de la persona si la restauración la trae; si no, la de su región.
    static func proposedCurrency(restoredCode: String?, region: CurrencyCode) -> (currency: CurrencyCode, fromRegion: Bool) {
        if let restoredCode, let restored = CurrencyCode(rawValue: restoredCode) { return (restored, restored == region) }
        return (region, true)
    }

    /// El nombre que se guarda: el escrito, sin espacios a los lados. Vacío no deja seguir.
    static func acceptedName(_ typed: String) -> String? {
        let trimmed = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : String(trimmed.prefix(maxNameLength))
    }

    /// Mismo tope que el nombre de un miembro de grupo: el saludo cabe en una línea.
    static let maxNameLength = 40

    /// La moneda propuesta por la región y el atajo a dólares. Si la región ya es dólares, solo se ofrece una vez.
    static func currencyOptions(region: CurrencyCode) -> [CurrencyCode] {
        region == .usd ? [.usd] : [region, .usd]
    }

    /// La pregunta que sigue a una respuesta.
    static func step(after step: Step) -> Step {
        Step(rawValue: step.rawValue + 1) ?? .done
    }

    /// Cuántas filas de la tarjeta «Tu Yala» están llenas: los puntos de arriba.
    static func filledRows(name: String?, currency: CurrencyCode?, tracking: Tracking?) -> Int {
        [name != nil, currency != nil, tracking != nil].filter { $0 }.count
    }
}
