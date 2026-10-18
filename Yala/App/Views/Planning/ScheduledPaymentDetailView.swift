//
//  ScheduledPaymentDetailView.swift
//  Yala
//
//  Detalle de un pago planificado. Auditoría UX 2.2, lote 10 (Jürgen, 2026-10-15):
//
//  - L10-8 B: arriba, el estado de la próxima fecha en una píldora («Vence mañana · 15 de octubre») y las dos acciones a
//    las que se viene: «Ya lo pagué» (relleno) y «Saltar este mes» (cristal). Sin «PEN» sobre el importe. Si el mes en
//    curso ya está pagado, lo dice. «Próximos» e «Historial», como la línea de tiempo de C: cada fecha con su estado y
//    sus acciones al lado. Fuera la nota de «fechas estimadas», que contradecía el «Pagado» real.
//  - L10-7 B: «Pausar este pago» / «Reanudar».
//  - L10-9 B: «Ya lo pagué» abre la hoja de «Apuntarlo ahora» o «Ya lo apunté».
//  - L10-10 B: «Saltar este mes» explica qué hace, y tras saltar un aviso deja deshacerlo; el inverso es «No saltar».
//  - L10-11 B: «Pagar ahora» dice qué fecha paga y vuelve aquí al guardar.
//  - L10-12 B: «Ver registro» abre el detalle del registro, con su «Editar».
//

import SwiftData
import SwiftUI

