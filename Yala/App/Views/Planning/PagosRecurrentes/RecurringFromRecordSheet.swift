//
//  RecurringFromRecordSheet.swift
//  Yala
//
//  «Hacer recurrente» a partir de un registro (encargo del 15-nov). Una sola presentación con fases: si ya hay un
//  recurrente parecido, primero se ofrece vincular el registro a él; si no, o si la persona prefiere otro, el editor de
//  recurrentes de siempre, prellenado con el registro. En los dos caminos el registro queda como un pago del
//  recurrente y no se crea ningún gasto más (`RecurringFromRecordService`).
//
//  Fases en vez de una alerta seguida de una hoja: una alerta no admite el nombre del recurrente en el botón, y dos
//  presentaciones encadenadas desde el mismo ancla son el molde que deja flags pegados (`swiftui-ds.md`).
//

import SwiftData
import SwiftUI

struct RecurringFromRecordSheet: View {
    let record: TransactionItem
    /// Termina el flujo: se creó o se vinculó. Se llama antes de que la hoja se cierre.
    var onFinished: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.yalaTheme) private var theme

    private enum Phase {
        case deciding
        case choice(ScheduledPayment)
        case editor(ScheduledPaymentPrefill)
    }

    @State private var phase: Phase = .deciding

    var body: some View {
        // Un registro borrado mientras la hoja está abierta no se lee (`swiftui-ds.md`, filas con modelo borrado).
        if record.isDeleted || record.modelContext == nil {
            Color.clear
        } else {
            switch phase {
            case .deciding:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .yalaScreenBackground(.subtle)
                    .onAppear(perform: decide)
            case .choice(let payment):
                choiceView(payment)
            case .editor(let prefill):
                ScheduledPaymentEditorView(
                    payment: nil,
                    prefill: prefill,
                    onSaved: { paymentID in
                        if RecurringFromRecordService.linkAsFirstPayment(
                            record, paymentID: paymentID, context: modelContext) != nil {
                            SavedRecordNotice.showInfo(message: L10n.RecurringFromRecord.noticeCreated)
                        }
                        onFinished?()
                    }
                )
            }
        }
    }

    private func decide() {
        if let similar = RecurringFromRecordService.similarPayment(for: record, in: modelContext) {
            phase = .choice(similar)
        } else {
            phase = .editor(RecurringFromRecordService.prefill(from: record))
        }
    }

    // MARK: - Ya hay uno parecido

    private func choiceView(_ payment: ScheduledPayment) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        Text(L10n.RecurringFromRecord.choiceHeadline)
                            .font(DS.Typography.title3)
                            .accessibilityAddTraits(.isHeader)
                        Text(L10n.RecurringFromRecord.choiceBody)
                            .font(DS.Typography.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    paymentCard(payment)

                    VStack(spacing: DS.Spacing.md) {
                        YalaPrimaryButton(L10n.RecurringFromRecord.choiceLink(payment.name)) {
                            link(to: payment)
                        }
                        .accessibilityIdentifier("recurring_from_record_link")

                        Button {
                            phase = .editor(RecurringFromRecordService.prefill(from: record))
                        } label: {
                            Text(L10n.RecurringFromRecord.choiceCreateNew)
                                .font(DS.Typography.headline)
                                .foregroundStyle(theme.accentText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, DS.Spacing.lg)
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("recurring_from_record_create_new")
                    }
                }
                .padding(DS.Spacing.xl)
                .frame(maxWidth: DS.Adaptive.readableWidth)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .navigationTitle(L10n.RecurringFromRecord.makeRecurring)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }
            }
            .yalaScreenBackground(.subtle)
        }
        .accessibilityIdentifier("recurring_from_record_choice")
    }

    private func paymentCard(_ payment: ScheduledPayment) -> some View {
        let dateStyle = Date.FormatStyle(date: .abbreviated, time: .omitted).locale(AppLocale.current)
        return HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(payment.name)
                    .font(DS.Typography.headline)
                Text(L10n.RecurringFromRecord.choiceNextDue(payment.nextDueDate.formatted(dateStyle)))
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: DS.Spacing.sm)
            Text(appPreferences.currency(payment.amount, currencyCode: payment.currencyCode))
                .font(DS.Typography.headline)
                .monospacedDigit()
        }
        .padding(DS.Spacing.lg)
        .background(theme.card, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
        .accessibilityElement(children: .combine)
    }

    private func link(to payment: ScheduledPayment) {
        let name = payment.name
        guard RecurringFromRecordService.link(record, to: payment, context: modelContext) else {
            DS.Haptic.error()
            return
        }
        DS.Haptic.success()
        onFinished?()
        dismiss()
        SavedRecordNotice.showInfo(message: L10n.RecurringFromRecord.noticeLinked(name))
    }
}

