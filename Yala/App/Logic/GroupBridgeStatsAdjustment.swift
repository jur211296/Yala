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
    static func build(
        from transactions: [TransactionItem],
        loanToGroupsSubcatIDs: Set<PersistentIdentifier> = []
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
                    let preferred = realLeg.amountInPreferredCurrency
                        + loanBySign.reduce(0) { $0 + $1.amountInPreferredCurrency }
                    adjustedReal[realLeg.persistentModelID] = AdjustedAmounts(native: native, preferred: preferred)
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

    /// Conveniencia para callers con `ModelContext`: resuelve los ids `loanToGroups` (read-only)
    /// y delega en el `build` puro. Construir desde el set MÁS AMPLIO del caller (con AMBAS
    /// hermanas). El `build(from:loanToGroupsSubcatIDs:)` puro se conserva para tests.
    @MainActor
    static func build(from transactions: [TransactionItem], context: ModelContext) -> GroupBridgeStatsAdjustment {
        build(
            from: transactions,
            loanToGroupsSubcatIDs: GroupBridgeSystemEntities.loanToGroupsSubcategoryIDs(context: context)
        )
    }
}
