//
//  ScheduledPaymentRowView.swift
//  Yala
//
//  Fila de un pago planificado. Auditoría UX 2.2 · L10-1 B (Jürgen, 2026-10-15): bajo el nombre, una píldora rellena con
//  el estado de la fecha («Vence hoy», «En 4 días», «Vencido», «Pagado») y la fecha; el importe en color de texto y en
//  rosa solo si está vencido. Ya no dice «Mensual» en cada fila (el dato que menos cambia) ni esconde el estado en
//  letra de 11 pt.
//

import SwiftData
import SwiftUI

struct ScheduledPaymentRowView: View {
    let summary: ScheduledPaymentSummary
    let currencyCode: String

    @Environment(AppPreferences.self) private var appPreferences

    var body: some View {
        let state = summary.rowState
        NavigationLink(value: summary.payment.persistentModelID) {
            HStack(spacing: DS.Spacing.md) {
                paymentIcon
                    // Lo hecho, saltado o pausado, atenuado: lo que falta es lo que llama la atención.
                    .opacity(ScheduledPaymentListLogic.section(for: state) == .toPay ? 1 : 0.55)

                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(summary.payment.name)
                        .font(DS.Typography.label)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(spacing: DS.Spacing.xs) {
                        ScheduledPaymentStatusPill(state: state, isIncome: summary.payment.isIncome)
                        Text(ScheduledPaymentDateText.dayMonth(summary.dueDate))
                            .font(DS.Typography.captionSmall)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        if summary.payment.isGroupPayment {
                            // Gasto compartido (F6): la cuenta es solo un prefill, así que se dice que es compartido.
                            Image(systemName: "person.2.fill")
                                .font(DS.Typography.captionSmall)
                                .foregroundStyle(.secondary)
                                .accessibilityLabel(L10n.Scheduled.GroupExpense.sharedBadge)
                        }
                    }
                }

                Spacer(minLength: DS.Spacing.sm)

                Text(Self.amountText(summary, appPreferences: appPreferences))
                    .font(DS.Typography.headline)
                    .foregroundStyle(Self.amountColor(state: state, isIncome: summary.payment.isIncome))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .contentShape(Rectangle())
            .panelCard(small: true)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("scheduled_payment_row")
    }

    // MARK: - Components

    private var paymentIcon: some View {
        ZStack {
            Circle()
                .fill(Color(hex: summary.color))
                .frame(width: DS.Icon.badgeLarge, height: DS.Icon.badgeLarge)

            Image(systemName: summary.icon)
                .font(DS.Typography.label)
                .foregroundStyle(.white)
        }
        .accessibilityHidden(true)
    }

    // MARK: - Shared formatting (lista y línea de tiempo)

    /// «-S/ 45.00» (o «+» en un ingreso); con «≈» si el monto es estimado y aún no se pagó.
    static func amountText(_ summary: ScheduledPaymentSummary, appPreferences: AppPreferences) -> String {
        let prefix = summary.payment.isIncome ? "+" : "-"
        let isEstimate = summary.paidAmount == nil && summary.payment.isVariableAmount
        return prefix + appPreferences.currency(
            summary.displayAmount, currencyCode: summary.displayCurrencyCode,
            forceFullPrecision: true, isEstimate: isEstimate
        )
    }

    /// Color de texto; rosa solo lo vencido (L10-1). Un ingreso conserva su tono, el único que se colorea en una lista
    /// de movimientos. Lo pagado o saltado, en gris.
    static func amountColor(state: ScheduledPaymentRowState, isIncome: Bool) -> Color {
        switch state {
        case .paid, .skipped, .paused: return .secondary
        case .overdue: return isIncome ? Color.incomeAmount : Color.hotPink
        case .dueToday, .dueTomorrow, .dueInDays: return isIncome ? Color.incomeAmount : .primary
        }
    }
}
