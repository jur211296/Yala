//
//  RecurringProposalsListSheet.swift
//  Yala
//
//  La hoja «Pagos que se repiten» (Jürgen, 17-nov): se abre a tamaño grande desde el banner de Pagos planificados con
//  todos los casos que Yala encontró en el historial. Tocar uno abre el formulario completo de «Nuevo pago planificado»
//  (`ScheduledPaymentEditorView`) prellenado con lo detectado; al guardar, el caso sale de la lista. Descartar se hace
//  deslizando la fila o desde su menú: «No es fijo» (no vuelve a proponerse) y «Ahora no» (vuelve con el próximo cobro).
//  Si no queda nada por responder, la hoja se cierra sola. Los registros pasados no se tocan (decisión S4).
//

import SwiftData
import SwiftUI

struct RecurringProposalsListSheet: View {
    let model: RecurringProposalsModel
    /// «Ver» del aviso de pago creado: quien presenta la hoja la cierra y lleva la lista a ese mes.
    let onShowMonth: (Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.yalaTheme) private var theme

    /// El caso abierto en el formulario. `sheet(item:)`: un objeto, una hoja (`swiftui-ds.md`).
    @State private var editingItem: RecurringProposalsSource.Item?
    /// Lo que el aviso de después necesita del pago recién guardado; se lee al cerrarse el formulario.
    @State private var savedPaymentID: UUID?
    @State private var showsSettings = false

    private var preferences: RecurringProposalPreferences { .shared }

    var body: some View {
        let items = model.visibleItems(preferences: preferences)
        NavigationStack {
            YalaSettingsList {
                Section {
                    ForEach(items) { item in
                        row(item)
                            .listRowBackground(theme.card)
                    }
                } header: {
                    // Texto de apoyo, no un título: la cabecera de sección por defecto lo pintaba casi como el título.
                    Text(PagosRecurrentesText.cardSubtitle)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(Color(.secondaryLabel))
                        .textCase(nil)
                } footer: {
                    Text(PagosRecurrentesText.listFooter)
                }
            }
            .yalaScreenBackground(.subtle)
            .navigationTitle(PagosRecurrentesText.cardTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .sheet(isPresented: $showsSettings) {
                RecurringProposalsSettingsView()
            }
        }
        .presentationDetents([.large])
        // El formulario cuelga del contenedor, fuera de la pila: lo que la persona rellena no vive en su raíz.
        .sheet(item: $editingItem, onDismiss: editorClosed) { item in
            ScheduledPaymentEditorView(
                payment: nil,
                prefill: RecurringProposalPrefill.prefill(for: item),
                onSaved: { paymentID in paymentSaved(paymentID, item: item) }
            )
        }
        .onChange(of: items.isEmpty) { _, isEmpty in closeIfNothingLeft(isEmpty) }
        .accessibilityIdentifier("recurring_proposals_list")
    }

    // MARK: - Fila

    private func row(_ item: RecurringProposalsSource.Item) -> some View {
        RecurringProposalRow(item: item) { editingItem = item }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button { dismissProposal(item) } label: {
                    Label(PagosRecurrentesText.notFixed, systemImage: "nosign")
                }
                .tint(DS.Semantic.warningForeground)
                .accessibilityIdentifier("recurring_proposal_swipe_not_fixed")

                Button { snoozeProposal(item) } label: {
                    Label(PagosRecurrentesText.notNow, systemImage: "clock")
                }
                .tint(.gray)
                .accessibilityIdentifier("recurring_proposal_swipe_not_now")
            }
            .contextMenu {
                Button { editingItem = item } label: {
                    Label(PagosRecurrentesText.create, systemImage: "calendar.badge.plus")
                }
                Button { dismissProposal(item) } label: {
                    Label(PagosRecurrentesText.notFixed, systemImage: "nosign")
                }
                Button { snoozeProposal(item) } label: {
                    Label(PagosRecurrentesText.notNow, systemImage: "clock")
                }
            }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                dismiss()
            }
            .accessibilityIdentifier("recurring_proposals_list_close")
        }
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button {
                    showsSettings = true
                } label: {
                    Label(PagosRecurrentesText.cardManage, systemImage: "gearshape")
                }
                .accessibilityIdentifier("recurring_proposals_manage")
            } label: {
                Label(PagosRecurrentesText.cardManageA11y, systemImage: "ellipsis")
            }
            .accessibilityIdentifier("recurring_proposals_menu")
        }
    }

    // MARK: - Respuestas

    private func dismissProposal(_ item: RecurringProposalsSource.Item) {
        dsWithAnimation(reduceMotion) { preferences.dismiss(item.proposal) }
    }

    private func snoozeProposal(_ item: RecurringProposalsSource.Item) {
        dsWithAnimation(reduceMotion) { preferences.snooze(item.proposal) }
    }

    /// Con el formulario abierto no se cierra nada: lo decide `editorClosed` cuando ya no está encima.
    private func closeIfNothingLeft(_ isEmpty: Bool) {
        guard isEmpty, editingItem == nil else { return }
        dismiss()
    }

    // MARK: - Pago creado

    /// El guardado del formulario ya subió `dataVersion`. Aquí solo se olvida lo que la persona contestó de ese comercio.
    private func paymentSaved(_ paymentID: UUID, item: RecurringProposalsSource.Item) {
        preferences.forget(item.proposal)
        savedPaymentID = paymentID
    }

    /// Al cerrarse el formulario: la lista sin el caso creado, el aviso de siempre y, si no queda nada, fuera la hoja.
    private func editorClosed() {
        guard let paymentID = savedPaymentID else { return }
        savedPaymentID = nil
        model.refresh(context: modelContext)
        announceCreated(paymentID)
        if model.visibleItems(preferences: preferences).isEmpty {
            dismiss()
        }
    }

    private func announceCreated(_ paymentID: UUID) {
        let descriptor = FetchDescriptor<ScheduledPayment>(predicate: #Predicate { $0.id == paymentID })
        let payment: ScheduledPayment
        do {
            guard let found = try modelContext.fetch(descriptor).first else { return }
            payment = found
        } catch {
            #if DEBUG
            print("RecurringProposalsListSheet: Error: \(error)")
            #endif
            return
        }
        let name = payment.name
        let firstDue = payment.nextDueDate
        let message: String
        if let reminder = RecurringProposalPrefill.firstReminderDate(
            dueDate: firstDue, notifies: payment.notifyOnDueDate, daysBefore: payment.notifyDaysBefore
        ) {
            message = PagosRecurrentesText.createdNotice(
                name: name, reminderDate: ScheduledPaymentDateText.dayMonthLong(reminder)
            )
        } else {
            message = PagosRecurrentesText.createdNoticeNoReminder(name: name)
        }
        let showMonth = onShowMonth
        DraftDiscardUndoNotice.show(
            message: message,
            systemImage: "checkmark.circle",
            undoTitle: PagosRecurrentesText.createdView,
            noticeIdentifier: "recurring_created_notice",
            undoIdentifier: "recurring_created_view"
        ) {
            showMonth(firstDue)
        }
    }
}

