//
//  AccountCardView.swift
//  Yala
//
//  Tarjeta de cuenta del carrusel del Panel. Rediseño del 2026-10-03 (`panel-accounts-redesign`, propuesta «A»
//  elegida por Jürgen): tarjeta grande, nombre y «tipo · moneda» arriba, saldo grande abajo. El color de la cuenta
//  vive en el icono; la tarjeta entera se tiñe de ese color solo cuando la cuenta está dentro del filtro, así que el
//  tinte dice qué está filtrado. Sin botón de editar: el toque abre la ficha, y editar se hace desde ahí.
//

import SwiftUI

// MARK: - Tarjeta de cuenta

struct AccountCardView: View {
    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(CurrencyConverter.self) private var currencyConverter

    let account: Account
    /// Saldo actual de la cuenta en su moneda nativa, ya calculado externamente.
    let currentBalance: Double

    /// La cuenta está en el filtro de cuentas del Panel (incluida o excluida según `isExcludeMode`).
    var isSelected: Bool

    /// En modo excluir, la cuenta seleccionada se atenúa con el signo menos.
    var isExcludeMode: Bool = false

    /// En modo «solo gastos» el importe es lo gastado en el período, no el saldo, y la etiqueta lo dice.
    var isExpensesOnlyMode: Bool = false

    /// Nombre del período del Panel («Este mes»), para la etiqueta de lo gastado.
    var periodName: String = ""

    /// Alto mínimo de la tarjeta. Crece con el texto grande: la tarjeta no recorta.
    static let minHeight: CGFloat = 168

    init(
        account: Account,
        currentBalance: Double,
        isSelected: Bool = false,
        isExcludeMode: Bool = false,
        isExpensesOnlyMode: Bool = false,
        periodName: String = ""
    ) {
        self.account = account
        self.currentBalance = currentBalance
        self.isSelected = isSelected
        self.isExcludeMode = isExcludeMode
        self.isExpensesOnlyMode = isExpensesOnlyMode
        self.periodName = periodName
    }

    private var currencyCode: String { normalizeCurrencyCode(account.currencyCode) }

    private var amountKind: PanelAccountCardLogic.AmountKind {
        PanelAccountCardLogic.amountKind(
            isExpensesOnlyMode: isExpensesOnlyMode,
            isCreditCard: AccountType(rawValue: account.type) == .creditCard,
            value: currentBalance
        )
    }

    private var amountLabel: String {
        switch amountKind {
        case .balance: return L10n.PanelAccountCard.balance
        case .toPay: return L10n.PanelAccountCard.toPay
        case .spent: return L10n.PanelAccountCard.spentInPeriod(periodName)
        }
    }

    /// Las cuentas de sistema (`Grupos [moneda]`) van en gris neutro: no son cuentas del usuario y no deben competir
    /// con las suyas. `Color(.systemGray)` es dark-mode safe.
    private var accountColor: Color {
        account.isSystemAccount ? Color(.systemGray) : Color(hex: account.colorHex)
    }

