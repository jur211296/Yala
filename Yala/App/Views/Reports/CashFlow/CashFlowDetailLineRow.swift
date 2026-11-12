//
//  CashFlowDetailLineRow.swift
//  Yala
//
//  A single line row in the month detail view.
//  Tap → cell detail sheet. Context menu → ask to delete the line (the month detail confirms).
//
//  Lienzo «Una sola Yala» (2A, decisión de Jürgen del 19-oct): una línea del plan dice lo mismo que un presupuesto
//  —cuánto llevas de cuánto y cuánto te queda—, así que es la tarjeta de Presupuestos: icono de 40, «S/ 1,238 de
//  S/ 1,950 · 13 días», «Te quedan / Te pasaste por» a la derecha y la barra a lo ancho. En un ingreso, «Te falta
//  recibir» y recibir de más no se pinta en rosa (B7). Un mes que viene dice lo planeado y cómo se calcula, en gris: el
//  método ya no se pinta como un enlace (L18-7).
//

import SwiftUI

struct CashFlowDetailLineRow: View {
    let lineResult: CashFlowLineResult
    let line: CashFlowLine?
    let month: CashFlowMonth
    let currencyCode: String
    let onTapLine: () -> Void
    let onDeleteLine: (() -> Void)?

    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button {
            onTapLine()
        } label: {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                AdaptiveRowStack(spacing: DS.Spacing.md, stackedSpacing: DS.Spacing.sm) {
                    categoryIcon
                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        Text(lineResult.name)
                            .font(DS.Typography.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                        subtitle
                    }
                } trailing: {
                    trailingFigure
                }

                if let real = lineResult.realAmount, hasRealData, lineResult.plannedAmount > 0 {
                    BudgetProgressBar(
                        percentage: real / lineResult.plannedAmount * 100,
                        color: "",
                        isExceeded: CashFlowLineSideLogic.progressIsAlarm(
                            progress: real / lineResult.plannedAmount, isIncome: lineResult.isIncome
                        ),
                        simplified: true
                    )
                }
            }
            .padding(DS.Spacing.lg)
            .contentShape(Rectangle())
            .solidCard(radius: DS.Radius.md)
        }
        .buttonStyle(.plain)
        .pointerHighlight(cornerRadius: DS.Radius.md)
        .accessibilityIdentifier("cashflow_detail_line")
        .contextMenu {
            // El botón pide el borrado; la confirmación la pinta `CashFlowMonthDetailView`. Antes el botón
            // llevaba el texto de la pregunta y borraba sin preguntar nada.
            if let onDeleteLine {
                Button(role: .destructive) {
                    onDeleteLine()
                } label: {
                    Label(L10n.CashFlowPlan.deleteLine, systemImage: "trash")
                }
                .accessibilityIdentifier("cashflow_line_delete")
            }
        }
    }

    /// El mes ya tiene movimientos (en curso o pasado): se compara lo real con lo planeado.
    private var hasRealData: Bool { month.isPast || month.isCurrent }

    // MARK: - Subtítulo

    @ViewBuilder
    private var subtitle: some View {
        if hasRealData, let real = lineResult.realAmount {
            // «S/ 1,238 de S/ 1,950 · 13 días» (en curso) o «· Cerrado» (pasado), como un presupuesto.
            BudgetSpentLine(
                spent: real,
                limit: lineResult.plannedAmount,
                currencyCode: currencyCode,
                suffix: month.isCurrent ? L10n.UXL9.shortDays(daysLeftInMonth) : L10n.UXL9.shortDays(-1)
            )
        } else {
            Text(methodText)
                .font(DS.Typography.captionSmall)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    /// Cómo sale el monto de un mes que viene: «Promedio 6 meses», «Desde noviembre» (un cambio «y los siguientes»)
    /// o «Monto ajustado manualmente».
    private var methodText: String {
        if lineResult.isOverride { return L10n.CashFlowPlan.cellDetailOverrideActive }
        if let from = lineResult.amountChangeFromMonthKey, let date = Self.monthDate(from) {
            return L10n.UXL18.fromMonth(CashFlowMonthSummaryLogic.monthInSentence(date))
        }
        return lineResult.estimationMethod.displayName
    }

    private var daysLeftInMonth: Int {
        let calendar = Calendar.current
        guard let range = calendar.range(of: .day, in: .month, for: month.date) else { return 0 }
        let today = calendar.component(.day, from: .now)
        return max(1, range.count - today + 1)
    }

    // MARK: - Cifra de la derecha

    @ViewBuilder
    private var trailingFigure: some View {
        if hasRealData, let real = lineResult.realAmount {
            let remaining = lineResult.plannedAmount - real
            let isOver = remaining < 0
            // Un ingreso cobrado entero dice «Recibido» y lo cobrado, no «Te falta recibir S/ 0.00».
            let fullyReceived = lineResult.isIncome && abs(remaining) < 0.005
            VStack(alignment: .trailing, spacing: DS.Spacing.xxs) {
                Text(fullyReceived ? L10n.CashFlowPlan.realIncome : trailingLabel(isOver: isOver))
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(isOver && !lineResult.isIncome ? Color.overBudgetText : Color.secondary)
                    .lineLimit(1)
                Text(appPreferences.currency(fullyReceived ? real : abs(remaining), currencyCode: currencyCode))
                    .font(DS.Typography.headline)
                    .foregroundStyle(isOver && !lineResult.isIncome ? Color.overBudgetText : Color.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .layoutPriority(1)
        } else {
            VStack(alignment: .trailing, spacing: DS.Spacing.xxs) {
                Text(L10n.CashFlowPlan.plan)
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                AmountText(
                    value: lineResult.plannedAmount,
                    currencyCode: currencyCode,
                    font: DS.Typography.headline.monospacedDigit(),
                    tint: .color(Color.amountTint(isIncome: lineResult.isIncome)),
                    isEstimate: lineResult.isPlannedApproximate
                )
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            }
            .layoutPriority(1)
        }
    }

    private func trailingLabel(isOver: Bool) -> String {
        if lineResult.isIncome {
            return isOver ? L10n.UXL18.receivedExtra : L10n.UXL18.toReceive
        }
        return isOver ? L10n.UXL9.overLabel : L10n.UXL9.remainingLabel
    }

    // MARK: - Category Icon

    private var categoryIcon: some View {
        let iconName = line?.subcategory?.iconName ?? line?.category?.iconName
        let colorHex = line?.subcategory?.colorHex ?? line?.category?.colorHex

        return ZStack {
            Circle()
                .fill(iconName != nil && colorHex != nil ? Color(hex: colorHex ?? "") : Color.secondary.opacity(0.2))
                .frame(width: 40, height: 40)
            Image(systemName: iconName ?? "questionmark")
                .font(DS.Typography.label)
                .foregroundStyle(iconName != nil && colorHex != nil ? Color.white : Color.secondary)
        }
        .accessibilityHidden(true)
    }

    // MARK: - Helpers

    private static let monthKeyParser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM"
        return formatter
    }()

    static func monthDate(_ key: String) -> Date? { monthKeyParser.date(from: key) }
}
