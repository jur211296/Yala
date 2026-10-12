//
//  GroupBridgeStatsAdjustment.swift
//  Yala
//
//  SSOT pure-logic para proyectar los gastos de grupo BRIDGEADOS a "mi parte" (neto) en la
//  capa de agregación de estadísticas — SIN persistencia nueva ni cambio de schema/wire.
//
//  PROBLEMA. El bridge Caso A (yo pago un gasto del grupo) crea DOS `TransactionItem` con el
//  mismo `splitExpenseID`:
//    · pata REAL en mi cuenta: `amount = -total` (subcat/tags manuales del usuario),
//    · pata VIRTUAL "lent" en la cuenta de sistema "Grupos": `amount = +lent (= total - myShare)`
//      con subcategoría de sistema `loanToGroups` (income) y SIN tags.
//  El neto de la pareja es `-total + lent = -myShare`, pero ese neto NO vive en ninguna fila:
//  la pata real (que porta los tags/subcat) vale `-total`. Como TODA calculadora de gasto lee
//  `amount`/`amountInPreferredCurrency` de esa fila, un gasto de S/300 del que me tocan S/100
//  aparece inflado a S/300 (y la lent como un +S/200 de "ingreso fantasma" en CashFlow).
//  `splitMyValue` NO sirve: es un valor contextual polimórfico (%, personas, partes, exacto),
//  no dinero, y se muestra en la UI de split personal.
//
//  SOLUCIÓN. Netear la pareja por `splitExpenseID` en la capa de agregación:
//    · a la pata REAL se le atribuye `-myShare` (= `real.amount + Σ patas de préstamo`),
//    · las patas de préstamo (income-direction) se SUPRIMEN en superficies income-aware
//      (matan el ingreso fantasma y mantienen el neto correcto).
//  Los splits PERSONALES ya guardan `amount = mi parte`, así que NO se tocan (no bridgeados).
//
//  IDENTIFICACIÓN ROBUSTA A HIDRATACIÓN LAZY. Las relaciones `account`/`subcategory`/`category`
//  de `TransactionItem` son CloudKit-lazy (pueden venir `nil` en cold-start con sync). Por eso:
//    · si CUALQUIER pata del grupo no hidrató su `account` → el grupo NO se toca (transitorio),
//    · la pata de préstamo se detecta por el SIGNO del monto (`amount > 0`, escalar nunca-lazy),
//      NO por `category?.isIncome` (relación lazy),
//    · el rol de subcategoría SOLO se consulta para desambiguar una pata de préstamo SUELTA
//      (sin hermana de costo) de un "saldo inicial: me deben" — ambos `+income` — con skip-if-nil.
//
//  LA INCERTIDUMBRE VIAJA CON EL MONTO. Quien sume `amountInPreferredCurrency(_:)` NO puede leer el
//  `isExchangeRateProvisional` de la fila: ese flag describe UNA pata y el monto son varias, y la
//  pata de préstamo está suprimida del recorrido. El accessor es
//  `approximateMagnitude(_:magnitude:)`, que devuelve `Σ|patas provisionales|` — obligatorio en los
//  numeradores de `ApproximateMarkThreshold` (HeroBucketsCalculator, CashFlowCalculator rama «misma
//  divisa», RecordsViewModel.calculateSummary, WidgetDataCache.buildPeriodSummary).
//
//  UN IMPORTE GUARDADO QUE NO SE PUEDE CREER SE RECONVIERTE. Si una pata trae su importe convertido
//  a 0 (con nativo distinto de 0) o guardado en otra divisa preferida que la pata real, sumarlo tal
//  cual da el importe del grupo entero, y sin «≈». Esa pata se reconvierte desde su nativo con la
//  regla de `CashFlowCalculator.resolvedAmount` (`preferredContribution(of:in:converter:)`).
//
//  CONSUMIDORES (mantener sincronizado — un consumidor de gasto que olvide cablearse vuelve a
//  inflar el Caso A). Expense-magnitude: TagSpending / TopSpendingCategories / TopSubcategories /
//  Weekday / DailySpending / PivotTable / CashFlowProjection calculators; BudgetsViewModel;
//  InsightsCalculator (highest/need); WidgetDataCache; FullFinancialContextBuilder;
//  ReportNotificationService (topCategory). Income-aware (accessor COMBINADO + suppress):
//  CashFlowCalculator; StatisticsViewModel.calculateTotals; TrendDataProcessor; HeroBucketsCalculator;
//  SankeyFlowCalculator; RecordsViewModel.calculateSummary; ReportNotificationService (totals);
//  WidgetDataCache (periodSummary/cashFlowByDay); FullFinancialContextBuilder.buildPeriods;
//  FinancialScoreCalculator; InsightsCalculator (period + groupContext.totalShared); AnomalyDetection.
//  NUNCA ajustar: LiveBalanceCalculator / BalanceTrendCalculator (los saldos reflejan montos reales).
//

