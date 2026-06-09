//
//  SettlementFormView.swift
//  Yala
//
//  Formulario para registrar un pago de liquidación entre miembros.
//

import SwiftUI
import SwiftData

struct SettlementFormView: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.yalaTheme) private var theme
    @Environment(SessionState.self) private var sessionState

    // MARK: - Input

    let group: SplitGroup
    let debt: Debt
    let memberNameLookup: [String: String]
    let onSave: () -> Void

    // MARK: - State

    @State private var amountString: String
    @State private var note: String = ""
    @State private var date: Date = .now
    @State private var isSaving: Bool = false
    @State private var showSaveError: Bool = false
    @State private var saveErrorMessage: String = ""

    // A0-Bridge: Caso C proactivo — cuenta para liquidación (solo .full/.completed)
    @State private var selectedAccount: Account? = nil
    @State private var showAccountSelector: Bool = false

    // Opt-out: alert post-save cuando bridge effective OFF en Caso C.
    @State private var pendingOptInSettlementID: String?
    @State private var showOptInAlert: Bool = false

    // Toggle del segmented control superior: alterna entre el monto original
    // (`debt.currencyCode`) y el sugerido convertido a `group.currencyCode`.
    @State private var useSuggestedAmount: Bool = false

    // MARK: - Init

    init(
        group: SplitGroup,
        debt: Debt,
        memberNameLookup: [String: String],
        onSave: @escaping () -> Void
    ) {
        self.group = group
        self.debt = debt
        self.memberNameLookup = memberNameLookup
        self.onSave = onSave
        self._amountString = State(initialValue: AmountInputHelper.formatWithGrouping(debt.amount))
    }

    // MARK: - Body

    // MARK: - Suggested Amount Computeds (cross-currency)

    /// Monto sugerido en `group.currencyCode` si el toggle del grupo está ON, el debt
    /// es cross-currency y existe un tipo de cambio que produzca un delta significativo.
    /// Si la conversión devuelve el mismo monto (sin rate disponible) → nil para ocultar
    /// el segmented silenciosamente.
    private var suggestedAmount: Double? {
        guard group.showDebtsInSingleCurrency,
              debt.currencyCode != group.currencyCode
        else { return nil }

        let converted = CurrencyConverter.shared.convertWithLatestRate(
            Decimal(debt.amount),
            from: debt.currencyCode,
            to: group.currencyCode
        )
        let result = NSDecimalNumber(decimal: converted).doubleValue
        guard abs(result - debt.amount) > 0.01 else { return nil }
        return result
    }

    /// Currency efectivo según selección del segmented (Original / Sugerido).
    private var effectiveCurrency: String {
        useSuggestedAmount ? group.currencyCode : debt.currencyCode
    }

    /// Monto canónico para la moneda efectivo (sin contar edits manuales del user).
    private var effectiveCanonicalAmount: Double {
        useSuggestedAmount ? (suggestedAmount ?? debt.amount) : debt.amount
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    // Header: who pays whom
                    paymentHeader

                    // Segmented currency picker (solo si hay suggested amount real)
                    currencySegmentedControl

                    // Amount
                    amountSection

                    // A0-Bridge: cuenta de origen (oculto para .groupInvite)
                    accountSection

                    // Details
                    detailsSection

                    // Submit button
                    YalaPrimaryButton(L10n.Groups.Settlement.registerPayment, icon: "checkmark.circle.fill") {
                        handleSave()
                    }
                    .disabled(parsedAmount <= 0 || isSaving)
                    .padding(.horizontal, DS.Spacing.lg)
                }
                .padding(.top, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.safeBottom)
                .dismissKeyboardOnTap()
            }
            .scrollDismissesKeyboard(.interactively)
            .yalaScreenBackground(.subtle)
            .navigationTitle(L10n.Groups.Settlement.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }
            }
            .alert(L10n.Common.error, isPresented: $showSaveError) {
                Button(L10n.Common.ok) {}
            } message: {
                Text(saveErrorMessage)
            }
            .alert(L10n.Groups.Bridge.optoutAlertTitle, isPresented: $showOptInAlert) {
                Button(L10n.Groups.Bridge.optoutAlertYes) { confirmOptIn() }
                Button(L10n.Groups.Bridge.optoutAlertNo, role: .cancel) { declineOptIn() }
            } message: {
                Text(L10n.Groups.Bridge.optoutAlertBody)
            }
            .sheet(isPresented: $showAccountSelector) {
                AccountSelectorSheet(
                    selectedAccount: $selectedAccount,
                    title: L10n.Groups.Settlement.fromAccount,
                    currencyFilter: effectiveCurrency
                )
            }
            // M6: NO defaults — selectedAccount inicial nil, user siempre elige.
            // Cambio de currency → reset amount al canónico + nullify selectedAccount si
            // deja de ser compatible (selectivo: preserva la cuenta si sigue OK).
            .onChange(of: useSuggestedAmount) { _, _ in
                let newAmount = AmountInputHelper.formatWithGrouping(effectiveCanonicalAmount)
                if amountString != newAmount {
                    amountString = newAmount
                }
                if let account = selectedAccount, account.currencyCode != effectiveCurrency {
                    selectedAccount = nil
                }
            }
        }
    }

    // MARK: - Currency Segmented Control (cross-currency settlement)

    @ViewBuilder
    private var currencySegmentedControl: some View {
        if let suggested = suggestedAmount {
            Picker("", selection: $useSuggestedAmount) {
                Text("\(debt.currencyCode) \(AmountInputHelper.formatWithGrouping(debt.amount))")
                    .tag(false)
                Text("≈ \(group.currencyCode) \(AmountInputHelper.formatWithGrouping(suggested))")
                    .tag(true)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, DS.Spacing.lg)
        }
    }

    // MARK: - Bridge Effective Mode

    /// Opt-out: si bridge effective OFF, el form NO pide cuenta (alert post-save F2c
    /// ofrece opt-in para crear draft Inbox bajo demanda).
    private var bridgeEnabled: Bool {
        BridgeModeResolver.shared.isBridgeEnabled(for: group, context: modelContext)
    }

    // MARK: - Account Section (A0-Bridge Caso C proactivo)

    @ViewBuilder
    private var accountSection: some View {
        if !sessionState.isGroupInviteMode && bridgeEnabled {
            SectionBox(title: L10n.Groups.Settlement.fromAccount) {
                Button {
                    showAccountSelector = true
                } label: {
                    HStack(spacing: DS.Spacing.md) {
                        if let account = selectedAccount {
                            Circle()
                                .fill(Color(hex: account.colorHex))
                                .frame(width: 24, height: 24) // A11Y-DT: row icon decorative
                            Text(account.name).font(DS.Typography.body).foregroundStyle(.primary)
                        } else {
                            Text(L10n.Groups.Settlement.fromAccountNone)
                                .font(DS.Typography.body)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(DS.Typography.captionSmall)
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                    .padding(.horizontal, DS.FormRow.paddingH)
                    .padding(.vertical, DS.FormRow.paddingV)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DS.Spacing.lg)
        }
    }

    // MARK: - Payment Header

    private var paymentHeader: some View {
        VStack(spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.md) {
                memberBubble(debt.fromMemberID)

                VStack(spacing: DS.Spacing.xxs) {
                    Image(systemName: "arrow.right")
                        .font(DS.Typography.headline)
                        .foregroundStyle(.secondary)
                    Text(L10n.Groups.Settlement.payTo)
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.secondary)
                }

                memberBubble(debt.toMemberID)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.lg)
    }

    private func memberBubble(_ memberID: String) -> some View {
        let name = memberNameLookup[memberID] ?? "?"
        return VStack(spacing: DS.Spacing.xs) {
            ZStack {
                Circle()
                    .fill(Color(hex: group.colorHex).opacity(0.2))
                    .frame(width: 48, height: 48) // A11Y-DT: decorative avatar, fixed size

                Text(String(name.prefix(1)).uppercased())
                    .font(DS.Typography.headline)
                    .foregroundStyle(Color(hex: group.colorHex))
            }

            Text(name)
                .font(DS.Typography.caption)
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .accessibilityLabel(name)
    }

    // MARK: - Amount Section

    private var amountSection: some View {
        VStack(spacing: DS.Spacing.xs) {
            HStack(spacing: DS.Spacing.sm) {
                Text(effectiveCurrency)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.thAccent)

                TextField("0.00", text: $amountString)
                    .font(.system(size: 36, weight: .bold, design: .rounded)) // A11Y-DT: amount display
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .keyboardType(.decimalPad)
                    .onChange(of: amountString) { _, newValue in
                        let filtered = AmountInputHelper.filterAmountInput(newValue)
                        if filtered != newValue {
                            amountString = filtered
                        }
                    }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, DS.Spacing.lg)
    }

    // MARK: - Details Section

    private var detailsSection: some View {
        SectionBox(title: L10n.Groups.Expense.noteLabel) {
            VStack(spacing: DS.Spacing.none) {
                TextField(L10n.Groups.Expense.notePlaceholder, text: $note)
                    .font(DS.Typography.body)
                    .padding(.horizontal, DS.FormRow.paddingH)
                    .padding(.vertical, DS.FormRow.paddingV)

                Divider().padding(.leading, DS.FormRow.paddingH)

                DatePicker(L10n.Groups.Expense.date, selection: $date, displayedComponents: .date)
                    .font(DS.Typography.body)
                    .padding(.horizontal, DS.FormRow.paddingH)
                    .padding(.vertical, DS.FormRow.paddingV)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
    }

    // MARK: - Actions

    private var parsedAmount: Double {
        AmountInputHelper.parseDecimal(amountString)
    }

    private func handleSave() {
        guard parsedAmount > 0 else { return }
        isSaving = true

        do {
            // A0-Bridge: Caso C proactivo — para .full/.completed + bridge ON pasamos cuenta
            // seleccionada; para .groupInvite o bridge OFF no aplica (solo TX virtual).
            let accountToPass = (sessionState.isGroupInviteMode || !bridgeEnabled) ? nil : selectedAccount

            let settlement = try GroupExpenseService.shared.createSettlement(
                in: group,
                fromMemberID: debt.fromMemberID,
                toMemberID: debt.toMemberID,
                amount: parsedAmount,
                currencyCode: effectiveCurrency,
                note: note.isEmpty ? nil : note,
                date: date,
                accountForCurrentUser: accountToPass
            )

            // Marca confirmed + dispara bridge con cuenta (Caso C proactivo end-to-end).
            try GroupExpenseService.shared.confirmSettlement(
                settlement,
                in: group,
                accountForCurrentUser: accountToPass
            )

            DS.Haptic.success()
            TelemetryService.track(.groupSettlementCreated)
            isSaving = false

            // Opt-out: si bridge effective OFF y Caso C (.full/.completed), preguntar al user
            // si quiere crear TX real opt-in. groupInvite no aplica (no hay cuentas reales).
            if !bridgeEnabled && !sessionState.isGroupInviteMode {
                pendingOptInSettlementID = settlement.id.uuidString
                showOptInAlert = true
                return  // diferir dismiss hasta resolver alert
            }

            onSave()
            dismiss()
        } catch {
            #if DEBUG
            print("SettlementFormView: Error saving: \(error)")
            #endif
            saveErrorMessage = error.localizedDescription
            showSaveError = true
            isSaving = false
        }
    }

    private func confirmOptIn() {
        guard let settlementID = pendingOptInSettlementID else { return }
        do {
            try DraftService.shared.createGroupSettlementOptInDraft(
                splitSettlementID: settlementID,
                groupZoneID: group.cloudKitZoneID
            )
        } catch {
            #if DEBUG
            print("SettlementFormView: createGroupSettlementOptInDraft failed: \(error)")
            #endif
        }
        pendingOptInSettlementID = nil
        onSave()
        dismiss()
    }

    private func declineOptIn() {
        pendingOptInSettlementID = nil
        onSave()
        dismiss()
    }
}