// MARK: - Prellenado

/// De un caso detectado al prellenado del formulario de «Nuevo pago planificado». Puro: lo fijan los tests.
@MainActor
enum RecurringProposalPrefill {
    /// Nombre, monto y divisa del último cobro; cuenta y categoría del cobro más reciente que las tenga; cada mes o cada
    /// semana desde el próximo cobro que calculó el detector; suscripción si es una marca del catálogo; y si el monto
    /// cambia de un cobro a otro. El aviso queda en lo que propone el formulario.
    static func prefill(
        for item: RecurringProposalsSource.Item, calendar: Calendar = .current
    ) -> ScheduledPaymentPrefill {
        let proposal = item.proposal
        let plan = RecurringProposalPlan(
            proposal: proposal, firstCharge: proposal.nextDueDate, reminder: .default, calendar: calendar
        )
        var prefill = ScheduledPaymentPrefill(
            transactionType: "expense",
            amount: AmountInputHelper.formatWithGrouping(proposal.amount),
            note: "",
            account: item.liveAccount,
            subcategory: item.liveSubcategory,
            tagIDs: [],
            needOverride: nil,
            currencyCode: proposal.currencyCode,
            transactionDate: plan.paymentDate
        )
        prefill.name = proposal.displayName
        prefill.recurrenceType = plan.recurrenceType
        prefill.dayOfMonth = plan.dayOfMonth
        prefill.isSubscription = plan.paymentCategory == .subscription
        prefill.isVariableAmount = plan.isVariableAmount
        return prefill
    }

