//
//  GroupsListBalanceLogic.swift
//  Yala
//
//  Lo que enseña la lista de Grupos encima y dentro de cada tarjeta (decisión de Jürgen, 2026-10-30, sobre las
//  propuestas de `docs/disenos/grupos-rediseno-2-2/`):
//
//  - El neto en tu moneda principal, la cifra grande de arriba (propuesta 2 de Jürgen, 2026-11-03): lo que te deben
//    menos lo que debes, cada divisa convertida con los tipos de cambio de la app. Solo presentación: los saldos no se
//    tocan. Con él, la barra que reparte lo que debes y lo que te deben y una línea por divisa en cada lado.
//  - Las filas por persona de cada tarjeta: primero lo que debes y después lo que te deben, cada lado de mayor a menor,
//    como mucho tres y el resto en «y N más».
//

import Foundation

enum GroupsListBalanceLogic {

    // MARK: - Neto en la moneda principal

    enum NetDirection: Equatable {
        case owedToMe
        case iOwe
        /// Lo que debes y lo que te deben se compensan (a menos de un céntimo).
        case even
    }

    struct Net: Equatable {
        /// Siempre ≥ 0: el signo va en `direction`.
        let amount: Double
        let currencyCode: String
        let direction: NetDirection
        /// Alguna divisa se convirtió con una tasa que no es la del día (`RateQuality.isExact == false`).
        let isEstimate: Bool
    }

    /// `nil` sin nada pendiente: sin deudas no hay nada que resumir y el aviso no sale.
    static func net(
        owedToMe: [String: Double],
        iOwe: [String: Double],
        mainCurrency: String,
        converter: CurrencyConverting
    ) -> Net? {
        let owed = owedToMe.filter { $0.value > 0.01 }
        let owe = iOwe.filter { $0.value > 0.01 }
        guard !owed.isEmpty || !owe.isEmpty else { return nil }

        var total = Decimal(0)
        var isEstimate = false
        func add(_ byCurrency: [String: Double], sign: Decimal) {
            // Orden fijo: la suma de `Decimal` no depende del orden, pero así el recorrido es reproducible.
            for (code, value) in byCurrency.sorted(by: { $0.key < $1.key }) {
                let amount = Decimal(value)
                if code == mainCurrency {
                    total += sign * amount
                } else {
                    let converted = converter.convertCheckedWithLatestRate(amount, from: code, to: mainCurrency)
                    total += sign * converted.amount
                    if !converted.quality.isExact { isEstimate = true }
                }
            }
        }
        add(owed, sign: 1)
        add(owe, sign: -1)

        let value = (NSDecimalNumber(decimal: total).doubleValue * 100).rounded() / 100
        if abs(value) < 0.01 {
            // «Se compensan» solo si hay algo que compensar: con un solo lado, un resto que al convertirlo baja del
            // céntimo (0,40 JPY a soles) no es un saldo cero, es un saldo que no se ve en esta divisa.
            guard !owed.isEmpty, !owe.isEmpty else { return nil }
        }
        let direction: NetDirection = abs(value) < 0.01 ? .even : (value > 0 ? .owedToMe : .iOwe)
        return Net(
            amount: direction == .even ? 0 : abs(value),
            currencyCode: mainCurrency,
            direction: direction,
            isEstimate: isEstimate
        )
    }

    /// El rótulo de la cifra grande: «Debes en total · en S/», «Te deben en total · en S/» o «Estás a mano · en S/».
    static func netCaption(_ direction: NetDirection, currencySymbol: String) -> String {
        switch direction {
        case .owedToMe: L10n.Groups.Hero.netOwedToMe(currencySymbol)
        case .iOwe: L10n.Groups.Hero.netIOwe(currencySymbol)
        case .even: L10n.Groups.Hero.netEven(currencySymbol)
        }
    }

    // MARK: - Barra y montos de cada lado (propuesta 2 de Jürgen, 2026-11-03)

    /// Un lado entero (lo que debes o lo que te deben) pasado a la moneda principal, con la misma conversión que el neto.
    static func total(
        _ byCurrency: [String: Double],
        mainCurrency: String,
        converter: CurrencyConverting
    ) -> Double {
        var total = Decimal(0)
        for (code, value) in byCurrency.filter({ $0.value > 0.01 }).sorted(by: { $0.key < $1.key }) {
            let amount = Decimal(value)
            total += code == mainCurrency
                ? amount
                : converter.convertCheckedWithLatestRate(amount, from: code, to: mainCurrency).amount
        }
        return NSDecimalNumber(decimal: total).doubleValue
    }

    /// Qué parte de la barra es lo que debes (0…1). `nil` si los dos lados están vacíos: no hay barra que pintar.
    static func oweShare(iOweInMain: Double, owedInMain: Double) -> Double? {
        let total = iOweInMain + owedInMain
        guard total > 0 else { return nil }
        return min(1, max(0, iOweInMain / total))
    }

    struct SideLines: Equatable {
        let shown: [GroupBalancesPresentationLogic.CurrencyAmount]
        /// Las divisas que no caben («y N más»).
        let hiddenCount: Int
    }

    /// Una línea por divisa, de mayor a menor en la moneda principal (desempate por código). Como mucho `limit` líneas
    /// contando la de «y N más»: con tres divisas salen las tres; con cuatro o más, las dos mayores y «y N más»
    /// (Jürgen, 2026-11-03: «limitamos a 3 monedas y la 3ra dice “+1 más”»).
    static func sideLines(
        _ byCurrency: [String: Double],
        mainCurrency: String,
        converter: CurrencyConverting,
        limit: Int = 3
    ) -> SideLines {
        let items = byCurrency
            .filter { $0.value > 0.01 }
            .map { (code: $0.key, amount: $0.value,
                    inMain: total([$0.key: $0.value], mainCurrency: mainCurrency, converter: converter)) }
            .sorted { a, b in a.inMain != b.inMain ? a.inMain > b.inMain : a.code < b.code }
            .map { GroupBalancesPresentationLogic.CurrencyAmount(currencyCode: $0.code, amount: $0.amount) }
        let cap = max(1, limit)
        guard items.count > cap else { return SideLines(shown: items, hiddenCount: 0) }
        return SideLines(shown: Array(items.prefix(cap - 1)), hiddenCount: items.count - (cap - 1))
    }

    // MARK: - Filas por persona de la tarjeta

    struct PersonRows: Equatable {
        let shown: [GroupsViewModel.DebtRow]
        /// Las que no caben («y N más»).
        let hiddenCount: Int
    }

    /// Primero lo que debes y después lo que te deben; dentro de cada lado, de mayor a menor (desempate por nombre y
    /// divisa, para que la tarjeta no baile entre recargas). Como mucho `limit`.
    static func personRows(_ debts: [GroupsViewModel.DebtRow], limit: Int = 3) -> PersonRows {
        func rank(_ row: GroupsViewModel.DebtRow) -> Int { row.perspective == .iOwe ? 0 : 1 }
        let sorted = debts
            .filter { $0.amount > 0.01 }
            .sorted { a, b in
                if rank(a) != rank(b) { return rank(a) < rank(b) }
                if a.amount != b.amount { return a.amount > b.amount }
                if a.counterpartyName != b.counterpartyName { return a.counterpartyName < b.counterpartyName }
                return a.currencyCode < b.currencyCode
            }
        let cap = max(0, limit)
        return PersonRows(shown: Array(sorted.prefix(cap)), hiddenCount: max(0, sorted.count - cap))
    }
}
