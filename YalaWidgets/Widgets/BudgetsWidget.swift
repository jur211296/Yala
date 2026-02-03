//
//  BudgetsWidget.swift
//  YalaWidgets
//
//  Widget showing budget progress.
//  Supports Medium size with top 3 budgets sorted by usage.
//

import WidgetKit
import SwiftUI

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
                    percentUsed: 90
                ),
                WidgetBudget(
                    id: "2",
                    name: "Entretenimiento",
                    limitAmount: 300,
                    spentAmount: 180,
                    currencyCode: "PEN",
                    periodType: "monthly",
                    percentUsed: 60
                ),
                WidgetBudget(
                    id: "3",
                    name: "Transporte",
                    limitAmount: 400,
                    spentAmount: 120,
                    currencyCode: "PEN",
                    periodType: "monthly",
                    percentUsed: 30
                )
            ],
            currencyDisplayFormat: "symbol",
            isPlaceholder: true
        )
    }
}

// MARK: - Timeline Provider

struct BudgetsWidgetProvider: TimelineProvider {
    typealias Entry = BudgetsEntry

    func placeholder(in context: Context) -> BudgetsEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (BudgetsEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
        } else {
            completion(createEntry())
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BudgetsEntry>) -> Void) {
        let entry = createEntry()

        // Refresh every 4 hours
        let refreshDate = Calendar.current.date(byAdding: .hour, value: 4, to: Date()) ?? Date()

        let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
        completion(timeline)
    }

    private func createEntry() -> BudgetsEntry {
        // Get budgets sorted by critical (highest % used first)
        var budgets = WidgetDataService.getBudgets(sortByCritical: true)
        budgets = Array(budgets.prefix(3))

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
        VStack(alignment: .leading, spacing: WDS.Spacing.md) {
            // Header
            WidgetHeader(
                title: "Presupuestos",
                icon: "chart.pie"
            )

            if entry.budgets.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: WDS.Spacing.xs) {
                        Image(systemName: "chart.pie")
                            .font(.title2)
                            .foregroundStyle(.tertiary)
                        Text("Sin presupuestos")
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
        .padding(WDS.Spacing.xl)
        .clipped()
        .widgetURL(URL(string: "yala://budgets"))
    }
}

// MARK: - Budget Row

struct BudgetRowView: View {
    let budget: WidgetBudget
    let displayFormat: String

    var body: some View {
        VStack(alignment: .leading, spacing: WDS.Spacing.xs) {
            HStack {
                Text(budget.name)
                    .font(WDS.Typography.label)
                    .lineLimit(1)

                Spacer()

                Text("\(Int(budget.percentUsed))%")
                    .font(WDS.Typography.label)
                    .foregroundColor(progressColor)
            }

            // Progress bar
            WidgetProgressBar.budget(
                percentUsed: budget.percentUsed,
                height: WDS.Progress.height
            )

            // Amount info
            HStack {
                Text(formattedSpent)
                    .font(WDS.Typography.tiny)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("de \(formattedLimit)")
                    .font(WDS.Typography.tiny)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var progressColor: Color {
        WidgetColors.forBudget(percentUsed: budget.percentUsed)
    }

    private var formattedSpent: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0

        let formatted = formatter.string(from: NSNumber(value: budget.spentAmount)) ?? "0"
        let currency = displayFormat == "symbol"
            ? CurrencySymbols.symbol(for: budget.currencyCode)
            : budget.currencyCode

        return "\(currency) \(formatted)"
    }

    private var formattedLimit: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0

        let formatted = formatter.string(from: NSNumber(value: budget.limitAmount)) ?? "0"
        let currency = displayFormat == "symbol"
            ? CurrencySymbols.symbol(for: budget.currencyCode)
            : budget.currencyCode

        return "\(currency) \(formatted)"
    }
}

// MARK: - Widget Definition

struct BudgetsWidget: Widget {
    let kind: String = "BudgetsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: BudgetsWidgetProvider()
        ) { entry in
            BudgetsWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Presupuestos")
        .description("Progreso de tus presupuestos")
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
                percentUsed: 115
            ),
            WidgetBudget(
                id: "2",
                name: "Entretenimiento",
                limitAmount: 300,
                spentAmount: 290,
                currencyCode: "PEN",
                periodType: "monthly",
                percentUsed: 97
            ),
            WidgetBudget(
                id: "3",
                name: "Transporte",
                limitAmount: 400,
                spentAmount: 250,
                currencyCode: "PEN",
                periodType: "monthly",
                percentUsed: 62
            )
        ],
        currencyDisplayFormat: "symbol",
        isPlaceholder: false
    )
}
