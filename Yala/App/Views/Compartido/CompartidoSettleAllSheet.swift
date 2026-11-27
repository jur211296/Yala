//
//  CompartidoSettleAllSheet.swift
//  Yala
//
//  «Saldar todo» con una persona cuando son varios pagos (lote 2 de Compartido, 26-nov-2026): uno por grupo y moneda.
//  Antes de apuntarlos, la hoja los enumera para que nadie espere ver un solo pago (riesgo de la maqueta v2). Con un
//  solo pago no sale: va al formulario de «Saldar» de siempre (`SettlementFormView`).
//

import SwiftUI

struct CompartidoSettleAllSheet: View {
    let personName: String
    let items: [CompartidoPersonDetailLogic.SettleItem]
    /// Apunta los pagos. Devuelve `false` si alguno falló (la hoja se queda abierta con el aviso).
    let onConfirm: () -> Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(AppPreferences.self) private var appPreferences
    @State private var isSaving = false
    @State private var showsFailure = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    Text(L10n.Compartido.Detail.settleSheetMessage(items.count))
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        ForEach(items) { item in
                            itemRow(item)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .panelCard()
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.sm)
                .padding(.bottom, DS.Spacing.safeBottom)
                .readableColumn()
            }
            .scrollContentBackground(.hidden)
            .safeAreaBar(edge: .bottom, spacing: DS.Spacing.sm) {
                YalaPrimaryButton(
                    L10n.Compartido.Detail.settleConfirm(items.count), isLoading: isSaving, keepsDisabledToneInBar: true
                ) {
                    confirm()
                }
                .accessibilityIdentifier("compartido_settle_all_confirm")
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.sm)
            }
            .navigationTitle(L10n.Compartido.Detail.settleSheetTitle(personName))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Common.cancel) { dismiss() }
                        .accessibilityIdentifier("compartido_settle_all_cancel")
                }
            }
            .alert(L10n.Common.error, isPresented: $showsFailure) {
                Button(L10n.Common.ok) {}
            } message: {
                Text(L10n.Compartido.Detail.settleFailed)
            }
        }
        .yalaScreenBackground(.subtle)
    }

    private func itemRow(_ item: CompartidoPersonDetailLogic.SettleItem) -> some View {
        let amount = appPreferences.currency(
            item.debt.amount, currencyCode: item.debt.currencyCode, isEstimate: item.isEstimate)
        return VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            Text(item.groupName)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(item.iPay
                 ? L10n.Compartido.Detail.rowYouPay(personName, amount)
                 : L10n.Compartido.Detail.rowTheyPay(personName, amount))
                .font(DS.Typography.subheadlineEmphasized)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("compartido_settle_all_item")
    }

    private func confirm() {
        guard !isSaving else { return }
        isSaving = true
        if onConfirm() {
            dismiss()
        } else {
            DS.Haptic.error()
            isSaving = false
            showsFailure = true
        }
    }
}
