//
//  CashFlowCellDetailSheet.swift
//  Yala
//
//  Rich detail sheet for a cash flow line cell.
//  3 variants: current month (chart + transactions), past month (comparison),
//  future month (estimation + adjust). Timeline navigable within sheet.
//
//  Auditoría UX 2.2 · lote 18 decidido:
//  - L18-7 (opción B): «Cómo se calcula: Promedio 6 meses · Cambiar» (abre el mismo selector que crear el plan) y, al
//    final, «Eliminar línea» a la vista. El método ya no se pinta en el color de los enlaces.
//  - L18-8 (opción A): «y los siguientes» guarda desde qué mes vale el monto nuevo; aquí se ve «Desde noviembre: S/ X
//    cada mes».
//  - L18-9 (opción C): el campo dice «Monto para noviembre», «Guardar» va también en la barra sobre el teclado y la
//    pregunta nombra el mes («¿Solo noviembre, o noviembre y los siguientes?»).
//  - Lienzo «Una sola Yala»: «Últimos registros» con la fila de Registros (y se puede tocar), la barra de Presupuestos.
//

import Charts
import SwiftData
import SwiftUI

struct CashFlowCellDetailSheet: View {
    let lineResult: CashFlowLineResult
    let line: CashFlowLine?
    let month: CashFlowMonth
    let currencyCode: String
    let transactions: [TransactionItem]
    @Bindable var viewModel: CashFlowPlanViewModel

    @Environment(\.dismiss) private var dismiss
    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences

    // Local navigation state (resets on dismiss)
    @State private var activeMonthKey: String = ""

    @State private var showAdjustAmount = false
    @State private var adjustAmountText = ""
    @State private var adjustNote = ""
    @FocusState private var amountFieldFocused: Bool

    @State private var showOverrideScopeAlert = false
    @State private var pendingOverrideAmount: Double = 0
    @State private var pendingOverrideNote: String = ""
    @State private var pendingOverrideLine: CashFlowLine?
    @State private var pendingOverrideMonthKey: String = ""

    @State private var methodPickerLine: SuggestedLine?
    @State private var showDeleteLineAlert = false

    @State private var detailTransaction: TransactionItem?
    @State private var editingTransaction: TransactionItem?
    @State private var recordAwaitingEditor: TransactionItem?

    // Derived from activeMonthKey
    private var activeMonth: CashFlowMonth? {
        viewModel.projection?.months.first { $0.monthKey == activeMonthKey }
    }

    private var activeLineResult: CashFlowLineResult? {
        guard let m = activeMonth else { return nil }
        let all = m.incomeLines + m.expenseLines
        return all.first { $0.lineID == lineResult.lineID }
    }

