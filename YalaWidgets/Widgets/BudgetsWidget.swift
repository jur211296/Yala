//
//  BudgetsWidget.swift
//  YalaWidgets
//
//  Widget showing budget progress.
//  Supports Medium size with configurable budget selection.
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Configuration Intent

struct BudgetsWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Presupuestos" }
    static var description: IntentDescription { "Muestra el progreso de tus presupuestos" }

    @Parameter(title: "Mostrar", default: .critical)
    var displayMode: BudgetDisplayMode
}

enum BudgetDisplayMode: String, AppEnum {
    case critical = "critical"
    case all = "all"

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Modo"
    }

    static var caseDisplayRepresentations: [BudgetDisplayMode: DisplayRepresentation] {
        [
            .critical: "Más críticos",
            .all: "Todos"
        ]
    }
}

// MARK: - Timeline Entry

struct BudgetsEntry: TimelineEntry {
    let date: Date
    let budgets: [WidgetBudget]
    let isPlaceholder: Bool
    let displayMode: BudgetDisplayMode

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
            isPlaceholder: true,
            displayMode: .critical
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
        let sortByCritical = configuration.displayMode == .critical
        var budgets = WidgetDataService.getBudgets(sortByCritical: sortByCritical)

        // Limit to 3-4 budgets for widget display
        budgets = Array(budgets.prefix(3))

        return BudgetsEntry(
            date: Date(),
            budgets: budgets,
            isPlaceholder: false,
            displayMode: configuration.displayMode
        )
    }
}

// MARK: - Widget View

struct BudgetsWidgetView: View {
    var entry: BudgetsEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "chart.pie")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Presupuestos")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            if entry.budgets.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "chart.pie")
                            .font(.title2)
                            .foregroundStyle(.tertiary)
                        Text("Sin presupuestos")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                // Budget list
                ForEach(entry.budgets, id: \.id) { budget in
                    BudgetRow(budget: budget)
                }

                Spacer(minLength: 0)
            }
        }
        .padding()
        .widgetURL(URL(string: "yala://budgets"))
    }
}

struct BudgetRow: View {
    let budget: WidgetBudget

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(budget.name)
                    .font(.caption)
                    .lineLimit(1)

                Spacer()

                Text("\(Int(budget.percentUsed))%")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(progressColor)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)

                    // Progress
                    RoundedRectangle(cornerRadius: 3)
                        .fill(progressColor)
                        .frame(width: progressWidth(in: geometry.size.width), height: 6)
                }
            }
            .frame(height: 6)

            // Amount info
            HStack {
                Text(formattedSpent)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("de \(formattedLimit)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var progressColor: Color {
        WidgetColors.forBudget(percentUsed: budget.percentUsed)
    }

    private func progressWidth(in totalWidth: CGFloat) -> CGFloat {
        let percent = min(budget.percentUsed, 100) / 100
        return totalWidth * CGFloat(percent)
    }

    private var formattedSpent: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: budget.spentAmount)) ?? "0"
    }

    private var formattedLimit: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: budget.limitAmount)) ?? "0"
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