import Foundation
import SwiftData

struct GroupBridgeStatsAdjustment {

    private struct AdjustedAmounts {
        let native: Double
        let preferred: Double
        /// `Σ|contribución en divisa preferida|` de las patas provisionales que se sumaron para
        /// formar `preferred`. **Magnitudes, nunca el neto.** Ver `approximateMagnitude(_:magnitude:)`.
        let approximatePreferred: Double
    }

    /// Por id de la pata REAL Caso A: montos ajustados (`native`/`preferred`) = `-myShare`.
    private let adjustedReal: [PersistentIdentifier: AdjustedAmounts]
    /// Patas de préstamo derivadas a EXCLUIR en superficies income-aware.
    private let suppressed: Set<PersistentIdentifier>

    // `nonisolated`: solo asigna datos Sendable → usable desde el inicializador nonisolated de
    // `none` y como valor de default-param (que se chequea en contexto nonisolated bajo
    // SWIFT_DEFAULT_ACTOR_ISOLATION=MainActor). Los accessors que leen props `@Model` sí son MainActor.
    nonisolated private init(adjustedReal: [PersistentIdentifier: AdjustedAmounts], suppressed: Set<PersistentIdentifier>) {
        self.adjustedReal = adjustedReal
        self.suppressed = suppressed
    }

    /// Identidad: no cambia nada. Default para callers/tests no cableados (byte-idéntico al previo).
    nonisolated static let none = GroupBridgeStatsAdjustment(adjustedReal: [:], suppressed: [])

    // MARK: - Accessors

    /// Monto SIGNED nativo para stats: `-myShare` para la pata real Caso A; original en el resto.
    func amount(_ tx: TransactionItem) -> Double {
        adjustedReal[tx.persistentModelID]?.native ?? tx.amount
    }

    /// Monto SIGNED en moneda preferida para stats.
    func amountInPreferredCurrency(_ tx: TransactionItem) -> Double {
        adjustedReal[tx.persistentModelID]?.preferred ?? tx.amountInPreferredCurrency
    }

    /// `true` si la TX es una pata de préstamo derivada que NO debe contarse como ingreso/gasto
    /// en superficies income-aware (mata el "ingreso fantasma" +lent).
    func isSuppressed(_ tx: TransactionItem) -> Bool {
        suppressed.contains(tx.persistentModelID)
    }

    /// Hermano de `amountInPreferredCurrency(_:)` para el **numerador** de
    /// `ApproximateMarkThreshold`: cuánta magnitud dudosa hay detrás del importe que aquel devuelve.
    ///
    /// **Existe porque el importe sintetizado no es de una sola fila.** La pata de préstamo está
    /// SUPRIMIDA del recorrido, así que su `isExchangeRateProvisional` no lo lee nadie — y sin
    /// embargo su monto sí entra en el número que se muestra. Un gasto de grupo con la pata real
    /// exacta (−1.000) y la de préstamo provisional (+900) se contaba como 100 % exacto, cuando el
    /// 90 % de la aritmética que produjo esos −100 salió de una tasa dudosa. Importa más desde el
    /// 2026-09-08 (`approximate-mark-ors-over-whole-period`): el importe entra en un **cociente**,
    /// así que una atribución mal hecha no solo se pierde — desplaza el umbral del bucket entero.
    ///
    /// **Devuelve `Σ|patas provisionales|`, NO el neto marcado.** Es el contrato explícito de
    /// `ApproximateMarkThreshold`, con este mismo ejemplo: «un gasto de 1.000 y un reembolso de 900,
    /// los dos con tasa dudosa, no dejan 100 de incertidumbre: dejan 1.900». Un gasto de grupo es
    /// justo esa resta, y marcar el neto falla en las **dos** direcciones — medido:
    ///
    /// - **Se queda corto** cuando mi parte es pequeña: viaje, adelanto el hotel de 10 personas
    ///   (10.000, mi parte 1.000, préstamo 9.000 con tasa dudosa) y el resto del mes son 25.000
    ///   exactos. Con el neto, 1.000/26.000 = 3,8 % ⇒ sin marca, con un tercio de la aritmética
    ///   dudosa. Con magnitudes, 9.000/26.000 = 34,6 % ⇒ marca.
    /// - **Se pasa** cuando mi parte es grande: cena de dos, 10.000, mi parte 9.700, préstamo 300
    ///   con tasa dudosa, mes de 10.300. Con el neto, 9.700/10.300 = 94 % ⇒ marca el mes entero por
    ///   300 dudosos. En el límite, dos céntimos dudosos marcarían el mes — que es exactamente la
    ///   erosión que el umbral vino a evitar.
    ///
    /// - Parameter magnitude: la magnitud que el llamador está sumando al DENOMINADOR de esa misma
    ///   TX. Solo se usa para las filas sin ajuste (ahí el numerador es esa misma magnitud, o cero);
    ///   pedirla en vez de recalcularla es lo que mantiene numerador y denominador en la misma
    ///   unidad que el importe que el llamador suma (`CashFlowCalculator.resolvedAmount` le pasa
    ///   `abs(value)`).
    func approximateMagnitude(_ tx: TransactionItem, magnitude: Double) -> Double {
        if let ajustada = adjustedReal[tx.persistentModelID] { return ajustada.approximatePreferred }
        return tx.isExchangeRateProvisional ? magnitude : 0
    }

