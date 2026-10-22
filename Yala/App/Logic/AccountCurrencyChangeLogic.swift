//
//  AccountCurrencyChangeLogic.swift
//  Yala
//
//  ¿Se puede cambiar la divisa de una cuenta que ya tiene movimientos?
//  Ticket `changing-an-account-currency-orphans-its-whole-history`.
//

import Foundation

/// Decide qué pasa cuando el usuario cambia la divisa de una cuenta **que ya tiene histórico**.
///
/// **El problema que cierra:** `AccountFormViewModel` escribía `account.currencyCode` también en la
/// ruta de update, sin mirar las transacciones. El histórico entero se quedaba estampado en la
/// divisa vieja dentro de una cuenta que ya decía otra, y a partir de ahí media app suma en crudo
/// rotulando con la divisa de la CUENTA (`AccountBalanceCalculator`, tarjetas del Panel, widgets) y
/// la otra media lee `tx.currencyCode` y convierte (`LiveBalanceCalculator`, presupuestos, informes).
/// Dos respuestas distintas sobre el mismo dinero, y solo una se movía con el tipo de cambio.
///
/// **La política, decidida por el owner el 2026-09-09: prohibir, y ofrecer convertir cuando se
/// puede.** No «avisar y seguir»: eso deja vivo el desemparejamiento y además rompe el round-trip de
/// exportación (se exporta `transaction.currencyCode` y la importación rechaza toda fila cuya divisa
/// no sea la de la cuenta destino).
///
/// **Por qué hay filas que ni siquiera se pueden convertir.** No es prudencia: en las tres una
/// conversión NO SE SOSTIENE, medido en este árbol el 2026-09-09.
///
/// - **Pata de transferencia.** Las dos patas codifican juntas la tasa de la operación: una sale de
///   una cuenta con su importe y la otra entra en otra con el suyo. `bulkUpdateAmount` ya bloquea
///   por esto mismo (`RecordsViewModel:722-728`, «cambiar el amount destruiría el exchange rate»), y
///   `bulkUpdateAccount` bloquea transferencias enteras (`:565`). Reexpresar una sola pata desde la
///   pantalla de cuentas convertiría una transferencia interna en cross-divisa sin que nadie lo
///   pidiera.
/// - **Gasto de grupo (`splitExpenseID`).** El re-bridge **pisa el `amount`** en cada pasada
///   (`GroupTransactionBridge:393`), así que la conversión duraría hasta la siguiente. Y es peor que
///   inútil: el guard de esa rama es `realTx.currencyCode == expense.currencyCode` (`:391`); en
///   cuanto dejan de casar, el bridge **BORRA la transacción** y deja un draft en el Inbox
///   (`:410-422`). Convertirla destruye la fila del usuario en el siguiente re-bridge.
/// - **Liquidación (`splitSettlementID`).** `bridgeSettlement` hace delete+recreate incondicional y
///   toma `amount` y `currencyCode` del settlement (`:1069-1083`). Lo que se escriba aquí se pierde.
///
/// En los tres casos manda otra entidad —la cuenta hermana, el gasto de grupo, la liquidación— y la
/// pantalla de cuentas no es su sitio. Por eso la divisa se bloquea entera en vez de convertir a
/// medias: dejar unas filas reexpresadas y otras no reproduce el bug original en pequeño.
enum AccountCurrencyChangeLogic {

    // MARK: - Motivos de bloqueo

    /// Por qué una fila concreta no admite que se reexprese su importe.
    ///
    /// `String` como raw a propósito: el orden de declaración NO se usa para nada que se vea fuera
    /// (el copy se elige por `case`, no por índice), así que añadir un motivo en medio es inocuo.
    enum BlockReason: String, CaseIterable, Hashable, Sendable {
        /// Una de las dos patas de una transferencia entre cuentas.
        case transfer
        /// Derivada de un gasto de grupo — el importe lo manda el grupo.
        case groupExpense
        /// Derivada de una liquidación de grupo — se recrea entera en cada re-bridge.
        case groupSettlement
    }

    // MARK: - Forma de una fila

    /// Lo único que hace falta saber de una transacción para clasificarla, sin SwiftData de por
    /// medio: así la decisión se puede fijar con tests puros y no depende de montar un contenedor.
    struct RowShape: Equatable, Sendable {
        /// `balanceAdjustmentType == "transfer"`.
        let isTransferType: Bool
        /// `transferPairID != nil` — se mira **además** del tipo, no en su lugar.
        ///
        /// Los dos campos pueden divergir: al desligar un par, `NewTransactionViewModel:634` deja el
        /// `transferPairID` en `nil` conservando el tipo. Preguntar por uno solo dejaría pasar la
        /// mitad de las formas de «esto es media transferencia», y aquí el coste de un falso negativo
        /// (convertir una pata suelta) es mucho mayor que el de un falso positivo (bloquear una fila
        /// que ya no tiene pareja).
        let hasTransferPairID: Bool
        /// `splitExpenseID != nil`.
        let hasSplitExpenseID: Bool
        /// `splitSettlementID != nil`.
        let hasSplitSettlementID: Bool

        init(
            isTransferType: Bool = false,
            hasTransferPairID: Bool = false,
            hasSplitExpenseID: Bool = false,
            hasSplitSettlementID: Bool = false
        ) {
            self.isTransferType = isTransferType
            self.hasTransferPairID = hasTransferPairID
            self.hasSplitExpenseID = hasSplitExpenseID
            self.hasSplitSettlementID = hasSplitSettlementID
        }
    }

    /// El motivo por el que esta fila frena el cambio de divisa, o `nil` si se puede reexpresar.
    ///
    /// El orden de comprobación decide qué motivo se enseña cuando una fila cumple varios; se
    /// resuelve por especificidad —una liquidación es más concreta que un gasto— y no cambia el
    /// veredicto, que solo mira si hay motivo o no.
    static func blockReason(for row: RowShape) -> BlockReason? {
        if row.hasSplitSettlementID { return .groupSettlement }
        if row.hasSplitExpenseID { return .groupExpense }
        if row.isTransferType || row.hasTransferPairID { return .transfer }
        return nil
    }

    // MARK: - Veredicto

    /// Qué puede hacer el formulario con el selector de divisa de esta cuenta.
    enum Verdict: Equatable, Sendable {
        /// Sin movimientos: la divisa se cambia y no hay nada que reexpresar.
        case free
        /// Todas las filas admiten conversión. `rowCount` es lo que se le enseña al usuario en la
        /// confirmación, así que es el número de filas que se van a tocar de verdad.
        case needsConversion(rowCount: Int)
        /// Hay al menos una fila que manda otra entidad: la divisa no se puede cambiar.
        case blocked(reasons: Set<BlockReason>, blockedCount: Int)
    }

    /// El veredicto para el conjunto de filas de una cuenta.
    ///
    /// **Basta UNA fila bloqueada para bloquear el conjunto.** La alternativa —convertir las libres y
    /// dejar las otras— produce una cuenta en USD con parte del histórico en PEN, que es exactamente
    /// el estado que este ticket existe para impedir, solo que más pequeño y más difícil de ver.
    static func verdict(for rows: [RowShape]) -> Verdict {
        guard !rows.isEmpty else { return .free }

        var reasons: Set<BlockReason> = []
        var blockedCount = 0
        for row in rows {
            if let reason = blockReason(for: row) {
                reasons.insert(reason)
                blockedCount += 1
            }
        }

        guard reasons.isEmpty else {
            return .blocked(reasons: reasons, blockedCount: blockedCount)
        }
        return .needsConversion(rowCount: rows.count)
    }
}
