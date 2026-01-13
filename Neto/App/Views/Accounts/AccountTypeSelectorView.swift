//
//  AccountTypeSelectorView.swift
//  Neto
//
//  Created by Neto Refactoring.
//

import SwiftUI

struct AccountTypeSelectorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedType: AccountType

    var body: some View {
        List {
            ForEach(AccountType.allCases) { type in
                HStack {
                    Text(type.localizedName)
                    Spacer()
                    if type == selectedType {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.tint)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedType = type
                    dismiss()
                }
            }
        }
        .navigationTitle(L10n.Account.type)
    }
}
