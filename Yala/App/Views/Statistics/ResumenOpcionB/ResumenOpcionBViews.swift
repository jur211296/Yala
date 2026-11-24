//
//  ResumenOpcionBViews.swift
//  Yala
//
//  Las piezas nuevas de Estadísticas › Resumen, opción B · Decidir (Jürgen, 23-nov-2026; propuesta en
//  `docs/propuestas/estadisticas-resumen-2-3/`): la franja de salud, «Para decidir hoy», la fila «Ir a», los puntos de
//  frecuencia de los gastos hormiga y la cápsula de Registros por comercio. Lo que deciden lo calcula
//  `ResumenOpcionBLogic`; aquí solo se pinta.
//

import SwiftUI

// MARK: - Franja de salud financiera

/// La nota en una franja chata, como la tarjeta del Panel, con sus cuatro partes en barras cortas y la parte que más la
/// baja. Tocar la cabecera abre el detalle de la nota; tocar una barra, el de esa parte (las mismas hojas de siempre).
struct ResumenSaludFranja: View {
    let score: FinancialScore
    let sessionState: SessionState
    var hasBudgets: Bool = false

    @Environment(SceneNavigation.self) private var navigation
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    // A11Y-DT: el anillo crece con el tamaño del texto, como el de la tarjeta del Panel.
    @ScaledMetric(relativeTo: .title2) private var ringSize: CGFloat = 46

    @State private var presentedSheet: FinancialScoreDetailKind?

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Button {
                presentedSheet = .total
            } label: {
                header
            }
            .buttonStyle(.plain)
            // La etiqueta de siempre (la del anillo de la tarjeta completa) y, de valor, lo que más la baja.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(headerAccessibilityLabel)
            .accessibilityValue(subtitle)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(ResumenOpcionBText.Health.openHint)
            .accessibilityIdentifier("insights_health_strip")

            LazyVGrid(columns: barColumns, alignment: .leading, spacing: DS.Spacing.sm) {
                ForEach(parts, id: \.kind) { part in
                    partBar(part)
                }
            }

