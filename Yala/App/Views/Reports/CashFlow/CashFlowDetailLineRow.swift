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
//  Límites con pagos y monedas (encargo del 2026-11-20, pregunta `fila`, opción A): la cifra sigue en la moneda del flujo
//  y, bajo el nombre, el original («⇄ 500.00 USD») y, en una línea de pagos, «4 pagos + extra». VoiceOver lee «Renta,
//  límite S/ 1,850.00, 500.00 USD convertidos».
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
                        limitCaption
                    }
                } trailing: {
                    trailingFigure
                }

                if let real = lineResult.realAmount, hasRealData, lineResult.plannedAmount > 0 {
                    // Mes en curso: lo real sólido y lo que falta rayado (decisión 31 de 2.3). Cerrado o superado, la
                    // barra de siempre.
                    if let segments = CashFlowRealEstimateBarLogic.segments(
                        real: real, planned: lineResult.plannedAmount, isCurrentMonth: month.isCurrent
                    ) {
                        CashFlowRealEstimateBar(segments: segments)
                    } else {
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
            }
            .padding(DS.Spacing.lg)
            .contentShape(Rectangle())
            .solidCard(radius: DS.Radius.md)
        }
        .buttonStyle(.plain)
        .pointerHighlight(cornerRadius: DS.Radius.md)
        .modifier(OriginalAccessibility(label: originalAccessibilityLabel))
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

    // MARK: - Pagos y moneda del límite

    /// El original en otra moneda que se enseña bajo el nombre.
    private var originalText: String? {
        guard let original = lineResult.limitBreakdown?.original else { return nil }
        return FlujoMonedaTexto.original(original.monto, moneda: original.moneda)
    }

    /// «4 pagos + extra» en una línea de pagos.
    private var paymentsText: String? {
        guard let desglose = lineResult.limitBreakdown, lineResult.estimationMethod == .scheduled else { return nil }
        let cuantos = desglose.pagos.filter { $0.estado != .noEsta }.count
        guard cuantos > 1 || desglose.extra != nil else { return nil }
        return L10n.FlujoDetalleLinea.filaPagos(cuantos, conExtra: desglose.extra != nil)
    }

    @ViewBuilder
    private var limitCaption: some View {
        if originalText != nil || paymentsText != nil {
            HStack(spacing: DS.Spacing.sm) {
                if let originalText {
                    Label(originalText, systemImage: "arrow.left.arrow.right")
                        .labelStyle(.titleAndIcon)
                        .accessibilityIdentifier("cashflow_line_original")
                }
                if let paymentsText {
                    Text(paymentsText)
                        .accessibilityIdentifier("cashflow_line_payments_count")
                }
            }
            .font(DS.Typography.captionSmall)
            .foregroundStyle(.secondary)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)
        }
    }

    /// «Renta, límite S/ 1,850.00, 500.00 USD convertidos»: solo con un original en otra moneda.
    private var originalAccessibilityLabel: String? {
        guard let originalText else { return nil }
        let lectura = L10n.FlujoDetalleLinea.filaAccesible(
            lineResult.name,
            limite: appPreferences.currency(lineResult.plannedAmount, currencyCode: currencyCode,
                                            isEstimate: lineResult.isPlannedApproximate),
            original: originalText, esIngreso: lineResult.isIncome
        )
        // Lo que la fila enseña a la derecha («Te pasaste por…», «Estimado que falta…») también se lee.
        return trailingSummary.map { "\(lectura), \($0)" } ?? lectura
    }

    /// El rótulo y la cifra de la derecha de un mes con registros, como texto.
    private var trailingSummary: String? {
        guard hasRealData, let real = lineResult.realAmount else { return nil }
        let overBy = lineResult.plannedAmount - real
        let remaining = month.isCurrent && overBy >= 0 ? lineResult.expectedAmount - real : overBy
        let isOver = remaining < 0
        let fullyReceived = (lineResult.isIncome || month.isCurrent) && abs(remaining) < 0.005
        let label = fullyReceived ? L10n.CashFlowPlan.realIncome : trailingLabel(isOver: isOver)
        return "\(label), \(appPreferences.currency(fullyReceived ? real : abs(remaining), currencyCode: currencyCode))"
    }

    /// Pone la lectura de VoiceOver de una fila con original; sin él, deja la de siempre (la de sus textos).
    private struct OriginalAccessibility: ViewModifier {
        let label: String?
        func body(content: Content) -> some View {
            if let label {
                content.accessibilityElement(children: .combine).accessibilityLabel(label)
            } else {
                content
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
            // En el mes en curso, «Estimado que falta» es lo que el mes suma todavía en esta línea (motor del mes,
            // 18-nov-2026): lo fechado, lo pendiente y lo que le queda, ya sin lo anotado en su categoría madre. Así la
            // fila dice lo mismo que el total del mes.
            let overBy = lineResult.plannedAmount - real
            let remaining = month.isCurrent && overBy >= 0 ? lineResult.expectedAmount - real : overBy
            let isOver = remaining < 0
            // Un ingreso cobrado entero dice «Real» y lo cobrado, no «Te falta recibir S/ 0.00»; en el mes en curso, un
            // gasto ya hecho entero tampoco dice «Estimado que falta S/ 0.00» (decisión 31 de 2.3).
            let fullyReceived = (lineResult.isIncome || month.isCurrent) && abs(remaining) < 0.005
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
        // Lo que falta en el mes en curso es una estimación: «Estimado que falta», la misma palabra que el resto de lo
        // estimado de la zona (decisión 31 de 2.3). Pasarse o recibir de más ya es real.
        if month.isCurrent && !isOver { return L10n.CashFlowPlan.estimateLeft }
        if lineResult.isIncome {
            return isOver ? L10n.UXL18.receivedExtra : L10n.UXL18.toReceive
        }
        return Self.expenseLabel(isOver: isOver, monthIsPast: month.isPast)
    }

    /// Un gasto por debajo de lo planeado en un mes que ya cerró dice «Te sobró», no «Te quedan»: ese dinero ya no se
    /// puede gastar en ese mes. Mismo criterio que el período cerrado de Presupuestos (`BudgetRemainingLogic`).
    static func expenseLabel(isOver: Bool, monthIsPast: Bool) -> String {
        if isOver { return L10n.UXL9.overLabel }
        return monthIsPast ? L10n.UXL9.leftoverLabel : L10n.UXL9.remainingLabel
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
