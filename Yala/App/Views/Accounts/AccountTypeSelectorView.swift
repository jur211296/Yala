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
                        VStack(spacing: DS.Spacing.none) {
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
                                            .font(DS.Typography.body)
                                            .foregroundStyle(.secondary)
                                            .frame(width: DS.FormRow.iconWidth)

                                        Text(type.localizedName)
                                            .font(DS.Typography.body)
                                            .foregroundStyle(.primary)

                                        Spacer()

                                        if type == selectedType {
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(Color.electricIndigo)
                                                .font(DS.Typography.headline)
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
