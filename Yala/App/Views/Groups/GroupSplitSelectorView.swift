//
//  GroupSplitSelectorView.swift
//  Yala
//
//  Sheet unificado de división del gasto (estilo Splitwise): segmented de modos
//  arriba, lista de TODOS los miembros activos en medio, y el cuadre de asignación
//  fijo abajo. Lo usa el editor de pagos planificados de grupo; el formulario del gasto
//  lleva el reparto en línea (`GroupSplitEditorCard`) con la misma lista de personas.
//
//  Inclusión por modo:
//  - .equal → check por miembro (todos por default); el cuadre muestra "Cada uno paga".
//  - .exact/.percentage/.shares → campo editable por miembro; participa quien tenga un
//    valor (implícito, estilo Splitwise). Llenar incluye, vaciar excluye.
//

import SwiftUI

struct GroupSplitSelectorView: View {

    @Bindable var viewModel: GroupExpenseViewModel
    /// Solo en grupos de 2: vuelve a la pre-pantalla de 4 opciones rápidas. `nil` en 3+ → no aparece.
    var onRequestSimpleOptions: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(AppPreferences.self) private var appPreferences

    /// Tipo SALIENTE para la conversión inteligente al tocar otro segmento (el callback
    /// del segmented solo entrega el nuevo). Init en `.onAppear`. El segmented NO dispara
    /// `onTypeChange` en el mount (solo en tap) → no hace falta guard de prefill.
    @State private var lastType: SplitType = .equal

    var body: some View {
        NavigationStack {
            VStack(spacing: DS.Spacing.none) {
                SplitTypeSegmentedSelector(selectedType: $viewModel.splitType) { newType in
                    viewModel.convertSplitValues(from: lastType, to: newType)
                    lastType = newType
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.sm)

                ScrollView {
                    VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                        sheetHeader
                        memberSharesCard
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.lg)
                }
            }
            .safeAreaInset(edge: .bottom) { cuadreFooter }
            .yalaScreenBackground(.subtle)
            .navigationTitle(L10n.Groups.Expense.dividePayment)
            .navigationBarTitleDisplayMode(.inline)
            .dismissKeyboardOnTap()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }
                // Solo en grupos de 2: volver a la pre-pantalla de 4 opciones rápidas.
                if let onRequestSimpleOptions {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(L10n.Groups.Expense.TwoPerson.quickOptions) {
                            onRequestSimpleOptions()
                            dismiss()
                        }
                    }
                }
            }
            .onAppear { lastType = viewModel.splitType }
        }
        .yalaSheetDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Header (título + explicación por tipo)

    private var sheetHeader: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(sheetTitle)
                .font(DS.Typography.title3)
                .foregroundStyle(.primary)
            Text(sheetHint)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sheetTitle: String {
        switch viewModel.splitType {
        case .equal: return L10n.Groups.Expense.SplitSheet.equalTitle
        case .percentage: return L10n.Groups.Expense.SplitSheet.percentageTitle
        case .exact: return L10n.Groups.Expense.SplitSheet.exactTitle
        case .shares: return L10n.Groups.Expense.SplitSheet.sharesTitle
        }
    }

    private var sheetHint: String {
        switch viewModel.splitType {
        case .equal: return L10n.Groups.Expense.SplitSheet.equalHint
        case .percentage: return L10n.Groups.Expense.SplitSheet.percentageHint
        case .exact: return L10n.Groups.Expense.SplitSheet.exactHint
        case .shares: return L10n.Groups.Expense.SplitSheet.sharesHint
        }
    }

    // MARK: - Member list

    /// La lista vive en `GroupSplitMemberList` (compartida con la tarjeta del formulario);
    /// aquí conserva el color del grupo en los avatares y su tarjeta propia.
    private var memberSharesCard: some View {
        GroupSplitMemberList(
            viewModel: viewModel,
            avatarColor: { _ in Color(hex: viewModel.group.colorHex) }
        )
        .solidCard(radius: DS.Radius.xl)
    }

    // MARK: - Cuadre (footer fijo)

    private var cuadreFooter: some View {
        VStack(spacing: DS.Spacing.none) {
            Divider()
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                if viewModel.amount > 0 {
                    // Mismo formato en TODOS los modos: "{asignado} de {total}" + estado.
                    // En iguales asignado == total → "300 de 300" + "Balanceado".
                    HStack {
                        Text("\(appPreferences.currency(viewModel.assignedToAllocate, currencyCode: viewModel.currencyCode)) \(L10n.Split.sharesOf) \(appPreferences.currency(viewModel.amount, currencyCode: viewModel.currencyCode))")
                            .font(DS.Typography.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Spacer()
                        GroupSplitStatusBadge(viewModel: viewModel)
                    }
                }
                Text(L10n.Groups.Expense.membersSelected(viewModel.selectedMembers.count, viewModel.activeSheetMembers.count))
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(DS.Spacing.lg)
        }
        .background(.thCard)
    }
}
