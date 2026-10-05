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
import SwiftData

enum PanelTotalAccountsLogic {
    /// Las cuentas que el conteo «en N cuentas» del panorama puede contar: las que suman.
    ///
    /// Lo decide «Excluir de las estadísticas», el mismo filtro que aplica
    /// `LiveBalanceCalculator` al saldo, y no estar archivada (decisión de Jürgen, 2026-10-03:
    /// archivar solo enciende ese toggle). Antes contaba las no archivadas, así que una cuenta
    /// archivada seguía en el saldo sin estar en el conteo, y una excluida en el conteo sin estar
    /// en el saldo.
    ///
    /// Excepción: las cuentas sistema de Grupos que la propia app archiva
    /// (`GroupBridgeSystemEntities`, al quedarse sin movimientos o por duplicadas) no cuentan.
    /// Esas no las archiva el usuario, no se auto-excluyen y no se ven en ningún sitio; su saldo
    /// es 0, así que dejarlas fuera no separa el conteo del saldo.
    static func countableAccounts(_ accounts: [Account]) -> [Account] {
        accounts.filter { !$0.excludeFromStatistics && !($0.isSystemAccount && $0.isArchived) }
    }

    static func accountsForTotal(
        _ accounts: [Account],
        includeGroups: Bool,
        hasSelectedAccount: Bool
    ) -> [Account] {
        guard !hasSelectedAccount, !includeGroups else { return accounts }
        return accounts.filter { !$0.isSystemAccount }
    }

    /// ¿El saldo mostrado es el TOTAL AGREGADO, y por tanto le aplica el toggle
    /// `includeGroupsInPanelTotal`?
    ///
    /// Lo es cuando no hay filtro de cuentas **y también en modo excluir**: "todas
    /// menos éstas" sigue siendo un agregado, y el usuario que apagó las cuentas de
    /// grupos espera que sigan apagadas. Sin la segunda condición, excluir una
    /// cuenta devolvía al agregado las cuentas sistema que el toggle había
    /// quitado — y el saldo del Panel SUBÍA al excluir una cuenta con saldo
    /// positivo.
    ///
    /// Vive aquí, y no en el ViewModel, porque tiene dos consumidores —el saldo y
    /// el conteo "en N cuentas" del panorama— y tienen que decir lo mismo.
    static func hasAccountFilter(
        selectedAccountIDs: Set<PersistentIdentifier>,
        isExcludeMode: Bool
    ) -> Bool {
        !selectedAccountIDs.isEmpty && !isExcludeMode
    }
}
