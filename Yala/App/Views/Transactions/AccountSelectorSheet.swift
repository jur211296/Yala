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
    /// La moneda del monto de un gasto o ingreso (Jürgen, 23-nov-2026): la hoja enseña solo las cuentas en ella. Si no
    /// hay ninguna, enseña todas y lo dice arriba (`AccountSelectorCurrencyScope`). `nil` = todas (transferencias).
    var currencyScope: String?

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
    /// Las cuentas que casan con lo leído en una foto (`CuentaSolaAlLeer`): van arriba con su motivo, y el resto debajo en
    /// «Otras cuentas». Sin pista, la lista de siempre.
    @Environment(\.cuentaSolaAlLeerSelector) private var cuentaSolaPista

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
        currencyScope: String? = nil,
        sizing: SelectorSheetSizing = .large,
        offersCreatingAccount: Bool = false
    ) {
        _selectedAccount = selectedAccount
        self.title = title ?? L10n.Account.selectAccount
        self.excludeAccount = excludeAccount
        self.currencyFilter = currencyFilter
        self.routingCurrency = routingCurrency
        self.currencyScope = currencyScope
        self.sizing = sizing
        self.offersCreatingAccount = offersCreatingAccount
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    let candidates = viewModel.activeAccounts.filter { account in
                        if let exclude = excludeAccount,
                           account.persistentModelID == exclude.persistentModelID {
                            return false
                        }
                        if let currencyFilter, account.currencyCode != currencyFilter {
                            return false
                        }
                        return true
                    }
                    let scoped = AccountSelectorCurrencyScope.shown(
                        candidates, currencyCode: currencyScope, currencyOf: \.currencyCode)
                    let filteredAccounts = scoped.accounts
                    // Con una moneda que filtra de verdad, la lista es plana como con la divisa fija.
                    let isFlatList = currencyFilter != nil || (currencyScope != nil && !scoped.isFallback)

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
                        if scoped.isFallback, let currencyScope {
                            Text(String(
                                format: NuevoRegistroB1Text.string("accountSelector.noneInCurrency"),
                                currencyScope.uppercased()))
                                .font(DS.Typography.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("account_selector_none_in_currency")
                        }
                        // Con divisa fija (gastos de grupo, liquidaciones) la lista es plana: solo caben cuentas de esa
                        // divisa, y una línea sale con su nombre («Visa · USD»). Sin ella, cada tarjeta una vez con sus
                        // líneas debajo (entrega 3): la tarjeta va antes, así que la primera fila sigue siendo una cabeza.
                        let cards = !isFlatList
                            ? viewModel.cards(of: filteredAccounts)
                            : filteredAccounts.map { AccountCard(head: $0, lines: []) }
                        // Cada fila dice una sola divisa, la suya; la principal de una tarjeta con líneas la lleva además
                        // en el nombre («Sapphire · PEN»), como la línea de debajo (Jürgen, 6-nov).
                        let headsWithLines = viewModel.headsWithLines
                        let pinned = pinnedRows(among: filteredAccounts)
                        let otherCards = cards.filter { card in
                            !pinned.contains { $0.account.persistentModelID == card.head.persistentModelID }
                        }
                        if let pista = cuentaSolaPista, !pinned.isEmpty {
                            SectionBox(title: pista.titulo) {
                                VStack(spacing: DS.Spacing.none) {
                                    ForEach(Array(pinned.enumerated()), id: \.element.account.persistentModelID) { index, row in
                                        if index > 0 {
                                            SubsectionDivider()
                                        }
                                        AccountSelectorRow(
                                            account: row.account,
                                            displayName: viewModel.rowName(for: row.account, headsWithLines: headsWithLines),
                                            isSelected: isSelected(row.account),
                                            caption: row.motivo.map { "\(row.account.currencyCode) · \($0)" }
                                        ) {
                                            choose(row.account)
                                        }
                                    }
                                }
                            }
                        }
                        if !otherCards.isEmpty {
                            SectionBox(title: pinned.isEmpty ? "" : L10n.CuentaSolaAlLeer.Selector.others) {
                                VStack(spacing: DS.Spacing.none) {
                                    ForEach(
                                        Array(otherCards.enumerated()),
                                        id: \.element.head.persistentModelID
                                    ) { index, card in
                                        if index > 0 {
                                            SubsectionDivider()
                                        }

                                        AccountSelectorRow(
                                            account: card.head,
                                            displayName: viewModel.rowName(for: card.head, headsWithLines: headsWithLines),
                                            isSelected: isSelected(card.head)
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

    /// Una línea tocada a propósito se guarda tal cual; la tarjeta se enruta por la divisa del importe, salvo desde una de
    /// sus propias líneas, que vuelve a la principal (`AccountSelectorViewModel.selection`).
    private func choose(_ account: Account) {
        // Elegir en un selector del formulario: selección (card C4; mapa de `DS.Haptic`).
        DS.Haptic.selection()
        selectedAccount = viewModel.selection(
            for: account, current: selectedAccount?.persistentModelID, routingCurrency: routingCurrency)
        dismiss()
    }

    /// Las filas de arriba (pista de `CuentaSolaAlLeer`), en su orden y entre las cuentas que la hoja enseña.
    private func pinnedRows(among accounts: [Account]) -> [(account: Account, motivo: String?)] {
        guard let pista = cuentaSolaPista else { return [] }
        return pista.filas.compactMap { fila in
            accounts.first { $0.shortcutID == fila.accountID }.map { ($0, fila.motivo) }
        }
    }

    private func isSelected(_ account: Account) -> Bool {
        guard let selected = selectedAccount else { return false }
        return selected.persistentModelID == account.persistentModelID
    }
}

// MARK: - Cuentas por la moneda del monto

/// Qué cuentas enseña el selector de cuenta de un gasto o ingreso según la moneda del monto (Jürgen, 23-nov-2026): solo
/// las de esa moneda. Si no hay ninguna, todas, con `isFallback` para que la hoja lo diga: una hoja vacía no deja seguir.
/// Sin moneda, todas. Genérico para probarlo sin SwiftData (`YalaTests/SelectorCuentaMoneda/`).
nonisolated enum AccountSelectorCurrencyScope {
    struct Shown<Element> {
        let accounts: [Element]
        /// No había cuentas en la moneda pedida y salen todas.
        let isFallback: Bool
    }

    static func shown<Element>(
        _ accounts: [Element], currencyCode: String?, currencyOf: (Element) -> String
    ) -> Shown<Element> {
        guard let currencyCode else { return Shown(accounts: accounts, isFallback: false) }
        let wanted = currencyCode.uppercased()
        let inCurrency = accounts.filter { currencyOf($0).uppercased() == wanted }
        if inCurrency.isEmpty, !accounts.isEmpty {
            return Shown(accounts: accounts, isFallback: true)
        }
        return Shown(accounts: inCurrency, isFallback: false)
    }
}

// MARK: - Account Selector Row

struct AccountSelectorRow: View {
    let account: Account
    /// El nombre que se pinta: el de la cuenta, o «Sapphire · PEN» en la principal de una tarjeta con líneas. El
    /// identificador de accesibilidad sigue con el nombre guardado (`account_selector_row_<nombre>`).
    var displayName: String?
    let isSelected: Bool
    /// Una línea de la tarjeta de arriba: va sangrada y con el icono más pequeño.
    var isNestedLine: Bool = false
    /// La línea de debajo del nombre; sin ella, la divisa. «PEN · Lo dice la imagen» en las filas de `CuentaSolaAlLeer`.
    var caption: String? = nil
    let action: () -> Void

    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 36
    @ScaledMetric(relativeTo: .body) private var lineIconSize: CGFloat = 26

    private var name: String { displayName ?? account.name }

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
                    Text(name)
                        .font(isNestedLine ? DS.Typography.subheadline : DS.Typography.body)
                        .foregroundStyle(.primary)

                    Text(caption ?? account.currencyCode)
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
        // Con motivo («PEN · Tu regla «zip»», `CuentaSolaAlLeer`), VoiceOver lo lee entero: sin él solo oía nombre y divisa.
        .accessibilityLabel(L10n.Accessibility.accountRow(name, caption ?? account.currencyCode))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    AccountSelectorSheet(selectedAccount: .constant(nil))
}
