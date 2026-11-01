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

/// La cifra compacta de la pantalla bloqueada («79,4K» / «79.4K»), con el separador decimal del idioma
/// (`WidgetInsightsLogic.compactAmount`; hasta 2.2 salía siempre un punto).
///
/// **Sin marca «≈» a propósito.** No imprime divisa y el «≈» del repo se antepone al SÍMBOLO de la divisa, no al número.
/// En un aro de dos o tres glifos, un «≈» delante se lee como parte de la cifra y compite por el espacio con ella. Que el
/// número sea aproximado se ve en el widget grande del mismo dato, que sí trae divisa.
private func formatCompact(_ value: Double) -> String {
    WidgetInsightsLogic.compactAmount(value, locale: .current)
}

/// El aro de la pantalla bloqueada: fondo del sistema, icono arriba, la cifra y su rótulo.
private struct AccessoryFigure: View {
    let systemImage: String
    let value: String
    let label: String

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: WidgetDS.Spacing.none) {
                Image(systemName: systemImage)
                    .font(WidgetDS.Typography.captionSmall)
                Text(value)
                    .font(WidgetDS.Typography.headline)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .widgetNumericTransition()
                    .widgetAccentable()
                Text(label)
                    .font(WidgetDS.Typography.labelTiny)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, WidgetDS.Spacing.xs)
        }
        .accessibilityElement(children: .combine)
    }
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
        return Timeline(entries: [entry], policy: .after(WidgetRefresh.nextDate(after: entry.date)))
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
        AccessoryFigure(
            systemImage: entry.isExpensesOnly ? "arrow.down.right" : "wallet.bifold.fill",
            value: formatCompact(entry.amount),
            label: entry.isExpensesOnly
                ? String(localized: "widget.ui.expenses", bundle: .main)
                : String(localized: "widget.ui.available", bundle: .main)
        )
        .widgetURL(WidgetURLHelper.url(for: "panel"))
    }
}

struct AccessoryBalanceWidget: Widget {
    let kind = "AccessoryBalanceWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: AccessoryBalanceIntent.self, provider: AccessoryBalanceProvider()) { entry in
            AccessoryBalanceWidgetView(entry: entry)
                .invitesToOpenYalaWithoutData(isPlaceholder: entry.isPlaceholder, message: "widget.empty.openYalaBalance")
                .invitesToActivateFullWhenGroupsOnly()
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
        return Timeline(entries: [entry], policy: .after(WidgetRefresh.nextDate(after: entry.date)))
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
        AccessoryFigure(
            systemImage: "arrow.down.right",
            value: formatCompact(entry.expense),
            label: String(localized: "widget.ui.expenses", bundle: .main)
        )
        .widgetURL(WidgetURLHelper.url(for: WidgetDeepLink.expenses))
    }
}

struct AccessoryExpenseWidget: Widget {
    let kind = "AccessoryExpenseWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: AccessoryExpenseIntent.self, provider: AccessoryExpenseProvider()) { entry in
            AccessoryExpenseWidgetView(entry: entry)
                .invitesToOpenYalaWithoutData(isPlaceholder: entry.isPlaceholder)
                .invitesToActivateFullWhenGroupsOnly()
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
    /// Lo que queda (negativo = te pasaste), en la divisa del presupuesto.
    var remaining: Double = 0
    var currencyCode: String = "PEN"
    var currencyDisplayFormat: String = "symbol"
    var periodType: String = "monthly"
    var iconName: String? = nil

    static var placeholder: AccessoryBudgetEntry {
        AccessoryBudgetEntry(date: Date(), budgetName: "Comida", percentUsed: 75, isPlaceholder: true,
                             remaining: 200, iconName: "fork.knife")
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
        return Timeline(entries: [entry], policy: .after(WidgetRefresh.nextDate(after: entry.date)))
    }

    private func createEntry() -> AccessoryBudgetEntry {
        let budgets = WidgetDataService.getBudgets(sortByCritical: true)
        guard let top = budgets.first else {
            return AccessoryBudgetEntry(date: Date(), budgetName: nil, percentUsed: 0, isPlaceholder: false)
        }
        return AccessoryBudgetEntry(
            date: Date(),
            budgetName: top.name,
            percentUsed: top.percentUsed,
            isPlaceholder: false,
            remaining: WidgetInsightsLogic.budgetRemaining(limit: top.limitAmount, spent: top.spentAmount),
            currencyCode: top.currencyCode,
            currencyDisplayFormat: WidgetDataService.getCurrencyDisplayFormat(),
            periodType: top.periodType,
            iconName: top.iconName
        )
    }
}