            // Revisión 2.3, decisión 9 (PN-2): sin nota, qué falta para tenerla; y lo que va mal y la nota no ve.
            if let missing = FinancialScoreCopy.missingLine(for: score) {
                Text(missing)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("health_missing_parts")
            }
            if let unseen = FinancialScoreCopy.unseenLine(for: score, isExpensesOnlyMode: sessionState.isExpensesOnlyMode) {
                Text(unseen)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("health_unseen")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .solidCard(padding: DS.Spacing.lg, radius: DS.Panel.widgetRadius)
        .sheet(item: $presentedSheet) { kind in
            FinancialScoreDetailSheet(
                kind: kind,
                score: value(for: kind),
                onPrimaryCTA: primaryCTA(for: kind),
                breakdown: score,
                hasBudgets: hasBudgets
            )
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: DS.Spacing.md) {
            ring
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(L10n.Panel.Health.cardTitle)
                    .font(DS.Typography.subheadlineEmphasized)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("insights_health_lowering")
            }
            .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(DS.Typography.caption)
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var headerAccessibilityLabel: String {
        let title = L10n.Panel.Health.totalSheetTitle
        guard let total = score.total else { return "\(title), \(L10n.Panel.Health.noData)" }
        return "\(title), \(L10n.Panel.Health.scoreVoiceover(score: total))"
    }

    /// «Lo que más la baja: Presupuestos»; si nada la baja (o aún no hay nota), el mensaje de la tarjeta del Panel.
    private var subtitle: String {
        if let part = ResumenSaludLogic.loweringPart(score) {
            return ResumenOpcionBText.Health.lowering(FinancialScoreCopy.partName(part))
        }
        return FinancialScoreCopy.cardMessage(for: score, isExpensesOnlyMode: sessionState.isExpensesOnlyMode)
    }

    private var ring: some View {
        ZStack {
            ScoreRingView(
                progress: (score.total.map { Double($0) / 100.0 }) ?? 0,
                size: ringSize,
                lineWidth: ringSize * 0.11,
                foreground: ringForeground
            )
            Text(score.total.map { "\($0)" } ?? L10n.Panel.Health.emptyBadge)
                .font(DS.Typography.headline)
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .foregroundStyle(score.total == nil ? DS.Semantic.disabledForeground : Color.primary)
                .padding(.horizontal, ringSize * 0.12)
        }
        .frame(width: ringSize, height: ringSize)
        .accessibilityLabel(score.total.map { L10n.Panel.Health.scoreVoiceover(score: $0) } ?? L10n.Panel.Health.noData)
    }

    /// Relleno sólido del tono de la nota, sin degradado (regla de Jürgen).
    private var ringForeground: AnyShapeStyle {
        guard let total = score.total else { return AnyShapeStyle(DS.Semantic.disabledForeground.opacity(0.4)) }
        return AnyShapeStyle(FinancialScoreTint.color(for: total))
    }

    // MARK: Partes

    private struct Part {
        let kind: FinancialScoreDetailKind
        let label: String
        let value: Int?
    }

    /// Las cuatro partes, en el orden de la tarjeta. «Lo que te queda» no cuenta en «Solo gastos».
    private var parts: [Part] {
        var list = [
            Part(kind: .budget, label: L10n.Panel.Health.subScoreBudget, value: score.budget),
            Part(kind: .activity, label: L10n.Panel.Health.subScoreActivity, value: score.activity),
            Part(kind: .bills, label: L10n.Panel.Health.subScoreBills, value: score.bills),
        ]
        if !sessionState.isExpensesOnlyMode {
            list.append(Part(kind: .savings, label: L10n.NotaSaludTeQueda.nombre, value: score.savings))
        }
        return list
    }

    /// Dos columnas; con el texto al máximo, una (los nombres no se cortan).
    private var barColumns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.flexible(), spacing: DS.Spacing.lg), GridItem(.flexible(), spacing: DS.Spacing.lg)]
    }

    private func partBar(_ part: Part) -> some View {
        Button {
            presentedSheet = part.kind
        } label: {
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                HStack(spacing: DS.Spacing.xs) {
                    Text(part.label)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                        .minimumScaleFactor(0.85)
                    Spacer(minLength: 0)
                    Text(part.value.map { "\($0)" } ?? L10n.Panel.Health.emptyBadge)
                        .font(DS.Typography.caption)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                        .foregroundStyle(part.value == nil ? DS.Semantic.disabledForeground : Color.primary)
                }
                ScoreBarTrack(value: part.value)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(part.value.map { "\(part.label), \(L10n.Panel.Health.scoreVoiceover(score: $0))" }
            ?? "\(part.label), \(L10n.Panel.Health.noData)")
        .accessibilityAddTraits(.isButton)
    }

    private func value(for kind: FinancialScoreDetailKind) -> Int? {
        switch kind {
        case .total: return score.total
        case .budget: return score.budget
        case .activity: return score.activity
        case .bills: return score.bills
        case .savings: return score.savings
        }
    }

    /// Las mismas salidas que la tarjeta completa (`FinancialScoreView`).
    private func primaryCTA(for kind: FinancialScoreDetailKind) -> (() -> Void)? {
        switch kind {
        case .total: return nil
        case .budget: return { navigation.navigateToBudgets() }
        case .activity: return { sessionState.navigateToRecordsStandalone() }
        case .bills: return { navigation.navigateToScheduledPayments() }
        case .savings: return { navigation.navigateToDetail(.categories) }
        }
    }
}

/// La barra corta de una parte: el carril mide y el relleno va en su overlay (con el relleno como hermano, la barra no
/// encogía al girar; regla del iPhone Duo en `swiftui-ds.md`).
private struct ScoreBarTrack: View {
    let value: Int?
    @State private var width: CGFloat = 0

