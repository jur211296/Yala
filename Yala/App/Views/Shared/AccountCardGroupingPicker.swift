//
//  AccountCardGroupingPicker.swift
//  Yala
//
//  «Por tarjeta · Por línea» (tarjeta con varias divisas, entrega 4): el mismo selector en la tabla de informes agrupada
//  por cuenta y en el flujo de caja por cuenta de Tendencias. Solo lo monta quien tiene alguna tarjeta con líneas.
//

import SwiftUI

struct AccountCardGroupingPicker: View {
    @Binding var selection: AccountCardGrouping

    var body: some View {
        Picker(L10n.AccountCardGrouping.label, selection: $selection) {
            ForEach(AccountCardGrouping.allCases) { grouping in
                Text(grouping.title).tag(grouping)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("account_card_grouping_picker")
    }
}