    private var activeTransactions: [TransactionItem] {
        guard let m = activeMonth else { return [] }
        let calendar = Calendar.current
        return transactions
            .filter { tx in
                let txKey = CashFlowProjectionCalculator.monthKey(for: tx.date, calendar: calendar)
                guard txKey == m.monthKey else { return false }
                if let sub = line?.subcategory {
                    return tx.subcategory?.persistentModelID == sub.persistentModelID
                }
                if let cat = line?.category {
                    return tx.category?.persistentModelID == cat.persistentModelID
                }
                return false
            }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                if let m = activeMonth, let lr = activeLineResult {
                    VStack(spacing: DS.Spacing.xl) {
                        if m.isCurrent {
                            currentMonthContent(m: m, lr: lr)
                        } else if m.isPast {
                            pastMonthContent(m: m, lr: lr)
                        } else {
                            futureMonthContent(m: m, lr: lr)
                        }
                        deleteLineButton
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.xl)
                    .yalaSafeBottomPadding()
                    .dismissKeyboardOnTap()
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .accessibilityIdentifier("cashflow_cell_detail")
            .yalaScreenBackground(.subtle)
            .navigationTitle(lineResult.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }
                // L18-9: «Guardar» sobre el teclado; el teclado numérico tapaba el botón de abajo.
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(L10n.Action.save) {
                        saveAdjustment()
                    }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("cashflow_adjust_keyboard_save")
                }
            }
        }
        .presentationDetents([.large])
        .onAppear { activeMonthKey = month.monthKey }
        // El título nombra el mes (L18-9). Los botones van literales: un texto que dependa del estado en el `actions`
        // de una alerta rompió flujos ajenos (`swiftui-ds.md`).
        .alert(L10n.UXL18.scopeQuestion(monthName(pendingOverrideMonthKey)), isPresented: $showOverrideScopeAlert) {
            Button(L10n.UXL18.scopeOnlyThatMonth) {
                if let line = pendingOverrideLine {
                    viewModel.setOverride(line: line, monthKey: pendingOverrideMonthKey, amount: pendingOverrideAmount, note: pendingOverrideNote)
                }
                dismiss()
            }
            .accessibilityIdentifier("cashflow_scope_only_month")
            Button(L10n.UXL18.scopeAlsoFollowing) {
                if let line = pendingOverrideLine {
                    viewModel.setAmountFromMonthOnward(line: line, monthKey: pendingOverrideMonthKey, amount: pendingOverrideAmount)
                }
                dismiss()
            }
            .accessibilityIdentifier("cashflow_scope_also_following")
            Button(L10n.Action.cancel, role: .cancel) { }
        }
        .alert(L10n.CashFlowPlan.deleteLineConfirmation, isPresented: $showDeleteLineAlert) {
            Button(L10n.Action.delete, role: .destructive) {
                if let line {
                    viewModel.removeLine(line)
                }
                dismiss()
            }
            .accessibilityIdentifier("cashflow_detail_delete_confirm")
            Button(L10n.Action.cancel, role: .cancel) { }
        }
        .sheet(item: $methodPickerLine) { suggestion in
            CashFlowMethodPickerSheet(line: suggestion, currencyCode: currencyCode, viewModel: viewModel) { method, manual in
                if let line {
                    viewModel.changeEstimationMethod(line: line, to: method, manualAmount: manual)
                }
            }
        }
        // `item:` y no `isPresented:` + un `@State` aparte (regla de `swiftui-ds.md`): con el segundo la hoja salía vacía.
        .sheet(item: $detailTransaction, onDismiss: handleRecordDetailDismiss) { transaction in
            TransactionDetailSheet(
                transaction: transaction,
                onEdit: {
                    recordAwaitingEditor = transaction
                    detailTransaction = nil
                }
            )
        }
        .sheet(item: $editingTransaction) { transaction in
            NewTransactionView(transactionToEdit: transaction)
                .presentationDetents([.large])
        }
    }

    private func handleRecordDetailDismiss() {
        if let record = recordAwaitingEditor {
            recordAwaitingEditor = nil
            editingTransaction = record
        }
    }

    // MARK: - Header

    private func headerInfo(m: CashFlowMonth) -> some View {
        HStack(spacing: DS.Spacing.md) {
            categoryIcon
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(lineResult.name)
                    .font(DS.Typography.headline)
                Text(m.date.formatted(.dateTime.month(.wide).year()))
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var categoryIcon: some View {
        let iconName = line?.subcategory?.iconName ?? line?.category?.iconName
        let colorHex = line?.subcategory?.colorHex ?? line?.category?.colorHex
        let hasIcon = iconName != nil && colorHex != nil

        return ZStack {
            Circle()
                .fill(hasIcon ? Color(hex: colorHex ?? "") : Color.secondary.opacity(0.2))
                .frame(width: DS.Icon.badgeLarge, height: DS.Icon.badgeLarge)
            Image(systemName: iconName ?? "questionmark")
                .font(.system(size: DS.Icon.sizeLarge, weight: .semibold))
                .foregroundStyle(hasIcon ? Color.white : Color.secondary)
        }
        .accessibilityHidden(true)
    }

    // MARK: - Cómo se calcula (L18-7)

    /// «Cómo se calcula: Promedio 6 meses · Cambiar», su explicación y, si la línea tiene un cambio «desde este mes»
    /// que vale aquí, «Desde noviembre: S/ 9,000 cada mes» (L18-8).
    private func methodSection(lr: CashFlowLineResult) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(spacing: DS.Spacing.xs) {
                Text(L10n.UXL18.howItsCalculated)
                    .font(DS.Typography.label)
                    .foregroundStyle(.secondary)
                Spacer(minLength: DS.Spacing.sm)
                Text(lr.estimationMethod.displayName)
                    .font(DS.Typography.label)
                    .foregroundStyle(.primary)
                    .accessibilityIdentifier("cashflow_detail_method")
                if line != nil {
                    Button {
                        openMethodPicker(lr: lr)
                    } label: {
                        Text("· " + L10n.UXL18.change)
                            .font(DS.Typography.label.weight(.semibold))
                            .foregroundStyle(theme.accent)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.UXL18.change)
                    .accessibilityIdentifier("cashflow_detail_change_method")
                }
            }
            Text(lr.estimationMethod.descriptionText)
                .font(DS.Typography.captionSmall)
                .foregroundStyle(.secondary)
            if let from = lr.amountChangeFromMonthKey {
                Text(L10n.UXL18.changeFrom(
                    monthName(from),
                    appPreferences.currency(lr.plannedAmount, currencyCode: currencyCode)
                ))
                .font(DS.Typography.captionSmall)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("cashflow_detail_change_from")
            }
            if lr.isOverride {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "pencil.circle.fill")
                        .foregroundStyle(.secondary)
                    Text(L10n.CashFlowPlan.cellDetailOverrideActive)
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func openMethodPicker(lr: CashFlowLineResult) {
        guard let line else { return }
        viewModel.prepareMethodPreviews(transactions: transactions, currencyCode: currencyCode)
        methodPickerLine = SuggestedLine(
            category: line.category,
            subcategory: line.subcategory,
            scheduledPayment: line.scheduledPayment,
            name: line.name,
            isIncome: line.isIncome,
            suggestedAmount: line.method == .manual ? (line.manualAmount ?? lr.plannedAmount) : lr.plannedAmount,
            estimationMethod: line.method,
            monthsWithActivity: 0,
            isSelected: true
        )
    }

    // MARK: - Current Month

    private func currentMonthContent(m: CashFlowMonth, lr: CashFlowLineResult) -> some View {
        VStack(spacing: DS.Spacing.xl) {
            currentProgressCard(m: m, lr: lr)

            if !activeTransactions.isEmpty {
                CashFlowCellMiniChart(
                    transactions: activeTransactions,
                    plannedAmount: lr.plannedAmount,
                    month: m,
                    currencyCode: currencyCode,
                    isIncome: lr.isIncome
                )
                .solidCard()
            }

            monthTimeline

            if !activeTransactions.isEmpty {
                recentTransactionsCard
            }

            adjustAmountButton(m: m, lr: lr)
        }
    }

    private func currentProgressCard(m: CashFlowMonth, lr: CashFlowLineResult) -> some View {
        VStack(spacing: DS.Spacing.md) {
            headerInfo(m: m)

            Divider()

            HStack(alignment: .firstTextBaseline) {
                AmountText(
                    value: lr.realAmount ?? 0,
                    currencyCode: currencyCode,
                    font: DS.Typography.title.weight(.bold).monospacedDigit()
                )
                Text(L10n.CashFlowPlan.cellDetailOf)
                    .font(DS.Typography.body)
                    .foregroundStyle(.secondary)
                AmountText(
                    value: lr.plannedAmount,
                    currencyCode: currencyCode,
                    font: DS.Typography.body.monospacedDigit(),
                    tint: .secondary,
                    isEstimate: lr.isPlannedApproximate
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let progress = lr.progress {
                VStack(spacing: DS.Spacing.xs) {
                    BudgetProgressBar(
                        percentage: progress * 100,
                        color: "",
                        isExceeded: CashFlowLineSideLogic.progressIsAlarm(progress: progress, isIncome: lr.isIncome),
                        simplified: true
                    )

                    HStack {
                        Text("\(Int(min(progress, 9.99) * 100))%")
                            .font(DS.Typography.captionSmall)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        Spacer()
                        let remaining = lr.plannedAmount - (lr.realAmount ?? 0)
                        if remaining > 0 {
                            // En un ingreso lo que falta no es dinero que te queda: es lo que aún no recibiste.
                            let remainingText = appPreferences.currency(remaining, currencyCode: currencyCode)
                            Text(lr.isIncome
                                ? L10n.CashFlowPlan.cellDetailPendingIncome(remainingText)
                                : L10n.CashFlowPlan.cellDetailRemaining(remainingText))
                                .font(DS.Typography.captionSmall)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Divider()

            methodSection(lr: lr)
        }
        .padding(DS.Spacing.lg)
        .solidCard()
    }

    // MARK: - Past Month

    private func pastMonthContent(m: CashFlowMonth, lr: CashFlowLineResult) -> some View {
        VStack(spacing: DS.Spacing.xl) {
            VStack(spacing: DS.Spacing.md) {
                headerInfo(m: m)

                Divider()

                if let real = lr.realAmount, let diff = lr.difference {
                    let isGood = lr.isIncome ? diff >= 0 : diff <= 0
                    let verb = lr.isIncome ? L10n.CashFlowPlan.cellDetailEarned : L10n.CashFlowPlan.cellDetailSpent
                    let diffAbs = abs(diff)
                    let percent = lr.differencePercent.map { abs($0) } ?? 0

                    VStack(spacing: DS.Spacing.sm) {
                        Text("\(verb) \(appPreferences.currency(real, currencyCode: currencyCode)) vs \(L10n.CashFlowPlan.plan.lowercased()) \(appPreferences.currency(lr.plannedAmount, currencyCode: currencyCode))")
                            .font(DS.Typography.body)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: isGood ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                .foregroundStyle(isGood ? Color.electricIndigo : Color.hotPink)
                            Text("\(appPreferences.currency(diffAbs, currencyCode: currencyCode)) \(diff > 0 ? L10n.CashFlowPlan.cellDetailMore : L10n.CashFlowPlan.cellDetailLess) (\(String(format: "%.1f", percent))%)")
                                .font(DS.Typography.subheadline)
                                .foregroundStyle(isGood ? Color.electricIndigo : Color.hotPink)
                            Spacer()
                        }
                    }

                    Divider()

                    detailRow(label: L10n.CashFlowPlan.plan, value: lr.plannedAmount, isEstimate: lr.isPlannedApproximate)
                    detailRow(label: lr.isIncome ? L10n.CashFlowPlan.realIncome : L10n.CashFlowPlan.real, value: real)
                    detailRow(label: L10n.CashFlowPlan.difference, value: diff, color: isGood ? Color.electricIndigo : Color.hotPink)
                }

                Divider()

                methodSection(lr: lr)
            }
            .padding(DS.Spacing.lg)
            .solidCard()

            // Chart for past months (they have real data)
            if !activeTransactions.isEmpty {
                CashFlowCellMiniChart(
                    transactions: activeTransactions,
                    plannedAmount: lr.plannedAmount,
                    month: m,
                    currencyCode: currencyCode,
                    isIncome: lr.isIncome
                )
                .solidCard()
            }

            monthTimeline

            // Transactions for past months
            if !activeTransactions.isEmpty {
                recentTransactionsCard
            }
        }
    }

    // MARK: - Future Month

    private func futureMonthContent(m: CashFlowMonth, lr: CashFlowLineResult) -> some View {
        VStack(spacing: DS.Spacing.xl) {
            VStack(spacing: DS.Spacing.md) {
                headerInfo(m: m)

                Divider()

                HStack {
                    Text(L10n.CashFlowPlan.plan)
                        .font(DS.Typography.label)
                        .foregroundStyle(.secondary)
                    Spacer()
                    AmountText(
                        value: lr.plannedAmount,
                        currencyCode: currencyCode,
                        font: DS.Typography.title.weight(.bold).monospacedDigit(),
                        isEstimate: lr.isPlannedApproximate
                    )
                    .accessibilityIdentifier("cashflow_detail_planned_amount")
                }

                Divider()

                methodSection(lr: lr)
            }
            .padding(DS.Spacing.lg)
            .solidCard()

            monthTimeline

            adjustAmountButton(m: m, lr: lr)
        }
    }

    // MARK: - Recent Transactions

    /// «Últimos registros» con la fila de Registros: icono de 40, la cuenta debajo y el monto; tocarla abre el registro.
    private var recentTransactionsCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.CashFlowPlan.cellDetailRecentTransactions)
                .font(DS.Typography.headline)
                .foregroundStyle(.primary)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: DS.Spacing.sm) {
                ForEach(Array(activeTransactions.prefix(5)), id: \.persistentModelID) { tx in
                    RecordRowView(
                        record: tx,
                        currencyCode: currencyCode,
                        isSelectionMode: false,
                        isSelected: false,
                        onTap: { detailTransaction = tx },
                        onToggleSelection: {}
                    )
                }
            }
        }
    }

    // MARK: - Adjust Amount (L18-9)

    private func adjustAmountButton(m: CashFlowMonth, lr: CashFlowLineResult) -> some View {
        VStack(spacing: DS.Spacing.md) {
            if showAdjustAmount {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    Text(L10n.UXL18.amountFor(monthName(m.monthKey)))
                        .font(DS.Typography.label)
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                        Text(appPreferences.currencyIdentifier(for: currencyCode))
                            .font(DS.Typography.headline)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        TextField("0", text: $adjustAmountText)
                            .keyboardType(.decimalPad)
                            .font(DS.Typography.headline)
                            .monospacedDigit()
                            .focused($amountFieldFocused)
                            .accessibilityLabel(L10n.UXL18.amountFor(monthName(m.monthKey)))
                            .accessibilityIdentifier("cashflow_adjust_amount_field")
                    }
                    .padding(DS.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                            .fill(.thCard)
                    )

                    TextField(L10n.CashFlowPlan.cellDetailNote, text: $adjustNote)
                        .font(DS.Typography.body)
                        .padding(DS.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                                .fill(.thCard)
                        )

                    YalaPrimaryButton(L10n.CashFlowPlan.cellDetailSaveAdjustment, icon: "checkmark.circle.fill") {
                        saveAdjustment()
                    }
                }
                .padding(DS.Spacing.lg)
                .solidCard()
            } else {
                Button {
                    adjustAmountText = CashFlowStartingBalanceSheet.editableText(lr.plannedAmount)
                    showAdjustAmount = true
                    amountFieldFocused = true
                } label: {
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "pencil.line")
                        Text(L10n.CashFlowPlan.adjustAmount)
                    }
                    .font(DS.Typography.label)
                    .foregroundStyle(theme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.md)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("cashflow_adjust_amount")
            }
        }
    }

    /// Lo comparten el botón de abajo y el «Guardar» de sobre el teclado.
    private func saveAdjustment() {
        guard showAdjustAmount, let m = activeMonth else { return }
        let amount = AmountInputHelper.parseDecimal(adjustAmountText)
        amountFieldFocused = false
        if let line, amount > 0 {
            pendingOverrideAmount = amount
            pendingOverrideNote = adjustNote
            pendingOverrideLine = line
            pendingOverrideMonthKey = m.monthKey
            showOverrideScopeAlert = true
        } else {
            dismiss()
        }
    }

    // MARK: - Eliminar línea (L18-7)

    @ViewBuilder
    private var deleteLineButton: some View {
        if line != nil {
            Button(role: .destructive) {
                showDeleteLineAlert = true
            } label: {
                Text(L10n.CashFlowPlan.deleteLine)
                    .font(DS.Typography.label)
                    .foregroundStyle(DS.Semantic.errorForeground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.md)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("cashflow_detail_delete_line")
        }
    }

    // MARK: - Month Timeline

    private var monthTimeline: some View {
        let snapshots = timelineSnapshots
        return VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            if snapshots.count > 1 {
                HStack(spacing: DS.Spacing.none) {
                    ForEach(snapshots, id: \.monthKey) { snap in
                        Button {
                            withAnimation(.easeInOut(duration: DS.Animation.fast)) {
                                activeMonthKey = snap.monthKey
                                showAdjustAmount = false
                            }
                        } label: {
                            VStack(spacing: DS.Spacing.xs) {
                                Text(snap.label)
                                    .font(DS.Typography.captionSmall)
                                    .foregroundStyle(snap.isActive ? .primary : .tertiary)
                                    .fontWeight(snap.isActive ? .semibold : .regular)

                                Text(YalaFormatter.amountCompactTable(value: snap.amount))
                                    .font(snap.isActive ? DS.Typography.label : DS.Typography.captionSmall)
                                    .fontWeight(snap.isActive ? .bold : .regular)
                                    .foregroundStyle(snap.isActive ? .primary : .secondary)
                                    .monospacedDigit()

                                Circle()
                                    .fill(snap.dotColor)
                                    .frame(width: snap.isActive ? 8 : 5, height: snap.isActive ? 8 : 5)
                            }
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("cashflow_detail_timeline_\(snap.monthKey)")
                    }
                }
                .padding(DS.Spacing.lg)
                .solidCard()
            }
        }
    }

    private struct TimelineSnapshot {
        let monthKey: String
        let label: String
        let amount: Double
        let plannedAmount: Double
        let isActive: Bool
        let isPastOrCurrent: Bool
        let isIncome: Bool
        let dotColor: Color
    }

    private var timelineSnapshots: [TimelineSnapshot] {
        guard let projection = viewModel.projection else { return [] }

        let allMonths = projection.months
        guard let originIdx = allMonths.firstIndex(where: { $0.monthKey == month.monthKey }) else { return [] }

        let startIdx = max(0, originIdx - 2)
        let endIdx = min(allMonths.count - 1, originIdx + 2)

        var snapshots: [TimelineSnapshot] = []
        for i in startIdx...endIdx {
            let m = allMonths[i]
            let allLines = m.incomeLines + m.expenseLines
            let lineData = allLines.first { $0.lineID == lineResult.lineID }
            let planned = lineData?.plannedAmount ?? 0
            let real = lineData?.realAmount
            let displayAmount: Double
            if let real, m.isPast || m.isCurrent {
                displayAmount = real
            } else {
                displayAmount = planned
            }

            // Dot color: past/current with real data → indigo if on track, hotPink if over
            let dotColor: Color
            if let real, (m.isPast || m.isCurrent), planned > 0 {
                let isIncome = lineData?.isIncome ?? false
                if isIncome {
                    dotColor = real >= planned ? .electricIndigo : .hotPink
                } else {
                    dotColor = real <= planned ? .electricIndigo : .hotPink
                }
            } else {
                dotColor = .secondary.opacity(0.3)
            }

            snapshots.append(TimelineSnapshot(
                monthKey: m.monthKey,
                label: m.date.formatted(.dateTime.month(.abbreviated)),
                amount: displayAmount,
                plannedAmount: planned,
                isActive: m.monthKey == activeMonthKey,
                isPastOrCurrent: m.isPast || m.isCurrent,
                isIncome: lineData?.isIncome ?? false,
                dotColor: dotColor
            ))
        }
        return snapshots
    }

    // MARK: - Helpers

    /// «noviembre» desde la clave `yyyy-MM`.
    private func monthName(_ key: String) -> String {
        guard let date = CashFlowDetailLineRow.monthDate(key) else { return key }
        return CashFlowMonthSummaryLogic.monthInSentence(date)
    }

    private func detailRow(label: String, value: Double, color: Color? = nil, isEstimate: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
            Spacer()
            AmountText(
                value: value,
                currencyCode: currencyCode,
                font: DS.Typography.amountSmall.weight(.semibold).monospacedDigit(),
                tint: color.map { .color($0) } ?? .primary,
                isEstimate: isEstimate
            )
        }
    }
}
