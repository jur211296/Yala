//
//  RecordSubcategoryChangeSheet.swift
//  Yala
//
//  «Cambiar subcategoría» desde el menú de una fila (auditoría UX 2.2, L8-9, opción B adaptada; decisión de Jürgen
//  del 2026-10-15): arriba el registro que cambia («Supermercado · S/ 11»), la subcategoría actual marcada, y bajo
//  cada opción su categoría y su necesidad. Al elegir se aplica, la hoja se cierra y sale el aviso
//  «Ahora es Restaurantes (Alimentación · Opcional) · Deshacer»; si la necesidad no cambia, solo la subcategoría.
//
//  Antes era el selector del formulario, titulado «Subcategoría», sin marcar la actual ni decir qué registro cambiaba,
//  y aplicaba en silencio al cerrarse (la necesidad también cambiaba sin que se viera).
//

import SwiftData
import SwiftUI

struct RecordSubcategoryChangeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.yalaTheme) private var theme

    let record: TransactionItem
    let viewModel: RecordsViewModel

    @State private var selectorData = SubcategorySelectorViewModel()

    var body: some View {
        NavigationStack {
            List {
                // El registro que cambia y, debajo, su subcategoría de ahora, marcada: se ve sin buscarla en la lista.
                Section {
                    recordSummary
                    if let current = record.subcategory {
                        option(current)
                    }
                }

                if !recentOptions.isEmpty {
                    Section(L10n.Common.recent) {
                        ForEach(recentOptions, id: \.persistentModelID) { option($0) }
                    }
                }

                ForEach(selectorData.groupedSubcategories, id: \.category.persistentModelID) { group in
                    Section(group.category.name) {
                        ForEach(group.subcategories, id: \.persistentModelID) { option($0) }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .yalaScreenBackground(.subtle)
            .navigationTitle(L10n.UXL8.changeSubcategoryTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                    .accessibilityIdentifier("record_subcategory_change_close")
                }
            }
        }
        .accessibilityIdentifier("record_subcategory_change_sheet")
        .onAppear {
            selectorData.setContext(
                modelContext,
                transactionType: TransactionClassificationLogic.isIncome(record) ? .income : .expense
            )
        }
    }

    /// Las recientes sin la actual: la actual ya va marcada en su categoría y repetirla arriba confunde.
    private var recentOptions: [Subcategory] {
        selectorData.recentSubcategories.filter { !isCurrent($0) }
    }

    // MARK: - El registro que cambia

    private var recordSummary: some View {
        let colorHex = record.category?.colorHex ?? AppConstants.defaultColorHex
        let iconName = record.subcategory?.iconName ?? record.category?.iconName ?? "tag.fill"
        let name = RecordDeleteConfirmationLogic.displayName(
            note: record.note,
            subcategoryName: record.subcategory?.name,
            categoryName: record.category?.name
        )
        let amount = appPreferences.currency(abs(record.amount), currencyCode: record.currencyCode)

        return HStack(spacing: DS.Spacing.md) {
            ZStack {
                Circle()
                    .fill(Color(hex: colorHex))
                    .frame(width: DS.ListRow.iconSize, height: DS.ListRow.iconSize)
                Image(systemName: iconName)
                    .font(DS.Typography.label)
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)

            Text(name.map { RecordDeleteConfirmationLogic.summary(name: $0, amount: amount) } ?? amount)
                .font(DS.Typography.label)
                .foregroundStyle(.primary)
                .lineLimit(2)
            Spacer(minLength: DS.Spacing.none)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("record_subcategory_change_record")
        .listRowBackground(theme.card)
    }

    // MARK: - Una opción

    private func isCurrent(_ subcategory: Subcategory) -> Bool {
        record.subcategory?.persistentModelID == subcategory.persistentModelID
    }

    private func option(_ subcategory: Subcategory) -> some View {
        let current = isCurrent(subcategory)
        let colorHex = subcategory.colorHex ?? subcategory.safeCategory.colorHex
        return Button {
            choose(subcategory)
        } label: {
            HStack(spacing: DS.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(Color(hex: colorHex).opacity(current ? 1 : 0.15))
                        .frame(width: DS.ListRow.iconSize, height: DS.ListRow.iconSize)
                    Image(systemName: subcategory.iconName ?? "tag.fill")
                        .font(DS.Typography.label)
                        .foregroundStyle(current ? Color.white : Color(hex: colorHex))
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(subcategory.name)
                        .font(DS.Typography.label)
                        .foregroundStyle(.primary)
                    Text(optionDetail(subcategory))
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: DS.Spacing.sm)

                if current {
                    // La actual, rellena y con su rótulo: se ve sin buscar el contorno (criterio c de Jürgen).
                    Label(L10n.UXL8.current, systemImage: "checkmark")
                        .labelStyle(.titleAndIcon)
                        .font(DS.Typography.labelSmall)
                        .foregroundStyle(.white)
                        .padding(.horizontal, DS.Chip.paddingH)
                        .padding(.vertical, DS.Chip.paddingV)
                        .background(Capsule().fill(theme.accent))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("record_subcategory_option_\(subcategory.name)")
        .accessibilityAddTraits(current ? .isSelected : [])
        .listRowBackground(theme.card)
    }

    /// «Alimentación · Opcional»; en un ingreso, la necesidad no aplica y va solo la categoría.
    private func optionDetail(_ subcategory: Subcategory) -> String {
        let category = subcategory.safeCategory
        guard !category.isIncome else { return category.name }
        return "\(category.name) · \(subcategory.need.displayName)"
    }

    // MARK: - Elegir y deshacer

    private func choose(_ subcategory: Subcategory) {
        guard !isCurrent(subcategory) else {
            dismiss()
            return
        }
        let previousSubcategory = record.subcategory
        let previousCategory = record.category
        let previousNeed = record.effectiveNeed
        let recordID = record.persistentModelID

        viewModel.updateSubcategory(subcategory, ids: [recordID], context: modelContext)
        guard viewModel.bulkUpdateError == nil else {
            // El menú solo ofrece el cambio cuando se puede; si algo lo rechaza, no se anuncia un cambio que no hubo.
            viewModel.bulkUpdateError = nil
            dismiss()
            return
        }
        DS.Haptic.success()

        let newNeed = record.effectiveNeed
        let isIncome = subcategory.safeCategory.isIncome
        let message = SubcategoryChangeNoticeLogic.mentionsNeed(old: previousNeed, new: isIncome ? nil : newNeed)
            ? L10n.UXL8.changedToWithNeed(subcategory.name, subcategory.safeCategory.name, newNeed.displayName)
            : L10n.UXL8.changedTo(subcategory.name)

        let context = modelContext
        let viewModel = viewModel
        dismiss()
        DraftDiscardUndoNotice.show(
            message: message,
            systemImage: "arrow.triangle.2.circlepath",
            undoTitle: L10n.UXL8.undo,
            noticeIdentifier: "record_subcategory_change_notice",
            undoIdentifier: "record_subcategory_change_undo"
        ) {
            viewModel.restoreSubcategory(
                previousSubcategory, category: previousCategory, id: recordID, ifStillIs: subcategory, context: context)
        }
    }
}
