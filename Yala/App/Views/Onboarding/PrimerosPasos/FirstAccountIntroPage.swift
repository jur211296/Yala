//
//  FirstAccountIntroPage.swift
//  Yala
//
//  Y23-07: la página corta «qué son las cuentas» (E2 del prototipo oficial v35): ¿Qué es una cuenta? · Así se ven tus
//  cuentas · ¿Por qué tenerlas al día?, cada 3,4 s, con «Crear mi primera cuenta» siempre a la vista. Los importes y
//  nombres son de ejemplo (la ficha: los datos del prototipo son solo para mostrar) y van en la moneda de la persona.
//

import SwiftUI

struct FirstAccountIntroPage: View {
    @Binding var part: Int
    let mainCurrency: CurrencyCode
    let onBack: () -> Void
    let onStart: () -> Void

    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences

    private typealias T = L10n.PrimerosPasos23.Account

    var body: some View {
        TutorialStoryPage(
            eyebrow: T.introEyebrow,
            count: 3,
            part: $part,
            onBack: onBack,
            content: { index in partView(index) },
            footer: {
                YalaPrimaryButton(T.createFirst, action: onStart)
                    .accessibilityIdentifier("first_account_start")
                    .primerosPasosButtonText()
            }
        )
    }

    @ViewBuilder
    private func partView(_ index: Int) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text(title(index))
                    .font(DS.Typography.welcomeHeadline)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(message(index))
                    .font(DS.Typography.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            switch index {
            case 0: placesVisual
            case 1: accountsVisual
            default: upToDateVisual
            }
        }
        .padding(.top, DS.Spacing.md)
    }

    private func title(_ index: Int) -> String {
        [T.introPart1Title, T.introPart2Title, T.introPart3Title][min(index, 2)]
    }

    private func message(_ index: Int) -> String {
        let second = FirstAccountFlowView.secondCurrencySuggestion(main: mainCurrency.rawValue)
        return [
            T.introPart1Message,
            T.introPart2Message(mainCurrency.shortPluralName, second.shortPluralName),
            T.introPart3Message,
        ][min(index, 2)]
    }

    private func money(_ value: Double, _ code: CurrencyCode? = nil) -> String {
        appPreferences.currency(value, currencyCode: (code ?? mainCurrency).rawValue)
    }

    // MARK: Parte 1 · cada lugar donde está tu dinero

    private var placesVisual: some View {
        let places: [(FirstAccountFlowLogic.Kind, String, String)] = [
            (.cash, T.placeWallet, L10n.Account.AccountType.cash),
            (.checking, T.placePaid, T.placeBank),
            (.savings, T.placeSaved, T.kindSavings),
            (.creditCard, T.placeOwe, T.placeCard),
        ]
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DS.Spacing.md) {
            ForEach(places, id: \.0) { kind, caption, name in
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Image(systemName: iconName(for: kind.accountType))
                        .font(DS.Typography.headline)
                        .foregroundStyle(Color(hex: kind.colorHex))
                    Text(caption).font(DS.Typography.caption).foregroundStyle(.secondary)
                    Text(name).font(DS.Typography.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DS.Spacing.md)
                .background(RoundedRectangle(cornerRadius: DS.Radius.lg).fill(theme.card))
                .accessibilityElement(children: .combine)
            }
        }
    }

    // MARK: Parte 2 · así se ven tus cuentas

    private var accountsVisual: some View {
        let second = FirstAccountFlowView.secondCurrencySuggestion(main: mainCurrency.rawValue)
        let rows: [(FirstAccountFlowLogic.Kind, String, String, String)] = [
            (.cash, L10n.Account.AccountType.cash, T.rowCashCaption, money(150)),
            (.checking, T.exampleChecking, T.placeBank, money(1200)),
            (.savings, T.exampleSavings, T.rowSavingsCaption, money(300) + " + " + money(200, second)),
            (.creditCard, T.exampleCard, T.rowCardCaption, "−" + money(620)),
        ]
        return VStack(spacing: DS.Spacing.sm) {
            ForEach(rows, id: \.0) { kind, name, caption, amount in
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: iconName(for: kind.accountType))
                        .font(DS.Typography.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(RoundedRectangle(cornerRadius: DS.Radius.md).fill(Color(hex: kind.colorHex)))
                    VStack(alignment: .leading, spacing: 0) {
                        Text(name).font(DS.Typography.subheadline.weight(.semibold))
                        Text(caption).font(DS.Typography.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: DS.Spacing.sm)
                    Text(amount)
                        .font(DS.Typography.subheadline.weight(.semibold))
                        .foregroundStyle(kind == .creditCard ? Color.hotPink : .primary)
                        .multilineTextAlignment(.trailing)
                }
                .padding(DS.Spacing.md)
                .background(RoundedRectangle(cornerRadius: DS.Radius.lg).fill(theme.card))
                .accessibilityElement(children: .combine)
            }
        }
    }

    // MARK: Parte 3 · ¿por qué tenerlas al día?

    private var upToDateVisual: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(T.yalaSays).font(DS.Typography.caption).foregroundStyle(.secondary)
                    Text(money(1200)).font(DS.Typography.headline)
                }
                Spacer()
                Text(verbatim: "=").font(DS.Typography.title2.weight(.bold)).foregroundStyle(Color.incomeAmount)
                Spacer()
                VStack(alignment: .trailing, spacing: DS.Spacing.xxs) {
                    Text(T.bankSays).font(DS.Typography.caption).foregroundStyle(.secondary)
                    Text(money(1200)).font(DS.Typography.headline)
                }
            }
            .padding(DS.Spacing.md)
            .background(RoundedRectangle(cornerRadius: DS.Radius.lg).fill(theme.card))
            .accessibilityElement(children: .combine)
            ForEach([
                ("checkmark.circle.fill", T.benefitSpend),
                ("chart.pie.fill", T.benefitReports),
                ("arrow.left.arrow.right", T.benefitAdjust),
            ], id: \.1) { icon, text in
                Label {
                    Text(text).font(DS.Typography.subheadline)
                } icon: {
                    Image(systemName: icon).foregroundStyle(.thAccentText)
                }
            }
        }
    }
}
