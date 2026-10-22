//
//  GroupLegKindLogic.swift
//  Yala
//
//  Qué es una transacción puenteada de grupo cuando hay que decidir qué hacer con ella: la pata REAL o la VIRTUAL.
//  Ticket `orphaned-group-records-stay-out-of-the-notice`.
//

import Foundation

/// La regla ÚNICA de «fila de grupo sin cuenta»: real, virtual o no se sabe.
///
/// **Por qué hace falta.** El puente deja por cada gasto una pata REAL (lo que salió de una cuenta de la persona) y una o
/// varias VIRTUALES (el espejo en la cuenta de sistema «Grupos»). Con la cuenta a la vista se distinguen por ella. Sin
/// cuenta —una cuenta real que se eliminó antes de la 2.1, o una cuenta de sistema que no llegó por el espejo— las dos se
/// leen igual, y hasta este cambio los cuatro sitios que deciden (`OrphanedBridgedTxSweeper`, `GroupsAssociationDetach`,
/// `LegacyGroupsRetirement` y el aviso «Movimientos sin cuenta») resolvían esa duda cada uno a su manera: tres la trataban
/// como real y soltaban sus punteros, y el aviso la dejaba fuera siempre. Soltar una virtual la deja sin cuenta y sin
/// puntero: entra en el aviso, y moverla a una cuenta la convierte en un gasto real que se cuenta dos veces.
///
/// **La regla.** Con cuenta, manda la cuenta (como siempre). Sin cuenta, solo se afirma lo que se puede PROBAR:
/// - **virtual** si su subcategoría es de sistema y no es «Liquidación enviada»: los préstamos, los saldos iniciales y las
///   patas de liquidación de la cuenta «Grupos» son las únicas que llevan esas subcategorías;
/// - **real** si es la pata «Liquidación enviada» de una liquidación (la única pata real con subcategoría de sistema), o
///   si el gasto sigue aquí y la fila tiene exactamente la forma que el puente le da a la pata real (`provesRealLeg`);
/// - **no se sabe** en cualquier otro caso. Quien decide con un «no se sabe» no toca la fila.
///
/// Pura y sin `ModelContext`: la evidencia la reúne `GroupLegEvidence`.
enum GroupLegKindLogic {

    enum Kind: Equatable, Sendable {
        case real
        case virtual
        case unknown
    }

    /// La subcategoría de la fila, en lo que importa aquí.
    enum SubcategoryClass: Equatable, Sendable {
        /// Sin subcategoría (o sin hidratar).
        case none
        /// Una subcategoría del usuario.
        case user
        /// «Liquidación enviada»: la subcategoría de la pata REAL de una liquidación que pagué (Caso C).
        case settlementSent
        /// Cualquier otra de sistema: préstamo a grupos, cobro, pago de liquidación, saldos iniciales.
        case otherSystem
    }

    /// Lo que se sabe del gasto al que apunta la fila, cuando sigue en este teléfono.
    struct SourceEvidence: Equatable, Sendable {
        /// Pagué yo el gasto (Caso A).
        let currentUserPaid: Bool
        /// Gasto de saldo inicial: nunca tiene pata real.
        let isOpeningBalance: Bool
        /// Importe del gasto, en su divisa.
        let amount: Double
        let currencyCode: String
        /// Otra transacción con el mismo puntero vive en una cuenta REAL: esa es la pata real, y esta no.
        let siblingHasRealAccount: Bool
    }

    struct LegShape: Equatable, Sendable {
        /// `nil` = la fila no tiene cuenta.
        let accountIsSystem: Bool?
        let subcategory: SubcategoryClass
        /// Apunta a una liquidación (`splitSettlementID`); si no, a un gasto.
        let isSettlementLeg: Bool
        let amount: Double
        let currencyCode: String
        /// `nil` si el gasto ya no está aquí, no se pudo leer, o la fila es de una liquidación.
        let source: SourceEvidence?
        /// La Bandeja ya pregunta por esta liquidación («¿a qué cuenta llegó?»): hay un borrador pendiente suyo.
        var settlementHasPendingDraft: Bool = false
    }

    static func classify(_ leg: LegShape) -> Kind {
        if let isSystem = leg.accountIsSystem { return isSystem ? .virtual : .real }
        switch leg.subcategory {
        case .otherSystem:
            return .virtual
        case .settlementSent:
            // Solo la pata real del Caso C la lleva. En una fila de gasto no tiene sentido: no se afirma nada.
            // **Con un borrador pendiente de esa liquidación tampoco**: la Bandeja ya pide su cuenta, y aprobarlo crea
            // otra pata real. Moverla además contaría el pago dos veces, y aquí no se puede re-puentear para retirar ese
            // borrador: `bridgeSettlement` borra todas las patas de la liquidación, también la movida.
            guard leg.isSettlementLeg else { return .unknown }
            return leg.settlementHasPendingDraft ? .unknown : .real
        case .none, .user:
            return provesRealLeg(leg) ? .real : .unknown
        }
    }

    /// La forma exacta de la pata real que el puente crea para un gasto que pagué yo: importe `-total` en la divisa del
    /// gasto (`GroupTransactionBridge.bridgeExpense`, rama Caso A), sin otra pata real al lado.
    ///
    /// **Por qué no hay doble conteo aunque coincida con una virtual.** La única virtual con ese importe es la `-miParte`
    /// de un gasto que pagué yo y cuya parte es el total (no presté nada): ahí la pata real y la virtual valen lo mismo,
    /// no hay préstamo que la compense, y tratarla como real deja el mismo neto. Cualquier otra virtual tiene otro importe
    /// (el préstamo es positivo, `-miParte` es menor que el total) o no es de un gasto que pagué.
    static func provesRealLeg(_ leg: LegShape) -> Bool {
        guard leg.accountIsSystem == nil, !leg.isSettlementLeg, let source = leg.source else { return false }
        guard source.currentUserPaid, !source.isOpeningBalance, !source.siblingHasRealAccount else { return false }
        guard normalizeCurrencyCode(leg.currencyCode) == normalizeCurrencyCode(source.currencyCode) else { return false }
        return abs(leg.amount + source.amount) < amountTolerance
    }

    /// Medio céntimo: los importes viajan como `Double` y el puente escribe `-total` tal cual.
    static let amountTolerance = 0.005
}
