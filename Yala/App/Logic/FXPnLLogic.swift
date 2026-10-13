//
//  FXPnLLogic.swift
//  Yala
//
//  Ganancia/pérdida cambiaria (FX P&L) del saldo vivo: cuánto ha cambiado de valor, sólo por el
//  tipo de cambio, el dinero que el usuario tiene HOY en divisas distintas de su moneda preferida.
//
//  Lógica pura y sin estado — el molde de la casa para condiciones de visibilidad y umbrales
//  (`PanelTotalAccountsLogic`, `PanelAvailabilityLogic`) — para poder probar los casos de borde sin
//  ModelContext ni simulador.
//
//  ── Por qué FIFO y no un TC medio de todos los movimientos ──────────────────────────────────
//
//  El primer diseño promediaba `Σ|amountInPreferredCurrency| / Σ|amount|` sobre todas las
//  transacciones de la divisa. Es más simple y está MAL, de dos formas que la review adversarial
//  reprodujo con números:
//
//   · **Un gasto no es una entrada.** Comprar 1.000 USD a 3,00 y volver a venderlos el mismo año
//     arrastra el «TC de entrada» de 100 dólares comprados a 4,00 en 2023 hasta 3,05 — y con el
//     dólar hoy a 3,50 la card anuncia GANANCIA a quien ha perdido. El signo, no la magnitud.
//   · **Un traspaso entre cuentas propias tampoco.** Sus dos patas entran en el promedio al TC de
//     hoy, así que mover dinero de bolsillo empuja el P&L hacia cero: medido, +4.000 → +1.333.
//
//  FIFO responde a la pregunta real —«¿qué pagué por los dólares que TODAVÍA tengo?»— porque
//  consume los lotes conforme el dinero sale. Es además el criterio que usan Wise y Revolut, la
//  referencia que el propio ticket cita.
//

import Foundation
import SwiftData

enum FXPnLLogic {

    // MARK: - Constantes

    /// Saldo convertido por debajo del cual una divisa se considera residual (EUR −0,00 tras
    /// redondeos). Mismo criterio y mismo valor que `BalanceLiveAnchorEducationSheet`, para que las
    /// dos superficies no discrepen sobre qué divisas «tiene» el usuario.
    static let nearZero: Decimal = Decimal(1) / Decimal(100)

    /// Fracción de la base expuesta a divisa por debajo de la cual el P&L es ruido y la card no se
    /// muestra. 0,5 %, como pedía el ticket.
    static let presentationThreshold: Decimal = Decimal(5) / Decimal(1000)

    // MARK: - Modelo

    /// Una divisa extranjera con saldo vivo, y qué le ha hecho el tipo de cambio.
    struct CurrencyRow: Equatable, Identifiable, Sendable {
        /// Código ISO de la divisa nativa (nunca la preferida: ésa no tiene P&L).
        let code: String
        /// Saldo actual en esa divisa. Puede ser negativo (una tarjeta en dólares es deuda).
        let nativeBalance: Decimal
        /// TC medio de los lotes que siguen vivos — no de todo lo que pasó por la cuenta.
        let averageEntryRate: Decimal
        /// TC de hoy, derivado de la conversión real del saldo (no de una tasa unitaria aparte:
        /// así el desglose cuadra con el total al céntimo).
        let currentRate: Decimal
        /// Lo que ese saldo vale hoy, en moneda preferida.
        let valueToday: Decimal
        /// Lo que costó, en moneda preferida, al TC de los lotes vivos.
        let costBasis: Decimal

        /// Si el número de esta fila se apoya en alguna tasa que no era la del día.
        ///
        /// Recoge las **dos vías** que exige `.claude/rules/currency-fx.md`, porque el P&L es una
        /// resta entre una rama guardada y una viva y cada una se estropea por su lado: el coste
        /// base sale de `amountInPreferredCurrency` (→ `tx.isExchangeRateProvisional`) y el valor de
        /// hoy sale del converter (→ `RateQuality`). Con sólo la segunda, una transacción sellada
        /// con la tabla estática produce un P&L inventado y lo presenta como exacto.
        ///
        /// Va por fila y no una sola para todo el resumen porque la calidad se guarda **por
        /// divisa** (misma razón que `CachedRates.origins`): con dólares exactos y yenes
        /// arrastrados, una señal común marcaría de más la fila del dólar, y marcar de más erosiona
        /// la marca igual que no ponerla.
        let isApproximate: Bool

