//
//  GroupBudgetLogic.swift
//  Yala
//
//  Presupuesto de grupo: UN límite por grupo, en la moneda del grupo (decisión Jürgen 2026-09-06).
//
//  QUÉ CALCULA. Cuánto lleva gastado el grupo ENTERO contra su tope. No es la porción de nadie: suma
//  `SplitExpense.amount` —el importe total del gasto compartido— de todo el grupo.
//
//  LAS CUATRO REGLAS, y por qué cada una:
//
//  1. **Los saldos de apertura NO son gasto.** `isOpeningBalance` marca las filas que el puente crea para
//     arrastrar una deuda previa al grupo; contarlas haría que un viaje empezara con la barra ya medio
//     llena por dinero que no se gastó en el viaje. Es la misma exclusión que hacen las estadísticas.
//
//  2. **Se deduplica por `id`, y no es defensa decorativa.** Los gastos llegan repetidos por merges del
//     canal de sync, y un duplicado infla el total: la barra diría 90 % con el grupo a la mitad, y la
//     alerta saltaría por dinero que nadie gastó. Molde exacto de `GroupBalanceService` y del resumen
//     compartible.
//
//  3. **SÍ se convierten las divisas, al contrario que el resumen compartible.** Ahí la regla es "una
//     moneda, un bloque: los totales nunca se suman entre divisas", y su motivo está escrito: una
//     conversión al cambio del momento **se congela en una imagen** que cada miembro leería distinto
//     según cuándo se generó. Una barra de progreso no se congela — se recalcula cada vez que se abre
//     la pantalla —, así que ese motivo no la alcanza. Lo que sí la alcanzaría es no convertir: un viaje
//     con tope en soles y la mitad de los gastos en dólares enseñaría una barra falsamente baja, y esa
//     es la mentira peligrosa (la que deja gastar de más). Se usa el TC actual, exactamente como el
//     presupuesto PERSONAL (`BudgetsViewModel.budgetAmount`: "coherente con la semántica «presupuesto
//     consumido HOY»") y como los saldos de Grupos con "moneda única para deudas".
//
//  4. **Si hubo conversión, el número va marcado `≈`.** `isEstimate` es la señal que ya usa el resto de
//     Grupos, y significa "hubo conversión", no "la tasa era mala" (`.claude/rules/currency-fx.md`).
//

import Foundation

/// Progreso de un presupuesto de grupo, ya resuelto a UNA moneda: la del grupo.
struct GroupBudgetProgress: Equatable {
    /// El tope, tal cual lo fijó un admin. Siempre > 0 (un límite de 0 o negativo no es un presupuesto).
    let limitAmount: Double
    /// Lo gastado por el grupo, convertido a `currencyCode`.
    let spentAmount: Double
    /// La moneda del grupo. Tope y gastado están ambos en ella.
    let currencyCode: String
    /// Hubo al menos un gasto en otra divisa ⇒ el total lleva conversión y se pinta con `≈`.
    let isEstimate: Bool

    /// 0 … 100 y más allá: pasarse del tope es un estado legítimo que la barra tiene que poder enseñar.
    var percentage: Double {
        guard limitAmount > 0 else { return 0 }
        return (spentAmount / limitAmount) * 100
    }

    /// Pasarse se mide con TOLERANCIA de medio céntimo, no con un `>` pelado sobre `Double`.
    ///
    /// `spentAmount` es una suma de importes de dos decimales, y en coma flotante 915,69 + 53,48 + 30,83
    /// da 1000.0000000000001. Con un `>` estricto, gastar EXACTAMENTE el tope pinta la barra en rojo y
    /// «te pasaste por 0,00» — y no es un caso raro de laboratorio: en un barrido de repartos de 1.000
    /// en 3-8 importes, el 16,5 % cruzaba el `>` por el último bit. Es el mismo motivo por el que
    /// `GroupBalanceService` redondea antes de comparar y trata «saldado» con un epsilon de un céntimo.
    var isExceeded: Bool { spentAmount - limitAmount > 0.005 }

    /// Lo que queda. Nunca negativo: cuando se ha pasado, lo que interesa es `exceededAmount`.
    var remainingAmount: Double { max(limitAmount - spentAmount, 0) }

