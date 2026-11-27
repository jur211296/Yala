//
//  CompartidoPersonDetailPieces.swift
//  Yala
//
//  Las piezas del detalle de una persona (lote 2 de Compartido, 26-nov-2026): la cápsula del filtro de grupo, la cifra
//  grande con ella al lado del rótulo, la tarjeta de «Saldar todo» con su desglose y «Por grupo» de Estadísticas. Copian
//  lo que ya hay en el detalle de grupo (`GroupBalanceHero`, la tarjeta de «Para quedar a mano», la cápsula de
//  Estadísticas); lo nuevo es el filtro y el desglose.
//

import SwiftUI

// MARK: - Filtro de grupo

/// La cápsula del filtro: la de Estadísticas del grupo («Todas», «Todo»), con «Todos los grupos · <grupos> · Sin grupo».
struct CompartidoGroupFilterMenu: View {
    let options: [CompartidoPersonDetailLogic.Filter]
    @Binding var selection: CompartidoPersonDetailLogic.Filter
    let label: (CompartidoPersonDetailLogic.Filter) -> String

    var body: some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button {
                    DS.Haptic.selection()
                    selection = option
                } label: {
                    HStack {
                        Text(label(option))
                        if option == selection {
                            Image(systemName: "checkmark").accessibilityHidden(true)
                        }
                    }
                }
            }
        } label: {
            PeriodSelectorLabel(title: label(selection), icon: nil)
        }
        .accessibilityLabel(L10n.Compartido.Detail.filterLabel)
        .accessibilityValue(label(selection))
        .accessibilityIdentifier("compartido_detail_filter")
    }
}

// MARK: - Cifra grande

/// La cifra de arriba del detalle de persona, en la maqueta de `GroupBalanceHero` (rótulo, cifra de 36 pt, línea
/// debajo), con el filtro de grupo a la derecha del rótulo, donde Estadísticas lleva el período.
struct CompartidoPersonHero: View {
    let personName: String
    let hero: CompartidoPersonDetailLogic.Hero
    let filter: CompartidoPersonDetailLogic.Filter
    /// El nombre del grupo elegido en el filtro (para «En Viaje a Cusco te deben»).
    let filterGroupName: String
    /// Las monedas que llevan «≈» (`CompartidoPersonDetailLogic.estimatedCurrencies`).
    var estimatedCurrencies: Set<String> = []
    /// En un grupo te debe y en otro le debes: sin la frase de «nada» (ver `hasOpposingGroups`).
    var hasOpposingGroups = false
    let filterMenu: CompartidoGroupFilterMenu
    /// Tocar la cifra lleva a Saldos (desde Gastos). `nil`: no se toca.
    var onTap: (() -> Void)?

    @Environment(AppPreferences.self) private var appPreferences

