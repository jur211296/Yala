//
//  LiveBalanceCalculator.swift
//  Yala
//
//  Calcula el saldo "vivo" del usuario en moneda preferida, agrupando
//  transacciones por moneda nativa y convirtiendo cada bucket con el TC
//  ACTUAL (no el TC del día de cada transacción). Esto refleja el valor
//  real disponible HOY.
//
//  Para flujos históricos (cashflow, income/gasto del mes, sankey, top
//  categorías) seguir usando `tx.amountInPreferredCurrency` directamente
//  — esa semántica es correcta porque refleja "qué pasó económicamente".
//
//  Las CURVAS de saldo no son un flujo: dibujan este saldo en el tiempo. Desde
//  el 2026-10-16 acumulan el saldo nativo con `addNative` y lo valoran cada día
//  a su tipo de cambio, y hoy con `convertAtLatestRate` (`BalanceValuation`),
//  así que acaban en esta cifra. Antes sumaban cada fila al tipo de su fecha y
//  la curva acababa lejos de la cifra que tenía al lado: el Panel decía
//  «+179,062» y dibujaba ~201K (ticket `panel-balance-chart-contradicts-its-own-figure`).
//

import Foundation
import SwiftData

struct LiveBalanceCalculator {

    /// Desglose por moneda nativa del saldo vivo, útil para debug y para
    /// futuras vistas educativas (FX P&L breakdown).
    struct Breakdown {
        let nativeBalances: [String: Decimal]
        let convertedTotal: Decimal
        let preferredCurrencyCode: String

        /// `true` si las divisas convertidas con una tasa que no era la de hoy **pesan** en el saldo:
        /// `ApproximateMarkThreshold` sobre `Σ|convertido dudoso|` frente a `|saldo|`.
        /// Este saldo usa el TC ACTUAL, así que la vía es siempre el converter — no hay aquí monto
        /// guardado en el que apoyarse, a diferencia de los totales históricos.
        ///
        /// Hasta el 2026-10-12 era un OR por divisa (decisión del 2026-09-08). Jürgen eligió ese día
        /// la opción B de `dos-criterios-de-aproximado-en-la-misma-pantalla`: el mismo umbral que
        /// los números del período, para que el «≈» signifique una sola cosa en todo el Panel.
        let amountsAreApproximate: Bool

        /// Las cuentas que este desglose acabó sumando, ya resueltas (contables, filtro de
        /// selección e `isExcludeMode` aplicados).
        ///
        /// Se expone para que el cálculo de ganancia/pérdida cambiaria recorra **exactamente** las
        /// mismas transacciones que este saldo. El FX P&L es una resta contra ese saldo: si cada
        /// lado resolviera la elegibilidad por su cuenta, el día que cambie una de las reglas el
        /// resultado seguirá pareciendo plausible y estará mal. Compartir el conjunto ya resuelto
        /// es lo que hace que no puedan divergir.
        let eligibleAccountIDs: Set<PersistentIdentifier>
    }

    /// Output del helper `liveBalanceOverride`: valor total + breakdown por
    /// moneda nativa. El breakdown habilita UX educativa sobre composición
    /// multi-currency (sheet "Tu saldo hoy"). Stats consumers ignoran el
    /// breakdown y usan solo `value`.
    /// **Historia del campo `amountsAreApproximate`, que importa para no repetirla.** Se añadió y se
    /// retiró en la misma sesión (`fx-presentation-still-shows-1to1`, 2026-09-06) al medir que nadie
    /// lo leía: un campo que nadie lee parece cobertura en una auditoría posterior y no lo es.
    /// Vuelve el 2026-09-09 con `fx-approximate-mark-missing-on-secondary-surfaces` **porque ahora
    /// sí tiene lector**: la hoja «¿Cuánto tienes hoy?» pinta este mismo `value`, y sin la señal lo
    /// declaraba exacto justo en la pantalla que existe para explicar que es multimoneda. El carril
    /// es el que `nativeBalances` ya recorría —processor, los dos ViewModels, `TrendChartView`—, no
    /// uno nuevo.
    struct LiveAnchorInfo: Equatable, Sendable {
        let value: Double
        let nativeBalances: [String: Decimal]

