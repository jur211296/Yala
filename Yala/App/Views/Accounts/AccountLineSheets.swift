//
//  AccountLineSheets.swift
//  Yala
//
//  Tarjeta con varias divisas, entrega 2: las dos hojas que abre el formulario de una cuenta. «Añadir línea en otra
//  divisa» elige la divisa (solo las que la tarjeta aún no tiene) y, si se quiere, el saldo de hoy; «Vincular cuenta
//  existente» lista las cuentas y explica bajo cada una por qué no se puede, si no se puede. Las reglas las decide el
//  ViewModel (`AccountFormViewModel+Lines.swift`); aquí no se repite ninguna.
//

import SwiftData
import SwiftUI

// MARK: - Añadir línea

struct AddAccountLineSheet: View {
    let viewModel: AccountFormViewModel

    @Environment(\.dismiss) private var dismiss
    @Environment(\.yalaTheme) private var theme

    @State private var selected: CurrencyCode?
    @State private var query: String = ""
    @State private var balanceText: String = ""
    @State private var isPositive: Bool = false
    /// El motivo de un añadido que no salió; se enseña en esta hoja, que tapa al formulario.
    @State private var failure: String?
    @State private var showsFailure: Bool = false

    private var isCreditCard: Bool { viewModel.selectedType == .creditCard }

    /// Las divisas que la tarjeta aún no tiene: primero la de la región y USD, EUR y GBP (como el selector de divisas),
    /// después el resto en su orden.
    private var currencies: [CurrencyCode] {
        let addable = viewModel.addableLineCurrencies
        let usual = [CurrencyDefaults.detectCurrencyFromRegion(), .usd, .eur, .gbp]
        var ordered: [CurrencyCode] = []
        for currency in usual where addable.contains(currency) && !ordered.contains(currency) {
            ordered.append(currency)
        }
        ordered += addable.filter { !ordered.contains($0) }
        return CurrencySearchLogic.filter(ordered, query: query)
    }

    /// El saldo escrito, con su signo; `nil` sin nada escrito. Lo mismo que el saldo al crear una cuenta.
    private var parsedBalance: Double?? {
        let trimmed = balanceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .some(nil) }
        let magnitude = AmountInputHelper.parseDecimal(trimmed)
        if magnitude == 0 && trimmed != "0" && !trimmed.hasPrefix("0") { return nil }
        return .some(isPositive ? magnitude : -magnitude)
    }

    private var canAdd: Bool { selected != nil && parsedBalance != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    SectionBox(title: L10n.Account.Lines.addBalance) {
                        VStack(spacing: DS.Spacing.none) {
                            HStack(spacing: DS.Spacing.md) {
                                Text(selected?.symbol ?? "")
                                    .font(DS.Typography.headline)
                                    .foregroundStyle(.secondary)
                                TextField("0", text: $balanceText)
                                    .keyboardType(.decimalPad)
                                    .accessibilityLabel(L10n.Account.Lines.addBalance)
                                    .accessibilityIdentifier("account_line_balance_field")
                            }
                            .padding()

                            SubsectionDivider()

                            Picker(L10n.Account.sign, selection: $isPositive) {
                                if isCreditCard {
                                    Text(L10n.Account.Sign.inFavor).tag(true)
                                    Text(L10n.Account.Sign.consumed).tag(false)
                                } else {
                                    Text(L10n.Account.positive).tag(true)
                                    Text(L10n.Account.negative).tag(false)
                                }
                            }
                            .pickerStyle(.segmented)
                            .padding()
                        }
                    }

                    if let selected {
                        Text(L10n.Account.Lines.addFooter(viewModel.newLineName(for: selected)))
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, DS.Spacing.sm)
                    }

                    SectionBox(title: L10n.Account.currency) {
                        VStack(spacing: DS.Spacing.none) {
                            ForEach(Array(currencies.enumerated()), id: \.element) { index, currency in
                                if index > 0 { SubsectionDivider() }
                                currencyRow(currency)
                            }
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xxl)
                .dismissKeyboardOnTap()
            }
            .scrollDismissesKeyboard(.interactively)
            .searchable(text: $query)
            .yalaScreenBackground(.subtle)
            .navigationTitle(L10n.Account.Lines.addTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.Action.add) { add() }
                        .fontWeight(.semibold)
                        .disabled(!canAdd)
                        .accessibilityIdentifier("account_line_add_confirm")
                }
            }
        }
        .alert(L10n.Common.error, isPresented: $showsFailure) {
            Button(L10n.Common.understood, role: .cancel) {}
        } message: {
            Text(failure ?? "")
        }
        .onAppear {
            // Una tarjeta de crédito suele empezar con deuda: el signo de «consumido» por defecto, como al crearla.
            isPositive = !isCreditCard
        }
    }

    private func currencyRow(_ currency: CurrencyCode) -> some View {
        let info = currencyInfo(for: currency)
        return Button {
            selected = currency
        } label: {
            HStack(spacing: DS.Spacing.md) {
                Text(info.flag)
                    .font(DS.Typography.title)
                    .accessibilityHidden(true)
                Text(info.name.capitalized)
                    .font(DS.Typography.body)
                    .foregroundStyle(.primary)
                Spacer()
                Text(verbatim: currency.rawValue)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                if selected == currency {
                    Image(systemName: "checkmark")
                        .font(DS.Typography.body)
                        .foregroundStyle(theme.accent)
                        .accessibilityHidden(true)
                }
            }
            .padding()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected == currency ? .isSelected : [])
        .accessibilityIdentifier("account_line_currency_\(currency.rawValue)")
    }

    private func add() {
        guard let selected, let balance = parsedBalance else { return }
        if viewModel.addLine(currency: selected, initialBalance: balance) {
            dismiss()
        } else {
            failure = viewModel.lineActionError
            showsFailure = true
        }
    }
}