// MARK: - Selector de registros (Planificación › Pagos › «Desde un registro»)

/// Los registros recientes que se pueden hacer recurrentes, con buscador. Al elegir uno sigue el mismo flujo que el
/// menú de un registro, en la misma hoja.
struct RecurringRecordPickerSheet: View {
    var onFinished: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppPreferences.self) private var appPreferences

    @State private var records: [TransactionItem] = []
    @State private var query = ""
    @State private var chosen: TransactionItem?
    @State private var hasLoaded = false

    /// Hasta dónde mira atrás: seis meses cubren cualquier cobro mensual o trimestral reciente.
    private static let lookbackMonths = 6
    private static let fetchLimit = 600

    var body: some View {
        if let chosen {
            RecurringFromRecordSheet(record: chosen, onFinished: onFinished)
        } else {
            NavigationStack {
                list
                    .navigationTitle(L10n.RecurringFromRecord.pickerTitle)
                    .navigationBarTitleDisplayMode(.inline)
                    .searchable(
                        text: $query,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: L10n.RecurringFromRecord.pickerSearchPrompt)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                                dismiss()
                            }
                        }
                    }
                    .yalaScreenBackground(.subtle)
            }
            .onAppear(perform: load)
        }
    }

    @ViewBuilder
    private var list: some View {
        let shown = RecurringRecordPickerFilter.matching(records, query: query)
        if hasLoaded && records.isEmpty {
            ContentUnavailableView(L10n.RecurringFromRecord.pickerEmpty, systemImage: "repeat")
        } else if !query.isEmpty && shown.isEmpty {
            ContentUnavailableView(L10n.RecurringFromRecord.pickerNoResults(query), systemImage: "magnifyingglass")
        } else {
            List {
                Section {
                    ForEach(shown, id: \.persistentModelID) { record in
                        Button {
                            DS.Haptic.selection()
                            chosen = record
                        } label: {
                            row(record)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("recurring_record_picker_row")
                    }
                } footer: {
                    Text(L10n.RecurringFromRecord.pickerFooter)
                }
            }
            .scrollContentBackground(.hidden)
            .accessibilityIdentifier("recurring_record_picker_list")
        }
    }

    private func row(_ record: TransactionItem) -> some View {
        let dateStyle = Date.FormatStyle(date: .abbreviated, time: .omitted).locale(AppLocale.current)
        let title = RecurringFromRecordLogic.paymentName(note: record.note, subcategoryName: record.subcategory?.name)
        let detail = [record.date.formatted(dateStyle), record.account?.name].compactMap { $0 }.joined(separator: " · ")
        return HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(title.isEmpty ? appPreferences.currency(abs(record.amount), currencyCode: record.currencyCode) : title)
                    .font(DS.Typography.body)
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: DS.Spacing.sm)
            Text(appPreferences.currency(abs(record.amount), currencyCode: record.currencyCode))
                .font(DS.Typography.body)
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
        .padding(.vertical, DS.Spacing.xs)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func load() {
        guard !hasLoaded else { return }
        hasLoaded = true
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .month, value: -Self.lookbackMonths, to: calendar.startOfDay(for: .now))
            ?? .distantPast
        var descriptor = FetchDescriptor<TransactionItem>(
            predicate: #Predicate { $0.date >= cutoff && $0.scheduledPaymentID == nil && $0.balanceAdjustmentType == nil },
            sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = Self.fetchLimit
        do {
            records = try modelContext.fetch(descriptor).filter(RecurringFromRecordService.offersMakeRecurring)
        } catch {
            #if DEBUG
            print("RecurringRecordPickerSheet: Error fetching records: \(error)")
            #endif
            records = []
        }
    }
}

/// El buscador del selector: descripción, categoría o subcategoría, sin distinguir mayúsculas ni tildes.
enum RecurringRecordPickerFilter {
    @MainActor
    static func matching(_ records: [TransactionItem], query: String) -> [TransactionItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return records }
        return records.filter { record in
            guard !record.isDeleted else { return false }
            return matches(
                fields: [record.note, record.subcategory?.name, record.category?.name, record.account?.name],
                query: trimmed)
        }
    }

    nonisolated static func matches(fields: [String?], query: String) -> Bool {
        fields.contains { field in
            guard let field, !field.isEmpty else { return false }
            return field.localizedStandardContains(query)
        }
    }
}