    var body: some View {
        Capsule()
            .fill(Color.primary.opacity(0.06))
            .frame(height: 6)
            .overlay(alignment: .leading) {
                if let value {
                    Capsule()
                        .fill(FinancialScoreTint.color(for: value))
                        .frame(width: max(6, width * CGFloat(max(0, min(value, 100))) / 100), height: 6)
                }
            }
            .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { width = $0 }
            .accessibilityHidden(true)
    }
}

// MARK: - Para decidir hoy

/// Hasta tres acciones con salida (`ResumenDecidirLogic`). Sin acciones no se monta: quien la usa mira antes.
struct ResumenDecidirSeccion: View {
    let actions: [ResumenAccion]
    let onOpen: (ResumenDestino) -> Void

    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.yalaTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            YalaSectionHeader(ResumenOpcionBText.Decide.title)
            ForEach(actions) { action in
                row(action)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("insights_decide")
    }

    private func row(_ action: ResumenAccion) -> some View {
        Button {
            onOpen(action.destination)
        } label: {
            HStack(spacing: DS.Spacing.md) {
                icon(for: action)
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(title(for: action))
                        .font(DS.Typography.subheadlineEmphasized)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(detail(for: action))
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(DS.Typography.caption)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .panelCard(small: true)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(hint(for: action.destination))
        .accessibilityIdentifier(identifier(for: action))
    }

    private func icon(for action: ResumenAccion) -> some View {
        let (symbol, color): (String, Color) = switch action.kind {
        case .budgetOver: ("exclamationmark", Color.hotPink)
        case .budgetAtRisk: ("gauge.with.dots.needle.67percent", theme.accentText)
        case .toPay: ("clock", theme.accentText)
        case .spendingUp: ("arrow.up.right", theme.accentText)
        }
        return ZStack {
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: 32, height: 32)
            Image(systemName: symbol)
                .font(DS.Typography.caption)
                .fontWeight(.bold)
                .foregroundStyle(color)
        }
        .accessibilityHidden(true)
    }

    private func money(_ value: Double, _ currencyCode: String? = nil, isEstimate: Bool = false) -> String {
        appPreferences.currency(
            value, currencyCode: currencyCode ?? appPreferences.defaultCurrencyCode.rawValue, isEstimate: isEstimate)
    }

    private func title(for action: ResumenAccion) -> String {
        switch action.kind {
        case .budgetOver(let name):
            return ResumenOpcionBText.Decide.budgetOverTitle(name)
        case .budgetAtRisk(let name):
            return ResumenOpcionBText.Decide.budgetAtRiskTitle(name, percent: L10n.UXL11D.percent(action.percent))
        case .toPay:
            return ResumenOpcionBText.Decide.toPayTitle(money(action.amount))
        case .spendingUp:
            return ResumenOpcionBText.Decide.spendingUpTitle(L10n.UXL11D.percent(action.percent))
        }
    }

    private func detail(for action: ResumenAccion) -> String {
        let until = action.until.map { ResumenOpcionBText.day($0) }
        switch action.kind {
        case .budgetOver:
            let currency = action.budget?.currencyCode
            return ResumenOpcionBText.Decide.budgetOverDetail(amount: money(action.amount, currency), until: until ?? "")
        case .budgetAtRisk:
            let currency = action.budget?.currencyCode
            if let perDay = action.budget?.perDay {
                return ResumenOpcionBText.Decide.budgetPerDay(
                    remaining: money(action.amount, currency), perDay: money(perDay, currency), until: until ?? "")
            }
            return ResumenOpcionBText.Decide.budgetSpent(until: until ?? "")
        case .toPay:
            if let until {
                return ResumenOpcionBText.Decide.toPayDetail(count: action.count, until: until)
            }
            return ResumenOpcionBText.Decide.toPayCount(action.count)
        case .spendingUp:
            // La misma marca «≈» que el «Promedio diario» de «Tus cifras»: es el mismo número.
            return ResumenOpcionBText.Decide.spendingUpDetail(money(action.amount, isEstimate: action.isApproximate))
        }
    }

    private func hint(for destination: ResumenDestino) -> String {
        switch destination {
        case .budgets: return ResumenOpcionBText.Decide.openBudgetsHint
        case .scheduledPayments: return ResumenOpcionBText.Decide.openPaymentsHint
        case .trends: return ResumenOpcionBText.Decide.openTrendsHint
        }
    }

    private func identifier(for action: ResumenAccion) -> String {
        switch action.kind {
        case .budgetOver: return "insights_decide_budget_over"
        case .budgetAtRisk: return "insights_decide_budget_risk"
        case .toPay: return "insights_decide_to_pay"
        case .spendingUp: return "insights_decide_spending_up"
        }
    }
}

// MARK: - Ir a

enum ResumenIrADestino: CaseIterable {
    case distribution, trends, records, budgets

