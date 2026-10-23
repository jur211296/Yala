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
    /// El destino de una transferencia (UX 2.2 · L2-6): sin otra cuenta a la que pasar dinero, la hoja lo dice y ofrece
    /// «Crear otra cuenta», que vuelve con la cuenta nueva ya puesta. Antes decía «Aún no tienes cuentas» con una puesta.
    var offersCreatingAccount: Bool = false
    @State private var showsAccountForm = false
    @State private var showsUpgradeForAccounts = false
    /// Las cuentas que había al abrir el formulario de cuenta: la nueva es la que no estaba.
    @State private var accountIDsBeforeCreating: Set<PersistentIdentifier> = []
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
        sizing: SelectorSheetSizing = .large,
        offersCreatingAccount: Bool = false
    ) {
        _selectedAccount = selectedAccount
        self.title = title ?? L10n.Account.selectAccount
        self.excludeAccount = excludeAccount
        self.currencyFilter = currencyFilter
        self.routingCurrency = routingCurrency
        self.sizing = sizing
        self.offersCreatingAccount = offersCreatingAccount
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

                    if filteredAccounts.isEmpty, offersCreatingAccount {
                        YalaEmptyState(
                            icon: "arrow.left.arrow.right",
                            title: L10n.UXL2.needsAnotherAccount,
                            message: nil,
                            actionTitle: L10n.UXL2.createAnotherAccount,
                            action: startCreatingAccount,
                            actionAccessibilityIdentifier: "account_selector_create_another"
                        )
                    } else if filteredAccounts.isEmpty {
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
        .sheet(isPresented: $showsAccountForm, onDismiss: pickCreatedAccount) {
            AccountFormView(existingNames: viewModel.accounts.map(\.name))
        }
        // Al límite del plan gratis, la hoja de Pro de siempre; si compra, sigue al formulario de cuenta.
        .proUpgradeSheet(isPresented: $showsUpgradeForAccounts, feature: .accounts, context: .limitReached) {
            showsAccountForm = true
        }
    }

    // MARK: - Crear otra cuenta (L2-6)

    private func startCreatingAccount() {
        accountIDsBeforeCreating = Set(viewModel.accounts.map(\.persistentModelID))
        let activeCount = viewModel.accounts.billableUserAccounts.count
        if FeatureGateService.shared.canCreate(.accounts, currentCount: activeCount) {
            showsAccountForm = true
        } else {
            showsUpgradeForAccounts = true
        }
    }

    /// Al cerrarse el formulario de cuenta: si se creó una, queda como destino y la hoja se cierra.
    private func pickCreatedAccount() {
        viewModel.setContext(modelContext)
        guard let created = viewModel.activeAccounts.first(where: {
            !accountIDsBeforeCreating.contains($0.persistentModelID)
        }) else { return }
        selectedAccount = created
        dismiss()
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

                // Lo elegido, tintado y con ✓ relleno del color de la cuenta (UX 2.2 · L2-19), como la rejilla de
                // categorías. Antes, solo un ✓ pequeño.
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(DS.Typography.headline)
                        .foregroundStyle(Color.selectedFill(hex: account.colorHex))
                        .accessibilityHidden(true)
                }
            }
            // Sangría fija: atada al icono escalado, con texto grande partía el nombre de la línea en dos.
            .padding(.leading, isNestedLine ? DS.Spacing.lg + DS.Spacing.xxl : DS.Spacing.lg)
            .padding(.trailing, DS.Spacing.lg)
            .padding(.vertical, isNestedLine ? DS.Spacing.sm : DS.Spacing.md)
            .background(isSelected ? Color(hex: account.colorHex).opacity(0.22) : Color.clear)
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
