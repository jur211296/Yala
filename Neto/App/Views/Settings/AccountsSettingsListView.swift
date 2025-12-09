//
//  AccountsSettingsListView.swift
//  Neto
//
//  Created by Neto Refactoring.
//

import SwiftData
import SwiftUI

// MARK: - Lista de cuentas desde Ajustes (FIN-42 con diseño y orden)

struct AccountsSettingsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Account.name, order: .forward) private var accounts: [Account]

    // FIN-46: Transacciones usadas para calcular saldos actuales en Ajustes
    @Query(sort: \TransactionItem.date, order: .reverse)
    private var transactions: [TransactionItem]

    @AppStorage("accountsSortOrderNames") private var accountsSortOrderNamesRaw: String = ""

    @State private var isPresentingCreateAccount = false
    @State private var accountToEdit: Account?

    // Solo cuentas no archivadas para esta vista
    private var activeAccounts: [Account] {
        accounts.filter { !$0.isArchived }
    }

    // Orden persistente por nombre
    private var accountsSortOrderNames: [String] {
        accountsSortOrderNamesRaw.split(separator: "|").map(String.init)
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

    // Cuentas archivadas (sin reordenamiento)
    private var archivedAccounts: [Account] {
        accounts.filter { $0.isArchived }
    }

    var body: some View {
        ZStack {
            PanelBackgroundView()

            ScrollView {
                VStack(spacing: 24) {
                    if !orderedActiveAccounts.isEmpty {
                        accountsSection(title: "Activas", accounts: orderedActiveAccounts)
                    }

                    if !archivedAccounts.isEmpty {
                        accountsSection(title: "Archivadas", accounts: archivedAccounts)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 32)
            }
        }
        .navigationTitle("Cuentas")
        .navigationBarTitleDisplayMode(.inline)  // título reducido y centrado
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isPresentingCreateAccount = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        // Alta de nueva cuenta desde Ajustes (reutiliza el formulario existente)
        .sheet(isPresented: $isPresentingCreateAccount) {
            AccountFormView(
                existingNames: accounts.map { $0.name }
            )
        }
        // Edición de cuenta existente reutilizando el mismo formulario
        .sheet(item: $accountToEdit) { account in
            AccountFormView(
                existingNames: accounts.map { $0.name }.filter { $0 != account.name },
                accountToEdit: account
            )
        }
    }
    // Caja blanca de sección (similar a Suscripciones de Apple)
    @ViewBuilder
    private func accountsSection(title: String, accounts: [Account]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.primary.opacity(0.6))  // gris un poco más fuerte
                .padding(.leading, 6)

            VStack(spacing: 0) {
                ForEach(Array(accounts.enumerated()), id: \.element.id) { index, account in
                    Button {
                        accountToEdit = account
                    } label: {
                        accountRow(account)
                    }
                    .buttonStyle(.plain)

                    if index < accounts.count - 1 {
                        SubsectionDivider()
                    }
                }
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

    // MARK: - Presentación de filas

    private func accountTypeText(for account: Account) -> String {
        account.type.replacingOccurrences(of: "_", with: " ").capitalized
    }

    // FIN-46: Saldo actual mostrado en la lista de cuentas de Ajustes
    private func formattedBalance(for account: Account) -> String {
        let normalizedCode = normalizeCurrencyCode(account.currencyCode)
        let currency = CurrencyCode(rawValue: normalizedCode) ?? .pen
        let info = currencyInfo(for: currency)

        // Calculamos el saldo actual en Decimal usando el servicio central.
        let currentDecimal = AccountBalanceCalculator.currentBalance(
            for: account,
            allTransactions: transactions
        )
        let nsNumber = currentDecimal as NSDecimalNumber
        let amountDouble = nsNumber.doubleValue

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2

        let formattedAmount = formatter.string(from: NSNumber(value: amountDouble)) ?? "0.00"
        return "\(info.code) \(formattedAmount)"
    }

    @ViewBuilder
    private func accountRow(_ account: Account) -> some View {
        let normalizedCode = normalizeCurrencyCode(account.currencyCode)
        let currency = CurrencyCode(rawValue: normalizedCode) ?? .pen
        let currencyInfoTuple = currencyInfo(for: currency)

        // Línea principal: número de cuenta si existe, si no el nombre
        let primaryText =
            (account.accountNumber?.isEmpty == false) ? account.accountNumber! : account.name

        HStack(spacing: 12) {
            // Ícono de la cuenta con color de fondo según configuración
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(colorForHex(account.colorHex))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: displayIconName(for: account))
                        .foregroundStyle(.white)
                )

            // Texto central (3 líneas)
            VStack(alignment: .leading, spacing: 2) {
                Text(primaryText)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(accountTypeText(for: account))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(currencyInfoTuple.name.capitalized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Monto + chevron a la derecha
            HStack(spacing: 4) {
                Text(formattedBalance(for: account))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)

                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

}
