//
//  LiveAnchorEducationLogic.swift
//  Yala
//
//  Decide si la píldora «Hoy ⓘ» del gráfico de saldo y su punto abren la hoja «Tu saldo hoy».
//
//  Esa hoja explica una sola cosa: que el saldo de hoy no coincide con la suma histórica porque hay
//  dinero en otras monedas y su valor cambia. Con todo el dinero en la divisa principal no hay
//  diferencia que explicar, y la hoja decía igual «Tienes dinero en otras monedas» — falso
//  (auditoría UX 2.2, lote 3, B1). El aviso de la primera vez (`PanelView.shouldShowTodayFXCoachMark`)
//  ya se callaba en ese caso; la píldora y el punto no.
//

import Foundation

enum LiveAnchorEducationLogic {
    /// `true` si alguna divisa distinta de la principal tiene saldo. Es la condición exacta en la que
    /// el valor de hoy y la suma histórica pueden separarse: una cuenta solo en dólares con la
    /// principal en soles cuenta, aunque sea la única divisa del desglose.
    static func explainsCurrencyDifference(
        _ breakdown: [String: Decimal]?,
        preferredCurrencyCode: String
    ) -> Bool {
        guard let breakdown else { return false }
        return breakdown.contains { code, balance in
            code != preferredCurrencyCode && balance != 0
        }
    }
}
