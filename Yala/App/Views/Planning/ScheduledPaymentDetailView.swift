//
//  ScheduledPaymentDetailView.swift
//  Yala
//
//  Detail view for a scheduled payment showing history and upcoming occurrences.
//  Accessed from ScheduledPaymentsListView in Planning tab.
//

import SwiftData
import SwiftUI

struct ScheduledPaymentDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences
    @ScaledMetric(relativeTo: .largeTitle) private var scaledAmountSize: CGFloat = 36 // A11Y-DT: @ScaledMetric

    let payment: ScheduledPayment
    @Bindable var viewModel: ScheduledPaymentsViewModel

    @State private var showEditor = false
    @State private var showAssociationSheet = false
    @State private var showOccurrenceActions = false
    @State private var selectedOccurrenceDate: Date?
    @State private var associationReferenceDate: Date?
    @State private var linkedTransactions: [TransactionItem] = []
    @State private var editingTransaction: TransactionItem?
    @State private var advancedDraft: InboxDraft?

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

    /// La próxima fecha que de verdad toca: desde `nextDueDate`, la primera que no se saltó ni se pagó. Tras «Saltar»
    /// seguía diciendo la fecha saltada.
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
                    // Summary Card
                    summaryCard

                    // Upcoming Section
                    if payment.isRecurring && !upcomingOccurrences.isEmpty {
                        upcomingSection
                    }

                    // History Section
                    if !pastOccurrences.isEmpty {
                        historySection
                    }

                    // Info note
                    infoNote
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
        .sheet(isPresented: $showEditor) {
            ScheduledPaymentEditorView(payment: payment, onDelete: {
                dismiss()
            })
            .onDisappear(perform: refreshPaymentData)
        }
        .sheet(isPresented: $showAssociationSheet) {
            TransactionAssociationSheet(
                payment: payment,
                referenceDate: associationReferenceDate ?? viewModel.selectedMonth,
                viewModel: viewModel
            )
            .onDisappear(perform: refreshPaymentData)
        }
        .sheet(item: $editingTransaction) { transaction in
            NewTransactionView(transactionToEdit: transaction)
                .presentationDetents([.large])
                .onDisappear {
                    editingTransaction = nil
                    linkedTransactions = viewModel.fetchLinkedTransactions(for: payment)
                }
        }
        .sheet(item: $advancedDraft) { draft in
            InboxDraftEditSheet(draft: draft)
                .presentationDetents([.large])
                .onDisappear {
                    advancedDraft = nil
                    linkedTransactions = viewModel.fetchLinkedTransactions(for: payment)
                }
        }
        .task {
            linkedTransactions = viewModel.fetchLinkedTransactions(for: payment)
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(spacing: DS.Spacing.lg) {
            // Amount
            VStack(spacing: DS.Spacing.xs) {
                Text(payment.currencyCode)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)

                Text(formatAmount(payment.amount, isEstimate: payment.isVariableAmount))
                    .font(DS.Typography.largeTitle)
                    // Crece con el texto del sistema y, si un importe largo no cabe en el ancho, se encoge en
                    // vez de cortarse. Sustituye al tope en AX1, que lo dejaba pequeño a propósito.
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(payment.transactionType == "income" ? Color.electricIndigo : .primary)

                if payment.isVariableAmount {
                    Text(L10n.Scheduled.VariableAmount.badge)
                        .font(DS.Typography.caption)
                        .padding(.horizontal, DS.Spacing.sm)
                        .padding(.vertical, DS.Spacing.xxs)
                        .background(DS.Semantic.infoBackground)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                }
            }

            Divider()
                .padding(.horizontal, DS.Spacing.xl)

            // Details grid
            VStack(spacing: DS.Spacing.md) {
                detailRow(
                    icon: "repeat",
                    label: L10n.Scheduled.Detail.frequency,
                    value: frequencyDescription
                )

                if payment.isRecurring {
                    detailRow(
                        icon: "calendar",
                        label: L10n.Scheduled.Detail.nextDate,
                        value: formatDate(nextDate)
                    )

                    if let endDate = payment.endDate {
                        detailRow(
                            icon: "calendar.badge.minus",
                            label: L10n.Scheduled.Detail.endDate,
                            value: formatDate(endDate)
                        )
                    }
                } else {
                    detailRow(
                        icon: "calendar",
                        label: L10n.Scheduled.Editor.paymentDate,
                        value: formatDate(payment.nextDueDate)
                    )
                }

                if let account = payment.account {
                    detailRow(
                        icon: "creditcard",
                        label: L10n.Scheduled.Editor.account,
                        value: account.name
                    )
                }

                if let subcategory = payment.subcategory {
                    detailRow(
                        icon: "tag",
                        label: L10n.Scheduled.Editor.subcategory,
                        value: subcategory.name
                    )
                }
            }

            // Status
            if !payment.isActive {
                HStack {
                    Image(systemName: "pause.circle.fill")
                        .foregroundStyle(Color.hotPink)
                        .accessibilityHidden(true)
                    Text(L10n.Scheduled.Detail.statusInactive)
                        .font(DS.Typography.label)
                        .foregroundStyle(Color.hotPink)
                }
                .padding(.top, DS.Spacing.sm)
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

    // MARK: - Upcoming Section

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "arrow.forward.circle.fill")
                    .foregroundStyle(.thAccent)
                    .accessibilityHidden(true)
                Text(L10n.Scheduled.Detail.upcoming)
                    .font(DS.Typography.subheadlineEmphasized)
                    .foregroundStyle(.primary)
            }
            .padding(.leading, DS.Spacing.xs)

            VStack(spacing: DS.Spacing.none) {
                ForEach(Array(upcomingOccurrences.enumerated()), id: \.offset) { index, date in
                    occurrenceRow(date: date, isPast: false, index: index + 1)

                    if index < upcomingOccurrences.count - 1 {
                        SubsectionDivider()
                    }
                }
            }
            .panelCard()
        }
    }

    // MARK: - History Section

    private var historySection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text(L10n.Scheduled.Detail.history)
                    .font(DS.Typography.subheadlineEmphasized)
                    .foregroundStyle(.primary)
            }
            .padding(.leading, DS.Spacing.xs)

            VStack(spacing: DS.Spacing.none) {
                ForEach(Array(pastOccurrences.enumerated()), id: \.offset) { index, date in
                    occurrenceRow(date: date, isPast: true, index: nil)

                    if index < pastOccurrences.count - 1 {
                        SubsectionDivider()
                    }
                }
            }
            .panelCard()
        }
    }

    private func occurrenceRow(date: Date, isPast: Bool, index: Int?) -> some View {
        let isSkipped = payment.isDateSkipped(date)
        // Derive paid status from actual linked transaction (works across all months)
        let rowLinkedTx = linkedByOccurrence[date]
        let isPaidForDate = rowLinkedTx != nil

        // Binding: true only when THIS row's date is the selected one
        let isDialogPresented = Binding<Bool>(
            get: { showOccurrenceActions && selectedOccurrenceDate.map { Calendar.current.isDate($0, inSameDayAs: date) } == true },
            set: { newValue in
                if !newValue {
                    showOccurrenceActions = false
                    selectedOccurrenceDate = nil
                }
            }
        )

        return Button {
            selectedOccurrenceDate = date
            showOccurrenceActions = true
        } label: {
            HStack(spacing: DS.Spacing.md) {
                // Date indicator
                VStack(spacing: DS.Spacing.xxs) {
                    Text(dayOfMonth(date))
                        .font(DS.Typography.title3.weight(.bold))
                        .foregroundStyle(isSkipped || isPast ? .secondary : .primary)
                    Text(monthAbbrev(date))
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.tertiary)
                }
                .frame(width: 40)

                // Full date + status (show real date from linked transaction if paid)
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    let displayDate = rowLinkedTx?.date ?? date
                    Text(formatFullDate(displayDate))
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(isSkipped || isPast ? .secondary : .primary)

                    if isSkipped {
                        HStack(spacing: DS.Spacing.xxs) {
                            Image(systemName: "arrow.uturn.forward.circle")
                                .font(DS.Typography.captionSmall)
                            Text(L10n.Scheduled.Detail.statusSkipped)
                                .font(DS.Typography.captionSmall)
                        }
                        .foregroundStyle(.secondary)
                    } else if isPaidForDate {
                        HStack(spacing: DS.Spacing.xxs) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(DS.Typography.captionSmall)
                            Text(L10n.Scheduled.Detail.statusPaid)
                                .font(DS.Typography.captionSmall)
                        }
                        .foregroundStyle(theme.accent)
                    } else if isPast {
                        HStack(spacing: DS.Spacing.xxs) {
                            Image(systemName: "exclamationmark.circle")
                                .font(DS.Typography.captionSmall)
                            Text(L10n.Scheduled.Detail.statusOverdue)
                                .font(DS.Typography.captionSmall)
                        }
                        .foregroundStyle(Color.hotPink)
                    } else if let idx = index {
                        Text(ordinalText(idx))
                            .font(DS.Typography.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                // Amount + chevron (show real amount from linked transaction if available)
                HStack(spacing: DS.Spacing.sm) {
                    let displayAmount = rowLinkedTx.map { abs($0.amount) } ?? payment.amount
                    let isEstimateRow = rowLinkedTx == nil && payment.isVariableAmount
                    Text(formatAmount(displayAmount, isEstimate: isEstimateRow))
                        .font(DS.Typography.label)
                        .foregroundStyle(isSkipped ? .secondary : (isPast ? .secondary : (payment.transactionType == "income" ? Color.electricIndigo : .primary)))

                    Image(systemName: "chevron.right")
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("scheduled_occurrence")
        .opacity(isSkipped ? 0.6 : 1.0)
        .confirmationDialog(
            formatFullDate(date),
            isPresented: isDialogPresented,
            titleVisibility: .visible
        ) {
            if isPaidForDate {
                if let linkedTx = rowLinkedTx {
                    Button {
                        editingTransaction = linkedTx
                    } label: {
                        Label(L10n.Scheduled.Detail.viewRecord, systemImage: "doc.text.magnifyingglass")
                    }
                }
                Button(role: .destructive) {
                    unlinkTransactionsForDate(date)
                } label: {
                    Label(L10n.Scheduled.Detail.unlink, systemImage: "minus.circle")
                }
            } else if isSkipped {
                Button(L10n.Scheduled.Detail.skipUndo) {
                    viewModel.unskipOccurrence(payment: payment, date: date)
                }
                .accessibilityIdentifier("scheduled_unskip_button")
            } else {
                // "Adelantar gasto" for upcoming (not past) occurrences
                if !isPast {
                    let isFirstUpcoming = upcomingOccurrences.first.map { Calendar.current.isDate($0, inSameDayAs: date) } == true
                    if isFirstUpcoming || !payment.isRecurring {
                        Button {
                            if let draft = viewModel.advanceOccurrence(payment: payment) {
                                advancedDraft = draft
                            }
                        } label: {
                            Label(L10n.Scheduled.Detail.advance, systemImage: "arrow.uturn.backward.circle")
                        }
                    }
                }
                Button {
                    associationReferenceDate = date
                    showAssociationSheet = true
                } label: {
                    Label(L10n.Scheduled.Detail.associateTitle, systemImage: "link.badge.plus")
                }
                Button(L10n.Scheduled.Detail.skip, role: .destructive) {
                    viewModel.skipOccurrence(payment: payment, date: date)
                }
                .accessibilityIdentifier("scheduled_skip_button")
            }
        }
    }

    /// Refresh linked transactions and recalculate payment data after sheet dismissal
    private func refreshPaymentData() {
        linkedTransactions = viewModel.fetchLinkedTransactions(for: payment)
        viewModel.reloadAndRecalculate()
    }

    /// Unlink transactions associated with this payment for a specific date
    private func unlinkTransactionsForDate(_ date: Date) {
        viewModel.unlinkTransactionsForDate(paymentID: payment.id, date: date)
        linkedTransactions = viewModel.fetchLinkedTransactions(for: payment)
    }

    // MARK: - Info Note

    private var infoNote: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "info.circle")
                .font(DS.Typography.body)
                .foregroundStyle(.thAccent)
                .accessibilityHidden(true)

            Text(L10n.Scheduled.Detail.infoNote)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(theme.accent.opacity(0.1))
        )
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

    // Fechas en el idioma de la app y con la plantilla del idioma: «miércoles, 14 de octubre de 2026», no
    // «14 octubre 2026» en el idioma del sistema.
    private func formatDate(_ date: Date) -> String {
        ScheduledPaymentDateText.medium(date)
    }

    private func formatFullDate(_ date: Date) -> String {
        ScheduledPaymentDateText.full(date)
    }

    private func dayOfMonth(_ date: Date) -> String {
        ScheduledPaymentDateText.day(date)
    }

    private func monthAbbrev(_ date: Date) -> String {
        ScheduledPaymentDateText.monthAbbreviation(date)
    }

    private func ordinalText(_ n: Int) -> String {
        switch n {
        case 1: return L10n.Scheduled.Detail.nextFirst
        case 2: return L10n.Scheduled.Detail.nextSecond
        case 3: return L10n.Scheduled.Detail.nextThird
        default: return ""
        }
    }

}

#Preview {
    NavigationStack {
        Text("Preview requires ScheduledPayment instance")
    }
}