        var id: String { code }

        /// Ganancia (>0) o pérdida (<0) cambiaria de esta divisa, en moneda preferida.
        var pnl: Decimal { valueToday - costBasis }

        /// Variación del tipo de cambio desde la entrada, en tanto por uno. Es el número de la
        /// frase «tus dólares valen hoy un 8,6 % más que cuando entraron».
        ///
        /// **Es la variación del TC, no la del P&L sobre el coste.** Coinciden en magnitud, pero
        /// esta se mantiene bien definida y con el signo correcto cuando el saldo es una deuda:
        /// dividir el P&L por un `costBasis` negativo invertiría el signo y le diría al usuario que
        /// ha ganado justo cuando su deuda en dólares se ha encarecido.
        var rateVariation: Decimal {
            guard averageEntryRate > 0 else { return 0 }
            return (currentRate - averageEntryRate) / averageEntryRate
        }
    }

    /// El FX P&L completo del saldo mostrado.
    struct Summary: Equatable, Identifiable, Sendable {
        /// Una fila por divisa extranjera con saldo vivo, ya ordenadas por exposición.
        let rows: [CurrencyRow]
        /// Suma de los P&L parciales, en `Decimal`.
        let totalPnL: Decimal
        /// Σ|coste base| de las divisas extranjeras: cuánto dinero del usuario está expuesto al
        /// tipo de cambio. Es el denominador honesto del umbral (ver `shouldPresent`).
        let exposedBase: Decimal
        let preferredCurrencyCode: String

        /// Identidad para `.sheet(item:)`: cambia cuando cambia el conjunto de divisas mostrado.
        var id: String { rows.map(\.code).joined(separator: "-") }

        /// El TOTAL se marca «≈» cuando las divisas con tasa dudosa **pesan** en él: el mismo
        /// `ApproximateMarkThreshold` que el resto del Panel (decisión B de Jürgen del 2026-10-12,
        /// `dos-criterios-de-aproximado-en-la-misma-pantalla`; antes bastaba una fila dudosa).
        ///
        /// Numerador: `Σ|pnl|` de las filas dudosas, la parte del número que ENTRÓ con una tasa
        /// mala, en magnitudes. Denominador: `|totalPnL|`, el número que se MUESTRA, que es una
        /// resta. Derivado de las filas —no un campo aparte— para que no puedan contradecirse.
        var isApproximate: Bool {
            let approximate = rows.filter(\.isApproximate).reduce(Decimal(0)) { $0 + abs($1.pnl) }
            return ApproximateMarkThreshold.marks(
                approximate: (approximate as NSDecimalNumber).doubleValue,
                total: (totalPnL as NSDecimalNumber).doubleValue
            )
        }

        /// Alguna fila lleva «≈». Es lo que decide la nota de la hoja que explica el glifo: una
        /// fila marcada necesita la explicación aunque el total no llegue al umbral.
        var hasApproximateRow: Bool { rows.contains(where: \.isApproximate) }

        /// La divisa que **explica el número**, y por tanto la que protagoniza la frase de la card.
        ///
        /// Se elige por `|pnl|` y no por exposición: con 10.000 USD planos y 1.000.000 ARS caídos,
        /// la mayor posición es la que no ha hecho nada, y titular «Pérdida» sobre la frase «tus
        /// dólares valen un 0 % más» es una tarjeta que se contradice a sí misma.
        var dominant: CurrencyRow? { rows.max { abs($0.pnl) < abs($1.pnl) } }
    }

    // MARK: - Lotes

    /// Un tramo de dinero que entró junto, con lo que costó. Consumido en orden de llegada.
    private struct Lot {
        var quantity: Decimal  // siempre positiva: la dirección la lleva `sign`
        let rate: Decimal  // unidades de preferida por unidad nativa
        let isProvisional: Bool
    }

    // MARK: - Cálculo

