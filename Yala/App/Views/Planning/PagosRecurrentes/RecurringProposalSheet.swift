//
//  RecurringProposalSheet.swift
//  Yala
//
//  La propuesta abierta (lote S1, paso 2 del recorrido de la definición): todo viene lleno desde el historial y se
//  puede cambiar antes de crear. Tres salidas: «Crear pago planificado», «No es fijo» (no vuelve a proponerse) y
//  «Ahora no» (vuelve con el próximo cobro). Guarda con `ScheduledPaymentEditorViewModel.savePayment`, el mismo
//  guardado del editor: mismo aviso a widgets, a los recordatorios y a la telemetría.
//
//  Es una hoja propia y no el editor con datos porque el prefill del editor no lleva la frecuencia semanal ni la
//  marca de suscripción (Paso 0, D3). Los registros pasados no se tocan (decisión S4).
//

import SwiftData
import SwiftUI

struct RecurringProposalSheet: View {

    /// Lo que el aviso de después necesita del pago creado.
    struct Created {
        let paymentID: UUID
        let name: String
        let firstDueDate: Date
        let firstReminder: Date?
    }

    let item: RecurringProposalsSource.Item
    let onCreated: (Created) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(EntityDeletionService.self) private var deletionService
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.yalaTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var editorModel = ScheduledPaymentEditorViewModel()
    @State private var amountText: String
    @State private var firstCharge: Date
    @State private var account: Account?
    @State private var reminder: RecurringProposalPlan.Reminder = .default
    @State private var isSaving = false
    /// El pago ya guardado mientras sale la hoja que pide las notificaciones (como el editor, UX 2.2 · L5-14).
    @State private var createdAwaitingPrimer: Created?
    @State private var showsNotificationPrimer = false
    @FocusState private var isAmountFocused: Bool

    init(item: RecurringProposalsSource.Item, onCreated: @escaping (Created) -> Void) {
        self.item = item
        self.onCreated = onCreated
        _amountText = State(initialValue: AmountInputHelper.formatWithGrouping(item.proposal.amount))
        _firstCharge = State(initialValue: item.proposal.nextDueDate)
        _account = State(initialValue: item.liveAccount)
    }

    private var proposal: RecurringPaymentDetector.Proposal { item.proposal }
    private var preferences: RecurringProposalPreferences { .shared }
    private var parsedAmount: Double { AmountInputHelper.parseDecimal(amountText) }
    private var canCreate: Bool { parsedAmount > 0 && account != nil && !isSaving }

