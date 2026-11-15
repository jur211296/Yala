//
//  BankNoticeReading.swift
//  Yala
//
//  Atajo del banco (2.3, B1): qué sale de leer el texto de un aviso del banco. Lo produce la acción de Atajos
//  («Registrar movimiento desde texto») en el teléfono y lo convierte en borrador la app (`BankNoticeDraftService`).
//  Tipos puros y `Codable`: viajan por la cola del App Group entre los dos procesos.
//

import Foundation

/// El banco o la billetera que mandó el aviso. `rawValue` estable: va en la cola y en la línea de evidencia del borrador.
nonisolated enum BankNoticeBank: String, Codable, CaseIterable, Equatable {
    case bcp
    case yape
    case interbank
    case plin
    case bbva
    case scotiabank
    /// Un banco sin reglas: solo lo lee el modelo del iPhone.
    case other

    /// Nombre de marca. Igual en todos los idiomas; es también la línea de evidencia del borrador.
    var brandName: String {
        switch self {
        case .bcp: return "BCP"
        case .yape: return "Yape"
        case .interbank: return "Interbank"
        case .plin: return "Plin"
        case .bbva: return "BBVA"
        case .scotiabank: return "Scotiabank"
        case .other: return Self.otherEvidence
        }
    }

    /// La evidencia de un aviso de un banco sin reglas. Marca técnica, no se enseña tal cual.
    static let otherEvidence = "Aviso"

    /// Palabras que delatan al banco dentro del texto, en minúsculas. El orden de `allCases` desempata: Yape va antes que
    /// BCP porque un aviso de Yape suele nombrar al BCP.
    var markers: [String] {
        switch self {
        case .bcp: return ["bcp", "banco de crédito", "banco de credito"]
        case .yape: return ["yape", "yapeó", "yapeo", "yapeaste"]
        case .interbank: return ["interbank"]
        case .plin: return ["plin", "plineó", "plineaste"]
        case .bbva: return ["bbva"]
        case .scotiabank: return ["scotiabank", "scotia"]
        case .other: return []
        }
    }

    /// El banco cuyo nombre aparece en el texto, o `nil`.
    static func detect(in text: String) -> BankNoticeBank? {
        let lowered = text.lowercased()
        let order: [BankNoticeBank] = [.yape, .plin, .interbank, .bbva, .scotiabank, .bcp]
        return order.first { bank in bank.markers.contains { lowered.contains($0) } }
    }

    /// El banco de una línea de evidencia guardada en un borrador, o `nil` si no es de un aviso del banco.
    static func fromEvidence(_ evidence: String?) -> BankNoticeBank? {
        guard let evidence else { return nil }
        return allCases.first { $0.brandName == evidence }
    }
}

/// Un movimiento leído de un aviso. El importe va siempre en positivo; `isExpense` dice el signo.
nonisolated struct BankNoticeMovement: Codable, Equatable {
    var amount: Decimal
    /// Código ISO 4217 si el aviso lo dice (`PEN`, `USD`); `nil` si solo trae un `$` u otra cosa ambigua.
    var currencyCode: String?
    /// El símbolo ambiguo que traía (`$`), para que la app lo resuelva con la última cuenta usada.
    var ambiguousSymbol: String?
    var isExpense: Bool
    /// Comercio (gasto) o persona que paga (ingreso), tal como lo escribe el aviso.
    var counterparty: String?
    /// Últimos cuatro dígitos de la tarjeta, si los trae.
    var cardLast4: String?
}

/// Qué entendió Yala del aviso.
nonisolated enum BankNoticeReading: Codable, Equatable {
    /// Un movimiento. `ruleID` dice qué regla lo leyó; `nil` si lo leyó el modelo del iPhone.
    case movement(BankNoticeMovement, ruleID: String?)
    /// No es un movimiento: una clave, un código, una promoción, un aviso de saldo. No deja borrador.
    case notAMovement
    /// No se entendió. Deja un borrador sin importe con el texto, para que la persona lo complete.
    case notUnderstood

    var leavesDraft: Bool {
        if case .notAMovement = self { return false }
        return true
    }
}
