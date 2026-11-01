//
//  BudgetsWidget.swift
//  YalaWidgets
//
//  Widget showing budget progress.
//  Medium: top 3 budgets sorted by usage. Large: top 6 (más filas, mismo diseño de fila).
//  Configurable: selection mode (auto/custom).
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Configuration Intent

struct BudgetsWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "widget.intent.budgets.title" }
    static var description: IntentDescription { "widget.intent.budgets.desc" }

    @Parameter(title: "widget.selection.mode.type", default: .automatic)
    var selectionMode: SelectionModeOption

    @Parameter(title: "widget.select.budgets")
    var selectedBudgets: [BudgetAppEntity]?

    static var parameterSummary: some ParameterSummary {
        When(\BudgetsWidgetIntent.$selectionMode, .equalTo, .custom) {
            Summary {
                \BudgetsWidgetIntent.$selectionMode
                \BudgetsWidgetIntent.$selectedBudgets
            }
        } otherwise: {
            Summary {
                \BudgetsWidgetIntent.$selectionMode
            }
        }
    }
}

// MARK: - Timeline Entry

struct BudgetsEntry: TimelineEntry {
    let date: Date
    let budgets: [WidgetBudget]
    let currencyDisplayFormat: String
    let isPlaceholder: Bool
    /// La persona no tiene ningún presupuesto activo: el widget invita a crear uno (UX 2.2 · L15-2). Con default para
    /// el placeholder, que trae ejemplos.
    var hasNoBudgets: Bool = false
    /// Cuándo escribió la app la foto: lo gastado es de esa hora, y la marca del ritmo se mide a la misma.
    var lastUpdated: Date? = nil
    /// Cuántos presupuestos activos se pasaron, de TODOS (no solo los que caben en este tamaño o los elegidos).
    var exceededCount: Int = 0

    static var placeholder: BudgetsEntry {
        BudgetsEntry(
            date: Date(),
            budgets: [
                WidgetBudget(
                    id: "1",
                    name: "Alimentación",
                    limitAmount: 800,
                    spentAmount: 720,
                    currencyCode: "PEN",
                    periodType: "monthly",
                    percentUsed: 90,
                    iconName: "fork.knife",
                    colorHex: "#FF6B6B"
                ),
                WidgetBudget(
                    id: "2",
                    name: "Entretenimiento",
                    limitAmount: 300,
                    spentAmount: 180,
                    currencyCode: "PEN",
                    periodType: "monthly",
                    percentUsed: 60,
                    iconName: "gamecontroller.fill",
                    colorHex: "#45B7D1"
                ),
                WidgetBudget(
                    id: "3",
                    name: "Transporte",
                    limitAmount: 400,
                    spentAmount: 120,
                    currencyCode: "PEN",
                    periodType: "monthly",
                    percentUsed: 30,
                    iconName: "car.fill",
                    colorHex: "#4ECDC4"
                ),
                WidgetBudget(
                    id: "4",
                    name: "Salud",
                    limitAmount: 250,
                    spentAmount: 60,
                    currencyCode: "PEN",
                    periodType: "monthly",
                    percentUsed: 24,
                    iconName: "heart.fill",
                    colorHex: "#EF4444"
                ),
                WidgetBudget(
                    id: "5",
                    name: "Hogar",
                    limitAmount: 600,
                    spentAmount: 120,
                    currencyCode: "PEN",
                    periodType: "monthly",
                    percentUsed: 20,
                    iconName: "house.fill",
                    colorHex: "#10B981"
                ),
                WidgetBudget(
                    id: "6",
                    name: "Educación",
                    limitAmount: 500,
                    spentAmount: 50,
                    currencyCode: "PEN",
                    periodType: "monthly",
                    percentUsed: 10,
                    iconName: "book.fill",
                    colorHex: "#8B5CF6"
                )
            ],
            currencyDisplayFormat: "symbol",
            isPlaceholder: true
        )
    }
}

// MARK: - Timeline Provider

struct BudgetsWidgetProvider: AppIntentTimelineProvider {
    typealias Entry = BudgetsEntry
    typealias Intent = BudgetsWidgetIntent

    func placeholder(in context: Context) -> BudgetsEntry {
        .placeholder
    }

    func snapshot(for configuration: BudgetsWidgetIntent, in context: Context) async -> BudgetsEntry {
        if context.isPreview {
            return .placeholder
        }
        return createEntry(for: configuration, family: context.family)
    }

    func timeline(for configuration: BudgetsWidgetIntent, in context: Context) async -> Timeline<BudgetsEntry> {
        let entry = createEntry(for: configuration, family: context.family)
        // A medianoche se mueve la marca del ritmo; los gastos nuevos llegan antes, cuando la app guarda.
        return Timeline(entries: [entry], policy: .after(WidgetRefresh.nextDate(after: entry.date)))
    }

