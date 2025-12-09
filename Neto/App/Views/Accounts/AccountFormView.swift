//
//  AccountFormView.swift
//  Neto
//
//  Created by Neto Refactoring.
//

import SwiftData
import SwiftUI

// MARK: - Formulario "Configurar cuenta"

struct AccountFormView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let existingNames: [String]
    let accountToEdit: Account?

    private var isEditing: Bool {
        accountToEdit != nil
    }

    // General
    @State private var name: String
    @State private var selectedType: AccountType
    @State private var accountNumber: String

    // Saldo actual
    @State private var isPositive: Bool
    @State private var balanceText: String

    // Moneda
    @State private var selectedCurrency: CurrencyCode

    // Ajuste
    @State private var selectedAdjustmentMode: AdjustmentMode

    // Color
    @State private var selectedColorHex: String
    @State private var customColor: Color
    @State private var isPresentingColorPicker: Bool

    // Acciones
    @State private var excludeFromStatistics: Bool
    @State private var isArchived: Bool

    // Navegación interna (reservado para futuros flows)
    @State private var showTypeSelector: Bool
    @State private var showCurrencySelector: Bool
    @State private var showAdjustmentSelector: Bool

    // Alertas de eliminación
    @State private var isShowingDeleteError: Bool = false
    @State private var deleteErrorMessage: String = ""

    init(existingNames: [String], accountToEdit: Account? = nil) {
        self.existingNames = existingNames
        self.accountToEdit = accountToEdit

        if let account = accountToEdit {
            _name = State(initialValue: account.name)
            _selectedType = State(initialValue: AccountType(rawValue: account.type) ?? .general)
            _accountNumber = State(initialValue: account.accountNumber ?? "")

            let balance = account.initialBalance
            _isPositive = State(initialValue: balance >= 0)
            _balanceText = State(initialValue: String(format: "%.2f", abs(balance)))

            _selectedCurrency = State(
                initialValue: CurrencyCode(rawValue: normalizeCurrencyCode(account.currencyCode))
                    ?? .pen)
            _selectedAdjustmentMode = State(
                initialValue: AdjustmentMode(rawValue: account.adjustmentMode) ?? .byEntry)

            _selectedColorHex = State(initialValue: account.colorHex)
            _customColor = State(initialValue: colorForHex(account.colorHex))

            _excludeFromStatistics = State(initialValue: account.excludeFromStatistics)
            _isArchived = State(initialValue: account.isArchived)
        } else {
            _name = State(initialValue: "")
            _selectedType = State(initialValue: .general)
            _accountNumber = State(initialValue: "")

            _isPositive = State(initialValue: true)
            _balanceText = State(initialValue: "")

            _selectedCurrency = State(initialValue: .pen)
            _selectedAdjustmentMode = State(initialValue: .byEntry)

            _selectedColorHex = State(initialValue: "#6366F1")  // electricIndigo
            _customColor = State(initialValue: Color(hex: "6366F1"))

            _excludeFromStatistics = State(initialValue: false)
            _isArchived = State(initialValue: false)
        }

        _isPresentingColorPicker = State(initialValue: false)
        _showTypeSelector = State(initialValue: false)
        _showCurrencySelector = State(initialValue: false)
        _showAdjustmentSelector = State(initialValue: false)
    }

    // MARK: Validaciones

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isNameValid: Bool {
        !trimmedName.isEmpty
    }

    private var isNameUnique: Bool {
        let lower = trimmedName.lowercased()
        return
            !existingNames
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .contains(lower)
    }

    private var isCurrencyValid: Bool {
        CurrencyCode.allCases.contains(where: { $0.rawValue == selectedCurrency.rawValue })
    }

    private var parsedAmount: Double? {
        let trimmed = balanceText.trimmingCharacters(in: .whitespacesAndNewlines)

        // Campo vacío: lo interpretamos como 0, para permitir cuentas sin saldo inicial.
        if trimmed.isEmpty {
            return 0
        }

        guard let decimal = parseDecimal(from: trimmed) else {
            return nil
        }

        return (decimal as NSDecimalNumber).doubleValue
    }

    private var isAmountValid: Bool {
        parsedAmount != nil
    }

    private var canSave: Bool {
        isNameValid && isNameUnique && isCurrencyValid && isAmountValid
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

                ScrollView {
                    VStack(spacing: 24) {
                        generalSection
                        currencySection
                        balanceSection
                        adjustmentSection
                        actionsSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle("Configurar cuenta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Guardar") {
                        saveAccount()
                    }
                    .disabled(!canSave)
                }
            }
            .sheet(isPresented: $isPresentingColorPicker) {
                NavigationStack {
                    VStack(spacing: 24) {
                        ColorPicker(
                            "Selecciona un color",
                            selection: $customColor,
                            supportsOpacity: false
                        )
                        .padding()

                        Button("Usar este color") {
                            selectedColorHex = hexString(from: customColor)
                            isPresentingColorPicker = false
                        }
                        .buttonStyle(.borderedProminent)

                        Spacer()
                    }
                    .padding()
                    .navigationTitle("Nuevo color")
                    .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
        .alert(
            "No se puede eliminar esta cuenta",
            isPresented: $isShowingDeleteError,
            actions: {
                Button("Entendido", role: .cancel) {}
            },
            message: {
                Text(deleteErrorMessage)
            }
        )
    }

    // MARK: Secciones de la vista

    private var generalSection: some View {
        SectionBox(title: "General") {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "textformat")
                        .foregroundStyle(.secondary)
                    TextField("Nombre de la cuenta", text: $name)
                        .textContentType(.name)
                }
                .padding()

                SubsectionDivider()

                NavigationLink {
                    AccountTypeSelectorView(selectedType: $selectedType)
                } label: {
                    HStack {
                        Text("Tipo")
                        Spacer()
                        Text(selectedType.rawValue)
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                    }
                    .padding()
                }

                SubsectionDivider()

                HStack(spacing: 12) {
                    Image(systemName: "number")
                        .foregroundStyle(.secondary)
                    TextField("Número de cuenta", text: $accountNumber)
                        .keyboardType(.numbersAndPunctuation)
                }
                .padding()
            }
        }
    }

    private var currencySection: some View {
        SectionBox(title: "Moneda") {
            NavigationLink {
                CurrencySelectorView(selectedCurrency: $selectedCurrency)
            } label: {
                HStack(spacing: 12) {
                    Text(currencyInfo(for: selectedCurrency).flag)
                        .font(.title3)

                    Text("Moneda")
                        .font(.body)

                    Spacer()

                    Text(currencyInfo(for: selectedCurrency).name.capitalized)
                        .foregroundStyle(.secondary)

                    Image(systemName: "chevron.right")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
                .padding()
            }
        }
    }

    private var balanceSection: some View {
        SectionBox(title: "Saldo actual") {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Text("Signo")
                        .font(.subheadline)
                    Spacer()
                    Picker("Signo", selection: $isPositive) {
                        Text("Positivo").tag(true)
                        Text("Negativo").tag(false)
                    }
                    .pickerStyle(.segmented)
                }
                .padding()

                SubsectionDivider()

                HStack {
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(currencyInfo(for: selectedCurrency).code)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("0.00", text: $balanceText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.system(size: 28, weight: .bold))
                    }
                }
                .padding()
            }
        }
    }

    private var adjustmentSection: some View {
        SectionBox(title: "Ajuste") {
            VStack(spacing: 0) {
                NavigationLink {
                    AdjustmentModeSelectorView(selectedAdjustmentMode: $selectedAdjustmentMode)
                } label: {
                    HStack {
                        Text("Ajuste")
                        Spacer()
                        Text(selectedAdjustmentMode.rawValue)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Image(systemName: "chevron.right")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                    }
                    .padding()
                }

                SubsectionDivider()

                Text(selectedAdjustmentMode.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var colorSection: some View {
        SectionBox(title: "Color") {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 16) {
                        ForEach(colorOptions, id: \.self) { hex in
                            Circle()
                                .fill(colorForHex(hex))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            Color.white, lineWidth: selectedColorHex == hex ? 3 : 1)
                                )
                                .shadow(radius: selectedColorHex == hex ? 4 : 0)
                                .onTapGesture {
                                    selectedColorHex = hex
                                }
                        }

                        Button {
                            isPresentingColorPicker = true
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

                    Text("Seleccionado: \(selectedColorHex)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
        }
    }

    private var actionsSection: some View {
        SectionBox(title: "Acciones") {
            VStack(spacing: 0) {
                Toggle(isOn: $excludeFromStatistics) {
                    Text("Excluir de las estadísticas")
                }
                .padding()

                SubsectionDivider()

                Toggle(isOn: $isArchived) {
                    Text("Archivar cuenta")
                }
                .padding()

                if isEditing {
                    SubsectionDivider()

                    Button(role: .destructive) {
                        handleDeleteTapped()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Eliminar cuenta")
                            Spacer()
                        }
                    }
                    .padding()
                }
            }
        }
    }

    // MARK: Utilidades de color

    private var colorOptions: [String] {
        ["#FF0080", "#D62246", "#FF7F11", "#4CB963", "#6366F1", "#1B065E", "#0F172A"]
    }

    private func hexString(from color: Color) -> String {
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        if uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            let r = Int(red * 255)
            let g = Int(green * 255)
            let b = Int(blue * 255)
            return String(format: "#%02X%02X%02X", r, g, b)
        } else {
            return selectedColorHex
        }
    }

    // MARK: Guardado

    private func saveAccount() {
        guard canSave, let amount = parsedAmount else { return }

        let finalAmount = isPositive ? amount : -amount
        let trimmedAccountNumber = accountNumber.trimmingCharacters(in: .whitespacesAndNewlines)

        if let account = accountToEdit {
            // Edición de cuenta existente
            account.name = trimmedName
            account.currencyCode = normalizeCurrencyCode(selectedCurrency.rawValue)
            account.colorHex = selectedColorHex
            account.iconName = iconName(for: selectedType)
            account.type = selectedType.rawValue
            account.accountNumber = trimmedAccountNumber.isEmpty ? nil : trimmedAccountNumber
            account.initialBalance = finalAmount
            account.adjustmentMode = selectedAdjustmentMode.rawValue
            account.excludeFromStatistics = excludeFromStatistics
            account.isArchived = isArchived
        } else {
            // Creación de nueva cuenta
            let newAccount = Account(
                name: trimmedName,
                currencyCode: normalizeCurrencyCode(selectedCurrency.rawValue),
                colorHex: selectedColorHex,
                iconName: iconName(for: selectedType),
                type: selectedType.rawValue,
                accountNumber: trimmedAccountNumber.isEmpty ? nil : trimmedAccountNumber,
                initialBalance: finalAmount,
                adjustmentMode: selectedAdjustmentMode.rawValue,
                excludeFromStatistics: excludeFromStatistics,
                isArchived: isArchived
            )

            modelContext.insert(newAccount)
        }

        dismiss()
    }

    // MARK: - Eliminación de cuenta

    private func handleDeleteTapped() {
        guard let account = accountToEdit else { return }

        // Regla mínima: no permitir eliminar cuentas con saldo distinto de 0.
        // Más adelante, cuando exista el modelo de transacciones, se deberá
        // ampliar esta validación para comprobar también que no tenga movimientos.
        if account.initialBalance != 0 {
            deleteErrorMessage =
                "No puedes eliminar esta cuenta porque tiene saldo distinto de cero. Ajusta el saldo a 0 antes de eliminarla."
            isShowingDeleteError = true
            return
        }

        modelContext.delete(account)
        dismiss()
    }
}