    /// Cuánto se ha pasado del tope. 0 si aún no se ha pasado.
    var exceededAmount: Double { max(spentAmount - limitAmount, 0) }
}

@MainActor
enum GroupBudgetLogic {

    /// Umbrales de aviso, FIJOS y no configurables — los mismos que el presupuesto personal ofrece por
    /// defecto. La decisión del owner fue "un límite por grupo" con un solo campo nuevo; unos umbrales
    /// configurables por grupo habrían pedido una segunda columna que nadie pidió.
    ///
    /// `nonisolated` a propósito: se usa como valor por defecto de un parámetro, y los argumentos por
    /// defecto se evalúan en contexto nonisolated (con el `static let` aislado al MainActor, Swift 6 lo
    /// convierte en error, no en aviso).
    nonisolated static let alertThresholds: [Int] = [50, 75, 90, 100]

    /// Progreso del presupuesto, o `nil` si el grupo no tiene uno (o si el tope no es utilizable).
    ///
    /// - Parameters:
    ///   - limitAmount: `SplitGroup.budgetLimitAmount`.
    ///   - currencyCode: `SplitGroup.currencyCode` — el tope se expresa SIEMPRE en ella.
    ///   - expenses: los gastos del grupo, sin filtrar (esta función excluye y deduplica lo que toca).
    static func progress(
        limitAmount: Double?,
        currencyCode: String,
        expenses: [SplitExpense],
        converter: CurrencyConverting = CurrencyConverter.shared
    ) -> GroupBudgetProgress? {
        // Un tope ausente, no finito o <= 0 no es un presupuesto: no hay nada que pintar.
        guard let limitAmount, limitAmount.isFinite, limitAmount > 0 else { return nil }

        // Regla 2 (dedup) y regla 1 (saldos de apertura fuera), en ese orden.
        let unique = Dictionary(grouping: expenses, by: \.id).values.compactMap(\.first)
        let real = unique.filter { !$0.isOpeningBalance }

        var spent: Double = 0
        var converted = false
        for expense in real {
            let amount = expense.amount.isFinite ? expense.amount : 0
            if expense.currencyCode == currencyCode {
                spent += amount
            } else {
                let value = converter.convertWithLatestRate(
                    Decimal(amount), from: expense.currencyCode, to: currencyCode
                )
                spent += NSDecimalNumber(decimal: value).doubleValue
                converted = true
            }
        }

        // Se redondea a 2 decimales lo que se expone, como hace `GroupBalanceService` con todo lo suyo:
        // la suma en coma flotante arrastra colas (1000.0000000000001) que no significan nada y que sí
        // deciden comparaciones y guards de igualdad.
        let safeSpent = spent.isFinite ? (spent * 100).rounded() / 100 : 0

        return GroupBudgetProgress(
            limitAmount: limitAmount,
            spentAmount: safeSpent,
            currencyCode: currencyCode,
            isEstimate: converted
        )
    }

    /// Conveniencia sobre el modelo. La sobrecarga de arriba es la que se testea: no necesita `SplitGroup`.
    static func progress(
        group: SplitGroup,
        expenses: [SplitExpense],
        converter: CurrencyConverting = CurrencyConverter.shared
    ) -> GroupBudgetProgress? {
        progress(
            limitAmount: group.budgetLimitAmount,
            currencyCode: group.currencyCode,
            expenses: expenses,
            converter: converter
        )
    }

    /// Los umbrales que `percentage` ha cruzado y que aún no se han avisado.
    ///
    /// Devuelve solo los NUEVOS, en orden ascendente. `alreadyNotified` es lo que ya se avisó para este
    /// grupo y este tope — la clave incluye el importe del tope, así que **cambiar el límite reabre los
    /// avisos**: subir el tope de 3000 a 6000 y volver a cruzar el 50 % es un aviso legítimo, no un
    /// duplicado.
    nonisolated static func newlyCrossedThresholds(
        percentage: Double,
        alreadyNotified: [Int],
        thresholds: [Int] = alertThresholds
    ) -> [Int] {
        guard percentage.isFinite else { return [] }
        let notified = Set(alreadyNotified)
        return thresholds
            .filter { percentage >= Double($0) && !notified.contains($0) }
            .sorted()
    }
}
