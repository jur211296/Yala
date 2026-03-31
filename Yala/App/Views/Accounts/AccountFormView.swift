//
//  AccountFormView.swift
//  Yala
//
//  Created by Yala Refactoring.
//

import SwiftData
import SwiftUI

// MARK: - Formulario "Configurar cuenta"

struct AccountFormView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(EntityDeletionService.self) private var deletionService
    @Environment(SessionState.self) private var sessionState

    @State private var viewModel: AccountFormViewModel
    @State private var showBalanceCalculator: Bool = false
    @State private var calcFieldState = BalanceCalculatorFieldState()
    @FocusState private var focusedField: Field?

    private enum Field {
        case name, accountNumber, balance
    }

    init(existingNames: [String], accountToEdit: Account? = nil) {
        _viewModel = State(
            initialValue: AccountFormViewModel(
                accountToEdit: accountToEdit,
                existingNames: existingNames
            ))
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()
                    .dismissKeyboardOnTap()

                ScrollView {
                    VStack(spacing: DS.Spacing.xxl) {
                        generalSection
                        ContextualGuideBanner.accountForm(accountType: viewModel.selectedType)
                        currencySection
                        if viewModel.selectedType == .creditCard {
                            creditCardSection
                        }
                        if viewModel.showAdjustmentMode {
                            adjustmentSection
                        }
                        balanceSection

                        // Balance calculator link (only for new accounts, not editing)
                        if !viewModel.isEditing && !sessionState.isExpensesOnlyMode {
                            Button {
                                showBalanceCalculator = true
                            } label: {
                                HStack(spacing: DS.Spacing.xs) {
                                    Image(systemName: "questionmark.circle")
                                        .font(DS.Typography.subheadline)
                                    Text(L10n.Onboarding.accountBalanceLearnMore)
                                        .font(DS.Typography.subheadline)
                                        .fontWeight(.semibold)
                                }
                                .foregroundStyle(Color.electricIndigo)
                            }
                            .buttonStyle(.plain)
                        }

                        actionsSection
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.xxl)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(L10n.Account.configure)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    YalaSaveButton(action: { saveAccount() }, isDisabled: !viewModel.canSave)
                }
            }
            .sheet(isPresented: $viewModel.isPresentingColorPicker) {
                NavigationStack {
                    VStack(spacing: DS.Spacing.xxl) {
                        ColorPicker(
                            L10n.Common.selectColor,
                            selection: $viewModel.customColor,
                            supportsOpacity: false
                        )
                        .padding()

                        Button(L10n.Common.useThisColor) {
                            viewModel.updateColorFromCustom()
                        }
                        .buttonStyle(.borderedProminent)

                        Spacer()
                    }
                    .padding()
                    .navigationTitle(L10n.Common.newColor)
                    .navigationBarTitleDisplayMode(.inline)
                }
            }
            .sheet(isPresented: $showBalanceCalculator) {
                BalanceCalculatorSheet(
                    accountType: viewModel.selectedType,
                    mindset: SessionState.shared.financialMindset,
                    currencySymbol: viewModel.selectedCurrency.symbol,
                    fieldState: calcFieldState,
                    onUseBalance: { amount in
                        if amount >= 0 {
                            viewModel.isPositive = true
                            viewModel.balanceText = AmountInputHelper.formatWithGrouping(amount)
                        } else {
                            viewModel.isPositive = false
                            viewModel.balanceText = AmountInputHelper.formatWithGrouping(abs(amount))
                        }
                    },
                    onDismiss: { showBalanceCalculator = false }
                )
            }
            .onChange(of: viewModel.isPresentingColorPicker) { _, isPresenting in
                if isPresenting { focusedField = nil }
            }
            .onChange(of: viewModel.selectedType) {
                calcFieldState.reset()
            }
            .onAppear {
                viewModel.setContext(modelContext)
                // Auto-focus name field for new accounts
                if !viewModel.isEditing {
                    Task {
                        try? await Task.sleep(for: .milliseconds(500))
                        focusedField = .name
                    }
                }
            }
        }


        .alert(
            L10n.Account.deleteError,
            isPresented: $viewModel.isShowingDeleteError,
            actions: {
                Button(L10n.Common.understood, role: .cancel) {}
            },
            message: {
                Text(viewModel.deleteErrorMessage)
            }
        )
        .alert(
            L10n.Common.error,
            isPresented: $viewModel.isShowingSaveError,
            actions: {
                Button(L10n.Common.understood, role: .cancel) {}
            },
            message: {
                Text(L10n.Common.saveError)
            }
        )
        .alert(
            L10n.Account.secondaryCurrencyTitle,
            isPresented: Binding(
                get: { viewModel.currencyToSuggestAsSecondary != nil },
                set: { if !$0 { viewModel.currencyToSuggestAsSecondary = nil } }
            ),
            actions: {
                Button(L10n.Account.secondaryCurrencyAccept) {
                    acceptSecondaryCurrency()
                    dismiss()
                }
                Button(L10n.Account.secondaryCurrencyReject, role: .cancel) {
                    viewModel.currencyToSuggestAsSecondary = nil
                    dismiss()
                }
            },
            message: {
                if let code = viewModel.currencyToSuggestAsSecondary {
                    Text(L10n.Account.secondaryCurrencyMessage(
                        code.rawValue,
                        CurrencyDefaults.currentPreferred,
                        code.rawValue
                    ))
                }
            }
        )
    }

    // MARK: Secciones de la vista

    private var generalSection: some View {
        SectionBox(title: L10n.Common.general) {
            VStack(spacing: DS.Spacing.none) {
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: "textformat")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    TextField(L10n.Account.accountName, text: $viewModel.name)
                        .textContentType(.name)
                        .focused($focusedField, equals: .name)
                        .accessibilityIdentifier("account_name_field")
                }
                .padding()

                SubsectionDivider()

                NavigationLink {
                    AccountTypeSelectorView(selectedType: $viewModel.selectedType)
                } label: {
                    HStack {
                        Text(L10n.Account.type)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(viewModel.selectedType.localizedName)
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(DS.Typography.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding()
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded { _ in focusedField = nil })

                SubsectionDivider()

                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: "number")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    TextField(L10n.Account.accountNumber, text: $viewModel.accountNumber)
                        .keyboardType(.numbersAndPunctuation)
                        .focused($focusedField, equals: .accountNumber)
                }
                .padding()
            }
        }
    }

    private var currencySection: some View {
        SectionBox(title: L10n.Account.currency) {
            NavigationLink {
                CurrencySelectorView(selectedCurrency: $viewModel.selectedCurrency)
                    .swipeBack()
            } label: {
                HStack(spacing: DS.Spacing.md) {
                    Text(currencyInfo(for: viewModel.selectedCurrency).flag)
                        .font(DS.Typography.title)

                    Text(L10n.Account.currency)
                        .font(DS.Typography.body)
                        .foregroundStyle(.primary)

                    Spacer()

                    Text(currencyInfo(for: viewModel.selectedCurrency).name.capitalized)
                        .foregroundStyle(.secondary)

                    Image(systemName: "chevron.right")
                        .font(DS.Typography.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding()
            }
            .buttonStyle(.plain)
            .simultaneousGesture(TapGesture().onEnded { _ in focusedField = nil })
        }
    }

    private var adjustmentSection: some View {
        SectionBox(title: L10n.Account.adjustment) {
            VStack(spacing: DS.Spacing.none) {
                NavigationLink {
                    AdjustmentModeSelectorView(
                        selectedAdjustmentMode: $viewModel.selectedAdjustmentMode)
                } label: {
                    HStack {
                        Text(L10n.Account.adjustment)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(viewModel.selectedAdjustmentMode.displayName)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Image(systemName: "chevron.right")
                            .font(DS.Typography.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding()
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded { _ in focusedField = nil })

                SubsectionDivider()

                Text(viewModel.selectedAdjustmentMode.description)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Date picker for "Ajustar por registro" mode
                if viewModel.selectedAdjustmentMode == .byEntry && viewModel.isEditing {
                    SubsectionDivider()

                    HStack {
                        Text(L10n.Account.adjustmentDate)
                            .font(DS.Typography.body)
                        Spacer()
                        DateFieldButton(
                            date: $viewModel.adjustmentDate,
                            title: L10n.Account.adjustmentDate
                        )
                    }
                    .padding()
                }
            }
        }
        .onChange(of: viewModel.selectedAdjustmentMode) {
            viewModel.adjustmentModeChanged()
        }
    }

    private var balanceSection: some View {
        SectionBox(
            title: viewModel.isEditing
                ? (viewModel.selectedAdjustmentMode == .changeInitialBalance
                    ? L10n.Account.initialBalance : L10n.Account.newBalance) : L10n.Account.initialBalance
        ) {
            VStack(spacing: DS.Spacing.none) {
                // Show current balance (read-only) when editing (hidden in expenses-only mode)
                if viewModel.isEditing && !sessionState.isExpensesOnlyMode {
                    HStack {
                        Text(L10n.Account.currentBalance)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(
                            formatAmount(
                                viewModel.currentBalance, currency: viewModel.selectedCurrency)
                        )
                        .font(DS.Typography.headline)
                        .foregroundStyle(.primary)
                    }
                    .padding()

                    SubsectionDivider()
                }

                // Sign selector (contextual labels for credit cards)
                HStack(spacing: DS.Spacing.md) {
                    Text(L10n.Account.sign)
                        .font(DS.Typography.subheadline)
                    Spacer()
                    Picker(L10n.Account.sign, selection: $viewModel.isPositive) {
                        if viewModel.selectedType == .creditCard {
                            Text(L10n.Account.Sign.inFavor).tag(true)
                            Text(L10n.Account.Sign.consumed).tag(false)
                        } else {
                            Text(L10n.Account.positive).tag(true)
                            Text(L10n.Account.negative).tag(false)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding()

                SubsectionDivider()

                // Balance input
                HStack {
                    Spacer()
                    VStack(alignment: .trailing, spacing: DS.Spacing.xs) {
                        Text(
                            viewModel.selectedAdjustmentMode == .changeInitialBalance
                                ? L10n.Account.initialBalance : L10n.Account.newBalance
                        )
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)

                        ZStack(alignment: .trailing) {
                            // Placeholder
                            if viewModel.balanceText.isEmpty {
                                Text("0.00")
                                    .font(DS.Typography.largeTitle)
                                    .foregroundStyle(DS.Semantic.disabledForeground.opacity(DS.Opacity.overlay))
                            }

                            TextField("", text: $viewModel.balanceText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .font(DS.Typography.largeTitle)
                                .focused($focusedField, equals: .balance)
                        }
                        .onChange(of: focusedField) { _, newField in
                            let isFocused = newField == .balance
                            // When field gains focus, clear placeholder values
                            if isFocused
                                && (viewModel.balanceText == "0" || viewModel.balanceText == "0.00" || viewModel.balanceText == "0,00")
                            {
                                viewModel.balanceText = ""
                            }
                            // When field loses focus, format if has value
                            if !isFocused && !viewModel.balanceText.isEmpty {
                                let amount = AmountInputHelper.parseDecimal(viewModel.balanceText)
                                viewModel.balanceText = AmountInputHelper.formatWithGrouping(amount)
                            }
                        }
                        .onChange(of: viewModel.balanceText) { _, newValue in
                            let filtered = AmountInputHelper.filterAmountInput(newValue)
                            if filtered != newValue {
                                viewModel.balanceText = filtered
                            }
                        }
                    }
                }
                .padding()

                // Show calculated final balance for "Cambiar saldo inicial" mode
                if viewModel.isEditing
                    && viewModel.selectedAdjustmentMode == .changeInitialBalance,
                    let finalBalance = viewModel.calculatedFinalBalance
                {
                    SubsectionDivider()

                    HStack {
                        Text(L10n.Account.finalBalance + ":")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(formatAmount(finalBalance, currency: viewModel.selectedCurrency))
                            .font(DS.Typography.headline)
                            .foregroundStyle(finalBalance >= 0 ? Color.primary : DS.Semantic.errorForeground)
                    }
                    .padding()
                }

                // Adjustment preview for "Ajustar por registro" mode
                if viewModel.isEditing && viewModel.selectedAdjustmentMode == .byEntry,
                    let adjustment = viewModel.adjustmentAmount, viewModel.needsAdjustment
                {
                    SubsectionDivider()

                    HStack {
                        Text(L10n.Account.adjustment + ":")
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(formatAdjustment(adjustment, currency: viewModel.selectedCurrency))
                            .font(DS.Typography.label)
                            .foregroundStyle(adjustment >= 0 ? DS.Semantic.successForeground : DS.Semantic.errorForeground)
                    }
                    .padding()
                }
            }
        }
    }

    private var colorSection: some View {
        SectionBox(title: L10n.Common.color) {
            VStack(spacing: DS.Spacing.none) {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    HStack(spacing: DS.Spacing.lg) {
                        ForEach(viewModel.colorOptions, id: \.self) { hex in
                            Circle()
                                .fill(colorForHex(hex))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            Color.white,
                                            lineWidth: viewModel.selectedColorHex == hex ? 3 : 1)
                                )
                                .shadow(radius: viewModel.selectedColorHex == hex ? 4 : 0)
                                .onTapGesture {
                                    viewModel.selectedColorHex = hex
                                }
                        }

                        Button {
                            viewModel.isPresentingColorPicker = true
                        } label: {
                            Circle()
                                .fill(DS.Colors.borderDark)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Image(systemName: "plus")
                                        .font(DS.Typography.labelSmall)
                                        .foregroundStyle(.primary)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(L10n.Accessibility.selectColor)
                    }

                    Text(L10n.Tag.colorSelected(viewModel.selectedColorHex))
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
        }
    }

    private var actionsSection: some View {
        SectionBox(title: L10n.Common.actions) {
            VStack(spacing: DS.Spacing.none) {
                Toggle(isOn: $viewModel.excludeFromStatistics) {
                    Text(L10n.Account.excludeFromStats)
                }

                .padding()

                SubsectionDivider()

                Toggle(isOn: $viewModel.isArchived) {
                    Text(L10n.Account.archive)
                }

                .padding()

                if viewModel.isEditing {
                    SubsectionDivider()

                    Button(role: .destructive) {
                        handleDeleteTapped()
                    } label: {
                        HStack {
                            Spacer()
                            Text(L10n.Account.delete)
                            Spacer()
                        }
                    }
                    .padding()
                }
            }
        }
    }

    private var creditCardSection: some View {
        SectionBox(title: L10n.Account.CreditCard.sectionTitle) {
            VStack(spacing: DS.Spacing.none) {
                Toggle(isOn: $viewModel.creditCardPaymentReminder) {
                    Text(L10n.Account.CreditCard.paymentReminder)
                }
                .padding()

                if viewModel.creditCardPaymentReminder {
                    SubsectionDivider()

                    HStack {
                        Text(L10n.Account.CreditCard.paymentDay)
                            .foregroundStyle(.primary)
                        Spacer()
                        Picker(L10n.Account.CreditCard.paymentDay, selection: $viewModel.creditCardPaymentDay) {
                            ForEach(1...28, id: \.self) { day in
                                Text("\(day)").tag(day)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    .padding()
                }
            }
        }
    }

    // MARK: - Static Formatters

    private static let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.maximumFractionDigits = 2
        return f
    }()

    // MARK: Helpers

    private func formatAmount(_ amount: Double, currency: CurrencyCode) -> String {
        Self.currencyFormatter.currencyCode = currency.rawValue
        return Self.currencyFormatter.string(from: NSNumber(value: amount)) ?? "0.00"
    }

    private func formatAdjustment(_ amount: Double, currency: CurrencyCode) -> String {
        let sign = amount >= 0 ? "+" : ""
        Self.currencyFormatter.currencyCode = currency.rawValue
        let formatted = Self.currencyFormatter.string(from: NSNumber(value: amount)) ?? "0.00"
        return sign + formatted
    }

    // MARK: Guardado

    private func saveAccount() {
        if viewModel.saveAccount(context: modelContext) {
            if viewModel.currencyToSuggestAsSecondary == nil {
                dismiss()
            }
            // else: alert will show and dismiss after user responds
        }
    }

    private func acceptSecondaryCurrency() {
        guard let code = viewModel.currencyToSuggestAsSecondary else { return }
        let raw = UserDefaults.standard.string(forKey: "secondaryCurrencies") ?? ""
        var existing = raw.split(separator: ",").map(String.init).filter { !$0.isEmpty }
        existing.append(code.rawValue)
        let newValue = existing.joined(separator: ",")
        PreferenceSyncService.shared.set(string: newValue, forKey: "secondaryCurrencies")
        SessionState.shared.needsExchangeRateWidgetRefresh = true

        Task {
            // Load historical exchange rates for the new currency
            let calendar = Calendar.current
            let today = Date.now
            guard let oneYearAgo = calendar.date(byAdding: .year, value: -1, to: today) else { return }
            let dateInterval = DateInterval(start: oneYearAgo, end: today)
            await ExchangeRateService.shared.forceUpdateToday(context: modelContext)
            await ExchangeRateService.shared.forceRefreshRates(for: dateInterval, context: modelContext)
            SessionState.shared.needsExchangeRateWidgetRefresh = true
        }
    }

    // MARK: - Eliminación de cuenta

    private func handleDeleteTapped() {
        guard let account = viewModel.accountToEdit else { return }
        deletionService.setContext(modelContext)
        do {
            try deletionService.deleteAccount(account)
            dismiss()
        } catch {
            #if DEBUG
            print("AccountFormView: Error deleting account: \(error)")
            #endif
        }
    }
}