struct AccessoryBudgetWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AccessoryBudgetEntry

    private var isOver: Bool { entry.remaining < 0 }
    private var percentText: String { (entry.percentUsed / 100).formatted(.percent.precision(.fractionLength(0))) }

    var body: some View {
        if let name = entry.budgetName {
            if family == .accessoryCircular {
                Gauge(value: min(max(entry.percentUsed / 100, 0), 1)) {
                    Image(systemName: entry.iconName ?? "chart.pie.fill")
                } currentValueLabel: {
                    Text(percentText)
                        .monospacedDigit()
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .widgetAccentable()
                .accessibilityLabel(Text(name))
            } else {
                VStack(alignment: .leading, spacing: WidgetDS.Spacing.xxs) {
                    Text(name)
                        .font(WidgetDS.Typography.headline)
                        .lineLimit(1)
                    Text((isOver ? String(localized: "widget.budgets.over", bundle: .main)
                                 : String(localized: "widget.budgets.remaining", bundle: .main))
                         + " " + WidgetAmountSplitter.split(
                            value: abs(entry.remaining),
                            symbol: CurrencySymbols.display(for: entry.currencyCode, format: entry.currencyDisplayFormat),
                            fractionDigits: 0).accessibilityFormatted)
                        .font(WidgetDS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    WidgetMeterBar(
                        fraction: entry.percentUsed / 100,
                        color: .primary,
                        pace: isOver ? nil : WidgetInsightsLogic.elapsedFraction(
                            periodType: entry.periodType, now: entry.date, calendar: .current)
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            // Ninguno creado: lo dice y el toque abre uno nuevo (UX 2.2 · L15-2).
            Text(String(localized: "widget.empty.noBudgetsYet", bundle: .main))
                .font(family == .accessoryCircular ? WidgetDS.Typography.labelTiny : WidgetDS.Typography.headline)
                .lineLimit(family == .accessoryCircular ? 3 : 2)
                .minimumScaleFactor(0.7)
                .multilineTextAlignment(family == .accessoryCircular ? .center : .leading)
                .foregroundStyle(.secondary)
        }
    }
}

struct AccessoryBudgetWidget: Widget {
    let kind = "AccessoryBudgetWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: AccessoryBudgetIntent.self, provider: AccessoryBudgetProvider()) { entry in
            AccessoryBudgetWidgetView(entry: entry)
                // El enlace va DENTRO del modificador: en solo grupos la invitación lo sustituye por el suyo, y dos
                // `widgetURL` en la misma jerarquía no tienen comportamiento definido.
                .widgetURL(WidgetURLHelper.url(
                    for: entry.budgetName == nil && !entry.isPlaceholder ? WidgetDeepLink.newBudget : "budgets"))
                .invitesToOpenYalaWithoutData(isPlaceholder: entry.isPlaceholder)
                .invitesToActivateFullWhenGroupsOnly()
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("widget.gallery.accessoryBudget")
        .description("widget.gallery.accessoryBudget.desc")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular])
    }
}

// MARK: - 4. Accessory Next Payment Widget (Rectangular)

struct AccessoryNextPaymentIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "widget.intent.accessoryPayment.title" }
    static var description: IntentDescription { "widget.intent.accessoryPayment.desc" }
}

struct AccessoryNextPaymentEntry: TimelineEntry {
    var date: Date
    let paymentName: String?
    let amount: Double
    let currencyCode: String
    let nextDueDate: Date
    let isOverdue: Bool
    let iconName: String?
    let isPlaceholder: Bool
    var isIncome: Bool = false
    var isVariableAmount: Bool = false
    var currencyDisplayFormat: String = "symbol"

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
        // A medianoche cambian «Hoy», «Mañana» y «En N días».
        return WidgetRefresh.dayAwareTimeline(entry) { midnight in
            var next = entry
            next.date = midnight
            return next
        }
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
            isPlaceholder: false,
            isIncome: next.isIncome,
            isVariableAmount: next.isVariableAmount ?? false,
            currencyDisplayFormat: WidgetDataService.getCurrencyDisplayFormat()
        )
    }
}

struct AccessoryNextPaymentWidgetView: View {
    let entry: AccessoryNextPaymentEntry

    var body: some View {
        if let name = entry.paymentName {
            HStack(spacing: WidgetDS.Spacing.xs) {
                Image(systemName: entry.iconName ?? "calendar")
                    .font(WidgetDS.Typography.headline)
                    .widgetAccentable()

                VStack(alignment: .leading, spacing: WidgetDS.Spacing.none) {
                    Text(name)
                        .font(WidgetDS.Typography.headline)
                        .lineLimit(1)
                    Text(WidgetAmountSplitter.split(
                        value: entry.isIncome ? abs(entry.amount) : -abs(entry.amount),
                        symbol: CurrencySymbols.display(for: entry.currencyCode, format: entry.currencyDisplayFormat),
                        fractionDigits: 2,
                        forceSign: true,
                        isEstimate: entry.isVariableAmount).accessibilityFormatted)
                        .font(WidgetDS.Typography.caption)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(WidgetDateText.due(entry.nextDueDate, isOverdue: entry.isOverdue, now: entry.date))
                        .font(WidgetDS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
        } else {
            // Ninguno creado: «Sin pagos pendientes» se leía como «estás al día» (UX 2.2 · L15-2).
            Text(String(localized: "widget.empty.noPaymentsYet", bundle: .main))
                .font(WidgetDS.Typography.headline)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .foregroundStyle(.secondary)
        }
    }
}

struct AccessoryNextPaymentWidget: Widget {
    let kind = "AccessoryNextPaymentWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: AccessoryNextPaymentIntent.self, provider: AccessoryNextPaymentProvider()) { entry in
            AccessoryNextPaymentWidgetView(entry: entry)
                // El enlace va DENTRO del modificador: en solo grupos la invitación lo sustituye por el suyo, y dos
                // `widgetURL` en la misma jerarquía no tienen comportamiento definido.
                .widgetURL(WidgetURLHelper.url(
                    for: entry.paymentName == nil && !entry.isPlaceholder
                        ? WidgetDeepLink.newScheduledPayment : "planning/scheduled-payments"))
                .invitesToOpenYalaWithoutData(isPlaceholder: entry.isPlaceholder)
                .invitesToActivateFullWhenGroupsOnly()
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("widget.gallery.accessoryPayment")
        .description("widget.gallery.accessoryPayment.desc")
        .supportedFamilies([.accessoryRectangular])
    }
}
