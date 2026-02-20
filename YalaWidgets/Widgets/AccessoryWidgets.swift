//
//  AccessoryWidgets.swift
//  YalaWidgets
//
//  Lock Screen widgets (accessoryCircular + accessoryRectangular).
//  4 widgets: Balance, Expense, Budget, Next Payment.
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Shared Helpers

/// Compact amount formatting for Lock Screen widgets
private func formatCompact(_ value: Double) -> String {
    let absValue = abs(value)
    let sign = value < 0 ? "-" : ""
    if absValue >= 1_000_000 {
        return String(format: "%@%.1fM", sign, absValue / 1_000_000)
    }
    if absValue >= 1000 {
        return String(format: "%@%.1fK", sign, absValue / 1000)
    }
    return String(format: "%@%.0f", sign, absValue)
}

/// Relative date label for payments
private func relativeDateLabel(for date: Date, isOverdue: Bool) -> String {
    if isOverdue {
        return String(localized: "widget.ui.overdue", bundle: .main)
    }
    let calendar = Calendar.current
    if calendar.isDateInToday(date) {
        return String(localized: "widget.ui.today", bundle: .main)
    }
    if calendar.isDateInTomorrow(date) {
        return String(localized: "widget.ui.tomorrow", bundle: .main)
    }
    let formatter = DateFormatter()
    formatter.setLocalizedDateFormatFromTemplate("dMMM")
    return formatter.string(from: date)
}

// MARK: - 1. Accessory Balance Widget (Circular)

struct AccessoryBalanceIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "widget.intent.accessoryBalance.title" }
    static var description: IntentDescription { "widget.intent.accessoryBalance.desc" }
}

struct AccessoryBalanceEntry: TimelineEntry {
    let date: Date
    let amount: Double
    let isExpensesOnly: Bool
    let isPlaceholder: Bool

    static var placeholder: AccessoryBalanceEntry {
        AccessoryBalanceEntry(date: Date(), amount: 1250, isExpensesOnly: false, isPlaceholder: true)
    }
}

struct AccessoryBalanceProvider: AppIntentTimelineProvider {
    typealias Entry = AccessoryBalanceEntry
    typealias Intent = AccessoryBalanceIntent

    func placeholder(in context: Context) -> AccessoryBalanceEntry { .placeholder }

    func snapshot(for configuration: Intent, in context: Context) async -> AccessoryBalanceEntry {
        context.isPreview ? .placeholder : createEntry()
    }

    func timeline(for configuration: Intent, in context: Context) async -> Timeline<AccessoryBalanceEntry> {
        let entry = createEntry()
        let refresh = Calendar.current.date(byAdding: .hour, value: 4, to: Date()) ?? Date()
        return Timeline(entries: [entry], policy: .after(refresh))
    }

    private func createEntry() -> AccessoryBalanceEntry {
        let period = WidgetDataService.getAppDefaultPeriod()
        let isExpensesOnly = WidgetDataService.isExpensesOnlyMode

        let amount: Double
        if isExpensesOnly, let summary = WidgetDataService.calculateSummary(for: period) {
            amount = summary.totalExpense
        } else {
            amount = WidgetDataService.getBalance(for: period)
        }

        return AccessoryBalanceEntry(date: Date(), amount: amount, isExpensesOnly: isExpensesOnly, isPlaceholder: false)
    }
}

struct AccessoryBalanceWidgetView: View {
    let entry: AccessoryBalanceEntry

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "creditcard.fill")
                .font(.caption)
            Text(formatCompact(entry.amount))
                .font(.system(.title3, design: .rounded).bold())
                .minimumScaleFactor(0.5)
                .widgetAccentable()
            Text(entry.isExpensesOnly
                 ? String(localized: "widget.ui.expenses", bundle: .main)
                 : String(localized: "widget.ui.balance", bundle: .main))
                .font(.system(.caption2))
                .foregroundStyle(.secondary)
        }
        .widgetURL(WidgetURLHelper.url(for: "panel"))
    }
}

struct AccessoryBalanceWidget: Widget {
    let kind = "AccessoryBalanceWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: AccessoryBalanceIntent.self, provider: AccessoryBalanceProvider()) { entry in
            AccessoryBalanceWidgetView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("widget.gallery.accessoryBalance")
        .description("widget.gallery.accessoryBalance.desc")
        .supportedFamilies([.accessoryCircular])
    }
}

// MARK: - 2. Accessory Expense Widget (Circular)

