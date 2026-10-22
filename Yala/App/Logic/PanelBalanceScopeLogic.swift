//
//  PanelBalanceScopeLogic.swift
//  Yala
//
//  Qué suma un SALDO en el Panel: el número grande de arriba, la curva de saldo y la hoja «¿Cuánto tienes hoy?».
//
//  Decisión de Jürgen (2026-10-22, ticket `hoja-del-saldo-vivo-ignora-los-filtros-de-sesion`): **un saldo es lo que
//  hay en tus cuentas**. Las tres superficies cuentan las mismas cuentas —las elegibles por el filtro de cuentas, sin
//  las de sistema de Grupos cuando el interruptor «Incluir grupos en el total» está apagado— con TODOS sus
//  movimientos. Los chips de etiqueta, categoría, divisa, búsqueda o importe mueven los gastos y los ingresos, no un
//  saldo. Hasta ese día el número de arriba respetaba el interruptor y no los chips, y la hoja y la curva al revés: con
//  el interruptor apagado o con una etiqueta elegida, la misma pantalla daba dos cifras del mismo dinero.
//

import Foundation
import SwiftData

enum PanelBalanceScopeLogic {

    /// Las cuentas que suma un saldo del Panel. `eligible` ya trae aplicado «Excluir de las estadísticas» y el filtro
    /// de cuentas (`PanelViewModel.computeEligibleAccounts`); aquí se añade el interruptor de Grupos, con la misma
    /// regla que el número de arriba (`PanelTotalAccountsLogic.accountsForTotal`): solo sobre el total agregado.
    static func accounts(
        eligible: [Account],
        includeGroups: Bool,
        selectedAccountIDs: Set<PersistentIdentifier>,
        isExcludeMode: Bool
    ) -> [Account] {
        PanelTotalAccountsLogic.accountsForTotal(
            eligible,
            includeGroups: includeGroups,
            hasSelectedAccount: PanelTotalAccountsLogic.hasAccountFilter(
                selectedAccountIDs: selectedAccountIDs,
                isExcludeMode: isExcludeMode
            )
        )
    }

    /// Los movimientos de un saldo: todos los de esas cuentas, sin recorte de fecha y sin los chips de filtro.
    /// Incluye ajustes y saldos iniciales, que son parte del saldo.
    static func transactions(
        _ all: [TransactionItem],
        accountIDs: Set<PersistentIdentifier>
    ) -> [TransactionItem] {
        all.filter { transaction in
            guard let account = transaction.account else { return false }
            return accountIDs.contains(account.persistentModelID)
        }
    }
}