        /// `true` si las divisas convertidas con una tasa que no era la de hoy pesan en el saldo
        /// (`ApproximateMarkThreshold`). Sale del MISMO `Breakdown` que `value`, así que número y
        /// marca no pueden divergir.
        let amountsAreApproximate: Bool
    }

    /// Saldo total "hoy" en moneda preferida. Si `selectedAccountIDs` no
    /// resuelve a ninguna cuenta contable, hace fallback al total agregado
    /// (replica behavior del antiguo `BalanceHelper.displayedBalance`).
    static func liveBalance(
        accounts: [Account],
        transactions: [TransactionItem],
        preferredCurrencyCode: String,
        selectedAccountIDs: Set<PersistentIdentifier> = [],
        isExcludeMode: Bool = false,
        converter: CurrencyConverting = CurrencyConverter.shared
    ) -> Double {
        let breakdown = liveBalanceBreakdown(
            accounts: accounts,
            transactions: transactions,
            preferredCurrencyCode: preferredCurrencyCode,
            selectedAccountIDs: selectedAccountIDs,
            isExcludeMode: isExcludeMode,
            converter: converter
        )
        return (breakdown.convertedTotal as NSDecimalNumber).doubleValue
    }

    /// Versión que retorna el desglose completo. La versión `liveBalance` la
    /// llama internamente.
    ///
    /// El filtro de cuentas es un **conjunto**, no una cuenta: `SessionState`
    /// admite varias (Registros → Filtros hace `insert` sin `removeAll`, y un
    /// presupuesto vuelca su conjunto resuelto), y colapsarlo a un elemento
    /// hacía que el saldo del Panel mostrase UNA cuenta —cuál, no era estable,
    /// porque `Set.first` no lo es— mientras Distribución sumaba todas.
    /// `isExcludeMode` viaja con el conjunto por la misma razón: sin él, "excluir
    /// la cuenta A" enseñaba justamente el saldo de A.
    static func liveBalanceBreakdown(
        accounts: [Account],
        transactions: [TransactionItem],
        preferredCurrencyCode: String,
        selectedAccountIDs: Set<PersistentIdentifier> = [],
        isExcludeMode: Bool = false,
        converter: CurrencyConverting = CurrencyConverter.shared
    ) -> Breakdown {
        // Las cuentas marcadas "excluir de estadísticas" nunca entran, se filtre
        // por cuenta o no.
        let countableIDs = Set(
            accounts.filter { !$0.excludeFromStatistics }
                .map { $0.persistentModelID }
        )

        let eligibleAccountIDs: Set<PersistentIdentifier>
        if selectedAccountIDs.isEmpty {
            eligibleAccountIDs = countableIDs
        } else if isExcludeMode {
            // "Todas menos las seleccionadas". Si se excluyen todas, el saldo es
            // 0 y no el total: aquí NO hay fallback, igual que en Estadísticas.
            eligibleAccountIDs = countableIDs.subtracting(selectedAccountIDs)
        } else {
            let filtered = countableIDs.intersection(selectedAccountIDs)
            // Fallback al total agregado cuando la selección no resuelve a
            // ninguna cuenta contable (p. ej. la única elegida está excluida de
            // estadísticas). Comportamiento heredado, fijado por test.
            eligibleAccountIDs = filtered.isEmpty ? countableIDs : filtered
        }

        var nativeBalances: [String: Decimal] = [:]
        for tx in transactions {
            guard let acc = tx.account,
                eligibleAccountIDs.contains(acc.persistentModelID)
            else { continue }
            addNative(tx, to: &nativeBalances)
        }

        let (convertedTotal, approximateMagnitude) = convertAtLatestRate(
            nativeBalances, to: preferredCurrencyCode, converter: converter
        )
        let amountsAreApproximate = ApproximateMarkThreshold.marks(
            approximate: (approximateMagnitude as NSDecimalNumber).doubleValue,
            total: (convertedTotal as NSDecimalNumber).doubleValue
        )

        return Breakdown(
            nativeBalances: nativeBalances,
            convertedTotal: convertedTotal,
            preferredCurrencyCode: preferredCurrencyCode,
            amountsAreApproximate: amountsAreApproximate,
            eligibleAccountIDs: eligibleAccountIDs
        )
    }

