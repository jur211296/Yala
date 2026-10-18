//
//  AccountSelectorSheet.swift
//  Yala
//
//  Created by Yala - New Transaction Form.
//

import SwiftData
import SwiftUI

// MARK: - Account Selector Sheet

/// Sheet para seleccionar una cuenta
struct AccountSelectorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var viewModel = AccountSelectorViewModel()

    @Binding var selectedAccount: Account?
    let title: String
    var excludeAccount: Account?
    var currencyFilter: String?
    /// Tarjeta con varias divisas (entrega 3): la divisa del importe que se está registrando. Tocar una tarjeta guarda su
    /// línea en esa divisa (o la principal si no tiene). `nil` = guardar la cuenta tocada tal cual (transferencias).
    var routingCurrency: String?

    /// Cómo abre la hoja (`SelectorSheetSizing`): `.mediumFirst` desde un registro nuevo, `.large` en el resto.
    var sizing: SelectorSheetSizing = .large
    @State private var selectedDetent: PresentationDetent = .medium
    @Environment(\.usesLargeSheets) private var usesLargeSheets
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var sheetBackground: YalaBackgroundVariant {
        guard sizing == .mediumFirst else { return .subtle }
        return sizing.background(
            selectedDetent: selectedDetent,
            usesLargeSheets: usesLargeSheets,
            dynamicTypeSize: dynamicTypeSize
        )
    }

    init(
        selectedAccount: Binding<Account?>,
        title: String? = nil,
        excludeAccount: Account? = nil,
        currencyFilter: String? = nil,
        routingCurrency: String? = nil,
        sizing: SelectorSheetSizing = .large
    ) {
        _selectedAccount = selectedAccount
        self.title = title ?? L10n.Account.selectAccount
        self.excludeAccount = excludeAccount
        self.currencyFilter = currencyFilter
        self.routingCurrency = routingCurrency
        self.sizing = sizing
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    let filteredAccounts = viewModel.activeAccounts.filter { account in
                        if let exclude = excludeAccount,
                           account.persistentModelID == exclude.persistentModelID {
                            return false
                        }
                        if let currencyFilter, account.currencyCode != currencyFilter {
                            return false
                        }
                        return true
                    }

                    if filteredAccounts.isEmpty {
                        YalaEmptyState.noAccounts()
                    } else {
                        // Con divisa fija (gastos de grupo, liquidaciones) la lista es plana: solo caben cuentas de esa
                        // divisa, y una línea sale con su nombre («Visa · USD»). Sin ella, cada tarjeta una vez con sus
                        // líneas debajo (entrega 3): la tarjeta va antes, así que la primera fila sigue siendo una cabeza.
                        let cards = currencyFilter == nil
                            ? viewModel.cards(of: filteredAccounts)
                            : filteredAccounts.map { AccountCard(head: $0, lines: []) }
                        SectionBox(title: "") {
                            VStack(spacing: DS.Spacing.none) {
                                ForEach(
                                    Array(cards.enumerated()),
                                    id: \.element.head.persistentModelID
                                ) { index, card in
                                    if index > 0 {
                                        SubsectionDivider()
                                    }

                                    AccountSelectorRow(
                                        account: card.head,
                                        isSelected: isSelected(card.head),
                                        cardCurrencies: card.hasLines ? card.members.map(\.currencyCode) : nil
                                    ) {
                                        choose(card.head)
                                    }

                                    ForEach(card.lines, id: \.persistentModelID) { line in
                                        AccountSelectorRow(
                                            account: line,
                                            isSelected: isSelected(line),
                                            isNestedLine: true
                                        ) {
                                            choose(line)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xxl)
            }
            .yalaScreenBackground(sheetBackground)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }
            }
        }
        .selectorSheetSizing(sizing, selectedDetent: $selectedDetent)
        .onAppear {
            viewModel.setContext(modelContext)
        }
    }

    /// Una línea tocada a propósito se guarda tal cual; la tarjeta se enruta por la divisa del importe.
    private func choose(_ account: Account) {
        let roles = AccountLineLogic.resolve(viewModel.accounts.map { AccountLineNode($0) })
        let isLine = roles[account.shortcutID]?.isLine ?? false
        selectedAccount = isLine ? account : viewModel.resolvedSelection(for: account, routingCurrency: routingCurrency)
        dismiss()
    }

    private func isSelected(_ account: Account) -> Bool {
        guard let selected = selectedAccount else { return false }
        return selected.persistentModelID == account.persistentModelID
    }
}

// MARK: - Account Selector Row

struct AccountSelectorRow: View {
    let account: Account
    let isSelected: Bool
    /// Tarjeta con varias divisas: las divisas de la tarjeta («PEN · USD») en vez de la de la principal.
    var cardCurrencies: [String]?
    /// Una línea de la tarjeta de arriba: va sangrada y con el icono más pequeño.
    var isNestedLine: Bool = false
    let action: () -> Void

    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 36
    @ScaledMetric(relativeTo: .body) private var lineIconSize: CGFloat = 26

    private var currencyText: String {
        cardCurrencies?.joined(separator: " · ") ?? account.currencyCode
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.md) {
                Circle()
                    .fill(Color(hex: account.colorHex))
                    .frame(width: isNestedLine ? lineIconSize : iconSize, height: isNestedLine ? lineIconSize : iconSize)
                    .overlay(
                        Image(systemName: displayIconName(for: account))
                            .font(isNestedLine ? DS.Typography.caption : DS.Typography.label)
                            .foregroundStyle(.white)
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(account.name)
                        .font(isNestedLine ? DS.Typography.subheadline : DS.Typography.body)
                        .foregroundStyle(.primary)

                    Text(currencyText)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(DS.Typography.headline)
                        .foregroundStyle(.thAccent)
                }
            }
            // Sangría fija: atada al icono escalado, con texto grande partía el nombre de la línea en dos.
            .padding(.leading, isNestedLine ? DS.Spacing.lg + DS.Spacing.xxl : DS.Spacing.lg)
            .padding(.trailing, DS.Spacing.lg)
            .padding(.vertical, isNestedLine ? DS.Spacing.sm : DS.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("account_selector_row_\(account.name)")
        .accessibilityLabel(L10n.Accessibility.accountRow(account.name, currencyText))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    AccountSelectorSheet(selectedAccount: .constant(nil))
}