    var body: some View {
        let style = PanelAccountCardLogic.style(isSelected: isSelected, isExcludeMode: isExcludeMode)
        let color = accountColor

        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(alignment: .center, spacing: DS.Spacing.md) {
                Image(systemName: account.iconName)
                    .font(DS.Typography.body)
                    .foregroundStyle(Color.contrastingText(for: color))
                    .frame(width: DS.Icon.badgeLarge, height: DS.Icon.badgeLarge)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                            .fill(color)
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(account.name)
                        .font(DS.Typography.headline)
                        .foregroundStyle(theme.primaryText)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Text(subtitle)
                        .font(DS.Typography.caption)
                        .foregroundStyle(theme.secondaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if style == .excluded {
                    Image(systemName: "minus.circle.fill")
                        .font(DS.Typography.body)
                        .foregroundStyle(DS.Semantic.errorForeground)
                        .accessibilityHidden(true)
                }
            }

            Spacer(minLength: 0)

            let kind = amountKind
            let shownValue = PanelAccountCardLogic.displayedValue(currentBalance, kind: kind)
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(amountLabel)
                    .font(DS.Typography.caption)
                    .foregroundStyle(theme.secondaryText)
                    .lineLimit(1)

                AmountText(
                    value: shownValue,
                    currencyCode: currencyCode,
                    font: DS.Typography.largeTitle.bold(),
                    secondaryFont: DS.Typography.title3,
                    tint: .color(theme.primaryText)
                )

                if let converted = convertedToDefault(shownValue, kind: kind) {
                    AmountText(
                        value: converted,
                        currencyCode: appPreferences.defaultCurrencyCode.rawValue,
                        font: DS.Typography.subheadline,
                        secondaryFont: DS.Typography.caption,
                        tint: .color(theme.secondaryText),
                        isEstimate: true
                    )
                }
            }
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, minHeight: Self.minHeight, alignment: .leading)
        .background {
            // El tinte va encima del fondo de la tarjeta: sobre `theme.card` sale claro en modo claro y oscuro en
            // oscuro, y el texto sigue en sus colores de siempre, así que el contraste no depende del color que el
            // usuario eligió para la cuenta.
            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .fill(theme.card)
                if style == .tinted {
                    RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                        .fill(color.opacity(0.16))
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .stroke(style == .tinted ? color.opacity(0.45) : DS.Colors.borderDark, lineWidth: style == .tinted ? 1.5 : 1)
        )
        .opacity(style == .excluded ? 0.5 : 1.0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityAddTraits(style == .tinted ? .isSelected : [])
    }

    private var subtitle: String {
        let typeName: String? = account.isSystemAccount
            ? L10n.Account.System.badge
            : AccountType(rawValue: account.type)?.localizedName
        return PanelAccountCardLogic.subtitle(
            typeName: typeName,
            currencyCode: normalizeCurrencyCode(account.currencyCode)
        )
    }

    /// Equivalente en la moneda principal, con la tasa más reciente: el mismo camino que el saldo total del Panel
    /// (`LiveBalanceCalculator`). `nil` cuando no aplica (misma moneda, o lo gastado en el período).
    private func convertedToDefault(_ value: Double, kind: PanelAccountCardLogic.AmountKind) -> Double? {
        let target = appPreferences.defaultCurrencyCode.rawValue
        guard PanelAccountCardLogic.showsConversion(kind: kind, accountCurrency: currencyCode, defaultCurrency: target)
        else { return nil }
        let outcome = currencyConverter.convertCheckedWithLatestRate(Decimal(value), from: currencyCode, to: target)
        return (outcome.amount as NSDecimalNumber).doubleValue
    }

    /// «Sueldo. Saldo: S/ 4,820.50» — nombre, qué es el número y el número. Solo puntuación entre piezas ya
    /// traducidas.
    private var accessibilitySummary: String {
        let kind = amountKind
        let shown = PanelAccountCardLogic.displayedValue(currentBalance, kind: kind)
        var parts = "\(account.name). \(amountLabel): \(appPreferences.currency(shown, currencyCode: currencyCode))"
        if let converted = convertedToDefault(shown, kind: kind) {
            parts += " (≈ \(appPreferences.currency(converted, currencyCode: appPreferences.defaultCurrencyCode.rawValue)))"
        }
        return parts
    }

}

// MARK: - Tarjeta para agregar cuenta

struct AddAccountCardView: View {

    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(spacing: DS.Spacing.md) {
                Image(systemName: "plus")
                    .font(DS.Typography.title)
                    .foregroundStyle(.thPrimaryText)

                Text(L10n.Account.addAccount)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.thPrimaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(DS.Spacing.lg)
            .frame(maxWidth: .infinity, minHeight: AccountCardView.minHeight)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .fill(.thCard.opacity(0.95))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .stroke(DS.Colors.borderDark, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("panel_add_account_card")
    }
}