    /// Construye el resumen recorriendo las transacciones de las **mismas** cuentas que sumó el
    /// saldo (`breakdown.eligibleAccountIDs`).
    ///
    /// Devuelve `nil` si no hay ninguna divisa extranjera con saldo vivo y base fiable: sin
    /// exposición no hay nada que explicar.
    static func summary(
        transactions: [TransactionItem],
        breakdown: LiveBalanceCalculator.Breakdown,
        converter: CurrencyConverting = CurrencyConverter.shared
    ) -> Summary? {
        let preferred = breakdown.preferredCurrencyCode

        // Agrupar por divisa, en orden de llegada. El FIFO necesita el tiempo; el bucle del saldo
        // no, y por eso allí no se ordena.
        var byCurrency: [String: [TransactionItem]] = [:]
        for tx in transactions {
            guard let acc = tx.account,
                breakdown.eligibleAccountIDs.contains(acc.persistentModelID),
                tx.currencyCode != preferred
            else { continue }
            // Un traspaso entre cuentas propias no compra ni vende divisa: mueve la misma de sitio.
            // Sus dos patas llevan el TC del día del traspaso, así que dejarlas entrar reescribiría
            // el coste de un dinero que el usuario no ha tocado.
            guard tx.balanceAdjustmentType != TransactionItem.adjustmentTypeTransfer else { continue }
            byCurrency[tx.currencyCode, default: []].append(tx)
        }

        var rows: [CurrencyRow] = []

        for (code, txs) in byCurrency {
            guard let nativeBalance = breakdown.nativeBalances[code], nativeBalance != 0 else {
                continue
            }

            let outcome = converter.convertCheckedWithLatestRate(
                nativeBalance, from: code, to: preferred
            )
            let valueToday = outcome.amount
            // Posiciones residuales tras redondeo (EUR −0,00): no son dinero, son ruido.
            guard abs(valueToday) > nearZero else { continue }

            guard
                let basis = costBasis(
                    of: nativeBalance,
                    transactions: txs,
                    code: code,
                    preferred: preferred,
                    converter: converter
                )
            else { continue }

            guard basis.rate > 0 else { continue }

            // `nativeBalance` no es 0 (comprobado arriba), así que la división es segura.
            rows.append(
                CurrencyRow(
                    code: code,
                    nativeBalance: nativeBalance,
                    averageEntryRate: basis.rate,
                    currentRate: valueToday / nativeBalance,
                    valueToday: valueToday,
                    costBasis: nativeBalance * basis.rate,
                    isApproximate: basis.isProvisional || !outcome.quality.isExact
                )
            )
        }

        guard !rows.isEmpty else { return nil }

        // Mayor exposición primero: así se lee el desglose. La frase de la card usa `dominant`,
        // que es otra pregunta y por eso ordena distinto.
        rows.sort { abs($0.costBasis) > abs($1.costBasis) }

        return Summary(
            rows: rows,
            totalPnL: rows.reduce(Decimal(0)) { $0 + $1.pnl },
            exposedBase: rows.reduce(Decimal(0)) { $0 + abs($1.costBasis) },
            preferredCurrencyCode: preferred
        )
    }

