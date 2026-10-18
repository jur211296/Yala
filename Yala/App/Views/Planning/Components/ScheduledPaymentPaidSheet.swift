//
//  ScheduledPaymentPaidSheet.swift
//  Yala
//
//  «Ya lo pagué» (o «Ya lo recibí» en un ingreso), UX 2.2 · L10-9 B (Jürgen, 2026-10-15). Antes, marcar un pago como
//  hecho era tocar una fecha, «Vincular gasto», buscar en «GASTOS PRÓXIMOS» y confirmar una pregunta que no decía qué
//  pasaba, también en un ingreso. Ahora la hoja cubre los dos casos reales:
//
//  - **Apuntarlo ahora**: el monto del pago, editable, y un toque. Crea el registro por el mismo camino que la Bandeja.
//  - **Ya lo apunté**: «Tus gastos de esas fechas» (los de ±15 días, sin transferencias), y se marca con el elegido.
//
//  Un pago compartido no ofrece «Apuntarlo ahora»: se aprueba con el formulario de grupo, desde la Bandeja.
//

import SwiftData
import SwiftUI

struct ScheduledPaymentPaidSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(DraftService.self) private var draftService
    @Environment(CurrencyConverter.self) private var currencyConverter

    let payment: ScheduledPayment
    let occurrence: Date
    @Bindable var viewModel: ScheduledPaymentsViewModel
    /// Sin cuenta o sin subcategoría no se puede apuntar en un toque: se abre el formulario de la Bandeja para esa fecha.
    let onRecordInForm: () -> Void

    @State private var amountString: String = ""
    @State private var candidates: [TransactionItem] = []
    @State private var showConfirmation: Bool = false
    @State private var selectedTransaction: TransactionItem?
    @State private var errorMessage: String = ""
    @State private var showError = false
    @State private var selectedDetent: PresentationDetent = .medium
    @FocusState private var isAmountFocused: Bool

    private var isLargeDetent: Bool { selectedDetent == .large }

    private var amount: Double { AmountInputHelper.parseDecimal(amountString) }

    /// En un toque solo con todo lo que pide un registro; si falta algo, el formulario lo pide.
    private var canRecordInline: Bool { payment.account != nil && payment.subcategory != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    header
                    if !payment.isGroupPayment {
                        recordNowCard
                    }
                    alreadyRecordedSection
                }
                .padding(DS.Spacing.lg)
                .dismissKeyboardOnTap()
            }
            .scrollDismissesKeyboard(.interactively)
            .yalaScreenBackground(isLargeDetent ? .subtle : .transparent)
            .navigationTitle(payment.isIncome ? L10n.UXL10.actionReceived : L10n.UXL10.actionPaid)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }
            }
            .onAppear {
                amountString = AmountInputHelper.formatWithGrouping(payment.amount)
                candidates = viewModel.fetchCandidateTransactions(for: payment, referenceDate: occurrence)
            }
            .alert(
                L10n.UXL10.confirmTitle(payment.name),
                isPresented: $showConfirmation
            ) {
                Button(L10n.Action.cancel, role: .cancel) {
                    selectedTransaction = nil
                }
                Button(L10n.UXL10.confirmYes) {
                    if let tx = selectedTransaction {
                        viewModel.associateTransaction(tx, to: payment)
                        dismiss()
                    }
                }
            } message: {
                Text(L10n.UXL10.confirmMessage)
            }
            .alert(
                L10n.Common.error,
                isPresented: $showError
            ) {
                Button(L10n.Common.understood, role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
        .yalaSheetDetents([.medium, .large], selection: $selectedDetent)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            Text(payment.name)
                .font(DS.Typography.headline)
                .foregroundStyle(.primary)
            Text(ScheduledPaymentDateText.full(occurrence))
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Apuntarlo ahora

    private var recordNowCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(L10n.UXL10.recordNow)
                .font(DS.Typography.subheadlineEmphasized)
                .foregroundStyle(.primary)

            if canRecordInline, let account = payment.account {
                Text(L10n.UXL10.recordNowHelp(account.name))
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: DS.Spacing.sm) {
                    Text(appPreferences.currencyIdentifier(for: payment.currencyCode))
                        .font(DS.Typography.title3)
                        .foregroundStyle(.secondary)
                    TextField("0.00", text: $amountString)
                        .keyboardType(.decimalPad)
                        .font(DS.Typography.title3.weight(.bold))
                        .focused($isAmountFocused)
                        .accessibilityIdentifier("scheduled_paid_amount_field")
                        .onChange(of: amountString) { _, newValue in
                            let filtered = AmountInputHelper.filterAmountInput(newValue)
                            if filtered != newValue { amountString = filtered }
                        }
                }
                .padding(DS.Spacing.md)
                .background(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous).fill(Color(.tertiarySystemFill)))

                YalaPrimaryButton(
                    L10n.UXL10.recordButton(appPreferences.currency(amount, currencyCode: payment.currencyCode, forceFullPrecision: true)),
                    isDisabled: amount <= 0
                ) {
                    recordNow()
                }
                .accessibilityIdentifier("scheduled_paid_record_now")
            } else {
                YalaPrimaryButton(L10n.UXL10.recordNow) {
                    dismiss()
                    onRecordInForm()
                }
                .accessibilityIdentifier("scheduled_paid_record_now")
            }
        }
        .padding(DS.Spacing.lg)
        .solidCard(padding: 0, radius: DS.Radius.lg)
    }

    private func recordNow() {
        isAmountFocused = false
        do {
            if try viewModel.recordPaymentNow(
                payment, occurrence: occurrence, amount: amount,
                draftService: draftService, currencyConverter: currencyConverter
            ) != nil {
                dismiss()
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? L10n.Common.saveError
            showError = true
        }
    }

    // MARK: - Ya lo apunté

    private var alreadyRecordedSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.UXL10.alreadyRecorded)
                .font(DS.Typography.subheadlineEmphasized)
                .foregroundStyle(.primary)
                .padding(.top, DS.Spacing.sm)
            Text(L10n.UXL10.alreadyRecordedHelp)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)

            Text((payment.isIncome ? L10n.UXL10.candidatesIncome : L10n.UXL10.candidatesExpenses).uppercased(with: AppLocale.current))
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .padding(.top, DS.Spacing.sm)

            if candidates.isEmpty {
                Text(L10n.UXL10.candidatesEmpty)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.lg)
            } else {
                ForEach(candidates, id: \.persistentModelID) { transaction in
                    candidateRow(transaction)
                }
            }
        }
    }

    /// Lo que identifica al registro: su nota o, sin nota, su subcategoría.
    private func candidateTitle(_ transaction: TransactionItem) -> String {
        if let note = transaction.note, !note.isEmpty { return note }
        if let sub = transaction.subcategory { return sub.name }
        if let category = transaction.category { return category.name }
        return ScheduledPaymentDateText.medium(transaction.date)
    }

    private func candidateRow(_ transaction: TransactionItem) -> some View {
        Button {
            selectedTransaction = transaction
            showConfirmation = true
        } label: {
            HStack(spacing: DS.Spacing.md) {
                if let sub = transaction.subcategory {
                    ZStack {
                        Circle()
                            .fill(Color(hex: sub.colorHex ?? sub.safeCategory.colorHex))
                            .frame(width: 32, height: 32)
                        Image(systemName: sub.iconName ?? sub.safeCategory.iconName ?? "tag")
                            .font(DS.Typography.captionSmall)
                            .foregroundStyle(.white)
                    }
                    .accessibilityHidden(true)
                } else {
                    Circle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "tag")
                                .font(DS.Typography.captionSmall)
                                .foregroundStyle(.secondary)
                        )
                        .accessibilityHidden(true)
                }

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(candidateTitle(transaction))
                        .font(DS.Typography.label)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(spacing: DS.Spacing.xs) {
                        Text(ScheduledPaymentDateText.medium(transaction.date))
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)

                        if let accountName = transaction.account?.name {
                            Text("•")
                                .font(DS.Typography.captionSmall)
                                .foregroundStyle(.secondary.opacity(0.5))
                            Text(accountName)
                                .font(DS.Typography.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()

                if transaction.currencyCode != payment.currencyCode {
                    Text(transaction.currencyCode)
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(DS.Semantic.warningForeground)
                        .padding(.horizontal, DS.Spacing.xs)
                        .padding(.vertical, DS.Spacing.xxs)
                        .background(Capsule().fill(DS.Semantic.warningBackground))
                }

                AmountText(
                    value: transaction.amount,
                    currencyCode: transaction.currencyCode,
                    font: DS.Typography.headline,
                    forceFullPrecision: true
                )
            }
            .padding(DS.Spacing.md)
            .background(.thCard)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("scheduled_paid_candidate")
    }
}