struct AccessoryExpenseIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "widget.intent.accessoryExpense.title" }
    static var description: IntentDescription { "widget.intent.accessoryExpense.desc" }
}

struct AccessoryExpenseEntry: TimelineEntry {
    let date: Date
    let expense: Double
    let isPlaceholder: Bool

    static var placeholder: AccessoryExpenseEntry {
        AccessoryExpenseEntry(date: Date(), expense: 850, isPlaceholder: true)
    }
}

struct AccessoryExpenseProvider: AppIntentTimelineProvider {
    typealias Entry = AccessoryExpenseEntry
    typealias Intent = AccessoryExpenseIntent

    func placeholder(in context: Context) -> AccessoryExpenseEntry { .placeholder }

    func snapshot(for configuration: Intent, in context: Context) async -> AccessoryExpenseEntry {
        context.isPreview ? .placeholder : createEntry()
    }

    func timeline(for configuration: Intent, in context: Context) async -> Timeline<AccessoryExpenseEntry> {
        let entry = createEntry()
        let refresh = Calendar.current.date(byAdding: .hour, value: 4, to: Date()) ?? Date()
        return Timeline(entries: [entry], policy: .after(refresh))
    }

    private func createEntry() -> AccessoryExpenseEntry {
        let period = WidgetDataService.getAppDefaultPeriod()
        let expense = WidgetDataService.calculateSummary(for: period)?.totalExpense ?? 0
        return AccessoryExpenseEntry(date: Date(), expense: expense, isPlaceholder: false)
    }
}

struct AccessoryExpenseWidgetView: View {
    let entry: AccessoryExpenseEntry

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.caption)
            Text(formatCompact(entry.expense))
                .font(.system(.title3, design: .rounded).bold())
                .minimumScaleFactor(0.5)
                .widgetAccentable()
            Text(String(localized: "widget.ui.expenses", bundle: .main))
                .font(.system(.caption2))
                .foregroundStyle(.secondary)
        }
        .widgetURL(WidgetURLHelper.url(for: "statistics"))
    }
}

struct AccessoryExpenseWidget: Widget {
    let kind = "AccessoryExpenseWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: AccessoryExpenseIntent.self, provider: AccessoryExpenseProvider()) { entry in
            AccessoryExpenseWidgetView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("widget.gallery.accessoryExpense")
        .description("widget.gallery.accessoryExpense.desc")
        .supportedFamilies([.accessoryCircular])
    }
}

// MARK: - 3. Accessory Budget Widget (Rectangular)

struct AccessoryBudgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "widget.intent.accessoryBudget.title" }
    static var description: IntentDescription { "widget.intent.accessoryBudget.desc" }
}

struct AccessoryBudgetEntry: TimelineEntry {
    let date: Date
    let budgetName: String?
    let percentUsed: Double
    let isPlaceholder: Bool

    static var placeholder: AccessoryBudgetEntry {
        AccessoryBudgetEntry(date: Date(), budgetName: "Comida", percentUsed: 75, isPlaceholder: true)
    }
}

struct AccessoryBudgetProvider: AppIntentTimelineProvider {
    typealias Entry = AccessoryBudgetEntry
    typealias Intent = AccessoryBudgetIntent

    func placeholder(in context: Context) -> AccessoryBudgetEntry { .placeholder }

    func snapshot(for configuration: Intent, in context: Context) async -> AccessoryBudgetEntry {
        context.isPreview ? .placeholder : createEntry()
    }

    func timeline(for configuration: Intent, in context: Context) async -> Timeline<AccessoryBudgetEntry> {
        let entry = createEntry()
        let refresh = Calendar.current.date(byAdding: .hour, value: 4, to: Date()) ?? Date()
        return Timeline(entries: [entry], policy: .after(refresh))
    }

    private func createEntry() -> AccessoryBudgetEntry {
        let budgets = WidgetDataService.getBudgets(sortByCritical: true)
        guard let top = budgets.first else {
            return AccessoryBudgetEntry(date: Date(), budgetName: nil, percentUsed: 0, isPlaceholder: false)
        }
        return AccessoryBudgetEntry(date: Date(), budgetName: top.name, percentUsed: top.percentUsed, isPlaceholder: false)
    }
}

struct AccessoryBudgetWidgetView: View {
    let entry: AccessoryBudgetEntry