    /// TC medio de los lotes que siguen vivos, por FIFO.
    ///
    /// Los movimientos del mismo signo que el saldo abren lote; los contrarios lo consumen en orden
    /// de llegada. Con una deuda el papel se invierte —los cargos abren y los pagos consumen—, que
    /// es lo que hace que una tarjeta en dólares tenga un coste de contratación y no un absurdo.
    ///
    /// Devuelve `nil` si los lotes vivos no cubren el saldo. Ocurre de verdad: un traspaso desde una
    /// cuenta que el filtro dejó fuera mete dinero cuyo origen no se ve. Antes que repartir el
    /// coste conocido sobre un saldo mayor —que inventa base y estropea el total— la divisa se
    /// descarta entera.
    private static func costBasis(
        of nativeBalance: Decimal,
        transactions txs: [TransactionItem],
        code: String,
        preferred: String,
        converter: CurrencyConverting
    ) -> (rate: Decimal, isProvisional: Bool)? {
        let sign: Decimal = nativeBalance > 0 ? 1 : -1
        var lots: [Lot] = []
        var consumedIndex = 0

        for tx in txs.sorted(by: { $0.date < $1.date }) {
            let native = Decimal(tx.amount)
            guard native != 0 else { continue }
            let magnitude = abs(native)

            let opensLot = (native > 0 && sign == 1) || (native < 0 && sign == -1)
            if opensLot {
                guard
                    let entry = entryRate(
                        for: tx, magnitude: magnitude, code: code, preferred: preferred,
                        converter: converter
                    )
                else { continue }
                lots.append(
                    Lot(quantity: magnitude, rate: entry.rate, isProvisional: entry.isProvisional)
                )
            } else {
                // Consumo FIFO: el dinero que salió es el que llevaba más tiempo dentro.
                var remaining = magnitude
                while remaining > 0, consumedIndex < lots.count {
                    let available = lots[consumedIndex].quantity
                    if available > remaining {
                        lots[consumedIndex].quantity = available - remaining
                        remaining = 0
                    } else {
                        remaining -= available
                        lots[consumedIndex].quantity = 0
                        consumedIndex += 1
                    }
                }
            }
        }

        let live = lots.filter { $0.quantity > 0 }
        let liveQuantity = live.reduce(Decimal(0)) { $0 + $1.quantity }
        let target = abs(nativeBalance)
        guard liveQuantity > 0 else { return nil }

        // Los lotes vivos tienen que dar cuenta del saldo. Un margen de una unidad mínima absorbe
        // el redondeo de importes con decimales sin dejar pasar un descuadre real.
        guard abs(liveQuantity - target) <= nearZero else { return nil }

        let cost = live.reduce(Decimal(0)) { $0 + $1.quantity * $1.rate }
        return (cost / liveQuantity, live.contains { $0.isProvisional })
    }

    /// A qué tipo de cambio entró una transacción concreta, y si esa tasa era fiable.
    ///
    /// Misma estructura que `CashFlowCalculator`: el importe guardado si fue sellado contra la
    /// moneda preferida de ahora, y si no, **reconversión con la tasa de aquel día**. Descartarla
    /// —que es lo que hacía una versión anterior de este código— sesga la muestra justo hacia las
    /// transacciones más antiguas o llegadas de otro dispositivo, es decir hacia otro momento del
    /// tipo de cambio.
    private static func entryRate(
        for tx: TransactionItem,
        magnitude: Decimal,
        code: String,
        preferred: String,
        converter: CurrencyConverting
    ) -> (rate: Decimal, isProvisional: Bool)? {
        if tx.preferredCurrencyCode == preferred {
            let historical = Decimal(abs(tx.amountInPreferredCurrency))
            // Un cero guardado no es «costó cero»: es un importe que nunca se escribió (el valor por
            // defecto del modelo). Tratarlo como dato daría un coste base de 0 y un P&L que es el
            // saldo entero presentado como ganancia. Una tasa inservible es una tasa AUSENTE.
            if historical > 0 {
                return (historical / magnitude, tx.isExchangeRateProvisional)
            }
        }
        let outcome = converter.convertChecked(magnitude, from: code, to: preferred, on: tx.date)
        guard outcome.amount > 0 else { return nil }
        return (outcome.amount / magnitude, !outcome.quality.isExact)
    }

    /// Si el movimiento cambiario merece ocupar sitio en el Panel.
    ///
    /// **El denominador es la base expuesta a divisa, no el balance total**, aunque el ticket
    /// propusiera «0,5 % del balance». Con el balance de denominador la regla degenera justo en los
    /// casos que el umbral existe para filtrar: un saldo cercano a cero, o posiciones que se
    /// cancelan (+1.000 USD contra −3.800 PEN), hacen que el 0,5 % sea ~0 y entonces **cualquier**
    /// céntimo de P&L pasa el filtro y la card no se va nunca. La base expuesta no puede ser ~0
    /// mientras haya saldo en divisa, y además responde a la pregunta real del usuario: de lo que
    /// tengo en otra moneda, ¿cuánto he ganado o perdido?
    static func shouldPresent(_ summary: Summary) -> Bool {
        guard summary.exposedBase > nearZero else { return false }
        // Un P&L que se redondea a cero en pantalla no puede encabezar una tarjeta: «Ganancia por
        // tipo de cambio +0,00 €» es ruido con aspecto de dato.
        guard abs(summary.totalPnL) > nearZero else { return false }
        return abs(summary.totalPnL) > presentationThreshold * summary.exposedBase
    }
}
