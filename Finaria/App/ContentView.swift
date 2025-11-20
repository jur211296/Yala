//
//  ContentView.swift
//  Finaria
//
//  Panel inicial con TabBar (Panel, Planificación, Estadísticas)
//  y flujo de creación de cuenta "Configurar cuenta".
//

import SwiftUI
import SwiftData
import UIKit

// MARK: - Enums de apoyo

enum AccountType: String, CaseIterable, Identifiable {
    case general = "General"
    case cash = "Efectivo"
    case checking = "Cuenta corriente"
    case savings = "Cuenta de ahorros"
    
    var id: String { rawValue }
}

enum AdjustmentMode: String, CaseIterable, Identifiable {
    case byEntry = "Ajustar por registro"
    case changeInitialBalance = "Cambiar saldo inicial"
    
    var id: String { rawValue }
    
    var description: String {
        switch self {
        case .byEntry:
            return "Escribe el saldo correcto y crearemos un registro de corrección. Úsalo si se te olvidó registrar algunos gastos."
        case .changeInitialBalance:
            return "Escribe el saldo correcto y cambiaremos el saldo inicial en tu cuenta. Usa esto si no has registrado durante mucho tiempo."
        }
    }
}

enum CurrencyCode: String, CaseIterable, Identifiable {
    case pen = "PEN"
    case usd = "USD"
    case eur = "EUR"
    
    var id: String { rawValue }
}

func currencyInfo(for currency: CurrencyCode) -> (name: String, code: String, flag: String) {
    switch currency {
    case .pen:
        return ("sol peruano", "PEN", "🇵🇪")
    case .usd:
        return ("dólar estadounidense", "USD", "🇺🇸")
    case .eur:
        return ("euro", "EUR", "🇪🇺")
    }
}

// MARK: - ContentView

struct ContentView: View {
    var body: some View {
        MainTabView()
    }
}

// MARK: - Tab principal con 3 secciones

struct MainTabView: View {
    var body: some View {
        TabView {
            PanelView()
                .tabItem {
                    Label("Panel", systemImage: "house.fill")
                }
            
            PlanningView()
                .tabItem {
                    Label("Planificación", systemImage: "calendar")
                }
            
            StatisticsView()
                .tabItem {
                    Label("Estadísticas", systemImage: "chart.bar.xaxis")
                }
        }
        .tint(.black)
    }
}

// MARK: - Panel (pantalla de inicio)

struct PanelView: View {
    
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Account.name, order: .forward) private var accounts: [Account]
    
    @State private var isPresentingAccountForm = false
    
    // Saldo total en soles (moneda predeterminada)
    private var totalBalanceInPEN: Double {
        accounts.reduce(0) { partial, account in
            let original = Decimal(account.initialBalance)
            let converted = convert(original, from: account.currencyCode, to: "PEN")
            let convertedDouble = (converted as NSDecimalNumber).doubleValue
            return partial + convertedDouble
        }
    }

    private var formattedTotalBalancePEN: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: totalBalanceInPEN)) ?? "0.00"
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        accountsSection
                        totalBalanceSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Panel")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        // TODO: navegar a ajustes cuando exista la vista
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .imageScale(.large)
                    }
                }
            }
            .sheet(isPresented: $isPresentingAccountForm) {
                AccountFormView(
                    existingNames: accounts.map { $0.name }
                )
            }
        }
    }
    
    // Sección de tarjetas de cuentas (incluye tarjeta "Agregar cuenta")
    private var accountsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cuentas")
                .font(.title2.weight(.semibold))
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(accounts) { account in
                        AccountCardView(account: account)
                    }
                    
                    AddAccountCardView {
                        isPresentingAccountForm = true
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var totalBalanceSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Saldo total")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Text("S/ \(formattedTotalBalancePEN)")
                .font(.title3.weight(.semibold))
        }
        .padding(.top, 8)
    }
}

// MARK: - Placeholders Planificación y Estadísticas

struct PlanningView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()
                Text("Planificación")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Planificación")
        }
    }
}

struct StatisticsView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()
                Text("Estadísticas")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Estadísticas")
        }
    }
}

// MARK: - Fondo general tipo Liquid Glass claro

struct PanelBackgroundView: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color.financeBackgroundTop,
                Color.financeBackgroundBottom
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

// MARK: - Tarjeta de cuenta

struct AccountCardView: View {
    
    let account: Account
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: iconForAccount)
                .font(.title2)
                .padding(10)
                .background(
                    Circle()
                        .fill(Color.black.opacity(0.05))
                )
                .foregroundStyle(.primary)
            
            Text(account.name.uppercased())
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text("\(normalizeCurrencyCode(account.currencyCode)) \(formattedAmount(account.initialBalance))")
                .font(.title3.weight(.bold))
        }
        .padding(16)
        .frame(width: 200, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.6), lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 18, x: 0, y: 10)
    }
    
    private var iconForAccount: String {
        if !account.iconName.isEmpty {
            return account.iconName
        } else {
            return "building.columns.fill"
        }
    }
    
    private func formattedAmount(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "0.00"
    }
}

// MARK: - Tarjeta para agregar cuenta

struct AddAccountCardView: View {
    
    let onTap: () -> Void
    
    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(spacing: 12) {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)
                
                Text("Agregar cuenta")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .frame(width: 200, height: 110)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.95))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 14, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Formulario "Configurar cuenta"

