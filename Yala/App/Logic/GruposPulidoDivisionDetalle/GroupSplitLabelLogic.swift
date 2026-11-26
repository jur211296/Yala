//
//  GroupSplitLabelLogic.swift
//  Yala
//
//  Qué tipo de reparto enseña el detalle de un gasto de grupo junto a «Reparto» (encargo del 2026-11-26).
//  Antes la etiqueta salía solo del tipo guardado y caía en «Partes iguales» para todo lo que no fuera porcentaje,
//  exacto o partes: un «Pagaste · es todo de Pia» (tipo `equal` con un único participante) se leía «Partes iguales»
//  con Tú S/ 0 y Pia S/ 214 debajo. Ahora mandan los montos reales del reparto, y el tipo guardado solo decide
//  entre varias personas con partes distintas.
//
//  Lógica pura: sin SwiftUI ni L10n. El texto vive en `GruposPulidoDivisionDetalleText`.
//

import Foundation

enum GroupSplitLabelLogic {

    /// Lo que se enseña junto a «Reparto».
    enum Kind: Equatable {
        /// Todos los que tienen parte, la misma (al céntimo de redondeo).
        case equal
        /// Una sola persona carga con todo el gasto: tú.
        case allForMe
        /// Una sola persona carga con todo el gasto: otra.
        case allFor(memberID: String)
        case exact
        case percentage
        case shares
        /// Partes distintas sin tipo que lo explique (gastos viejos o tipo desconocido).
        case custom
    }

    /// Tolerancia de «es la misma parte»: un céntimo y medio cubre el reparto de céntimos que no dividen exacto
    /// (S/ 100 entre 3 → 33.33 · 33.33 · 33.34) sin confundir montos de verdad distintos.
    static let equalTolerance = 0.015
    /// Por debajo, una parte cuenta como cero (la de quien pagó por otro).
    static let zeroTolerance = 0.004

    /// - Parameters:
    ///   - splitType: el tipo guardado (`SplitExpense.splitType`); vacío o desconocido en gastos viejos.
    ///   - shares: memberID y monto de cada parte guardada. Varias del mismo miembro se suman.
    ///   - currentMemberID: quién eres; `nil` si la identidad no se resolvió.
    static func kind(
        splitType: String?,
        shares: [(memberID: String, amount: Double)],
        currentMemberID: String?
    ) -> Kind {
        var byMember: [String: Double] = [:]
        for share in shares where share.amount.isFinite {
            byMember[share.memberID, default: 0] += share.amount
        }
        let positive = byMember.filter { $0.value > zeroTolerance }
        let stored = (splitType ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // Una sola persona con parte: es todo suyo, se haya guardado con el tipo que sea.
        if positive.count == 1, let only = positive.first {
            if let currentMemberID, only.key == currentMemberID { return .allForMe }
            return .allFor(memberID: only.key)
        }

        // Sin partes que mirar (aún no llegaron): lo que diga el tipo guardado, como antes.
        guard positive.count > 1 else { return kindFromStoredType(stored) }

        let amounts = positive.map(\.value)
        let isEven = (amounts.max() ?? 0) - (amounts.min() ?? 0) <= equalTolerance
        if isEven { return .equal }
        switch stored {
        case SplitType.percentage.rawValue: return .percentage
        case SplitType.exact.rawValue: return .exact
        case SplitType.shares.rawValue: return .shares
        default: return .custom   // `equal`, vacío o desconocido con partes distintas
        }
    }

    private static func kindFromStoredType(_ stored: String) -> Kind {
        switch stored {
        case SplitType.percentage.rawValue: return .percentage
        case SplitType.exact.rawValue: return .exact
        case SplitType.shares.rawValue: return .shares
        default: return .equal
        }
    }

    /// Icono SF Symbol de cada tipo.
    static func iconName(for kind: Kind) -> String {
        switch kind {
        case .equal: return "equal.circle.fill"
        case .allForMe, .allFor: return "person.fill"
        case .exact: return "number"
        case .percentage: return "percent"
        case .shares: return "chart.pie.fill"
        case .custom: return "slider.horizontal.3"
        }
    }

    /// La barra de proporciones solo informa cuando hay partes distintas entre varias personas.
    static func showsProportionBar(for kind: Kind) -> Bool {
        switch kind {
        case .exact, .percentage, .shares, .custom: return true
        case .equal, .allForMe, .allFor: return false
        }
    }
}