    /// Accessor COMBINADO obligatorio en superficies income-aware (income/expense/net): `nil` ⇒
    /// SKIP la TX. Imposible ajustar-el-gasto-sin-suprimir-la-lent (invertiría el neto).
    func incomeAwareNative(_ tx: TransactionItem) -> Double? {
        isSuppressed(tx) ? nil : amount(tx)
    }

    func incomeAwarePreferred(_ tx: TransactionItem) -> Double? {
        isSuppressed(tx) ? nil : amountInPreferredCurrency(tx)
    }

    // MARK: - Build

    /// Construye la proyección desde el set MÁS AMPLIO disponible (con AMBAS hermanas presentes,
    /// antes de filtros por cuenta/tag) para cerrar el edge "un filtro por cuenta real deja fuera
    /// la hermana lent". El consumo se hace desde el subset filtrado; la clave es
    /// `PersistentIdentifier` (estable aunque el subset provenga de otro fetch).
    ///
    /// - Parameter loanToGroupsSubcatIDs: ids de la(s) subcategoría(s) "Préstamo a grupos". Se usa
    ///   SOLO para desambiguar una pata de préstamo SUELTA (sin hermana de costo) de un "saldo
    ///   inicial: me deben" (ambos `+income`). En el caso común (hay pata de costo) basta el signo.
    ///   Vacío ⇒ las patas sueltas se conservan (comportamiento previo — sin falsos positivos).
    ///
    /// - Parameter converter: solo se consulta para reconvertir una pata cuyo importe guardado no se
    ///   puede creer (ver `storedPreferred(_:isUsableIn:)`). En el caso normal no se llama nunca.
    static func build(
        from transactions: [TransactionItem],
        loanToGroupsSubcatIDs: Set<PersistentIdentifier> = [],
        converter: CurrencyConverting = CurrencyConverter.shared
    ) -> GroupBridgeStatsAdjustment {
        // Agrupar SOLO gastos bridgeados. Settlements usan `splitSettlementID` (splitExpenseID nil)
        // y las TX personales también → quedan fuera de todo grupo.
        var byExpense: [String: [TransactionItem]] = [:]
        for tx in transactions {
            guard let sid = tx.splitExpenseID else { continue }
            byExpense[sid, default: []].append(tx)
        }

        var adjustedReal: [PersistentIdentifier: AdjustedAmounts] = [:]
        var suppressed: Set<PersistentIdentifier> = []

        for (_, legs) in byExpense {
            // Conservador: pata con cuenta sin hidratar (ventana lazy) → no tocar el grupo.
            if legs.contains(where: { $0.account == nil }) { continue }

            let real = legs.filter { $0.account?.isSystemAccount == false }
            let systemLegs = legs.filter { $0.account?.isSystemAccount == true }
            // Pata de préstamo = sistema + income-direction (SIGNO: escalar nunca-lazy).
            let loanBySign = systemLegs.filter { $0.amount > 0 }
            // Pata de costo clasificable = real, o sistema con `amount <= 0`
            // (Caso B `-myShare` / groupInvite TX1 / opening-balance-debt): ya son `-myShare`.
            let hasCostLeg = !real.isEmpty || systemLegs.contains { $0.amount <= 0 }

            if hasCostLeg {
                // Caso común (Caso A full / groupInvite): netear las patas de préstamo en la pata
                // REAL (si existe) y suprimirlas. Si NO hay real (Caso B / groupInvite / opening-debt)
                // la pata de costo ya vale `-myShare` → no se ajusta.
                if let realLeg = real.first {
                    let native = realLeg.amount + loanBySign.reduce(0) { $0 + $1.amount }
                    // Cada pata aporta su importe en la divisa preferida de la pata REAL —que es la
                    // que `CashFlowCalculator.resolvedAmount` compara— y la magnitud dudosa que lleva.
                    let target = realLeg.preferredCurrencyCode
                    let legs = ([realLeg] + loanBySign).map {
                        preferredContribution(of: $0, in: target, converter: converter)
                    }
                    let preferred = legs.reduce(0) { $0 + $1.value }
                    // La incertidumbre viaja con el monto, y se acumula en MAGNITUDES: las patas
                    // de préstamo se suprimen del recorrido, así que esta suma es la única vía por
                    // la que su tasa dudosa llega a un calculador. Sumarla con signo la cancelaría
                    // contra la pata real justo cuando más pesa — el neto de una resta apalancada
                    // no mide su propia incertidumbre.
                    let approximate = legs.reduce(0) { $0 + $1.approximateMagnitude }
                    adjustedReal[realLeg.persistentModelID] = AdjustedAmounts(
                        native: native, preferred: preferred, approximatePreferred: approximate
                    )
                    // Multi-real (no debería ocurrir): solo la primera se ajusta; el resto quedan
                    // sin tocar (estado inconsistente que el próximo re-bridge sana).
                }
                for leg in loanBySign { suppressed.insert(leg.persistentModelID) }
            } else {
                // Grupo de patas PURAMENTE derivadas (sin costo): distinguir "Préstamo a grupos"
                // (suprimir — ingreso fantasma de un pagador con parte 0 o de un Caso A remoto sin
                // aprobar) de "saldo inicial: me deben" (PRESERVAR) por ROL de subcategoría, con
                // skip-if-nil (subcat lazy nil → conservador: no suprimir).
                for leg in loanBySign {
                    guard let subID = leg.subcategory?.persistentModelID else { continue }
                    if loanToGroupsSubcatIDs.contains(subID) {
                        suppressed.insert(leg.persistentModelID)
                    }
                }
            }
        }

        return GroupBridgeStatsAdjustment(adjustedReal: adjustedReal, suppressed: suppressed)
    }

