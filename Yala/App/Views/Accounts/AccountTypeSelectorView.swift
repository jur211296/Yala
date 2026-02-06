//
//  AccountTypeSelectorView.swift
//  Yala
//
//  Created by Yala Refactoring.
//

import SwiftUI

struct AccountTypeSelectorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedType: AccountType

    var body: some View {
        ZStack {
            PanelBackgroundView()

            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    SectionBox(title: "") {
                        VStack(spacing: 0) {
                            ForEach(Array(AccountType.allCases.enumerated()), id: \.element) { index, type in
                                if index > 0 {
                                    SubsectionDivider()
                                }

                                Button {
                                    selectedType = type
                                    dismiss()
                                } label: {
                                    HStack(spacing: DS.Spacing.md) {
                                        Image(systemName: iconName(for: type))
                                            .font(.body)
                                            .foregroundStyle(.secondary)
                                            .frame(width: DS.FormRow.iconWidth)

                                        Text(type.localizedName)
                                            .font(.body)
                                            .foregroundStyle(.primary)

                                        Spacer()

                                        if type == selectedType {
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(Color.electricIndigo)
                                                .font(.body.weight(.semibold))
                                        }
                                    }
                                    .padding(.horizontal, DS.FormRow.paddingH)
                                    .padding(.vertical, DS.FormRow.paddingV)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xxl)
            }
        }
        .navigationTitle(L10n.Account.type)
        .navigationBarTitleDisplayMode(.inline)
    }
}
