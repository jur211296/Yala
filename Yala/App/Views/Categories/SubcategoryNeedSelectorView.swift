//
//  SubcategoryNeedSelectorView.swift
//  Yala
//
//  Created by Yala Refactoring.
//

import SwiftUI

/// Selector de naturaleza de subcategoría (Esencial, Prioritaria, Opcional, Sin clasificación)
struct SubcategoryNeedSelectorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedNeed: SubcategoryNeed

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                // Para qué sirve (auditoría UX 2.2, lote 7, L7-12): sin esto, nadie lo rellenaba.
                Text(L10n.UXL7.Categories.needExplainer)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, DS.Spacing.xs)
                    .accessibilityIdentifier("need_selector_explainer")

                SectionBox(title: "") {
                    VStack(spacing: DS.Spacing.none) {
                        ForEach(Array(SubcategoryNeed.allCases.enumerated()), id: \.element) {
                            index, need in
                            if index > 0 {
                                SubsectionDivider()
                            }
                            needRow(need)
                        }
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.xxl)
        }
        .yalaScreenBackground(.subtle)
        .navigationTitle(L10n.Need.title)
        .navigationBarTitleDisplayMode(.inline)
        .swipeBack()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                YalaToolbarButton(systemName: "chevron.left", label: L10n.Action.back) {
                    dismiss()
                }
            }
        }
    }

    /// La elegida va rellena de índigo, no solo con un check (criterio de foco).
    private func needRow(_ need: SubcategoryNeed) -> some View {
        let isSelected = need == selectedNeed
        return Button {
            selectedNeed = need
            dismiss()
        } label: {
            HStack(spacing: DS.Spacing.md) {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(need.displayName)
                        .font(DS.Typography.body)
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                    Text(need.description)
                        .font(DS.Typography.caption)
                        .foregroundStyle(isSelected ? Color.white.opacity(0.85) : Color.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.white)
                        .font(DS.Typography.headline)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.FormRow.paddingV)
            .background(isSelected ? Color.selectedIndigoFill : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