    var body: some View {
        if let name = entry.budgetName {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.headline)
                    .lineLimit(1)
                ProgressView(value: min(entry.percentUsed / 100, 1.0))
                    .widgetAccentable()
                Text("\(Int(entry.percentUsed))%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        } else {
            Text(String(localized: "widget.ui.noBudgets", bundle: .main))
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }
}

struct AccessoryBudgetWidget: Widget {
    let kind = "AccessoryBudgetWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: AccessoryBudgetIntent.self, provider: AccessoryBudgetProvider()) { entry in
            AccessoryBudgetWidgetView(entry: entry)
                .containerBackground(.clear, for: .widget)
                .widgetURL(WidgetURLHelper.url(for: "budgets"))
        }
        .configurationDisplayName("widget.gallery.accessoryBudget")
        .description("widget.gallery.accessoryBudget.desc")
        .supportedFamilies([.accessoryRectangular])
    }
}

// MARK: - 4. Accessory Next Payment Widget (Rectangular)

struct AccessoryNextPaymentIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "widget.intent.accessoryPayment.title" }
    static var description: IntentDescription { "widget.intent.accessoryPayment.desc" }
}

struct AccessoryNextPaymentEntry: TimelineEntry {
    let date: Date
    let paymentName: String?
    let amount: Double
    let currencyCode: String
    let nextDueDate: Date
    let isOverdue: Bool
    let iconName: String?
    let isPlaceholder: Bool

    static var placeholder: AccessoryNextPaymentEntry {
        AccessoryNextPaymentEntry(
            date: Date(),
            paymentName: "Netflix",
            amount: 15.99,
            currencyCode: "USD",
            nextDueDate: Date().addingTimeInterval(86400),
            isOverdue: false,
            iconName: "tv",
            isPlaceholder: true
        )
    }
}

struct AccessoryNextPaymentProvider: AppIntentTimelineProvider {
    typealias Entry = AccessoryNextPaymentEntry
    typealias Intent = AccessoryNextPaymentIntent

    func placeholder(in context: Context) -> AccessoryNextPaymentEntry { .placeholder }

    func snapshot(for configuration: Intent, in context: Context) async -> AccessoryNextPaymentEntry {
        context.isPreview ? .placeholder : createEntry()
    }

    func timeline(for configuration: Intent, in context: Context) async -> Timeline<AccessoryNextPaymentEntry> {
        let entry = createEntry()
        let refresh = Calendar.current.date(byAdding: .hour, value: 4, to: Date()) ?? Date()
        return Timeline(entries: [entry], policy: .after(refresh))
    }

    private func createEntry() -> AccessoryNextPaymentEntry {
        let payments = WidgetDataService.getScheduledPayments(filter: .all, limit: 1)
        guard let next = payments.first else {
            return AccessoryNextPaymentEntry(
                date: Date(), paymentName: nil, amount: 0, currencyCode: "USD",
                nextDueDate: Date(), isOverdue: false, iconName: nil, isPlaceholder: false
            )
        }
        return AccessoryNextPaymentEntry(
            date: Date(),
            paymentName: next.name,
            amount: next.amount,
            currencyCode: next.currencyCode,
            nextDueDate: next.nextDueDate,
            isOverdue: next.isOverdue,
            iconName: next.iconName,
            isPlaceholder: false
        )
    }
}

struct AccessoryNextPaymentWidgetView: View {
    let entry: AccessoryNextPaymentEntry

    var body: some View {
        if let name = entry.paymentName {
            HStack(spacing: 4) {
                Image(systemName: entry.iconName ?? "calendar.badge.clock")
                    .font(.title3)
                    .widgetAccentable()

                VStack(alignment: .leading, spacing: 1) {
                    Text(name)
                        .font(.headline)
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Text(formatCompact(entry.amount))
                            .font(.body)
                        Text("·")
                            .foregroundStyle(.secondary)
                        Text(relativeDateLabel(for: entry.nextDueDate, isOverdue: entry.isOverdue))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .lineLimit(1)
                }
            }
        } else {
            Text(String(localized: "widget.ui.noPayments", bundle: .main))
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }
}

struct AccessoryNextPaymentWidget: Widget {
    let kind = "AccessoryNextPaymentWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: AccessoryNextPaymentIntent.self, provider: AccessoryNextPaymentProvider()) { entry in
            AccessoryNextPaymentWidgetView(entry: entry)
                .containerBackground(.clear, for: .widget)
                .widgetURL(WidgetURLHelper.url(for: "planning"))
        }
        .configurationDisplayName("widget.gallery.accessoryPayment")
        .description("widget.gallery.accessoryPayment.desc")
        .supportedFamilies([.accessoryRectangular])
    }
}
