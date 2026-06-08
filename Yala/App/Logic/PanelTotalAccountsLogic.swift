//
//  PanelTotalAccountsLogic.swift
//  Yala
//
//  Pure-logic para decidir qué cuentas alimentan el balance TOTAL agregado del
//  Panel ("Tienes X en N cuentas"). Extraído para test sin SwiftData/ModelContext.
//
//  El toggle `includeGroupsInPanelTotal` solo aplica al TOTAL (sin cuenta
//  seleccionada): con el toggle OFF, las cuentas sistema de grupos ("Grupos
//  [moneda]") se excluyen del agregado. Si hay una cuenta seleccionada, el
//  balance es el de esa cuenta y el toggle no aplica. La lista del carrusel se
//  renderiza aparte (siempre muestra todas las cuentas) y no se ve afectada.
//

import Foundation

enum PanelTotalAccountsLogic {
    static func accountsForTotal(
        _ accounts: [Account],
        includeGroups: Bool,
        hasSelectedAccount: Bool
    ) -> [Account] {
        guard !hasSelectedAccount, !includeGroups else { return accounts }
        return accounts.filter { !$0.isSystemAccount }
    }
}
