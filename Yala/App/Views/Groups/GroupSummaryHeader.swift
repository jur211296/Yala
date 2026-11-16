//
//  GroupSummaryHeader.swift
//  Yala
//
//  Resumen global de la lista de grupos (propuesta 2 de Jürgen, 2026-11-03, sobre `docs/disenos/grupos-cabecera-2-2/`):
//
//  - Arriba, la cifra grande: el neto en tu moneda principal, en el color de quien va a favor («Debes en total · en S/»
//    en el rosa de marca, «Te deben en total · en S/» en verde, «Estás a mano» sin color). Solo en Yala completo: en solo
//    grupos no hay moneda principal que elegir y la cabecera empieza en la barra.
//  - Una barra que reparte lo que debes (rosa, a la izquierda) y lo que te deben (verde), las dos partes pasadas a la
//    moneda principal. Rellenos sólidos: nada de degradados ni brillos.
//  - Debajo, «Debes» a la izquierda y «Te deben» a la derecha, cada uno con una línea por divisa: como mucho tres, y
//    con cuatro o más, las dos mayores y «y N más». Un lado vacío dice «0.00» en gris.
//
//  El global NO se netea por divisa (se debe a personas distintas en grupos distintos): cada lado lleva sus divisas.
//  El neto en la moneda principal es solo presentación (`GroupsListBalanceLogic`).
//

import SwiftUI

struct GroupSummaryHeader: View {

    let summary: GroupGlobalSummary
    /// Yala completo: la cifra grande con el neto en la moneda principal. `false` en solo grupos.
    var showsNetInMainCurrency = false

    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var mainCurrency: String { appPreferences.defaultCurrencyCode.rawValue }

    /// La cifra del neto crece con el texto de accesibilidad, con techo (pase de estrés 2.2, card ysol). Con los 36 pt
    /// fijos de `panelHeroAmount`, a AX5 las líneas de «Debes / Te deben» (`headline`) salían mayores que el neto y la
    /// jerarquía se invertía. A tamaño normal y hasta xxxLarge sigue siendo el token de siempre.
    @ScaledMetric(relativeTo: .largeTitle) private var scaledNetSize: CGFloat = 36
    /// Techo del neto: el `largeTitle` de AX5. Con `minimumScaleFactor(0.6)` nunca baja de 36 pt, por encima de las
    /// líneas de cada lado, topadas en `sidesMaxTypeSize` (33 pt).
    private static let netMaxSize: CGFloat = 60
    /// Rótulo del neto y líneas de cada lado dejan de crecer en AX2: son detalle de la cifra, no compiten con ella.
    private static let sidesMaxTypeSize = DynamicTypeSize.accessibility2

    private var netFont: Font {
        guard dynamicTypeSize.isAccessibilitySize else { return DS.Typography.panelHeroAmount }
        // A11Y-DT: tamaño escalado a mano con techo; el token es fijo a propósito y aquí tiene que crecer.
        return .system(size: min(scaledNetSize, Self.netMaxSize), weight: .semibold)
    }

    var body: some View {
        let iOwe = summary.totalIOwe.filter { $0.value > 0.01 }
        let owedToMe = summary.totalOwedToMe.filter { $0.value > 0.01 }
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            if iOwe.isEmpty && owedToMe.isEmpty {
                HeroHeaderLabel(text: L10n.Groups.Summary.allSettled)
                    .accessibilityIdentifier("groups_hero_settled")
            } else {
                if showsNetInMainCurrency, let net = netInMainCurrency {
                    netFigure(net)
                }
                bar(iOwe: iOwe, owedToMe: owedToMe)
                sides(iOwe: iOwe, owedToMe: owedToMe)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("groups_balance_hero")
    }

    // MARK: - Piezas

    private func netFigure(_ net: GroupsListBalanceLogic.Net) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            HeroHeaderLabel(text: GroupsListBalanceLogic.netCaption(
                net.direction, currencySymbol: appPreferences.currencyIdentifier(for: net.currencyCode)))
                .dynamicTypeSize(...Self.sidesMaxTypeSize)
            Text(formatted(net.amount, net.currencyCode, isEstimate: net.isEstimate))
                .font(netFont)
                .foregroundStyle(Self.netColor(net.direction))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("groups_hero_net")
    }

    /// Lo que debes (izquierda) y lo que te deben (derecha), en proporción a lo que pesa cada lado en la moneda
    /// principal. Con un solo lado, la barra entera es de ese color.
    private func bar(iOwe: [String: Double], owedToMe: [String: Double]) -> some View {
        let converter = CurrencyConverter.shared
        let share = GroupsListBalanceLogic.oweShare(
            iOweInMain: GroupsListBalanceLogic.total(iOwe, mainCurrency: mainCurrency, converter: converter),
            owedInMain: GroupsListBalanceLogic.total(owedToMe, mainCurrency: mainCurrency, converter: converter)
        ) ?? 0.5
        let both = !iOwe.isEmpty && !owedToMe.isEmpty
        return GeometryReader { proxy in
            let gap: CGFloat = both ? DS.Spacing.xs : 0
            let width = max(0, proxy.size.width - gap)
            HStack(spacing: gap) {
                if !iOwe.isEmpty {
                    Capsule()
                        .fill(Color.groupOweAmount)
                        .frame(width: both ? width * share : width)
                }
                if !owedToMe.isEmpty {
                    Capsule().fill(Color.groupOwedAmount)
                }
            }
        }
        .frame(height: DS.Spacing.sm + DS.Spacing.xxs)
        .accessibilityHidden(true)
        .accessibilityIdentifier("groups_hero_bar")
    }

