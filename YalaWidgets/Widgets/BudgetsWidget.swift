//
//  BudgetsWidget.swift
//  YalaWidgets
//
//  Widget showing budget progress.
//  Supports Medium size with top 3 budgets sorted by usage.
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
        return createEntry(for: configuration)
    }

    func timeline(for configuration: BudgetsWidgetIntent, in context: Context) async -> Timeline<BudgetsEntry> {
        let entry = createEntry(for: configuration)

        // Refresh every 4 hours
        let refreshDate = Calendar.current.date(byAdding: .hour, value: 4, to: Date()) ?? Date()

        return Timeline(entries: [entry], policy: .after(refreshDate))
    }

    private func createEntry(for configuration: BudgetsWidgetIntent) -> BudgetsEntry {
        var budgets: [WidgetBudget]

        if configuration.selectionMode == .custom,
           let selected = configuration.selectedBudgets,
           !selected.isEmpty {
            // Custom mode: filter by selected IDs
            let selectedIDs = Set(selected.map(\.id))
            let allBudgets = WidgetDataService.getBudgets(sortByCritical: false)
            budgets = allBudgets.filter { selectedIDs.contains($0.id) }
            // Maintain selection order
            budgets = selected.compactMap { entity in
                allBudgets.first { $0.id == entity.id }
            }
            budgets = Array(budgets.prefix(3))
        } else {
            // Automatic mode: top 3 by % used
            budgets = WidgetDataService.getBudgets(sortByCritical: true)
            budgets = Array(budgets.prefix(3))
        }

        let displayFormat = WidgetDataService.getCurrencyDisplayFormat()

        return BudgetsEntry(
            date: Date(),
            budgets: budgets,
            currencyDisplayFormat: displayFormat,
            isPlaceholder: false
        )
    }
}

// MARK: - Widget View

struct BudgetsWidgetView: View {
    var entry: BudgetsEntry

    var body: some View {
        VStack(alignment: .leading, spacing: WDS.Spacing.sm) {
            // Header
            WidgetHeader(
                title: String(localized: "widget.ui.budgets", bundle: .main),
                icon: "chart.pie"
            )

            if entry.budgets.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: WDS.Spacing.xs) {
                        Image(systemName: "chart.pie")
                            .font(.title2) // A11Y-DT: widget empty state icon
                            .foregroundStyle(.tertiary)
                        Text("widget.ui.noBudgets", bundle: .main)
                            .font(WDS.Typography.body)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                // Budget list
                ForEach(entry.budgets, id: \.id) { budget in
                    BudgetRowView(
                        budget: budget,
                        displayFormat: entry.currencyDisplayFormat
                    )
                }

                Spacer(minLength: 0)
            }
        }
        .padding(WDS.Spacing.xs)
        .clipped()
        .widgetURL(WidgetURLHelper.url(for: "budgets"))
    }
}

// MARK: - Budget Row

struct BudgetRowView: View {
    let budget: WidgetBudget
    let displayFormat: String

    var body: some View {
        VStack(alignment: .leading, spacing: WDS.Spacing.xxs) {
            // Row 1: Icon + Name + %
            HStack(spacing: WDS.Spacing.sm) {
                // Icon badge compacto
                ZStack {
                    Circle()
                        .fill(budgetColor.opacity(0.2))
                        .frame(width: WDS.ListItem.iconSizeCompact,
                               height: WDS.ListItem.iconSizeCompact)

                    Image(systemName: budget.iconName ?? "chart.pie.fill")
                        .font(.system(size: WDS.Icon.sm)) // A11Y-DT: widget fixed layout
                        .foregroundStyle(budgetColor)
                        .widgetAccentable()
                }

                Text(budget.name)
                    .font(WDS.Typography.label)
                    .lineLimit(1)

                Spacer()

                // Spent/Limit compact
                Text(formattedAmounts)
                    .font(WDS.Typography.tiny)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: true, vertical: false)

                Text("\(Int(budget.percentUsed))%")
                    .font(WDS.Typography.labelSmall)
                    .foregroundStyle(progressColor)
                    .fixedSize(horizontal: true, vertical: false)
                    .widgetAccentable()
            }

            // Row 2: Progress bar alineada con texto
            WidgetProgressBar.budget(
                percentUsed: budget.percentUsed,
                height: WDS.Progress.heightCompact
            )
            .padding(.leading, WDS.ListItem.iconSizeCompact + WDS.Spacing.sm)
        }
    }

    private var budgetColor: Color {
        Color(hex: budget.colorHex ?? "#6366F1")
    }

    private var progressColor: Color {
        WidgetColors.forBudget(percentUsed: budget.percentUsed)
    }

    private var formattedAmounts: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0

        let spent = formatter.string(from: NSNumber(value: budget.spentAmount)) ?? "0"
        let limit = formatter.string(from: NSNumber(value: budget.limitAmount)) ?? "0"
        let currency = displayFormat == "symbol"
            ? CurrencySymbols.symbol(for: budget.currencyCode)
            : budget.currencyCode

        return "\(currency)\(spent)/\(limit)"
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
                .containerBackground(Color(.secondarySystemGroupedBackground), for: .widget)
        }
        .configurationDisplayName("widget.gallery.budgets")
        .description("widget.gallery.budgets.desc")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Previews

#Preview("Medium", as: .systemMedium) {
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