    // MARK: - La regla del saldo vivo, compartida con las curvas de saldo

    /// Lo que una fila suma al saldo, en su divisa NATIVA. Es la mitad de la regla del saldo vivo; la otra es
    /// `convertAtLatestRate`. Las curvas de saldo acumulan con esta misma función y valoran el punto de hoy con
    /// `convertAtLatestRate` (`BalanceValuation`): así su último punto ES la cifra del saldo, por construcción
    /// (ticket `panel-balance-chart-contradicts-its-own-figure`).
    static func addNative(_ transaction: TransactionItem, to nativeBalances: inout [String: Decimal]) {
        nativeBalances[transaction.currencyCode, default: 0] += Decimal(transaction.amount)
    }

    /// Un saldo por divisa nativa, pasado a `preferredCurrencyCode` con el tipo de cambio ACTUAL.
    ///
    /// Devuelve también la magnitud convertida con una tasa que no era la de hoy: el numerador de
    /// `ApproximateMarkThreshold`, en magnitudes (los errores de dos divisas no se cancelan). El denominador es el
    /// saldo que se MUESTRA, que es una resta (una tarjeta en dólares resta): `|total|`.
    static func convertAtLatestRate(
        _ nativeBalances: [String: Decimal],
        to preferredCurrencyCode: String,
        converter: CurrencyConverting
    ) -> (total: Decimal, approximateMagnitude: Decimal) {
        var total: Decimal = 0
        var approximateMagnitude: Decimal = 0
        // Orden estable: la suma en `Decimal` no depende del orden, pero así el resultado no puede depender del
        // orden de iteración de un diccionario ni en el último dígito.
        for code in nativeBalances.keys.sorted() {
            guard let amount = nativeBalances[code] else { continue }
            if code == preferredCurrencyCode {
                total += amount
            } else {
                let outcome = converter.convertCheckedWithLatestRate(
                    amount, from: code, to: preferredCurrencyCode
                )
                total += outcome.amount
                if !outcome.quality.isExact {
                    approximateMagnitude += abs(outcome.amount)
                }
            }
        }
        return (total, approximateMagnitude)
    }

    /// Override del último punto del trend chart. Solo retorna no-nil cuando
    /// la métrica es `.balance` y el intervalo cubre "hoy" — en otros casos
    /// el último punto del trend mantiene su valor histórico.
    /// Centraliza el patrón usado por callers de `TrendDataProcessor`.
    static func liveBalanceOverride(
        for metric: TrendType,
        interval: DateInterval,
        accounts: [Account],
        transactions: [TransactionItem],
        preferredCurrencyCode: String,
        converter: CurrencyConverting = CurrencyConverter.shared
    ) -> LiveAnchorInfo? {
        guard metric == .balance, interval.end >= Date.now else { return nil }
        let breakdown = liveBalanceBreakdown(
            accounts: accounts,
            transactions: transactions,
            preferredCurrencyCode: preferredCurrencyCode,
            converter: converter
        )
        return LiveAnchorInfo(
            value: (breakdown.convertedTotal as NSDecimalNumber).doubleValue,
            nativeBalances: breakdown.nativeBalances,
            amountsAreApproximate: breakdown.amountsAreApproximate
        )
    }
}
