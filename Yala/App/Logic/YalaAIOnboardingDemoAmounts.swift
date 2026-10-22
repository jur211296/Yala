//
//  YalaAIOnboardingDemoAmounts.swift
//  Yala
//
//  Importes de ejemplo de la presentación de Yala IA (chat del paso 1, su tarjeta, la frase
//  del estilo «Ahorrador» y el consejo del paso 5), en la DIVISA PRINCIPAL del usuario.
//
//  Antes cada idioma traía su divisa escrita en el copy («$12», «12 €», «1.200円») y la tarjeta
//  pintaba `USD 12.00` fijo: en es-MX la demo hablaba en dólares y en japonés la burbuja y la
//  tarjeta no coincidían. Ahora el copy lleva huecos y los importes salen de una base en dólares
//  escalada con la tasa de respaldo (`fallbackRateToUSD`) y redondeada a una cifra redonda, para
//  que un almuerzo no cueste 12 yenes ni 12 pesos argentinos.
//
//  Es decoración: no convierte nada del usuario ni lee tasas reales.
//

import Foundation

enum YalaAIOnboardingDemoAmounts {

    /// Los importes de la demo, ya en la divisa pedida y redondeados.
    struct Amounts: Equatable {
        let lunch: Double
        let coffeeThisMonth: Double
        let coffeeAboveAverage: Double
        let deliverySavingPerMonth: Double
        let saverSavingPerMonth: Double
        let tipCoffee: Double

        /// El ahorro anual es el mensual × 12 calculado, no otra cifra redonda: el copy dice
        /// «son X al año» y tiene que ser verdad para cualquier divisa.
        var deliverySavingPerYear: Double { deliverySavingPerMonth * 12 }
    }

    /// Base en dólares: las cifras que ya usaba el copy en inglés.
    static let baseUSD = Amounts(
        lunch: 12,
        coffeeThisMonth: 45,
        coffeeAboveAverage: 8,
        deliverySavingPerMonth: 80,
        saverSavingPerMonth: 40,
        tipCoffee: 5
    )

    static func amounts(for currency: CurrencyCode) -> Amounts {
        let rate = currency.fallbackRateToUSD
        let scale: (Double) -> Double = { roundedForDemo($0 * rate) }
        return Amounts(
            lunch: scale(baseUSD.lunch),
            coffeeThisMonth: scale(baseUSD.coffeeThisMonth),
            coffeeAboveAverage: scale(baseUSD.coffeeAboveAverage),
            deliverySavingPerMonth: scale(baseUSD.deliverySavingPerMonth),
            saverSavingPerMonth: scale(baseUSD.saverSavingPerMonth),
            tipCoffee: scale(baseUSD.tipCoffee)
        )
    }

    /// Una cifra que alguien diría en voz alta: por debajo de 10, el entero (mínimo 1); a partir
    /// de 10, dos cifras significativas (206 → 210, 1.376 → 1.400, 52.560 → 53.000).
    static func roundedForDemo(_ value: Double) -> Double {
        guard value.isFinite, value > 0 else { return 1 }
        if value < 10 { return max(1, value.rounded()) }
        let magnitude = pow(10, floor(log10(value)) - 1)
        return (value / magnitude).rounded() * magnitude
    }

    /// Un importe de la demo con el formato de la app (símbolo o código según la preferencia,
    /// separadores de la región) y sin decimales: son cifras redondas dichas en una frase.
    static func formatted(_ value: Double, identifier: String) -> String {
        CurrencyFormattingHelper.currency(
            value,
            decimals: 0,
            identifier: identifier,
            forceSign: false,
            isEstimate: false
        )
    }
}