    var body: some View {
        HeroHeader {
            if let onTap {
                Button(action: onTap) { HeroHeaderLabel(text: caption) }
                    .buttonStyle(.plain)
                    .accessibilityHint(L10n.Groups.Detail.balances)
            } else {
                HeroHeaderLabel(text: caption)
            }
        } period: {
            filterMenu
        } content: {
            if let main = mainAmount {
                AmountText(
                    value: main.amount,
                    currencyCode: main.currencyCode,
                    font: DS.Typography.panelHeroAmount,
                    secondaryFont: DS.Typography.panelHeroAmountSecondary,
                    tint: .primary,
                    isEstimate: estimatedCurrencies.contains(main.currencyCode),
                    forceFullPrecision: true,
                    animatesValue: true
                )
                .accessibilityIdentifier("compartido_detail_amount")
            }
            if let line = detailLine {
                Text(line)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("compartido_detail_hero")
    }

    private var isOwedSide: Bool { !hero.owedToMe.isEmpty }

    private var mainAmount: GroupBalancesPresentationLogic.CurrencyAmount? {
        (isOwedSide ? hero.owedToMe : hero.iOwe).first
    }

    private var caption: String {
        switch filter {
        case .group:
            return L10n.Compartido.Detail.heroIn(filterGroupName, owed: isOwedSide, settled: hero.isSettled)
        case .all, .noGroup:
            return L10n.Compartido.Detail.heroWith(personName, owed: isOwedSide, settled: hero.isSettled)
        }
    }

    /// «+ $ 40.00 · Tú no le debes nada.»: las otras monedas del lado de la cifra y, después, la frase.
    private var detailLine: String? {
        var parts: [String] = []
        let side = isOwedSide ? hero.owedToMe : hero.iOwe
        let rest = side.dropFirst().map(formatted)
        if !rest.isEmpty { parts.append("+ " + rest.joined(separator: " + ")) }
        if let sentence { parts.append(sentence) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var sentence: String? {
        if hero.isSettled { return filterSentence }
        if isOwedSide, !hero.iOwe.isEmpty {
            return L10n.Compartido.Detail.alsoYouOwe(hero.iOwe.map(formatted).joined(separator: " + "))
        }
        if let filterSentence { return filterSentence }
        if hasOpposingGroups { return nil }
        return isOwedSide ? L10n.Compartido.Detail.youOweNothing : L10n.Compartido.Detail.theyOweNothing
    }

    private var filterSentence: String? {
        switch filter {
        case .all: nil
        case .group: L10n.Compartido.Detail.onlyThisGroup
        case .noGroup: L10n.Compartido.Detail.onlyNoGroup
        }
    }

    private func formatted(_ amount: GroupBalancesPresentationLogic.CurrencyAmount) -> String {
        appPreferences.currency(
            amount.amount, currencyCode: amount.currencyCode, isEstimate: estimatedCurrencies.contains(amount.currencyCode))
    }
}

// MARK: - Saldar todo

/// «Para quedar a mano» con «Todos los grupos» y más de un grupo: una tarjeta con lo de la persona, «Saldar todo» y el
/// desglose por grupo debajo de la cifra (riesgo de la maqueta: si alguien espera un solo pago, tiene que ver que son
/// varios). La tarjeta y el botón son los de `GroupBalancesView`.
struct CompartidoSettleAllCard: View {
    let personName: String
    let personKey: String
    let hero: CompartidoPersonDetailLogic.Hero
    let breakdown: [CompartidoPersonDetailLogic.BreakdownRow]
    /// Las monedas del total que llevan «≈»; cada fila del desglose lleva la suya.
    var estimatedCurrencies: Set<String> = []
    /// `nil`: no hay nada que se pueda saldar desde aquí (grupo archivado o congelado).
    var onSettleAll: (() -> Void)?

    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            YalaSectionHeader(L10n.UXL13.settleUpTitle)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                pairLabel
                HStack(alignment: .firstTextBaseline) {
                    Text(amountsText)
                        .font(DS.Typography.headline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: DS.Spacing.sm)
                    if let onSettleAll {
                        Button(action: onSettleAll) { settleLabel }
                            .buttonStyle(.plain)
                            .accessibilityHint(L10n.Compartido.Detail.settleAllNote)
                            .accessibilityIdentifier("compartido_settle_all")
                    }
                }
                breakdownRows
                Text(L10n.Compartido.Detail.settleAllNote)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .panelCard()
        }
    }

    /// «Beto te paga» o «Tú pagas a Beto», con el sentido de la cifra grande.
    private var pairLabel: some View {
        HStack(spacing: DS.Spacing.sm) {
            if hero.owedToMe.isEmpty {
                Text(L10n.UXL13.youPayTo)
                    .font(DS.Typography.subheadlineEmphasized)
                CompartidoPersonAvatar(name: personName, seed: personKey)
                Text(personName)
                    .font(DS.Typography.subheadlineEmphasized)
                    .lineLimit(1)
            } else {
                CompartidoPersonAvatar(name: personName, seed: personKey)
                Text(personName)
                    .font(DS.Typography.subheadlineEmphasized)
                    .lineLimit(1)
                Text(L10n.GroupsNecesarias06.paysYou)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var amountsText: String {
        let side = hero.owedToMe.isEmpty ? hero.iOwe : hero.owedToMe
        return side.map {
            appPreferences.currency(
                $0.amount, currencyCode: $0.currencyCode, isEstimate: estimatedCurrencies.contains($0.currencyCode))
        }
        .joined(separator: " + ")
    }

    /// El desglose: un grupo por línea, con lo que te debe o le debes en ese grupo.
    private var breakdownRows: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            ForEach(breakdown) { row in
                AdaptiveRowStack(spacing: DS.Spacing.sm, stackedSpacing: DS.Spacing.xxs) {
                    Text(row.groupName)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } trailing: {
                    Text(CompartidoAmountText.signed(row.netCents, appPreferences: appPreferences, isEstimate: row.isEstimate))
                        .font(DS.Typography.subheadlineEmphasized)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("compartido_settle_breakdown_row")
            }
        }
        .padding(.top, DS.Spacing.xxs)
    }

    private var settleLabel: some View {
        Text(L10n.Compartido.Detail.settleAll)
            .font(DS.Typography.subheadlineEmphasized)
            .foregroundStyle(theme.onAccent)
            .padding(.horizontal, DS.Spacing.lg)
            .frame(minHeight: 44)
            .background(theme.accent, in: Capsule())
            .contentShape(Capsule())
    }
}

/// Los importes de un grupo en una frase: «te debe S/ 110.00 + $ 40.00», y lo que le debes aparte.
enum CompartidoAmountText {
    @MainActor
    static func signed(_ cents: [String: Int], appPreferences: AppPreferences, isEstimate: Bool) -> String {
        let sorted = cents.sorted { $0.key < $1.key }
        let owed = sorted.filter { $0.value > 0 }.map {
            appPreferences.currency(Double($0.value) / 100, currencyCode: $0.key, isEstimate: isEstimate)
        }
        let owe = sorted.filter { $0.value < 0 }.map {
            appPreferences.currency(Double(-$0.value) / 100, currencyCode: $0.key, isEstimate: isEstimate)
        }
        var parts: [String] = []
        if !owed.isEmpty { parts.append(L10n.Compartido.Detail.statsTheyOwe(owed.joined(separator: " + "))) }
        if !owe.isEmpty { parts.append(L10n.Compartido.Detail.statsYouOwe(owe.joined(separator: " + "))) }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Por grupo (Estadísticas)

/// «Por grupo»: cuánto te debe (o le debes) en cada grupo compartido, con una barra proporcional.
struct CompartidoByGroupSection: View {
    let rows: [CompartidoPersonDetailLogic.ByGroupRow]
    /// El color de cada grupo; `nil` para lo sin grupo (gris).
    let colorHex: (String) -> String?

    @Environment(AppPreferences.self) private var appPreferences
    @ScaledMetric(relativeTo: .caption) private var barHeight: CGFloat = 8 // A11Y-DT: @ScaledMetric

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            YalaSectionHeader(L10n.Compartido.Detail.statsByGroup)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                ForEach(rows) { row in
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        AdaptiveRowStack(spacing: DS.Spacing.sm, stackedSpacing: DS.Spacing.xxs) {
                            Text(row.groupName)
                                .font(DS.Typography.subheadline)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                        } trailing: {
                            Text(CompartidoAmountText.signed(
                                row.netCents, appPreferences: appPreferences, isEstimate: row.isEstimate))
                                .font(DS.Typography.subheadlineEmphasized)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        bar(row)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("compartido_by_group_row")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .panelCard()
        }
    }

    /// El relleno va en el `overlay` del carril, no a su lado: medido sobre el carril, nunca lo ensancha (regla del Duo
    /// en `swiftui-ds.md`).
    private func bar(_ row: CompartidoPersonDetailLogic.ByGroupRow) -> some View {
        Capsule()
            .fill(Color(.tertiarySystemFill))
            .frame(height: barHeight)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(colorHex(row.groupKey).map { Color(hex: $0) } ?? Color(.systemGray3))
                        .frame(width: max(proxy.size.width * row.fraction, row.fraction > 0 ? barHeight : 0))
                }
            }
            .accessibilityHidden(true)
    }
}

// MARK: - Empuje desde la lista

extension View {
    /// Empuja el detalle de la persona abierta desde su tarjeta (lote 2). En ventana ancha va en la columna de detalle,
    /// como un grupo. `onClosed`: al volver, la lista recarga (como al cerrar un grupo).
    func compartidoPersonDestination(
        person: Binding<CompartidoPersonasLogic.Person?>, isWide: Bool, onClosed: @escaping () -> Void
    ) -> some View {
        modifier(CompartidoPersonDestination(person: person, isWide: isWide, onClosed: onClosed))
    }
}

private struct CompartidoPersonDestination: ViewModifier {
    @Binding var person: CompartidoPersonasLogic.Person?
    let isWide: Bool
    let onClosed: () -> Void

    func body(content: Content) -> some View {
        content
            .navigationDestination(item: $person) { opened in
                CompartidoPersonDetailView(
                    person: opened,
                    presentation: isWide ? .column : .pushed,
                    onCloseColumn: { person = nil })
                .announcesShownInDetailColumn()
                // Otra persona es otra vista: sin esto, en la columna de detalle SwiftUI reusaría el `@State` de la
                // anterior (regla de `swiftui-ds.md`, «Lo que se abre en la columna de detalle lleva `.id`»).
                .id(opened.id)
            }
            .onChange(of: person) { _, newValue in
                if newValue == nil { onClosed() }
            }
    }
}
