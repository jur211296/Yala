//
//  GroupsListBalanceLogic.swift
//  Yala
//
//  Lo que enseña la lista de Grupos encima y dentro de cada tarjeta (decisión de Jürgen, 2026-10-30, sobre las
//  propuestas de `docs/disenos/grupos-rediseno-2-2/`):
//
//  - El neto en tu moneda principal para el aviso morado bajo «Debes / Te deben»: lo que te deben menos lo que debes,
//    cada divisa convertida con los tipos de cambio de la app. Solo presentación: los saldos no se tocan.
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

    /// «En tu moneda principal (S/), esto significa un saldo de S/ 566.81 que debes.»
    static func netText(_ net: Net, currencySymbol: String, formattedAmount: String) -> String {
        switch net.direction {
        case .owedToMe: L10n.Groups.Hero.netOwedToMe(currencySymbol, formattedAmount)
        case .iOwe: L10n.Groups.Hero.netIOwe(currencySymbol, formattedAmount)
        case .even: L10n.Groups.Hero.netEven(currencySymbol)
        }
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