    /// Cuántas filas caben por tamaño. El grande dobla el mediano: misma fila, el doble de alto.
    static func budgetLimit(for family: WidgetFamily) -> Int {
        family == .systemLarge ? 6 : 3
    }

    private func createEntry(for configuration: BudgetsWidgetIntent, family: WidgetFamily) -> BudgetsEntry {
        let limit = Self.budgetLimit(for: family)
        let budgets: [WidgetBudget]

        // Lo elegido a mano que ya no existe no deja el widget diciendo «no hay»: vuelve a los más usados
        // (UX 2.2 · L15-2, `WidgetSelectionFallback`).
        let allBudgets = WidgetDataService.getBudgets(sortByCritical: true)
        let selectedIDs = configuration.selectionMode == .custom
            ? (configuration.selectedBudgets ?? []).map(\.id)
            : []
        budgets = WidgetSelectionFallback.resolve(
            selectedIDs: selectedIDs,
            available: allBudgets,
            automatic: allBudgets,
            id: \.id,
            limit: limit
        )

        let displayFormat = WidgetDataService.getCurrencyDisplayFormat()

        return BudgetsEntry(
            date: Date(),
            budgets: budgets,
            currencyDisplayFormat: displayFormat,
            isPlaceholder: false,
            hasNoBudgets: allBudgets.isEmpty,
            lastUpdated: WidgetDataService.getLastUpdated(),
            exceededCount: allBudgets.filter {
                WidgetInsightsLogic.budgetIsOver(limit: $0.limitAmount, spent: $0.spentAmount)
            }.count
        )
    }
}

// MARK: - Widget View

