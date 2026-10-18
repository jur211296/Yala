//
//  ScheduledPaymentStatusViews.swift
//  Yala
//
//  Piezas compartidas de Pagos planificados (auditoría UX 2.2, lote 10): la píldora de estado de una fecha (lista,
//  línea de tiempo y detalle) y la leyenda del calendario. Un color, un significado: índigo relleno = pagado, rosa
//  relleno = vencido, rosa suave = hoy, índigo suave = próximo, gris = saltado o pausado.
//

import SwiftUI

extension ScheduledPayment {
    /// Terminado: una sola vez ya pagado, o pasó su fecha de fin. No se puede reanudar.
    var isScheduleFinished: Bool {
        ScheduledPaymentListLogic.isFinished(
            isActive: isActive, isRecurring: isRecurring, lastPaidDate: lastPaidDate,
            nextDueDate: nextDueDate, endDate: endDate
        )
    }

    /// Pausado por la persona (L10-7).
    var isPausedByUser: Bool { !isActive && !isScheduleFinished }

    var isIncome: Bool { transactionType == "income" }
}

extension ScheduledPaymentSummary {
    /// El estado de esta fecha. Un pago de una sola vez ya terminado cuenta como pagado aunque su registro caiga en
    /// otro mes.
    var rowState: ScheduledPaymentRowState {
        ScheduledPaymentListLogic.rowState(
            isPaid: isPaidForMonth || (payment.isScheduleFinished && !payment.isRecurring),
            isSkipped: isSkippedForMonth,
            isPaused: payment.isPausedByUser,
            daysUntilDue: daysUntilDue
        )
    }
}

/// La píldora rellena con el estado de una fecha.
struct ScheduledPaymentStatusPill: View {
    let state: ScheduledPaymentRowState
    var isIncome: Bool = false

    @Environment(\.yalaTheme) private var theme

    var body: some View {
        Text(Self.text(for: state, isIncome: isIncome))
            .font(DS.Typography.badgeLabel)
            .foregroundStyle(foreground)
            .lineLimit(1)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xxs)
            .background(Capsule().fill(fill))
            .accessibilityIdentifier("scheduled_status_pill")
    }

    static func text(for state: ScheduledPaymentRowState, isIncome: Bool) -> String {
        switch state {
        case .overdue: return L10n.UXL10.stateOverdue
        case .dueToday: return L10n.UXL10.stateToday
        case .dueTomorrow: return L10n.UXL10.stateTomorrow
        case .dueInDays(let days): return L10n.UXL10.stateInDays(days)
        case .paid: return isIncome ? L10n.UXL10.stateReceived : L10n.UXL10.statePaid
        case .skipped: return L10n.UXL10.stateSkipped
        case .paused: return L10n.UXL10.statePaused
        }
    }

    private var fill: Color {
        switch state {
        case .overdue: return Color.hotPink
        case .dueToday: return Color.hotPink.opacity(0.18)
        case .dueTomorrow, .dueInDays: return theme.accent.opacity(0.18)
        case .paid: return theme.accent
        case .skipped, .paused: return Color(.tertiarySystemFill)
        }
    }

    private var foreground: Color {
        switch state {
        case .overdue, .paid: return .white
        case .dueToday, .dueTomorrow, .dueInDays: return .primary
        case .skipped, .paused: return .secondary
        }
    }
}

/// El color de un punto del calendario (L10-3).
extension ScheduledPaymentDotStatus {
    func color(accent: Color) -> Color {
        switch self {
        case .paid: return accent
        case .overdue: return Color.hotPink
        case .pending: return Color.secondary.opacity(0.45)
        }
    }
}

/// La leyenda de una línea bajo el calendario.
struct ScheduledPaymentCalendarLegend: View {
    @Environment(\.yalaTheme) private var theme

    var body: some View {
        HStack(spacing: DS.Spacing.lg) {
            item(.paid, L10n.UXL10.statePaid)
            item(.overdue, L10n.UXL10.stateOverdue)
            item(.pending, L10n.UXL10.statePending)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("scheduled_calendar_legend")
    }

    private func item(_ status: ScheduledPaymentDotStatus, _ label: String) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Circle().fill(status.color(accent: theme.accent)).frame(width: 8, height: 8)
                .accessibilityHidden(true)
            Text(label)
                .font(DS.Typography.captionSmall)
                .foregroundStyle(.secondary)
        }
    }
}
