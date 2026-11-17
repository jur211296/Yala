//
//  HeroInfoSheet.swift
//  Yala
//
//  La hoja del «?» del hero de Estadísticas, Registros y el Flujo de caja (2026-11-16), con la forma de la del Panel
//  (`PanelSaldoInfoSheet`): qué es la cifra en una tarjeta, cómo se calcula, qué no cuenta y un ejemplo con números.
//  Para alguien que no sabe nada de dinero: frases cortas y el ejemplo con números, no con definiciones.
//
//  Qué explica lo decide `HeroClaroLogic.Topic`, que sale del mismo estado que elige la cifra y su rótulo: la hoja no
//  puede explicar otra cosa que la que se ve.
//

import SwiftUI

struct HeroInfoSheet: View {
    let topic: HeroClaroLogic.Topic
    /// El rótulo que la persona acaba de leer junto a la cifra («Te queda», «Al 30 de noviembre tendrías»…): la primera
    /// tarjeta lo repite tal cual, para que se reconozca.
    let figureLabel: String
    let currencyCode: String
    /// Un período ya cerrado: el saldo es el del cierre.
    var isClosedPeriod: Bool = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    ForEach(Array(cards.enumerated()), id: \.offset) { _, card in
                        figureCard(card)
                    }
                    ForEach(Array(notes.enumerated()), id: \.offset) { _, note in
                        Text(note)
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(.thSecondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    exampleSection
                    if showsNotCounted {
                        figureCard(Card(
                            systemName: "arrow.left.arrow.right",
                            title: L10n.HeroClaro.notCountedTitle,
                            body: L10n.HeroClaro.notCountedBody
                        ))
                        .accessibilityIdentifier("hero_info_not_counted")
                    }
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.vertical, DS.Spacing.lg)
                .readableColumn()
            }
            .scrollBounceBehavior(.basedOnSize)
            .yalaScreenBackground(.subtle)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Accessibility.close) {
                        dismiss()
                    }
                    .accessibilityIdentifier("hero_info_close")
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("hero_info_sheet")
    }

    // MARK: - Lo que dice cada tema

    private struct Card {
        let systemName: String
        let title: String
        let body: String
    }

    private var title: String {
        switch topic {
        case .net: L10n.HeroClaro.Net.title
        case .expense: L10n.HeroClaro.Expense.title
        case .income: L10n.HeroClaro.Income.title
        case .total: L10n.HeroClaro.Total.title
        case .accountsBalance: L10n.HeroClaro.Balance.title
        case .cashFlowMonthEnd: L10n.HeroClaro.CashFlowEnd.title
        case .cashFlowMonth: L10n.HeroClaro.CashFlowMonth.title
        }
    }

    private var cards: [Card] {
        switch topic {
        case .net:
            return [
                Card(systemName: "equal.circle.fill", title: figureLabel, body: L10n.HeroClaro.Net.body),
                Card(systemName: "arrow.up.right", title: L10n.CashFlow.income, body: L10n.HeroClaro.incomeBody),
                Card(systemName: "arrow.down.right", title: L10n.CashFlow.expense, body: L10n.HeroClaro.expenseBody),
            ]
        case .expense:
            return [Card(systemName: "arrow.down.right", title: figureLabel, body: L10n.HeroClaro.Expense.body)]
        case .income:
            return [Card(systemName: "arrow.up.right", title: figureLabel, body: L10n.HeroClaro.Income.body)]
        case .total:
            return [Card(systemName: "plus.forwardslash.minus", title: figureLabel, body: L10n.HeroClaro.Total.body)]
        case .accountsBalance:
            return [Card(systemName: "building.columns.fill", title: figureLabel, body: L10n.HeroClaro.Balance.body)]
        case .cashFlowMonthEnd:
            return [Card(systemName: "calendar", title: figureLabel, body: L10n.HeroClaro.CashFlowEnd.body)]
        case .cashFlowMonth:
            return [Card(systemName: "calendar", title: figureLabel, body: L10n.HeroClaro.CashFlowMonth.body)]
        }
    }

    private var notes: [String] {
        switch topic {
        case .net:
            return [L10n.HeroClaro.Net.notBalance, L10n.HeroClaro.filtersNote]
        case .expense, .income, .total:
            return [L10n.HeroClaro.filtersNote]
        case .accountsBalance:
            return isClosedPeriod ? [L10n.HeroClaro.Balance.closedNote] : []
        case .cashFlowMonthEnd:
            return [L10n.HeroClaro.CashFlowEnd.netNote, L10n.HeroClaro.cashFlowProjectedNote]
        case .cashFlowMonth:
            return [L10n.HeroClaro.cashFlowProjectedNote]
        }
    }

    /// Transferencias y ajustes de saldo no son ingresos ni gastos (`CashFlowCalculator`): lo dice cada cifra que suma
    /// ingresos o gastos. El saldo sí los cuenta, y el flujo de caja planifica líneas, no movimientos sueltos.
    private var showsNotCounted: Bool {
        switch topic {
        case .net, .expense, .income, .total: true
        case .accountsBalance, .cashFlowMonthEnd, .cashFlowMonth: false
        }
    }

    // MARK: - Piezas

    private func figureCard(_ card: Card) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            Image(systemName: card.systemName)
                .font(DS.Typography.headline)
                .foregroundStyle(.thAccentText)
                .frame(width: DS.Icon.badgeMedium, height: DS.Icon.badgeMedium)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(card.title)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.thPrimaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Text(card.body)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.thSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thCard, in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var exampleSection: some View {
        let rows = HeroClaroLogic.example(for: topic)
        return VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.SaldoPanel.Info.exampleTitle)
                .font(DS.Typography.headline)
                .foregroundStyle(.thPrimaryText)

            VStack(spacing: DS.Spacing.none) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    if index > 0 { Divider() }
                    exampleRow(row)
                }
            }
            .padding(.horizontal, DS.Spacing.md)
            .background(.thCard, in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
            // El ejemplo no son montos de la persona: el ojo del Panel no lo tapa.
            .environment(\.amountsHidden, false)
            .accessibilityIdentifier("hero_info_example")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func exampleRow(_ row: HeroClaroLogic.ExampleRow) -> some View {
        AdaptiveRowStack(spacing: DS.Spacing.sm, stackedSpacing: DS.Spacing.xxs) {
            Text(exampleLabel(row.label))
                .font(row.isResult ? DS.Typography.subheadlineEmphasized : DS.Typography.subheadline)
                .foregroundStyle(row.isResult ? .thPrimaryText : .thSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        } trailing: {
            AmountText(
                value: row.value,
                currencyCode: currencyCode,
                font: row.isResult ? DS.Typography.headline : DS.Typography.subheadline,
                secondaryFont: DS.Typography.caption
            )
        }
        .padding(.vertical, DS.Spacing.sm)
        .accessibilityElement(children: .combine)
    }

    private func exampleLabel(_ label: HeroClaroLogic.ExampleRow.Label) -> String {
        switch label {
        case .income: L10n.CashFlow.income
        case .expense: L10n.CashFlow.expense
        case .net: L10n.Panel.Hero.leftNow
        case .netShortfall: L10n.HeroClaro.Example.shortfall
        case .total: L10n.HeroClaro.Example.total
        case .balanceToday: L10n.Panel.Hero.haveToday
        case .leftToComeIn: L10n.ProjectedFlow.leftToComeIn
        case .leftToGoOut: L10n.ProjectedFlow.leftToGoOut
        case .monthEnd: L10n.HeroClaro.Example.monthEnd
        case .savings: L10n.SaldoPanel.Info.exampleSavings
        case .card: L10n.SaldoPanel.Info.exampleCard
        case .refund: L10n.HeroClaro.Example.refund
        case .salary: L10n.HeroClaro.Example.salary
        case .sale: L10n.HeroClaro.Example.sale
        }
    }
}

/// Lo que abre el «?» de un hero: qué explicar y con qué rótulo. Se presenta con `.sheet(item:)` (un objeto, una hoja:
/// `swiftui-ds.md`), y lleva el rótulo y el tiempo copiados al tocar, para que la hoja diga lo que la persona leía.
struct HeroInfoRequest: Identifiable, Equatable {
    let topic: HeroClaroLogic.Topic
    let figureLabel: String
    var isClosedPeriod: Bool = false

    var id: String { "\(topic)|\(figureLabel)|\(isClosedPeriod)" }
}

extension View {
    /// Cuelga la hoja del «?» del hero de quien lo monta.
    func heroInfoSheet(_ request: Binding<HeroInfoRequest?>, currencyCode: String) -> some View {
        sheet(item: request) { request in
            HeroInfoSheet(
                topic: request.topic,
                figureLabel: request.figureLabel,
                currencyCode: currencyCode,
                isClosedPeriod: request.isClosedPeriod
            )
        }
    }
}