struct BudgetsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: BudgetsEntry

    private var isLarge: Bool { family == .systemLarge }

    var body: some View {
        VStack(alignment: .leading, spacing: isLarge ? WidgetDS.Spacing.md : WidgetDS.Spacing.sm) {
            WidgetCardHeader(
                title: String(localized: "widget.ui.budgets", bundle: .main),
                systemImage: "chart.pie.fill",
                tint: WidgetColors.electricIndigo
            ) {
                if let exceeded = exceededText {
                    Text(exceeded)
                        .font(WidgetDS.Typography.indicator)
                        .foregroundStyle(WidgetColors.alertText)
                        .lineLimit(1)
                }
            }

            if entry.hasNoBudgets {
                Spacer(minLength: 0)
                WidgetCreateFirstView(icon: "chart.pie", message: "widget.empty.noBudgetsYet")
                Spacer(minLength: 0)
            } else if entry.budgets.isEmpty {
                Spacer(minLength: 0)
                Text("widget.ui.noBudgets", bundle: .main)
                    .font(WidgetDS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                Spacer(minLength: 0)
            } else {
                // El provider ya recortó a lo que cabe; las filas reparten el alto.
                let rows = Array(entry.budgets.prefix(BudgetsWidgetProvider.budgetLimit(for: family)))
                VStack(alignment: .leading, spacing: WidgetDS.Spacing.none) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, budget in
                        if index > 0 { Spacer(minLength: isLarge ? WidgetDS.Spacing.sm : WidgetDS.Spacing.xs) }
                        BudgetRowView(
                            budget: budget,
                            displayFormat: entry.currencyDisplayFormat,
                            asOf: entry.lastUpdated ?? entry.date,
                            isLarge: isLarge
                        )
                    }
                    if isLarge {
                        Spacer(minLength: WidgetDS.Spacing.sm)
                        WidgetFreshnessNote(lastUpdated: entry.lastUpdated, now: entry.date)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(WidgetURLHelper.url(for: entry.hasNoBudgets ? WidgetDeepLink.newBudget : "budgets"))
    }

    /// «1 se pasó» / «2 se pasaron», de todos los presupuestos activos aunque no quepan en este tamaño.
    private var exceededText: String? {
        let count = entry.exceededCount
        guard count > 0 else { return nil }
        return count == 1
            ? String(localized: "widget.budgets.exceeded.one", bundle: .main)
            : String(format: String(localized: "widget.budgets.exceeded.other", bundle: .main), count)
    }
}

// MARK: - Budget Row

/// La fila de presupuesto de la app (`BudgetWidgetRow` del Panel): insignia sólida con su color, «Te quedan / Te
/// pasaste por» con la cifra, y la barra índigo (rosa al pasarse) con la marca de cuánto del período ya pasó.
struct BudgetRowView: View {
    let budget: WidgetBudget
    let displayFormat: String
    /// La hora de lo gastado (la de la foto): la marca del ritmo se mide a esa hora, no a la de ahora.
    var asOf: Date = Date()
    var isLarge: Bool = false

    private var remaining: Double { WidgetInsightsLogic.budgetRemaining(limit: budget.limitAmount, spent: budget.spentAmount) }
    private var isOver: Bool { WidgetInsightsLogic.budgetIsOver(limit: budget.limitAmount, spent: budget.spentAmount) }
    private var pace: Double? {
        isOver ? nil : WidgetInsightsLogic.elapsedFraction(periodType: budget.periodType, now: asOf, calendar: .current)
    }

    var body: some View {
        HStack(alignment: .center, spacing: WidgetDS.Spacing.sm) {
            WidgetBadge(
                systemImage: budget.iconName ?? "chart.pie.fill",
                color: WidgetColors.fill(hex: budget.colorHex),
                size: isLarge ? WidgetDS.Icon.badgeMedium : WidgetDS.Icon.badgeSmall
            )

            VStack(alignment: .leading, spacing: WidgetDS.Spacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: WidgetDS.Spacing.xs) {
                    Text(budget.name)
                        .font(WidgetDS.Typography.label)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer(minLength: WidgetDS.Spacing.xs)
                    if !isLarge {
                        statusLabel
                    }
                    amount
                }

                if isLarge {
                    HStack(alignment: .firstTextBaseline, spacing: WidgetDS.Spacing.xs) {
                        Text(String(format: String(localized: "widget.budgets.spentOfLimit", bundle: .main),
                                    amountString(budget.spentAmount), amountString(budget.limitAmount))
                             + " · " + percentString)
                            .font(WidgetDS.Typography.captionSmall)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Spacer(minLength: WidgetDS.Spacing.xs)
                        statusLabel
                    }
                }

                WidgetMeterBar(
                    fraction: budget.percentUsed / 100,
                    color: isOver ? WidgetColors.hotPink : WidgetColors.electricIndigo,
                    pace: pace
                )
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var statusLabel: some View {
        Text(isOver ? String(localized: "widget.budgets.over", bundle: .main)
                    : String(localized: "widget.budgets.remaining", bundle: .main))
            .font(WidgetDS.Typography.captionSmall)
            .foregroundStyle(isOver ? WidgetColors.alertText : Color.secondary)
            .lineLimit(1)
            .fixedSize()
    }

    private var amount: some View {
        WidgetAmountText(
            value: abs(remaining),
            currencyCode: budget.currencyCode,
            displayFormat: displayFormat,
            font: WidgetDS.Typography.subheadlineEmphasized,
            secondaryFont: WidgetDS.Typography.captionSmall,
            tint: isOver ? .color(WidgetColors.alertText) : .primary
        )
        .fixedSize()
    }

    private var symbol: String {
        CurrencySymbols.display(for: budget.currencyCode, format: displayFormat)
    }

    private func amountString(_ value: Double) -> String {
        WidgetAmountSplitter.split(value: value, symbol: symbol, fractionDigits: 0).accessibilityFormatted
    }

    private var percentString: String {
        (budget.percentUsed / 100).formatted(.percent.precision(.fractionLength(0)))
    }
}

// MARK: - Widget Definition

struct BudgetsWidget: Widget {
    let kind: String = "BudgetsWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: BudgetsWidgetIntent.self,
            provider: BudgetsWidgetProvider()
        ) { entry in
            BudgetsWidgetView(entry: entry)
                .invitesToOpenYalaWithoutData(isPlaceholder: entry.isPlaceholder)
                .invitesToActivateFullWhenGroupsOnly()
                .containerBackground(WidgetColors.cardBackground, for: .widget)
        }
        .configurationDisplayName("widget.gallery.budgets")
        .description("widget.gallery.budgets.desc")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

// MARK: - Previews

#Preview("Medium", as: .systemMedium) {
    BudgetsWidget()
} timeline: {
    BudgetsEntry.placeholder
}

#Preview("Large", as: .systemLarge) {
    BudgetsWidget()
} timeline: {
    BudgetsEntry.placeholder
}

#Preview("Empty", as: .systemMedium) {
    BudgetsWidget()
} timeline: {
    BudgetsEntry(
        date: Date(),
        budgets: [],
        currencyDisplayFormat: "symbol",
        isPlaceholder: false
    )
}

#Preview("Over Budget", as: .systemMedium) {
    BudgetsWidget()
} timeline: {
    BudgetsEntry(
        date: Date(),
        budgets: [
            WidgetBudget(
                id: "1",
                name: "Alimentación",
                limitAmount: 800,
                spentAmount: 920,
                currencyCode: "PEN",
                periodType: "monthly",
                percentUsed: 115,
                iconName: "fork.knife",
                colorHex: "#FF6B6B"
            ),
            WidgetBudget(
                id: "2",
                name: "Entretenimiento",
                limitAmount: 300,
                spentAmount: 290,
                currencyCode: "PEN",
                periodType: "monthly",
                percentUsed: 97,
                iconName: "gamecontroller.fill",
                colorHex: "#45B7D1"
            ),
            WidgetBudget(
                id: "3",
                name: "Transporte",
                limitAmount: 400,
                spentAmount: 250,
                currencyCode: "PEN",
                periodType: "monthly",
                percentUsed: 62,
                iconName: "car.fill",
                colorHex: "#4ECDC4"
            )
        ],
        currencyDisplayFormat: "symbol",
        isPlaceholder: false
    )
}
