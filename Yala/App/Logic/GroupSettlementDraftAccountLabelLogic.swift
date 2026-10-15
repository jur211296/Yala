//
//  GroupSettlementDraftAccountLabelLogic.swift
//  Yala
//
//  Qué cuenta pide el borrador de una liquidación de grupo: de origen o de destino.
//

import Foundation

enum GroupSettlementDraftAccountLabelLogic {
    /// El puente crea el borrador de quien PAGA con el importe en negativo («Liquidación enviada»)
    /// y el de quien COBRA en positivo («Liquidación recibida»). Negativo = el dinero sale.
    static func isOutgoing(amount: Double?) -> Bool { (amount ?? 0) < 0 }
}