struct ScheduledPaymentDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences

    let payment: ScheduledPayment
    @Bindable var viewModel: ScheduledPaymentsViewModel

    @State private var showEditor = false
    @State private var linkedTransactions: [TransactionItem] = []
    /// La fecha cuya hoja de «Ya lo pagué» está abierta.
    @State private var paidSheetDate: OccurrenceTarget?
    /// El registro abierto con «Ver registro» (L10-12).
    @State private var viewedTransaction: TransactionItem?
    /// El registro que «Editar» del detalle pidió abrir al cerrarse la hoja del detalle.
    @State private var transactionAwaitingEditor: TransactionItem?
    @State private var editingTransaction: TransactionItem?
    /// El borrador de «Pagar ahora» o «Apuntarlo ahora» en el formulario de la Bandeja (L10-11).
    @State private var payNowTarget: PayNowTarget?

    // Fechas del calendario del pago (SSOT: `getPaymentDatesInMonth`). El historial son las que ya llegaron y las
    // próximas las que no, mire el mes que mire la lista (`ScheduledPaymentDetailLogic`).
    private var pastOccurrences: [Date] {
        ScheduledPaymentDetailLogic.pastOccurrences(selectedMonth: viewModel.selectedMonth, today: Date.now) { month in
            viewModel.getPaymentDatesInMonth(payment: payment, month: month)
        }
    }

    private var upcomingOccurrences: [Date] {
        guard payment.isRecurring else { return [] }
        return ScheduledPaymentDetailLogic.upcomingOccurrences(today: Date.now) { month in
            viewModel.getPaymentDatesInMonth(payment: payment, month: month)
        }
    }

    /// Qué gasto vinculado cubre cada fecha enseñada, con la regla de la lista (por mes y por orden).
    private var linkedByOccurrence: [Date: TransactionItem] {
        let occurrences = pastOccurrences + upcomingOccurrences
        let matches = ScheduledPaymentDetailLogic.linkedOccurrences(
            occurrences: occurrences,
            linkedDates: linkedTransactions.map(\.date),
            isSkipped: { payment.isDateSkipped($0) }
        )
        var result: [Date: TransactionItem] = [:]
        for (occurrenceIndex, txIndex) in matches {
            result[occurrences[occurrenceIndex]] = linkedTransactions[txIndex]
        }
        return result
    }

    /// La próxima fecha que de verdad toca: desde `nextDueDate`, la primera que no se saltó ni se pagó.
    private var nextDate: Date {
        ScheduledPaymentDetailLogic.nextDate(
            nextDueDate: payment.nextDueDate,
            linkedDates: linkedTransactions.map(\.date),
            isSkipped: { payment.isDateSkipped($0) }
        ) { month in
            viewModel.getPaymentDatesInMonth(payment: payment, month: month)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.xxl) {
                statusCard
                detailsCard

                if payment.isRecurring && !upcomingOccurrences.isEmpty {
                    occurrencesSection(
                        title: L10n.Scheduled.Detail.upcoming,
                        icon: "arrow.forward.circle.fill",
                        dates: upcomingOccurrences,
                        isPast: false
                    )
                }

                if !pastOccurrences.isEmpty {
                    occurrencesSection(
                        title: L10n.Scheduled.Detail.history,
                        icon: "clock.arrow.circlepath",
                        dates: pastOccurrences,
                        isPast: true
                    )
                }
            }
            .padding(.vertical, DS.Spacing.xxl)
        }
        .scrollViewGlassEdges()
        .yalaScreenBackground(.panel)
        .navigationTitle(payment.name)
        .navigationBarTitleDisplayMode(.inline)
        .swipeBack()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                YalaToolbarButton(systemName: "chevron.left", label: L10n.Action.back) {
                    dismiss()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                YalaToolbarButton(systemName: "pencil", label: L10n.Action.edit) {
                    showEditor = true
                }
            }
        }
        .modifier(DetailSheets(
            payment: payment,
            viewModel: viewModel,
            showEditor: $showEditor,
            paidSheetDate: $paidSheetDate,
            viewedTransaction: $viewedTransaction,
            transactionAwaitingEditor: $transactionAwaitingEditor,
            editingTransaction: $editingTransaction,
            payNowTarget: $payNowTarget,
            onRecordInForm: { openPayNow(for: $0, kind: .record) },
            onDelete: { dismiss() },
            onRefresh: refreshPaymentData
        ))
        .task {
            linkedTransactions = viewModel.fetchLinkedTransactions(for: payment)
        }
    }

    // MARK: - Estado y acciones (L10-8 B)

    /// Lo que enseña la píldora de arriba.
    private enum TopStatus {
        case date(ScheduledPaymentRowState, Date)
        case finished
    }

    private var topStatus: TopStatus {
        if payment.isPausedByUser { return .date(.paused, nextDate) }
        if payment.isScheduleFinished {
            return payment.isRecurring ? .finished : .date(.paid, payment.lastPaidDate ?? payment.nextDueDate)
        }
        let focus = payment.isRecurring ? nextDate : payment.nextDueDate
        let isPaid = linkedByOccurrence[focus] != nil
        return .date(rowState(for: focus, isPaid: isPaid, isSkipped: payment.isDateSkipped(focus)), focus)
    }

    private func rowState(for date: Date, isPaid: Bool, isSkipped: Bool) -> ScheduledPaymentRowState {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: .now), to: calendar.startOfDay(for: date)).day ?? 0
        // Pausado: las fechas que no se pagaron ni se saltaron dicen «Pausado», no «En 3 días» (L10-7).
        return ScheduledPaymentListLogic.rowState(
            isPaid: isPaid, isSkipped: isSkipped, isPaused: payment.isPausedByUser, daysUntilDue: days
        )
    }

    /// «Vence mañana · 15 de octubre», «Vencido · 14 de octubre», «Pagado · 1 de octubre», «Pausado».
    private func topPillText(_ status: TopStatus) -> String {
        switch status {
        case .finished:
            return L10n.UXL10.stateFinished
        case .date(let state, let date):
            let dateText = ScheduledPaymentDateText.dayMonthLong(date)
            switch state {
            case .overdue: return "\(L10n.UXL10.dueOverdue) · \(dateText)"
            case .dueToday: return L10n.UXL10.dueToday
            case .dueTomorrow: return "\(L10n.UXL10.dueTomorrow) · \(dateText)"
            case .dueInDays(let days): return "\(L10n.UXL10.dueInDays(days)) · \(dateText)"
            case .paid:
                return "\(payment.isIncome ? L10n.UXL10.stateReceived : L10n.UXL10.statePaid) · \(dateText)"
            case .skipped: return "\(L10n.UXL10.stateSkipped) · \(dateText)"
            case .paused: return L10n.UXL10.statePaused
            }
        }
    }

    private func topPillState(_ status: TopStatus) -> ScheduledPaymentRowState {
        switch status {
        case .finished: return .paused
        case .date(let state, _): return state
        }
    }

    /// El mes en curso ya está hecho: todas sus fechas pagadas o saltadas, y la próxima cae más adelante.
    private var currentMonthSettled: Bool {
        guard payment.isRecurring, payment.isActive else { return false }
        let calendar = Calendar.current
        let dates = viewModel.getPaymentDatesInMonth(payment: payment, month: .now)
        guard !dates.isEmpty, !calendar.isDate(nextDate, equalTo: .now, toGranularity: .month) else { return false }
        let linked = linkedByOccurrence
        return dates.allSatisfy { linked[$0] != nil || payment.isDateSkipped($0) }
    }

    private var statusCard: some View {
        let status = topStatus
        return VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            Text(topPillText(status))
                .font(DS.Typography.badgeLabel)
                .modifier(TopPillStyle(state: topPillState(status), accent: theme.accent))
                .accessibilityIdentifier("scheduled_detail_status")

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(formatAmount(payment.amount, isEstimate: payment.isVariableAmount))
                    .font(DS.Typography.largeTitle)
                    // Crece con el texto del sistema y, si un importe largo no cabe, se encoge en vez de cortarse.
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(payment.isIncome ? Color.incomeAmount : .primary)

                Text(subtitle)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)

                if payment.isVariableAmount {
                    Text(L10n.Scheduled.VariableAmount.badge)
                        .font(DS.Typography.caption)
                        .padding(.horizontal, DS.Spacing.sm)
                        .padding(.vertical, DS.Spacing.xxs)
                        .background(DS.Semantic.infoBackground)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                }

                if currentMonthSettled {
                    Label(
                        L10n.UXL10.monthAlreadyPaid(ScheduledPaymentDateText.monthYear(.now)),
                        systemImage: "checkmark.circle.fill"
                    )
                    .font(DS.Typography.label)
                    .foregroundStyle(theme.accent)
                    .accessibilityIdentifier("scheduled_detail_month_paid")
                }
            }

            actionButtons(status)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.xl)
        .solidCard(padding: 0, radius: DS.Panel.widgetRadius)
    }

    @ViewBuilder
    private func actionButtons(_ status: TopStatus) -> some View {
        if payment.isPausedByUser {
            filledButton(L10n.UXL10.actionResume, identifier: "scheduled_detail_resume_button") {
                viewModel.setPaused(payment, paused: false)
                refreshPaymentData()
            }
        } else if case .date(let state, let date) = status, state != .paid, state != .skipped {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack(spacing: DS.Spacing.md) {
                    filledButton(
                        payment.isIncome ? L10n.UXL10.actionReceived : L10n.UXL10.actionPaid,
                        identifier: "scheduled_detail_paid_button"
                    ) {
                        paidSheetDate = OccurrenceTarget(date: date)
                    }
                    if payment.isRecurring {
                        glassButton(L10n.UXL10.actionSkipMonth, identifier: "scheduled_detail_skip_button") {
                            skip(date)
                        }
                    }
                }
                if payment.isRecurring {
                    Text(L10n.UXL10.actionSkipHelp)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func filledButton(_ title: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(DS.Typography.bodyBold)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.md)
                .background(Capsule().fill(theme.accent))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    private func glassButton(_ title: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(DS.Typography.bodyBold)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.md)
                .glassEffect(.regular.interactive(), in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    /// «Mensual · Cuenta Principal · Telefonía».
    private var subtitle: String {
        var parts = [frequencyDescription]
        if !payment.isGroupPayment, let account = payment.account?.name { parts.append(account) }
        if let subcategory = payment.subcategory?.name { parts.append(subcategory) }
        return parts.joined(separator: " · ")
    }

    // MARK: - Ficha y pausa (L10-7)

    private var detailsCard: some View {
        VStack(spacing: DS.Spacing.md) {
            if payment.isRecurring {
                detailRow(icon: "calendar", label: L10n.Scheduled.Detail.nextDate, value: formatDate(nextDate))
                if let endDate = payment.endDate {
                    detailRow(icon: "calendar.badge.minus", label: L10n.Scheduled.Detail.endDate, value: formatDate(endDate))
                }
            } else {
                detailRow(icon: "calendar", label: L10n.Scheduled.Editor.paymentDate, value: formatDate(payment.nextDueDate))
            }

            if !payment.isScheduleFinished {
                Divider()
                if payment.isPausedByUser {
                    Text(L10n.UXL10.actionPauseHelp)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        glassButton(L10n.UXL10.actionPause, identifier: "scheduled_detail_pause_button") {
                            viewModel.setPaused(payment, paused: true)
                            refreshPaymentData()
                        }
                        Text(L10n.UXL10.actionPauseHelp)
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(DS.Spacing.xl)
        .solidCard(padding: 0, radius: DS.Panel.widgetRadius)
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(DS.Typography.body)
                .foregroundStyle(.secondary)
                .frame(width: 24)
                .accessibilityHidden(true)

            Text(label)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(DS.Typography.label)
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Fechas: estado y acciones por fecha (L10-8 C)

    private func occurrencesSection(title: String, icon: String, dates: [Date], isPast: Bool) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: icon)
                    .foregroundStyle(isPast ? Color.secondary : theme.accent)
                    .accessibilityHidden(true)
                Text(title)
                    .font(DS.Typography.subheadlineEmphasized)
                    .foregroundStyle(.primary)
            }
            .padding(.leading, DS.Spacing.xs)

            VStack(spacing: DS.Spacing.none) {
                ForEach(Array(dates.enumerated()), id: \.offset) { index, date in
                    occurrenceRow(date: date, isPast: isPast)
                    if index < dates.count - 1 {
                        SubsectionDivider()
                    }
                }
            }
            .panelCard()
        }
    }

    private func occurrenceRow(date: Date, isPast: Bool) -> some View {
        let isSkipped = payment.isDateSkipped(date)
        let linkedTx = linkedByOccurrence[date]
        let state = rowState(for: date, isPaid: linkedTx != nil, isSkipped: isSkipped)

        return Menu {
            occurrenceActions(date: date, state: state, linkedTx: linkedTx, isPast: isPast)
        } label: {
            HStack(spacing: DS.Spacing.md) {
                VStack(spacing: DS.Spacing.xxs) {
                    Text(ScheduledPaymentDateText.day(date))
                        .font(DS.Typography.title3.weight(.bold))
                        .foregroundStyle(state == .paid || state == .skipped ? .secondary : .primary)
                    Text(ScheduledPaymentDateText.monthAbbreviation(date))
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.tertiary)
                }
                .frame(width: 40)

                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(ScheduledPaymentDateText.full(linkedTx?.date ?? date))
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    ScheduledPaymentStatusPill(state: state, isIncome: payment.isIncome)
                }

                Spacer(minLength: DS.Spacing.sm)

                let displayAmount = linkedTx.map { abs($0.amount) } ?? payment.amount
                Text(formatAmount(displayAmount, isEstimate: linkedTx == nil && payment.isVariableAmount))
                    .font(DS.Typography.label)
                    .foregroundStyle(state == .overdue ? Color.hotPink : (state == .paid || state == .skipped ? .secondary : .primary))

                Image(systemName: "ellipsis.circle")
                    .font(DS.Typography.body)
                    .foregroundStyle(theme.accent)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(L10n.UXL10.dateActions)
        .accessibilityIdentifier("scheduled_occurrence")
    }

    @ViewBuilder
    private func occurrenceActions(date: Date, state: ScheduledPaymentRowState, linkedTx: TransactionItem?, isPast: Bool) -> some View {
        if state == .paid {
            if let linkedTx {
                Button {
                    viewedTransaction = linkedTx
                } label: {
                    Label(L10n.Scheduled.Detail.viewRecord, systemImage: "doc.text.magnifyingglass")
                }
                .accessibilityIdentifier("scheduled_view_record_button")
            }
            Button(role: .destructive) {
                viewModel.unlinkTransactionsForDate(paymentID: payment.id, date: linkedTx?.date ?? date)
                linkedTransactions = viewModel.fetchLinkedTransactions(for: payment)
            } label: {
                Label(L10n.Scheduled.Detail.unlink, systemImage: "minus.circle")
            }
        } else if state == .skipped {
            Button {
                viewModel.unskipOccurrence(payment: payment, date: date)
            } label: {
                Label(L10n.Scheduled.Detail.skipUndo, systemImage: "arrow.uturn.backward")
            }
            .accessibilityIdentifier("scheduled_unskip_button")
        } else {
            Button {
                paidSheetDate = OccurrenceTarget(date: date)
            } label: {
                Label(payment.isIncome ? L10n.UXL10.actionReceived : L10n.UXL10.actionPaid, systemImage: "checkmark.circle")
            }
            .accessibilityIdentifier("scheduled_mark_paid_button")
            // «Pagar ahora» solo en la próxima fecha que aún no llegó: pagar por adelantado (L10-11).
            let isFirstUpcoming = upcomingOccurrences.first.map { Calendar.current.isDate($0, inSameDayAs: date) } == true
            if !isPast, !payment.isGroupPayment, isFirstUpcoming || !payment.isRecurring {
                Button {
                    openPayNow(for: date, kind: .payNow)
                } label: {
                    Label(L10n.Scheduled.Detail.advance, systemImage: "arrow.uturn.backward.circle")
                }
                .accessibilityIdentifier("scheduled_pay_now_button")
            }
            if payment.isRecurring {
                Button {
                    skip(date)
                } label: {
                    Label {
                        Text(L10n.UXL10.actionSkip)
                        Text(L10n.UXL10.actionSkipHelp)
                    } icon: {
                        Image(systemName: "arrow.uturn.forward.circle")
                    }
                }
                .accessibilityIdentifier("scheduled_skip_button")
            }
        }
    }

    // MARK: - Acciones

    /// Salta la fecha y avisa con «Deshacer» (L10-10 B): explica sin añadir un paso a una acción que se puede deshacer.
    private func skip(_ date: Date) {
        viewModel.skipOccurrence(payment: payment, date: date)
        DraftDiscardUndoNotice.show(
            message: L10n.UXL10.skipped(ScheduledPaymentDateText.dayMonthLong(date)),
            systemImage: "arrow.uturn.forward.circle",
            undoTitle: L10n.Inbox.undoDiscard,
            noticeIdentifier: "scheduled_skip_notice",
            undoIdentifier: "scheduled_skip_undo"
        ) {
            viewModel.unskipOccurrence(payment: payment, date: date)
        }
    }

    /// «Pagar ahora» (adelantar, L10-11) o «Apuntarlo ahora» sin cuenta o subcategoría (L10-9).
    private enum PayNowKind { case payNow, record }

    /// Abre el formulario de la Bandeja para pagar esa fecha, con un título que la nombra.
    private func openPayNow(for date: Date, kind: PayNowKind) {
        guard let (draft, isNew) = viewModel.draftForPaying(payment, occurrence: date) else { return }
        let dateText = ScheduledPaymentDateText.dayMonthLong(date)
        let title = kind == .payNow ? L10n.UXL10.payNowTitle(dateText) : L10n.UXL10.recordTitle(dateText)
        payNowTarget = PayNowTarget(draft: draft, isNew: isNew, title: title)
    }

    /// Refresh linked transactions and recalculate payment data after sheet dismissal
    private func refreshPaymentData() {
        linkedTransactions = viewModel.fetchLinkedTransactions(for: payment)
        viewModel.reloadAndRecalculate()
    }

    // MARK: - Helpers

    private var frequencyDescription: String {
        ScheduledPaymentDetailLogic.frequencyText(
            isRecurring: payment.isRecurring,
            recurrenceType: payment.recurrenceType,
            interval: payment.recurrenceInterval
        )
    }

    private func formatAmount(_ amount: Double, isEstimate: Bool = false) -> String {
        appPreferences.currency(amount, currencyCode: payment.currencyCode, forceFullPrecision: true, isEstimate: isEstimate)
    }

    private func formatDate(_ date: Date) -> String {
        ScheduledPaymentDateText.medium(date)
    }
}

// MARK: - Tipos de presentación

/// Una fecha del pago, para `.sheet(item:)`.
struct OccurrenceTarget: Identifiable {
    let date: Date
    var id: Date { date }
}

/// El borrador que se abre en el formulario de la Bandeja para pagar una fecha.
struct PayNowTarget: Identifiable {
    let draft: InboxDraft
    /// Creado para esta vez: si se cierra sin guardar, se descarta.
    let isNew: Bool
    let title: String
    var id: PersistentIdentifier { draft.persistentModelID }
}

/// La píldora de arriba del detalle: los mismos colores que la de la lista, algo más grande.
private struct TopPillStyle: ViewModifier {
    let state: ScheduledPaymentRowState
    let accent: Color

    func body(content: Content) -> some View {
        content
            .foregroundStyle(foreground)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.xs)
            .background(Capsule().fill(fill))
    }

    private var fill: Color {
        switch state {
        case .overdue: return Color.hotPink
        case .dueToday: return Color.hotPink.opacity(0.18)
        case .dueTomorrow, .dueInDays: return accent.opacity(0.18)
        case .paid: return accent
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

/// Las hojas del detalle, fuera del `body` para que el compilador lo tipe por partes (regla del CI con Xcode 26.6).
private struct DetailSheets: ViewModifier {
    let payment: ScheduledPayment
    @Bindable var viewModel: ScheduledPaymentsViewModel
    @Binding var showEditor: Bool
    @Binding var paidSheetDate: OccurrenceTarget?
    @Binding var viewedTransaction: TransactionItem?
    @Binding var transactionAwaitingEditor: TransactionItem?
    @Binding var editingTransaction: TransactionItem?
    @Binding var payNowTarget: PayNowTarget?
    let onRecordInForm: (Date) -> Void
    let onDelete: () -> Void
    let onRefresh: () -> Void

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showEditor, onDismiss: onRefresh) {
                ScheduledPaymentEditorView(payment: payment, onDelete: onDelete)
            }
            .sheet(item: $paidSheetDate, onDismiss: onRefresh) { target in
                ScheduledPaymentPaidSheet(
                    payment: payment,
                    occurrence: target.date,
                    viewModel: viewModel,
                    onRecordInForm: { onRecordInForm(target.date) }
                )
            }
            // «Ver registro» abre el detalle del registro, el de Registros, con su «Editar» (L10-12).
            .sheet(item: $viewedTransaction, onDismiss: openAwaitingEditor) { transaction in
                TransactionDetailSheet(transaction: transaction) {
                    transactionAwaitingEditor = transaction
                    viewedTransaction = nil
                }
            }
            .sheet(item: $editingTransaction, onDismiss: onRefresh) { transaction in
                NewTransactionView(transactionToEdit: transaction)
                    .presentationDetents([.large])
            }
            .sheet(item: $payNowTarget, onDismiss: onRefresh) { target in
                InboxDraftEditSheet(draft: target.draft, payNowTitle: target.title)
                    .presentationDetents([.large])
                    .onDisappear {
                        if target.isNew { viewModel.discardUnusedPayNowDraft(target.draft) }
                    }
            }
    }

    private func openAwaitingEditor() {
        guard let transaction = transactionAwaitingEditor else { return }
        transactionAwaitingEditor = nil
        editingTransaction = transaction
    }
}