struct AccountFormView: View {
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let existingNames: [String]
    
    // General
    @State private var name: String = ""
    @State private var selectedType: AccountType = .general
    @State private var accountNumber: String = ""
    
    // Saldo actual
    @State private var isPositive: Bool = true
    @State private var balanceText: String = ""
    
    // Moneda
    @State private var selectedCurrency: CurrencyCode = .pen
    
    // Ajuste
    @State private var selectedAdjustmentMode: AdjustmentMode = .byEntry
    
    // Color
    @State private var selectedColorHex: String = "#1C3556"
    @State private var customColor: Color = Color(red: 0.11, green: 0.21, blue: 0.34)
    @State private var isPresentingColorPicker: Bool = false
    
    // Acciones
    @State private var excludeFromStatistics: Bool = false
    @State private var isArchived: Bool = false
    
    // Navegación interna (reservado para futuros flows)
    @State private var showTypeSelector = false
    @State private var showCurrencySelector = false
    @State private var showAdjustmentSelector = false
    
    // MARK: Validaciones
    
    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var isNameValid: Bool {
        !trimmedName.isEmpty
    }
    
    private var isNameUnique: Bool {
        let lower = trimmedName.lowercased()
        return !existingNames
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
                        colorSection
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
                        ColorPicker("Selecciona un color",
                                    selection: $customColor,
                                    supportsOpacity: false)
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
                
                Divider()
                    .padding(.horizontal, 20)
                
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
                
                Divider()
                    .padding(.horizontal, 20)
                
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
                
                Divider()
                    .padding(.horizontal, 20)
                
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
                
                Divider()
                    .padding(.horizontal, 20)
                
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
                                        .stroke(Color.white, lineWidth: selectedColorHex == hex ? 3 : 1)
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
                
                Divider()
                    .padding(.horizontal, 20)
                
                Toggle(isOn: $isArchived) {
                    Text("Archivar cuenta")
                }
                .padding()
            }
        }
    }
    
    // MARK: Utilidades de color
    
    private var colorOptions: [String] {
        ["#FF9F0A", "#30D158", "#FF375F", "#0A84FF", "#5E5CE6", "#FFD60A", "#1C3556"]
    }
    
    private func colorForHex(_ hex: String) -> Color {
        switch hex {
        case "#FF9F0A":
            return Color.orange
        case "#30D158":
            return Color.green
        case "#FF375F":
            return Color.red
        case "#0A84FF":
            return Color.blue
        case "#5E5CE6":
            return Color.purple
        case "#FFD60A":
            return Color.yellow
        case "#1C3556":
            return Color(red: 0.11, green: 0.21, blue: 0.34)
        default:
            return .gray
        }
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
        
        let newAccount = Account(
            name: trimmedName,
            currencyCode: normalizeCurrencyCode(selectedCurrency.rawValue),
            colorHex: selectedColorHex,
            iconName: "building.columns.fill",
            type: selectedType.rawValue,
            accountNumber: trimmedAccountNumber.isEmpty ? nil : trimmedAccountNumber,
            initialBalance: finalAmount,
            adjustmentMode: selectedAdjustmentMode.rawValue,
            excludeFromStatistics: excludeFromStatistics,
            isArchived: isArchived
        )
        
        modelContext.insert(newAccount)
        dismiss()
    }
}

// MARK: - Selectores de Tipo, Moneda y Ajuste

struct AccountTypeSelectorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedType: AccountType
    
    var body: some View {
        List {
            ForEach(AccountType.allCases) { type in
                HStack {
                    Text(type.rawValue)
                    Spacer()
                    if type == selectedType {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.tint)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedType = type
                    dismiss()
                }
            }
        }
        .navigationTitle("Tipo de cuenta")
    }
}

struct CurrencySelectorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedCurrency: CurrencyCode
    
    var body: some View {
        List {
            ForEach(CurrencyCode.allCases) { currency in
                HStack(spacing: 12) {
                    let info = currencyInfo(for: currency)
                    
                    Text(info.flag)
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(info.name)
                        Text(info.code)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    if currency == selectedCurrency {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.tint)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedCurrency = currency
                    dismiss()
                }
            }
        }
        .navigationTitle("Moneda")
    }
}

struct AdjustmentModeSelectorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedAdjustmentMode: AdjustmentMode
    
    var body: some View {
        List {
            ForEach(AdjustmentMode.allCases) { mode in
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(mode.rawValue)
                            .font(.body)
                        Text(mode.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    if mode == selectedAdjustmentMode {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.tint)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedAdjustmentMode = mode
                    dismiss()
                }
            }
        }
        .navigationTitle("Ajuste")
    }
}

// MARK: - Contenedor visual de secciones (Liquid Glass)

struct SectionBox<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.leading, 6)
            
            VStack(spacing: 0) {
                content()
            }
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.96))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 6)
        }
    }
}

// MARK: - Paleta Finaria (Liquid Glass claro)

extension Color {
    static let financeGreen = Color(red: 0.13, green: 0.75, blue: 0.45)
    static let financeBlue  = Color(red: 0.17, green: 0.47, blue: 0.96)
    static let financeOrange = Color(red: 1.00, green: 0.58, blue: 0.30)
    
    static let financeBackgroundTop = Color(red: 0.99, green: 0.99, blue: 1.00)
    static let financeBackgroundBottom = Color(red: 0.93, green: 0.95, blue: 0.99)
}