    private var today: Date { Calendar.current.startOfDay(for: .now) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                header
                fields
                if proposal.isVariableAmount {
                    Text(PagosRecurrentesText.variableAmount)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, DS.Spacing.xs)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.xl)
            .padding(.bottom, DS.Spacing.lg)
            .background { Color.clear.dismissKeyboardOnTap() }
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaBar(edge: .bottom, spacing: DS.Spacing.sm) { actions }
        .yalaScreenBackground(.subtle)
        .onAppear { editorModel.setContext(modelContext, deletionService: deletionService) }
        .notificationPrimerSheet(isPresented: $showsNotificationPrimer, context: .scheduledPayment) {
            if let created = createdAwaitingPrimer { finish(created) }
        }
        .accessibilityIdentifier("recurring_proposal_sheet")
    }

    // MARK: - Cabecera

    private var header: some View {
        HStack(alignment: .center, spacing: DS.Spacing.md) {
            if let brandID = proposal.brandID, let brand = SubscriptionBrandCatalog.brand(id: brandID) {
                SubscriptionBrandBadge(brand: brand, isDecorative: true)
            }
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(proposal.displayName)
                    .font(DS.Typography.title3)
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(.isHeader)
                Text(historyLine)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("recurring_proposal_history")
            }
        }
    }

    /// «Cada mes, el 14 · Cobros encontrados: 5 · Último cobro: 14 nov».
    private var historyLine: String {
        [
            RecurringProposalFormatting.cadenceText(proposal.cadence),
            PagosRecurrentesText.chargesFound(String(proposal.chargeCount)),
            PagosRecurrentesText.lastCharge(ScheduledPaymentDateText.dayMonth(proposal.lastChargeDate)),
        ].joined(separator: " · ")
    }

    // MARK: - Campos

    private var fields: some View {
        VStack(spacing: DS.Spacing.none) {
            fieldRow(PagosRecurrentesText.amount) {
                HStack(spacing: DS.Spacing.xs) {
                    Text(verbatim: appPreferences.currencyIdentifier(for: proposal.currencyCode))
                        .foregroundStyle(.secondary)
                    TextField(
                        PagosRecurrentesText.amount,
                        text: $amountText,
                        prompt: Text(verbatim: "0.00").foregroundStyle(.tertiary)
                    )
                    .amountKeyboard()
                    .multilineTextAlignment(.trailing)
                    .focused($isAmountFocused)
                    .onChange(of: amountText) { _, newValue in filterAmount(newValue) }
                    .accessibilityIdentifier("recurring_proposal_amount")
                }
                .font(DS.Typography.body)
            }
            divider
            fieldRow(PagosRecurrentesText.frequency) {
                Text(frequencyText)
                    .foregroundStyle(.secondary)
            }
            divider
            fieldRow(PagosRecurrentesText.nextCharge) {
                DatePicker(
                    PagosRecurrentesText.nextCharge,
                    selection: $firstCharge,
                    in: today...,
                    displayedComponents: [.date]
                )
                .labelsHidden()
                .accessibilityIdentifier("recurring_proposal_next_charge")
            }
            divider
            fieldRow(PagosRecurrentesText.account) { accountMenu }
            divider
            fieldRow(PagosRecurrentesText.category) {
                Text(item.liveSubcategory?.name ?? L10n.Report.uncategorized)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            divider
            fieldRow(PagosRecurrentesText.notify) { reminderMenu }
        }
        .padding(.horizontal, DS.Spacing.md)
        .background(theme.card, in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
    }

    private var frequencyText: String {
        switch proposal.cadence {
        case .monthly: return PagosRecurrentesText.frequencyMonthly
        case .weekly: return PagosRecurrentesText.frequencyWeekly
        }
    }

    private var divider: some View {
        Divider().padding(.leading, DS.Spacing.xs)
    }

    /// Título a la izquierda y valor a la derecha; con texto de accesibilidad, el valor debajo.
    private func fieldRow<Value: View>(_ title: String, @ViewBuilder value: () -> Value) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.xs))
            : AnyLayout(HStackLayout(spacing: DS.Spacing.md))
        return layout {
            Text(title)
                .font(DS.Typography.body)
                .foregroundStyle(.primary)
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: DS.Spacing.sm) }
            value()
                .font(DS.Typography.body)
        }
        .frame(minHeight: 44)
        .padding(.vertical, DS.Spacing.xs)
    }

    // MARK: - Cuenta y aviso

    /// Las cuentas activas en la divisa de los cobros y, aunque sea de otra divisa, la del último cobro (la que trae la
    /// propuesta: una suscripción en dólares cobrada en una tarjeta en soles), como deja el editor con la cuenta del
    /// registro de origen. Si no queda ninguna, todas las activas.
    private var accountOptions: [Account] {
        let active = editorModel.activeAccounts
        let sourceID = item.liveAccount?.persistentModelID
        let options = active.filter {
            $0.currencyCode.uppercased() == proposal.currencyCode || $0.persistentModelID == sourceID
        }
        return options.isEmpty ? active : options
    }

    private var accountMenu: some View {
        Menu {
            ForEach(accountOptions, id: \.persistentModelID) { option in
                Button {
                    account = option
                } label: {
                    if option.persistentModelID == account?.persistentModelID {
                        Label(option.name, systemImage: "checkmark")
                    } else {
                        Text(option.name)
                    }
                }
            }
        } label: {
            menuLabel(account?.name ?? PagosRecurrentesText.chooseAccount, isPlaceholder: account == nil)
        }
        .accessibilityIdentifier("recurring_proposal_account")
    }

    private var reminderMenu: some View {
        Menu {
            ForEach(RecurringProposalPlan.Reminder.allCases) { option in
                Button {
                    reminder = option
                } label: {
                    if option == reminder {
                        Label(reminderTitle(option), systemImage: "checkmark")
                    } else {
                        Text(reminderTitle(option))
                    }
                }
            }
        } label: {
            menuLabel(reminderTitle(reminder), isPlaceholder: false)
        }
        .accessibilityIdentifier("recurring_proposal_reminder")
    }

    private func menuLabel(_ text: String, isPlaceholder: Bool) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Text(text)
                .lineLimit(1)
            Image(systemName: "chevron.up.chevron.down")
                .font(DS.Typography.captionSmall)
                .accessibilityHidden(true)
        }
        .foregroundStyle(isPlaceholder ? theme.accentText : Color(.secondaryLabel))
    }

    private func reminderTitle(_ option: RecurringProposalPlan.Reminder) -> String {
        switch option {
        case .none: return PagosRecurrentesText.notifyNone
        case .sameDay: return PagosRecurrentesText.notifySameDay
        case .oneDay: return PagosRecurrentesText.notifyOneDay
        case .threeDays: return PagosRecurrentesText.notifyThreeDays
        case .oneWeek: return PagosRecurrentesText.notifyOneWeek
        }
    }

    // MARK: - Acciones

    private var actions: some View {
        VStack(spacing: DS.Spacing.sm) {
            YalaPrimaryButton(
                PagosRecurrentesText.create,
                isDisabled: !canCreate,
                isLoading: isSaving,
                keepsDisabledToneInBar: true
            ) {
                create()
            }
            .accessibilityIdentifier("recurring_proposal_create")

            ViewThatFits(in: .horizontal) {
                HStack(spacing: DS.Spacing.md) { secondaryActions }
                VStack(spacing: DS.Spacing.xs) { secondaryActions }
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.bottom, DS.Spacing.sm)
    }

    @ViewBuilder
    private var secondaryActions: some View {
        Button {
            preferences.dismiss(proposal)
            dismiss()
        } label: {
            Text(PagosRecurrentesText.notFixed)
                .font(DS.Typography.label)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(theme.accentText)
        .accessibilityIdentifier("recurring_proposal_not_fixed")

        Button {
            preferences.snooze(proposal)
            dismiss()
        } label: {
            Text(PagosRecurrentesText.notNow)
                .font(DS.Typography.label)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .accessibilityIdentifier("recurring_proposal_not_now")
    }

    private func filterAmount(_ newValue: String) {
        let filtered = AmountInputHelper.filterAmountInput(newValue)
        if filtered != newValue { amountText = filtered }
    }

    private func create() {
        guard canCreate, let account else { return }
        isSaving = true
        let plan = RecurringProposalPlan(proposal: proposal, firstCharge: firstCharge, reminder: reminder)
        let savedID = editorModel.savePayment(
            existing: nil,
            name: proposal.displayName,
            amount: parsedAmount,
            note: "",
            currencyCode: proposal.currencyCode,
            transactionType: "expense",
            paymentCategory: plan.paymentCategory,
            account: account,
            subcategory: item.liveSubcategory,
            selectedTags: [],
            isRecurring: true,
            recurrenceType: plan.recurrenceType,
            recurrenceInterval: 1,
            paymentDate: plan.paymentDate,
            dayOfMonth: plan.dayOfMonth,
            selectedWeekdays: plan.weekdays,
            yearlyMonth: nil,
            yearlyDay: nil,
            endDate: nil,
            notifyOnDueDate: plan.notifyOnDueDate,
            notifyDaysBefore: plan.notifyDaysBefore,
            isActive: true,
            isVariableAmount: plan.isVariableAmount,
            brandLogoID: .some(nil)
        )
        isSaving = false
        guard let savedID else { return }
        DS.Haptic.success()
        preferences.forget(proposal)
        let firstDue = savedFirstDueDate(savedID) ?? plan.paymentDate
        let created = Created(
            paymentID: savedID,
            name: proposal.displayName,
            firstDueDate: firstDue,
            firstReminder: RecurringProposalPlan.firstReminderDate(dueDate: firstDue, reminder: reminder)
        )
        guard reminder != .none else {
            finish(created)
            return
        }
        // Un pago nuevo con aviso es el momento de pedir las notificaciones, como en el editor: si no toca, se cierra.
        isSaving = true
        Task { @MainActor in
            if await NotificationPrimerMoments.claim(.scheduledPayment) {
                createdAwaitingPrimer = created
                showsNotificationPrimer = true
            } else {
                finish(created)
            }
        }
    }

    private func finish(_ created: Created) {
        createdAwaitingPrimer = nil
        dismiss()
        onCreated(created)
    }

    /// La fecha que dejó el guardado (la primera del calendario del pago desde «Próximo cobro»).
    private func savedFirstDueDate(_ id: UUID) -> Date? {
        let descriptor = FetchDescriptor<ScheduledPayment>(predicate: #Predicate { $0.id == id })
        do {
            return try modelContext.fetch(descriptor).first?.nextDueDate
        } catch {
            #if DEBUG
            print("RecurringProposalSheet: Error: \(error)")
            #endif
            return nil
        }
    }
}