    /// Lo que UNA pata aporta al importe sintetizado, en `target`, y la magnitud dudosa que lleva.
    ///
    /// Lo normal es el importe guardado, con la duda de su propio flag. Pero un importe guardado que
    /// no se puede creer **no es un importe: es una conversión que falta**, y sumarlo tal cual hacía
    /// salir un gasto de grupo de 1.000 del que me tocan 100 como **1.000, y sin «≈»** — la pata de
    /// préstamo aportaba 0 al importe y 0 a la duda (`bridge-synthesis-trusts-a-zero-converted-amount`).
    /// Esa pata se reconvierte desde su nativo con la regla de `CashFlowCalculator.resolvedAmount`
    /// (la tasa de su fecha; dudosa si la tasa no es exacta), así que el número es «mi parte» y lleva
    /// la marca solo cuando de verdad la tasa es aproximada.
    private static func preferredContribution(
        of leg: TransactionItem,
        in target: String,
        converter: CurrencyConverting
    ) -> (value: Double, approximateMagnitude: Double) {
        if storedPreferred(leg, isUsableIn: target) {
            let value = leg.amountInPreferredCurrency
            return (value, leg.isExchangeRateProvisional ? abs(value) : 0)
        }
        return CashFlowCalculator.reconverted(
            leg.amount, from: leg.currencyCode, to: target, on: leg.date, converter: converter
        )
    }

    /// `false` en los dos casos en que el `amountInPreferredCurrency` guardado de una pata no vale
    /// para sumarlo con el de la pata real:
    /// - **es 0 con un nativo distinto de 0**: la conversión no llegó a escribirse (sync de una fila
    ///   incompleta, o una pata creada sin contexto de tasas). Ninguna tasa usable convierte un
    ///   importe no nulo en cero — «una tasa inservible es una tasa AUSENTE» (`currency-fx.md`), y un
    ///   importe convertido a cero tampoco es un importe;
    /// - **se guardó en OTRA divisa preferida** que la de la pata real: sumarlos mezcla divisas, la
    ///   misma forma que `resolvedAmount` ya resuelve para una fila suelta.
    private static func storedPreferred(_ leg: TransactionItem, isUsableIn target: String) -> Bool {
        guard leg.preferredCurrencyCode == target else { return false }
        return !(leg.amountInPreferredCurrency == 0 && leg.amount != 0)
    }

    /// Conveniencia para callers con `ModelContext`: resuelve los ids `loanToGroups` (read-only)
    /// y delega en el `build` puro. Construir desde el set MÁS AMPLIO del caller (con AMBAS
    /// hermanas). El `build(from:loanToGroupsSubcatIDs:)` puro se conserva para tests.
    @MainActor
    static func build(
        from transactions: [TransactionItem],
        context: ModelContext,
        converter: CurrencyConverting = CurrencyConverter.shared
    ) -> GroupBridgeStatsAdjustment {
        build(
            from: transactions,
            loanToGroupsSubcatIDs: GroupBridgeSystemEntities.loanToGroupsSubcategoryIDs(context: context),
            converter: converter
        )
    }
}
