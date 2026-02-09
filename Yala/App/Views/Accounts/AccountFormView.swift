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
                        currencySection
                        if viewModel.isEditing {
                            adjustmentSection
                        }
                        balanceSection
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
                    YalaToolbarButton(systemName: "xmark", label: "Cerrar") {
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
            .onChange(of: viewModel.isPresentingColorPicker) { _, isPresenting in
                if isPresenting { focusedField = nil }
            }
            .onAppear {
                viewModel.setContext(modelContext)
                // Auto-focus name field for new accounts
                if !viewModel.isEditing {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        focusedField = .name
                    }
                }
            }
        }

        .tint(Color.electricIndigo)
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
    }

    // MARK: Secciones de la vista

    private var generalSection: some View {
        SectionBox(title: L10n.Common.general) {
            VStack(spacing: 0) {
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: "textformat")
                        .foregroundStyle(.secondary)
                    TextField(L10n.Account.accountName, text: $viewModel.name)
                        .textContentType(.name)
                        .focused($focusedField, equals: .name)
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
                            .font(.footnote)
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
                        .font(.title3)

                    Text(L10n.Account.currency)
                        .font(.body)
                        .foregroundStyle(.primary)

                    Spacer()

                    Text(currencyInfo(for: viewModel.selectedCurrency).name.capitalized)
                        .foregroundStyle(.secondary)

                    Image(systemName: "chevron.right")
                        .font(.footnote)
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
            VStack(spacing: 0) {
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
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                    }
                    .padding()
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded { _ in focusedField = nil })

                SubsectionDivider()

                Text(viewModel.selectedAdjustmentMode.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Date picker for "Ajustar por registro" mode
                if viewModel.selectedAdjustmentMode == .byEntry && viewModel.isEditing {
                    SubsectionDivider()

                    DatePicker(
                        L10n.Account.adjustmentDate,
                        selection: $viewModel.adjustmentDate,
                        displayedComponents: .date
                    )
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
            VStack(spacing: 0) {
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
                        .font(.headline)
                        .foregroundStyle(.primary)
                    }
                    .padding()

                    SubsectionDivider()
                }

                // Sign selector
                HStack(spacing: DS.Spacing.md) {
                    Text(L10n.Account.sign)
                        .font(.subheadline)
                    Spacer()
                    Picker(L10n.Account.sign, selection: $viewModel.isPositive) {
                        Text(L10n.Account.positive).tag(true)
                        Text(L10n.Account.negative).tag(false)
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
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        ZStack(alignment: .trailing) {
                            // Placeholder
                            if viewModel.balanceText.isEmpty {
                                Text("0.00")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundStyle(.gray.opacity(0.4))
                            }

                            TextField("", text: $viewModel.balanceText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .font(.system(size: 28, weight: .bold))
                                .focused($focusedField, equals: .balance)
                        }
                        .onChange(of: focusedField) { _, newField in
                            let isFocused = newField == .balance
                            // When field gains focus, clear placeholder values
                            if isFocused
                                && (viewModel.balanceText == "0" || viewModel.balanceText == "0.00")
                            {
                                viewModel.balanceText = ""
                            }
                            // When field loses focus, format if has value
                            if !isFocused && !viewModel.balanceText.isEmpty {
                                if let amount = Double(
                                    viewModel.balanceText.replacingOccurrences(of: ",", with: "."))
                                {
                                    viewModel.balanceText = String(format: "%.2f", amount)
                                }
                            }
                        }
                        .onChange(of: viewModel.balanceText) { _, newValue in
                            let filtered = filterBalanceInput(newValue)
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
                            .font(.headline)
                            .foregroundStyle(finalBalance >= 0 ? Color.primary : Color.red)
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
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(formatAdjustment(adjustment, currency: viewModel.selectedCurrency))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(adjustment >= 0 ? .green : .red)
                    }
                    .padding()
                }
            }
        }
    }

    private var colorSection: some View {
        SectionBox(title: L10n.Common.color) {
            VStack(spacing: 0) {
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
                                .fill(Color.black.opacity(0.05))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Image(systemName: "plus")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.primary)
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    Text(L10n.Tag.colorSelected(viewModel.selectedColorHex))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
        }
    }

    private var actionsSection: some View {
        SectionBox(title: L10n.Common.actions) {
            VStack(spacing: 0) {
                Toggle(isOn: $viewModel.excludeFromStatistics) {
                    Text(L10n.Account.excludeFromStats)
                }
                .tint(Color.electricIndigo)
                .padding()

                SubsectionDivider()

                Toggle(isOn: $viewModel.isArchived) {
                    Text(L10n.Account.archive)
                }
                .tint(Color.electricIndigo)
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

    // MARK: Helpers

    private func formatAmount(_ amount: Double, currency: CurrencyCode) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency.rawValue
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "0.00"
    }

    private func formatAdjustment(_ amount: Double, currency: CurrencyCode) -> String {
        let sign = amount >= 0 ? "+" : ""
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency.rawValue
        formatter.maximumFractionDigits = 2
        let formatted = formatter.string(from: NSNumber(value: amount)) ?? "0.00"
        return sign + formatted
    }

    /// Filters balance input to only allow numbers and one decimal with max 2 decimal places
    private func filterBalanceInput(_ input: String) -> String {
        let decimalSeparator = Locale.current.decimalSeparator ?? "."
        var result = ""
        var hasDecimal = false
        var decimalCount = 0

        for char in input {
            if char.isNumber {
                if hasDecimal {
                    if decimalCount < 2 {
                        result.append(char)
                        decimalCount += 1
                    }
                } else {
                    result.append(char)
                }
            } else if String(char) == decimalSeparator || char == "." || char == "," {
                if !hasDecimal {
                    result.append(decimalSeparator.first ?? ".")
                    hasDecimal = true
                }
            }
        }

        return result
    }

    // MARK: Guardado

    private func saveAccount() {
        if viewModel.saveAccount(context: modelContext) {
            dismiss()
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