    /// El primer aviso que recibirá: los días de antes, o el mismo día si esos días ya pasaron. `nil` sin aviso.
    static func firstReminderDate(
        dueDate: Date, notifies: Bool, daysBefore: Int, now: Date = .now, calendar: Calendar = .current
    ) -> Date? {
        guard notifies else { return nil }
        let due = calendar.startOfDay(for: dueDate)
        guard let before = calendar.date(byAdding: .day, value: -max(daysBefore, 0), to: due) else { return due }
        return before >= calendar.startOfDay(for: now) ? before : due
    }
}

// MARK: - Fila

/// Una propuesta: el logo del servicio (o el icono de pago recurrente), nombre, cada cuánto y con qué cuenta, y el monto.
struct RecurringProposalRow: View {
    let item: RecurringProposalsSource.Item
    let action: () -> Void

    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.yalaTheme) private var theme

    var body: some View {
        Button(action: action) {
            content
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("recurring_proposal_row_\(item.proposal.key)")
    }

    @ViewBuilder
    private var content: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                HStack(spacing: DS.Spacing.md) {
                    badge
                    nameAndDetail
                }
                amountLabel
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(spacing: DS.Spacing.md) {
                badge
                nameAndDetail
                Spacer(minLength: DS.Spacing.sm)
                amountLabel
                Image(systemName: "chevron.right")
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
    }

    @ViewBuilder
    private var badge: some View {
        if let brandID = item.proposal.brandID, let brand = SubscriptionBrandCatalog.brand(id: brandID) {
            SubscriptionBrandBadge(brand: brand, isDecorative: true)
        } else {
            ZStack {
                Circle().fill(theme.accent)
                Image(systemName: PaymentCategory.recurring.iconName)
                    .font(DS.Typography.label)
                    .foregroundStyle(theme.onAccent)
            }
            .frame(width: DS.Icon.badgeLarge, height: DS.Icon.badgeLarge)
            .accessibilityHidden(true)
        }
    }

    private var nameAndDetail: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            Text(item.proposal.displayName)
                .font(DS.Typography.label)
                .foregroundStyle(.primary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
            Text(RecurringProposalFormatting.detailLine(item))
                .font(DS.Typography.captionSmall)
                .foregroundStyle(.secondary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
        }
    }

    private var amountLabel: some View {
        Text(RecurringProposalFormatting.amount(item.proposal, appPreferences: appPreferences))
            .font(DS.Typography.headline)
            .foregroundStyle(.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}

// MARK: - Formato

@MainActor
enum RecurringProposalFormatting {
    /// «Cada mes, el 14 · Visa BCP».
    static func detailLine(_ item: RecurringProposalsSource.Item) -> String {
        let cadence = cadenceText(item.proposal.cadence)
        guard let account = item.liveAccount?.name, !account.isEmpty else { return cadence }
        return "\(cadence) · \(account)"
    }

    static func cadenceText(_ cadence: RecurringPaymentDetector.Cadence, locale: Locale? = nil) -> String {
        let locale = locale ?? AppLocale.current
        switch cadence {
        case .monthly(let day, let isApproximate):
            let dayText = String(day)
            return isApproximate
                ? PagosRecurrentesText.cadenceMonthlyApprox(day: dayText)
                : PagosRecurrentesText.cadenceMonthly(day: dayText)
        case .weekly(let weekday):
            return PagosRecurrentesText.cadenceWeekly(weekday: weekdayName(weekday, locale: locale))
        }
    }

    /// «lunes» (en el idioma de la app; `Calendar` cuenta 1 = domingo).
    static func weekdayName(_ weekday: Int, locale: Locale) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        let symbols = calendar.standaloneWeekdaySymbols
        guard weekday >= 1, weekday <= symbols.count else { return "" }
        let name = symbols[weekday - 1]
        // En español y portugués el día va en minúscula dentro de la frase.
        let lowercaseLanguages: Set<String> = ["es", "pt", "fr", "it", "nl", "pl"]
        if let language = locale.language.languageCode?.identifier, lowercaseLanguages.contains(language) {
            return name.lowercased(with: locale)
        }
        return name
    }

    /// El monto del último cobro con su divisa. Sin «≈» aunque varíe: «≈» solo marca una tasa de cambio aproximada
    /// (decisión 31 de 2.3); que el monto cambia lo dice el formulario («Monto variable»).
    static func amount(_ proposal: RecurringPaymentDetector.Proposal, appPreferences: AppPreferences) -> String {
        appPreferences.currency(proposal.amount, currencyCode: proposal.currencyCode, forceFullPrecision: true)
    }
}