// MARK: - Vincular cuenta existente

struct LinkAccountLineSheet: View {
    let viewModel: AccountFormViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var failure: String?
    @State private var showsFailure: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    Text(L10n.Account.Lines.linkFooter(viewModel.accountToEdit?.name ?? viewModel.trimmedName))
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, DS.Spacing.sm)

                    let candidates = viewModel.linkCandidates
                    if candidates.isEmpty {
                        Text(L10n.Account.Lines.linkEmpty)
                            .font(DS.Typography.body)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, DS.Spacing.xxl)
                    } else {
                        VStack(spacing: DS.Spacing.none) {
                            ForEach(Array(candidates.enumerated()), id: \.element.account.persistentModelID) {
                                index, candidate in
                                if index > 0 { SubsectionDivider() }
                                candidateRow(candidate.account, reason: candidate.reason)
                            }
                        }
                        .solidCard()
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xxl)
            }
            .yalaScreenBackground(.subtle)
            .navigationTitle(L10n.Account.Lines.linkTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) { dismiss() }
                }
            }
        }
        .alert(L10n.Common.error, isPresented: $showsFailure) {
            Button(L10n.Common.understood, role: .cancel) {}
        } message: {
            Text(failure ?? "")
        }
    }

    /// Una cuenta que se puede vincular se toca y se vincula; una que no, se ve atenuada con su porqué debajo.
    private func candidateRow(_ account: Account, reason: String?) -> some View {
        let code = normalizeCurrencyCode(account.currencyCode)
        return Button {
            if viewModel.link(account) {
                dismiss()
            } else {
                failure = viewModel.lineActionError
                showsFailure = true
            }
        } label: {
            HStack(spacing: DS.Spacing.md) {
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .fill(colorForHex(account.colorHex))
                    .frame(width: DS.Icon.badgeLarge, height: DS.Icon.badgeLarge)
                    .overlay(
                        Image(systemName: account.iconName)
                            .foregroundStyle(.white)
                    )
                    .opacity(reason == nil ? 1 : 0.45)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(account.name)
                        .font(DS.Typography.headline)
                        .foregroundStyle(reason == nil ? .primary : .secondary)
                    Text(verbatim: code)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)
                    if let reason {
                        Text(reason)
                            .font(DS.Typography.caption)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("account_link_reason_\(account.name)")
                    }
                }

                Spacer(minLength: DS.Spacing.sm)

                if reason == nil {
                    Image(systemName: "link")
                        .font(DS.Typography.body)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }
            .padding()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(reason != nil)
        .accessibilityIdentifier("account_link_candidate_\(account.name)")
    }
}
