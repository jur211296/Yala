//
//  PanelView.swift
//  Finaria
//
//  Created by Finaria Refactoring.
//

import SwiftData
import SwiftUI

// MARK: - Panel (pantalla de inicio)

struct PanelView: View {

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Account.name, order: .forward) private var accounts: [Account]
    // FIN-46: Transacciones usadas para calcular saldos actuales por cuenta
    @Query(sort: \TransactionItem.date, order: .reverse)
    private var transactions: [TransactionItem]

    @State private var isPresentingAccountForm = false
    @State private var isPresentingSettings = false
    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCodeRaw: String = CurrencyCode.pen
        .rawValue
    @AppStorage("accountsSortOrderNames") private var accountsSortOrderNamesRaw: String = ""

    private var defaultCurrency: CurrencyCode {
        CurrencyCode(rawValue: defaultCurrencyCodeRaw) ?? .pen
    }

    private var accountsSortOrderNames: [String] {
        accountsSortOrderNamesRaw.split(separator: "|").map(String.init)
    }

    private var activeAccounts: [Account] {
        accounts.filter { !$0.isArchived }
    }

    private var orderedActiveAccounts: [Account] {
        let order = accountsSortOrderNames
        let indexByName = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($1, $0) })

        return activeAccounts.sorted { a, b in
            let ia = indexByName[a.name]
            let ib = indexByName[b.name]

            switch (ia, ib) {
            case (let x?, let y?):
                return x < y
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            default:
                return a.name < b.name
            }
        }
    }

    // FIN-46: Saldo actual en moneda nativa de la cuenta
    // No modificar esta función sin revisar el impacto en todas las vistas
    // que muestran saldos por cuenta.
    private func currentBalance(for account: Account) -> Double {
        let currentDecimal = AccountBalanceCalculator.currentBalance(
            for: account,
            allTransactions: transactions
        )
        let nsNumber = currentDecimal as NSDecimalNumber
        return nsNumber.doubleValue
    }

    // Saldo total en la divisa preferida configurada en Ajustes (FIN-47)
    private var totalBalanceInDefaultCurrency: Double {
        // Divisa preferida desde Ajustes (AppStorage)
        let preferredCurrency = CurrencyCode(rawValue: defaultCurrencyCodeRaw) ?? .pen

        // Solo cuentas incluidas en estadísticas y no archivadas
        let eligibleAccounts = accounts.filter { account in
            !account.isArchived && !account.excludeFromStatistics
        }

        // Acumulamos el saldo actual de cada cuenta, convertido a la divisa preferida.
        let totalDecimal: Decimal = eligibleAccounts.reduce(0) { partial, account in
            // Saldo actual de la cuenta en su propia moneda (FIN-46)
            let currentBalance = AccountBalanceCalculator.currentBalance(
                for: account,
                allTransactions: transactions
            )

            // Código de moneda de la cuenta normalizado a CurrencyCode
            let sourceCurrency =
                CurrencyCode(
                    rawValue: normalizeCurrencyCode(account.currencyCode)
                ) ?? preferredCurrency

            // Convertimos el saldo de la cuenta a la divisa preferida
            let converted = convertToPreferredCurrency(
                amount: currentBalance,
                from: sourceCurrency,
                to: preferredCurrency
            )

            return partial + converted
        }

        let nsNumber = totalDecimal as NSDecimalNumber
        return nsNumber.doubleValue
    }

    // FIN-47: Conversión básica entre divisas hacia la divisa preferida.
    // En esta versión utilizamos un esquema simple con tasas por defecto cuando
    // no haya lógica de tipos de cambio más avanzada disponible.
    //
    // Tasas por defecto (ejemplo de FIN-47):
    // 1 USD = 3.54 PEN
    // 1 EUR = 3.89 PEN
    //
    // Estrategia:
    // - Convertimos primero el monto a PEN.
    // - Luego, si la divisa preferida no es PEN, convertimos de PEN a la divisa objetivo.
    private func convertToPreferredCurrency(
        amount: Decimal,
        from source: CurrencyCode,
        to target: CurrencyCode
    ) -> Decimal {
        // Si la divisa ya es la preferida, devolvemos el monto tal cual.
        if source == target {
            return amount
        }

        // Tasas de ejemplo tomadas como referencia para PEN (FIN-47).
        let usdToPen = Decimal(string: "3.54") ?? Decimal(3.54)
        let eurToPen = Decimal(string: "3.89") ?? Decimal(3.89)

        // Helpers internos para convertir PEN a otras divisas
        func penToUsd(_ pen: Decimal) -> Decimal {
            guard usdToPen != 0 else { return pen }
            return pen / usdToPen
        }

        func penToEur(_ pen: Decimal) -> Decimal {
            guard eurToPen != 0 else { return pen }
            return pen / eurToPen
        }

        // Paso 1: convertir a PEN
        let amountInPen: Decimal
        switch source {
        case .pen:
            amountInPen = amount
        case .usd:
            amountInPen = amount * usdToPen
        case .eur:
            amountInPen = amount * eurToPen
        }

        // Paso 2: convertir de PEN a la divisa destino
        switch target {
        case .pen:
            return amountInPen
        case .usd:
            return penToUsd(amountInPen)
        case .eur:
            return penToEur(amountInPen)
        }
    }

    private var formattedTotalBalance: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: totalBalanceInDefaultCurrency)) ?? "0.00"
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
                        isPresentingSettings = true
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
            .sheet(isPresented: $isPresentingSettings) {
                SettingsRootView()
            }
        }
        // -----------------------------------------------------------------
        // FIN-18: Semilla de categorías por defecto
        //
        // Esta llamada inicializa las categorías y subcategorías SOLO si
        // todavía no existe ninguna categoría en la base de datos.
        //
        // NO eliminar ni modificar esta llamada sin revisar el impacto en
        // la experiencia de onboarding y sin aprobación explícita del PO.
        // -----------------------------------------------------------------
        .onAppear {
            seedCategoriesIfNeeded(in: modelContext)
        }
    }

    // Sección de tarjetas de cuentas (incluye tarjeta "Agregar cuenta")
    private var accountsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cuentas")
                .font(.title2.weight(.semibold))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(orderedActiveAccounts) { account in
                        AccountCardView(
                            account: account,
                            currentBalance: currentBalance(for: account)
                        )
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

            let preferredCurrency = CurrencyCode(rawValue: defaultCurrencyCodeRaw) ?? .pen
            let preferredInfo = currencyInfo(for: preferredCurrency)
            Text("\(preferredInfo.code) \(formattedTotalBalance)")
                .font(.title3.weight(.semibold))
        }
        .padding(.top, 8)
    }
}
