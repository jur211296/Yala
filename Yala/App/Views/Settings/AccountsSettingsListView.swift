//
//  AccountsSettingsListView.swift
//  Yala
//
//  Created by Yala Refactoring.
//

import SwiftData
import SwiftUI

// MARK: - Lista de cuentas desde Ajustes

struct AccountsSettingsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Account.name, order: .forward) private var accounts: [Account]

    @Query(sort: \TransactionItem.date, order: .reverse)
    private var transactions: [TransactionItem]

    @AppStorage("accountsSortOrderNames") private var accountsSortOrderNamesRaw: String = ""

    @State private var isPresentingCreateAccount = false
    @State private var accountToEdit: Account?
    @State private var isEditMode = false

    // MARK: - Static Formatters (avoid recreation on each render)

    private static let balanceFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

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
                VStack(spacing: DS.Spacing.xxl) {
                    if accounts.isEmpty {
                        emptyState
                    } else {
                        if !orderedActiveAccounts.isEmpty {
                            listBasedSection
                        }

                        if !archivedAccounts.isEmpty {
                            accountsSection(title: L10n.Common.archived, accounts: archivedAccounts)
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xxxl)
            }
        }
        .navigationTitle(L10n.Settings.accounts)
        .navigationBarTitleDisplayMode(.inline)  // título reducido y centrado
        .swipeBack()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                YalaToolbarButton(systemName: "chevron.left") {
                    // Logic to pop? usually dismiss works for sheets, but for stack navigation we need environment dismiss
                    dismiss()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: DS.Spacing.md) {
                    YalaToolbarButton(systemName: isEditMode ? "checkmark" : "arrow.up.arrow.down")
                    {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isEditMode.toggle()
                        }
                    }

                    YalaToolbarButton(systemName: "plus") {
                        isPresentingCreateAccount = true
                    }
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

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.lg) {
            Image(systemName: "creditcard")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text(L10n.Empty.noAccounts)
                .font(.headline)
                .foregroundStyle(.secondary)

            Text(L10n.Empty.accountsDescription)
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.top, 64)
    }

    // Caja blanca de sección para cuentas archivadas
    @ViewBuilder
    private func accountsSection(title: String, accounts: [Account]) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.primary.opacity(0.6))
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
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .fill(Color.yalaCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 6)
        }
    }

    // MARK: - Active Accounts Section (List with Drag and Drop)

    private var listBasedSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.Common.active)
                .font(.headline)
                .foregroundStyle(Color.primary.opacity(0.6))
                .padding(.leading, 6)

            List {
                ForEach(Array(orderedActiveAccounts.enumerated()), id: \.element.id) {
                    index, account in
                    Button {
                        if !isEditMode {
                            accountToEdit = account
                        }
                    } label: {
                        listAccountRow(account)
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                    .listRowBackground(Color.yalaCard)
                    .listRowSeparator(
                        index == 0 || index == orderedActiveAccounts.count - 1 ? .hidden : .visible,
                        edges: index == 0 ? .top : .bottom)
                }
                .onMove(perform: moveAccountList)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDisabled(true)
            .frame(height: CGFloat(orderedActiveAccounts.count) * 84)  // Tight fit
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .fill(Color.yalaCard)
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 6)
            .environment(\.editMode, .constant(isEditMode ? .active : .inactive))
        }
    }

    private func listAccountRow(_ account: Account) -> some View {
        let normalizedCode = normalizeCurrencyCode(account.currencyCode)
        let currency = CurrencyCode(rawValue: normalizedCode) ?? .pen
        let currencyInfoData = currencyInfo(for: currency)
        let primaryText =
            (account.accountNumber?.isEmpty == false) ? account.accountNumber! : account.name

        return HStack(spacing: DS.Spacing.md) {
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .fill(colorForHex(account.colorHex))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: displayIconName(for: account))
                        .foregroundStyle(.white)
                )

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(primaryText)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(accountTypeText(for: account))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(currencyInfoData.name.capitalized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer()

            HStack(spacing: DS.Spacing.xs) {
                Text(formattedBalance(for: account))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)

                // Chevron only in normal mode
                if !isEditMode {
                    Image(systemName: "chevron.right")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .contentShape(Rectangle())
    }

    private func moveAccountList(from source: IndexSet, to destination: Int) {
        var currentOrder = orderedActiveAccounts.map { $0.name }
        currentOrder.move(fromOffsets: source, toOffset: destination)
        accountsSortOrderNamesRaw = currentOrder.joined(separator: "|")
    }

    // MARK: - Presentación de filas

    private func accountTypeText(for account: Account) -> String {
        if let accountType = AccountType(rawValue: account.type) {
            return accountType.localizedName
        }
        return account.type.replacingOccurrences(of: "_", with: " ").capitalized
    }

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

        let formattedAmount = Self.balanceFormatter.string(from: NSNumber(value: amountDouble)) ?? "0.00"
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

        HStack(spacing: DS.Spacing.md) {
            // Ícono de la cuenta con color de fondo según configuración
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .fill(colorForHex(account.colorHex))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: displayIconName(for: account))
                        .foregroundStyle(.white)
                )

            // Texto central (3 líneas)
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
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
            HStack(spacing: DS.Spacing.xs) {
                Text(formattedBalance(for: account))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)

                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.sm)
        .contentShape(Rectangle())
    }

}
