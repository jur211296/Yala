//
//  AdjustmentModeSelectorView.swift
//  Yala
//
//  Created by Yala Refactoring.
//

import SwiftUI

struct AdjustmentModeSelectorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedAdjustmentMode: AdjustmentMode

    var body: some View {
        ZStack {
            PanelBackgroundView()

            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    SectionBox(title: "") {
                        VStack(spacing: DS.Spacing.none) {
                            ForEach(Array(AdjustmentMode.allCases.enumerated()), id: \.element) { index, mode in
                                if index > 0 {
                                    SubsectionDivider()
                                }

                                Button {
                                    selectedAdjustmentMode = mode
                                    dismiss()
                                } label: {
                                    HStack(alignment: .top, spacing: DS.Spacing.md) {
                                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                                            Text(mode.displayName)
                                                .font(DS.Typography.body)
                                                .foregroundStyle(.primary)
                                            Text(mode.description)
                                                .font(DS.Typography.caption)
                                                .foregroundStyle(.secondary)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }

                                        Spacer()

                                        if mode == selectedAdjustmentMode {
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
        .navigationTitle(L10n.Account.adjustment)
        .navigationBarTitleDisplayMode(.inline)
    }
}
