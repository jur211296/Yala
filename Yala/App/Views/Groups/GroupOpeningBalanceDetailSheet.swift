//
//  GroupOpeningBalanceDetailSheet.swift
//  Yala
//
//  Detalle read-only de un saldo inicial (deuda de apertura). Detent medium
//  (iPhone) / large (iPad). El owner puede Editar (sube el editor vía el onDismiss
//  del padre) o Eliminar; un no-owner solo ve el vistazo, sin acciones.
//  Espejo simplificado de GroupExpenseDetailSheet.
//

import SwiftUI

struct GroupOpeningBalanceDetailSheet: View {
    private static let dateFormatter = AppLocale.dateFormatter(dateFormat: "d MMM yyyy")

    private static let rowIconWidth: CGFloat = 20

    let expense: SplitExpense
    /// memberID del deudor (la única share del saldo inicial).
    let debtorMemberID: String?
    let memberNameLookup: [String: String]
    let isOwner: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false

    private var detent: PresentationDetent {
        DS.Adaptive.usesLargeSheets ? .large : .medium
    }

    private var debtorName: String {
        debtorMemberID.flatMap { memberNameLookup[$0] } ?? "?"
    }

    private var creditorName: String {
        memberNameLookup[expense.paidByMemberID] ?? "?"
    }

    var body: some View {
        detailContent
            .presentationDetents([detent])
            .presentationDragIndicator(.hidden)
    }

    private var detailContent: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.lg) {
                    hero
                    detailsCard
                    if isOwner {
                        deleteButton
                    }
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.top, DS.Spacing.md)
                .padding(.bottom, DS.Spacing.xl)
            }
            .scrollBounceBehavior(.basedOnSize)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                    .accessibilityIdentifier("group_opening_balance_detail_close")
                }
                if isOwner {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(L10n.Action.edit) {
                            onEdit()
                        }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.primary)
                        .accessibilityIdentifier("group_opening_balance_detail_edit")
                    }
                }
            }
            .yalaScreenBackground(DS.Adaptive.usesLargeSheets ? .subtle : .transparent)
            .confirmationDialog(
                L10n.Action.delete,
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button(L10n.Action.delete, role: .destructive) {
                    onDelete()
                    dismiss()
                }
            }
        }
        .accessibilityIdentifier("group_opening_balance_detail_sheet")
    }

    private var hero: some View {
        VStack(spacing: DS.Spacing.xs) {
            HStack(spacing: DS.Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(Color(.secondaryLabel))
                        .frame(width: DS.Icon.badgeLarge, height: DS.Icon.badgeLarge)
                    Image(systemName: "arrow.left.arrow.right")
                        .font(DS.Typography.label)
                        .foregroundStyle(.white)
                        .accessibilityHidden(true)
                }

                AmountText(
                    value: expense.amount,
                    currencyCode: expense.currencyCode,
                    font: DS.Typography.largeTitle,
                    secondaryFont: DS.Typography.body,
                    tint: .primary,
                    forceFullPrecision: true
                )
            }

            Text(L10n.Groups.OpeningBalance.entryDescription)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var detailsCard: some View {
        VStack(spacing: DS.Spacing.none) {
            detailRow(icon: "arrow.up.circle", label: L10n.Groups.OpeningBalance.debtorLabel, value: debtorName)
            detailRow(icon: "arrow.down.circle", label: L10n.Groups.OpeningBalance.creditorLabel, value: creditorName)
            detailRow(
                icon: "calendar",
                label: L10n.Groups.OpeningBalance.dateLabel,
                value: Self.dateFormatter.string(from: expense.date)
            )
        }
        .padding(.vertical, DS.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(.thCard)
        )
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            showDeleteConfirm = true
        } label: {
            Label(L10n.Action.delete, systemImage: "trash")
                .font(DS.Typography.label)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.FormRow.paddingV)
        }
        .accessibilityIdentifier("group_opening_balance_detail_delete")
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: Self.rowIconWidth)
                .accessibilityHidden(true)

            Text(label)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(DS.Typography.label)
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.FormRow.paddingV)
    }
}