    @ViewBuilder
    private func sides(iOwe: [String: Double], owedToMe: [String: Double]) -> some View {
        let owe = side(label: L10n.Groups.Summary.iOwe, systemImage: "arrow.up.right", byCurrency: iOwe,
                       color: .groupOweAmount, alignment: .leading, identifier: "groups_hero_iowe")
        let owed = side(label: L10n.Groups.Summary.owedToMe, systemImage: "arrow.down.left", byCurrency: owedToMe,
                        color: .groupOwedAmount, alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing,
                        identifier: "groups_hero_owed")
        if dynamicTypeSize.isAccessibilitySize {
            // A tamaños de accesibilidad los dos lados no caben a lo ancho: uno debajo del otro, y topados para que el
            // neto siga siendo lo mayor de la cabecera.
            VStack(alignment: .leading, spacing: DS.Spacing.md) { owe; owed }
                .dynamicTypeSize(...Self.sidesMaxTypeSize)
        } else {
            HStack(alignment: .top) {
                owe
                Spacer(minLength: DS.Spacing.md)
                owed
            }
        }
    }

    private func side(
        label: String,
        systemImage: String,
        byCurrency: [String: Double],
        color: Color,
        alignment: HorizontalAlignment,
        identifier: String
    ) -> some View {
        let lines = GroupsListBalanceLogic.sideLines(byCurrency, mainCurrency: mainCurrency,
                                                    converter: CurrencyConverter.shared)
        return VStack(alignment: alignment, spacing: DS.Spacing.xxs) {
            HStack(spacing: DS.Spacing.xs) {
                if alignment == .trailing {
                    Text(label).foregroundStyle(.secondary)
                    Image(systemName: systemImage).foregroundStyle(color).accessibilityHidden(true)
                } else {
                    Image(systemName: systemImage).foregroundStyle(color).accessibilityHidden(true)
                    Text(label).foregroundStyle(.secondary)
                }
            }
            .font(DS.Typography.subheadline)
            if lines.shown.isEmpty {
                Text(formatted(0, mainCurrency))
                    .font(DS.Typography.headline)
                    // Gris secundario, no terciario: en terciario el lado vacío medía 1,7:1 en claro y casi se borraba.
                    .foregroundStyle(.secondary)
            }
            ForEach(lines.shown, id: \.currencyCode) { item in
                Text(formatted(item.amount, item.currencyCode))
                    .font(DS.Typography.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            if lines.hiddenCount > 0 {
                Text(L10n.Groups.Card.andMore(lines.hiddenCount))
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }

    // MARK: - Datos

    private var netInMainCurrency: GroupsListBalanceLogic.Net? {
        GroupsListBalanceLogic.net(
            owedToMe: summary.totalOwedToMe,
            iOwe: summary.totalIOwe,
            mainCurrency: mainCurrency,
            converter: CurrencyConverter.shared
        )
    }

    static func netColor(_ direction: GroupsListBalanceLogic.NetDirection) -> Color {
        switch direction {
        case .iOwe: .groupOweAmount
        case .owedToMe: .groupOwedAmount
        case .even: .primary
        }
    }

    private func formatted(_ amount: Double, _ currencyCode: String, isEstimate: Bool = false) -> String {
        appPreferences.currency(amount, currencyCode: currencyCode, forceFullPrecision: true, isEstimate: isEstimate)
    }

    /// Las divisas de un lado con algo pendiente, por código (el orden de siempre del resumen).
    static func amounts(_ byCurrency: [String: Double]) -> [GroupBalancesPresentationLogic.CurrencyAmount] {
        byCurrency
            .filter { $0.value > 0.01 }
            .sorted { $0.key < $1.key }
            .map { GroupBalancesPresentationLogic.CurrencyAmount(currencyCode: $0.key, amount: $0.value) }
    }
}

/// L19-9 · «+ S/ 190.00 y $ 46.67 que te deben en grupos archivados», bajo el total de la lista. Archivar ordena la
/// lista, no salda nada: sin esta línea «Te deben» bajaba al archivar como si te hubieran pagado. Sin nada pendiente
/// en los archivados no pinta nada.
struct ArchivedDebtLine: View {
    @Environment(AppPreferences.self) private var appPreferences

    let summary: GroupGlobalSummary

    private func amounts(_ byCurrency: [String: Double]) -> String? {
        let items = byCurrency
            .filter { $0.value > 0.01 }
            .sorted { $0.key < $1.key }
            .map { appPreferences.currency($0.value, currencyCode: $0.key) }
        return items.isEmpty ? nil : GroupDebtCopyLogic.joined(items)
    }

    var body: some View {
        let owed = amounts(summary.totalOwedToMe)
        let owe = amounts(summary.totalIOwe)
        if owed != nil || owe != nil {
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                if let owed {
                    Text(L10n.UXL19.archivedOwedLine(owed))
                }
                if let owe {
                    Text(L10n.UXL19.archivedOweLine(owe))
                }
            }
            .font(DS.Typography.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("groups_archived_debt_line")
        }
    }
}
