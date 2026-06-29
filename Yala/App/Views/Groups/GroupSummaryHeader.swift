//
//  GroupSummaryHeader.swift
//  Yala
//
//  Resumen global de la lista de grupos: misma banda inline que el detalle de un grupo
//  ("Te deben X" / "Debes Y" / "Te deben X · Debes Y" / "Están a mano"), pero sin card
//  ni chevron. A diferencia del detalle, el global NO se netea (se debe a personas
//  distintas en grupos distintos): mantiene ambos lados → cae en el caso de ambos lados.
//

import SwiftUI

struct GroupSummaryHeader: View {

    let summary: GroupGlobalSummary

    var body: some View {
        GroupHeaderBalanceBar(
            balance: headerBalance,
            debtsWereConverted: false,
            onTap: nil
        )
    }

    /// Mapea el resumen global (ambos lados por separado, por moneda) al modelo de la banda.
    private var headerBalance: GroupHeaderBalance {
        let owed = summary.totalOwedToMe.filter { $0.value > 0.01 }
        let owe = summary.totalIOwe.filter { $0.value > 0.01 }
        let state: GroupHeaderBalance.State
        switch (owed.isEmpty, owe.isEmpty) {
        case (true, true): state = .settled
        case (false, true): state = .theyOweMe
        case (true, false): state = .iOwe
        case (false, false): state = .mixed
        }
        return GroupHeaderBalance(state: state, owedToMe: owed, iOwe: owe)
    }
}