    var title: String {
        switch self {
        case .distribution: return DetailViewTab.categories.title
        case .trends: return DetailViewTab.trends.title
        case .records: return DetailViewTab.records.title
        case .budgets: return L10n.Panel.Health.subScoreBudget
        }
    }

    var icon: String {
        switch self {
        case .distribution: return DetailViewTab.categories.icon
        case .trends: return DetailViewTab.trends.icon
        case .records: return DetailViewTab.records.icon
        case .budgets: return "chart.bar.doc.horizontal"
        }
    }

    var identifier: String {
        switch self {
        case .distribution: return "insights_goto_distribution"
        case .trends: return "insights_goto_trends"
        case .records: return "insights_goto_records"
        case .budgets: return "insights_goto_budgets"
        }
    }
}

/// Accesos fijos a Distribución, Tendencias, Registros y Presupuestos. Comparativa no: vive en Informes.
struct ResumenIrA: View {
    let onSelect: (ResumenIrADestino) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.yalaTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            YalaSectionHeader(ResumenOpcionBText.GoTo.title)
            LazyVGrid(columns: columns, spacing: DS.Spacing.sm) {
                ForEach(ResumenIrADestino.allCases, id: \.self) { destination in
                    Button {
                        onSelect(destination)
                    } label: {
                        VStack(spacing: DS.Spacing.xs) {
                            Image(systemName: destination.icon)
                                .font(DS.Typography.body)
                                .foregroundStyle(theme.accentText)
                                .accessibilityHidden(true)
                            Text(destination.title)
                                .font(DS.Typography.captionSmall)
                                .foregroundStyle(.primary)
                                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .padding(.vertical, DS.Spacing.sm)
                        .contentShape(Rectangle())
                        .panelCard(small: true)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(destination.identifier)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Cuatro en fila; con el texto al máximo, dos por fila.
    private var columns: [GridItem] {
        let count = dynamicTypeSize.isAccessibilitySize ? 2 : 4
        return Array(repeating: GridItem(.flexible(), spacing: DS.Spacing.sm), count: count)
    }
}

// MARK: - Frecuencia de un gasto hormiga

/// Un punto por compra, hasta doce; más, «+N». Solo dibujo: la fila dice las veces en su etiqueta.
struct AntFrequencyDots: View {
    let count: Int
    static let maxDots = 12

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<min(count, Self.maxDots), id: \.self) { _ in
                Circle()
                    .fill(Color.orange)
                    .frame(width: 6, height: 6)
            }
            if count > Self.maxDots {
                Text(verbatim: "+\(count - Self.maxDots)")
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Registros por comercio

/// «Solo Starbucks ✕» encima de la lista de Registros de Estadísticas. La ✕ quita el filtro.
struct RecordsMerchantFilterChip: View {
    let filter: RecordsMerchantFilter
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: "ant.fill")
                .font(DS.Typography.captionSmall)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(ResumenOpcionBText.Records.only(filter.label))
                .font(DS.Typography.labelSmall)
                .foregroundStyle(.primary)
                .lineLimit(1)
            Button(action: onClear) {
                Image(systemName: "xmark")
                    .font(DS.Typography.captionSmall)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(ResumenOpcionBText.Records.clear(filter.label))
            .accessibilityIdentifier("records_merchant_filter_clear")
        }
        .padding(.leading, DS.Spacing.md)
        .background(.thCard, in: Capsule())
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("records_merchant_filter")
    }
}
