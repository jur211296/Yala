//
//  SaveAsRecurringSheet.swift
//  Yala
//
//  Sheet for saving current transaction as a recurring/scheduled payment.
//

import SwiftData
import SwiftUI

struct SaveAsRecurringSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Account.name) private var allAccounts: [Account]
    @Query(sort: \Tag.name) private var allTags: [Tag]

    // Initial values from transaction
    let transactionType: TransactionType
    let initialAmount: Double
    let initialNote: String
    let initialAccount: Account?
    let initialSubcategory: Subcategory?
    let initialTags: [Tag]
    let natureOverride: SubcategoryNature?
    let currencyCode: String
    let transactionDate: Date

    // Callback for success
    let onSaved: (String) -> Void

    // Editable fields
    @State private var name: String = ""
    @State private var selectedAccount: Account?
    @State private var selectedSubcategory: Subcategory?
    @State private var selectedTags: Set<PersistentIdentifier> = []
    @State private var amount: Double = 0
    @State private var amountString: String = ""
    @State private var note: String = ""
    @State private var includeNote: Bool = true

    // Payment category
    @State private var paymentCategory: PaymentCategory = .recurring

    // Recurrence
    @State private var isRecurring: Bool = true
    @State private var recurrenceType: RecurrenceType = .monthly
    @State private var recurrenceInterval: Int = 1
    @State private var startDate: Date = Date()
    @State private var dayOfMonth: Int = 1
    @State private var selectedWeekdays: Set<Int> = [2]  // Monday
    @State private var yearlyMonth: Int = 1
    @State private var yearlyDay: Int = 1
    @State private var hasEndDate: Bool = false
    @State private var endDate: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()

    // Sheet states
    @State private var showAccountSelector = false
    @State private var showSubcategorySelector = false
    @State private var showTagSelector = false

    @FocusState private var isNameFocused: Bool
    @FocusState private var isAmountFocused: Bool

    init(
        transactionType: TransactionType,
        amount: Double,
        note: String,
        account: Account?,
        subcategory: Subcategory?,
        tags: [Tag],
        natureOverride: SubcategoryNature?,
        currencyCode: String,
        transactionDate: Date,
        onSaved: @escaping (String) -> Void
    ) {
        self.transactionType = transactionType
        self.initialAmount = amount
        self.initialNote = note
        self.initialAccount = account
        self.initialSubcategory = subcategory
        self.initialTags = tags
        self.natureOverride = natureOverride
        self.currencyCode = currencyCode
        self.transactionDate = transactionDate
        self.onSaved = onSaved

        self._name = State(initialValue: note)
        self._selectedAccount = State(initialValue: account)
        self._selectedSubcategory = State(initialValue: subcategory)
        self._selectedTags = State(initialValue: Set(tags.map { $0.persistentModelID }))
        self._amount = State(initialValue: amount)
        self._amountString = State(initialValue: amount > 0 ? String(format: "%.2f", amount) : "")
        self._note = State(initialValue: note)
        self._includeNote = State(initialValue: !note.isEmpty)
        self._startDate = State(initialValue: transactionDate)
        self._dayOfMonth = State(initialValue: Calendar.current.component(.day, from: transactionDate))
        self._yearlyMonth = State(initialValue: Calendar.current.component(.month, from: transactionDate))
        self._yearlyDay = State(initialValue: Calendar.current.component(.day, from: transactionDate))
    }

    private var activeTags: [Tag] {
        allTags.filter { $0.isActive }
    }

    private var selectedTagObjects: [Tag] {
        activeTags.filter { selectedTags.contains($0.persistentModelID) }
    }

    private var parsedAmount: Double {
        Double(amountString.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    // Name Section
                    nameSection

                    // Fields Section
                    fieldsSection

                    // Subscription Toggle
                    subscriptionSection

                    // Recurrence Section
                    recurrenceSection

                    // Save button
                    YalaPrimaryButton(
                        L10n.Action.save,
                        isDisabled: name.trimmingCharacters(in: .whitespaces).isEmpty || parsedAmount <= 0
                    ) {
                        saveRecurring()
                    }
                    .padding(.top, DS.Spacing.md)
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xxl)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(
                PanelBackgroundView()
                    .dismissKeyboardOnTap()
            )
            .navigationTitle(L10n.Action.saveAsRecurring)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showAccountSelector) {
                AccountSelectorSheet(selectedAccount: $selectedAccount)
            }
            .sheet(isPresented: $showSubcategorySelector) {
                SubcategorySelectorSheet(
                    selectedSubcategory: $selectedSubcategory,
                    transactionType: transactionType
                )
            }
            .sheet(isPresented: $showTagSelector) {
                tagSelectorSheet
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isNameFocused = true
            }
        }
    }

    // MARK: - Name Section

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            SectionBox(title: "") {
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: "repeat")
                        .foregroundStyle(.secondary)
                        .frame(width: 24)

                    TextField(L10n.Common.name, text: $name)
                        .focused($isNameFocused)
                }
                .padding()
            }

            Text(L10n.Scheduled.saveDescription)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Fields Section

    private var fieldsSection: some View {
        SectionBox(title: L10n.Common.details) {
            VStack(spacing: 0) {
                // Amount (required - editable)
                amountRow

                SubsectionDivider()

                // Account (optional)
                fieldRow(
                    icon: "creditcard",
                    label: L10n.Transaction.account,
                    value: selectedAccount?.name,
                    color: selectedAccount.map { Color(hex: $0.colorHex) },
                    onTap: { showAccountSelector = true },
                    onClear: { selectedAccount = nil }
                )

                SubsectionDivider()

                // Subcategory (optional)
                fieldRow(
                    icon: "tag",
                    label: L10n.Transaction.subcategory,
                    value: selectedSubcategory?.name,
                    color: selectedSubcategory.map { Color(hex: $0.colorHex ?? $0.category.colorHex) },
                    onTap: { showSubcategorySelector = true },
                    onClear: { selectedSubcategory = nil }
                )

                SubsectionDivider()

                // Tags (optional)
                tagsRow

                if includeNote || !note.isEmpty {
                    SubsectionDivider()
                    noteRow
                }
            }
        }
    }

    private var amountRow: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "dollarsign.circle")
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(L10n.Transaction.amount)
                .foregroundStyle(.primary)

            Spacer()

            HStack(spacing: DS.Spacing.xs) {
                Text(currencyCode)
                    .foregroundStyle(.secondary)

                TextField("0.00", text: $amountString)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                    .focused($isAmountFocused)
            }
        }
        .padding()
    }

    private func fieldRow(
        icon: String,
        label: String,
        value: String?,
        color: Color? = nil,
        onTap: @escaping () -> Void,
        onClear: @escaping () -> Void
    ) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(label)
                .foregroundStyle(.primary)

            Spacer()

            if let value = value {
                Button(action: onTap) {
                    HStack(spacing: DS.Spacing.xs) {
                        if let color = color {
                            Circle()
                                .fill(color)
                                .frame(width: 8, height: 8)
                        }
                        Text(value)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)

                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            } else {
                Button(action: onTap) {
                    Text(L10n.Common.select)
                        .foregroundStyle(Color.electricIndigo)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .contentShape(Rectangle())
    }

    private var tagsRow: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "number")
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(L10n.Settings.tags)
                .foregroundStyle(.primary)

            Spacer()

            if selectedTags.isEmpty {
                Button { showTagSelector = true } label: {
                    Text(L10n.Common.select)
                        .foregroundStyle(Color.electricIndigo)
                }
                .buttonStyle(.plain)
            } else {
                Button { showTagSelector = true } label: {
                    Text("\(selectedTags.count)")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Button { selectedTags.removeAll() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .contentShape(Rectangle())
    }

    private var noteRow: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "note.text")
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(L10n.Transaction.note)
                .foregroundStyle(.primary)

            Spacer()

            if !note.isEmpty {
                Text(note)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Button { note = ""; includeNote = false } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
    }

    // MARK: - Tag Selector Sheet

    private var tagSelectorSheet: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

                ScrollView {
                    VStack(spacing: DS.Spacing.xxl) {
                        if activeTags.isEmpty {
                            YalaEmptyState(
                                icon: "tag.slash",
                                title: L10n.Empty.noTags,
                                message: L10n.Empty.tagsDescription
                            )
                        } else {
                            SectionBox(title: "") {
                                VStack(spacing: 0) {
                                    ForEach(Array(activeTags.enumerated()), id: \.element.persistentModelID) { index, tag in
                                        if index > 0 {
                                            SubsectionDivider()
                                        }
                                        Button {
                                            if selectedTags.contains(tag.persistentModelID) {
                                                selectedTags.remove(tag.persistentModelID)
                                            } else {
                                                selectedTags.insert(tag.persistentModelID)
                                            }
                                        } label: {
                                            HStack(spacing: DS.Spacing.md) {
                                                Circle()
                                                    .fill(Color(hex: tag.colorHex))
                                                    .frame(width: 28, height: 28)
                                                    .overlay(
                                                        Image(systemName: tag.iconName)
                                                            .font(.system(size: 12, weight: .semibold))
                                                            .foregroundStyle(.white)
                                                    )

                                                Text(tag.name)
                                                    .font(.body)
                                                    .foregroundStyle(.primary)

                                                Spacer()

                                                if selectedTags.contains(tag.persistentModelID) {
                                                    Image(systemName: "checkmark")
                                                        .font(.body.weight(.semibold))
                                                        .foregroundStyle(Color.electricIndigo)
                                                }
                                            }
                                            .padding(.horizontal, DS.Spacing.lg)
                                            .padding(.vertical, DS.FormRow.paddingV)
                                            .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.xxl)
                }
            }
            .navigationTitle(L10n.Settings.tags)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark") {
                        showTagSelector = false
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    YalaSaveButton(action: { showTagSelector = false })
                }
            }
        }
        .tint(Color.electricIndigo)
        .presentationDetents([.medium, .large])
    }

    // MARK: - Subscription Section

    private var subscriptionSection: some View {
        SectionBox(title: "") {
            Toggle(isOn: isSubscriptionBinding) {
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundStyle(.secondary)
                        .frame(width: 24)
                    Text(NSLocalizedString("scheduled.is.subscription", comment: ""))
                }
            }
            .tint(Color.electricIndigo)
            .padding()
        }
    }

    private var isSubscriptionBinding: Binding<Bool> {
        Binding(
            get: { paymentCategory == .subscription },
            set: { paymentCategory = $0 ? .subscription : .recurring }
        )
    }

    // MARK: - Recurrence Section

    private var recurrenceSection: some View {
        SectionBox(title: NSLocalizedString("scheduled.editor.recurrence", comment: "")) {
            VStack(spacing: 0) {
                Picker("", selection: $isRecurring) {
                    Text(NSLocalizedString("scheduled.recurrence.onetime", comment: "")).tag(false)
                    Text(NSLocalizedString("scheduled.recurrence.recurring", comment: "")).tag(true)
                }
                .pickerStyle(.segmented)
                .padding()

                SubsectionDivider()

                if !isRecurring {
                    paymentDateRow
                } else {
                    recurrenceIntervalRow

                    SubsectionDivider()

                    switch recurrenceType {
                    case .daily:
                        EmptyView()
                    case .weekly:
                        weekdaySelector
                        SubsectionDivider()
                    case .monthly:
                        dayOfMonthPicker
                        SubsectionDivider()
                    case .yearly:
                        yearlyDatePicker
                        SubsectionDivider()
                    }

                    startDateRow

                    SubsectionDivider()

                    endDateSection
                }
            }
        }
    }

    private var paymentDateRow: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "calendar")
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(NSLocalizedString("scheduled.payment.date", comment: ""))
                .foregroundStyle(.primary)

            Spacer()

            DatePicker("", selection: $startDate, displayedComponents: .date)
                .labelsHidden()
        }
        .padding()
    }

    private var recurrenceIntervalRow: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "repeat")
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(NSLocalizedString("scheduled.every", comment: ""))
                .foregroundStyle(.primary)

            Picker("", selection: $recurrenceInterval) {
                ForEach(1...30, id: \.self) { num in
                    Text("\(num)").tag(num)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 60)

            Picker("", selection: $recurrenceType) {
                ForEach(RecurrenceType.allCases) { type in
                    Text(recurrenceInterval == 1 ? type.localizedNameSingular : type.localizedNamePlural)
                        .tag(type)
                }
            }
            .pickerStyle(.menu)

            Spacer()
        }
        .padding()
    }

    private var weekdaySelector: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "calendar.day.timeline.left")
                    .foregroundStyle(.secondary)
                    .frame(width: 24)

                Text(NSLocalizedString("scheduled.which.days", comment: ""))
                    .foregroundStyle(.primary)
            }

            HStack(spacing: DS.Spacing.sm) {
                ForEach(weekdayOptions, id: \.value) { weekday in
                    weekdayChip(weekday)
                }
            }
        }
        .padding()
    }

    private var weekdayOptions: [(value: Int, short: String)] {
        [
            (1, NSLocalizedString("weekday.short.sunday", comment: "")),
            (2, NSLocalizedString("weekday.short.monday", comment: "")),
            (3, NSLocalizedString("weekday.short.tuesday", comment: "")),
            (4, NSLocalizedString("weekday.short.wednesday", comment: "")),
            (5, NSLocalizedString("weekday.short.thursday", comment: "")),
            (6, NSLocalizedString("weekday.short.friday", comment: "")),
            (7, NSLocalizedString("weekday.short.saturday", comment: ""))
        ]
    }

    private func weekdayChip(_ weekday: (value: Int, short: String)) -> some View {
        let isSelected = selectedWeekdays.contains(weekday.value)

        return Button {
            if isSelected {
                if selectedWeekdays.count > 1 {
                    selectedWeekdays.remove(weekday.value)
                }
            } else {
                selectedWeekdays.insert(weekday.value)
            }
        } label: {
            Text(weekday.short)
                .font(.caption.weight(.medium))
                .foregroundStyle(isSelected ? .white : .primary)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(isSelected ? Color.electricIndigo : Color(.tertiarySystemFill))
                )
        }
        .buttonStyle(.plain)
    }

    private var dayOfMonthPicker: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "number")
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(NSLocalizedString("scheduled.editor.day.of.month", comment: ""))
                .foregroundStyle(.primary)

            Spacer()

            Picker("", selection: $dayOfMonth) {
                ForEach(1...31, id: \.self) { day in
                    Text("\(day)").tag(day)
                }
            }
            .pickerStyle(.menu)
        }
        .padding()
    }

    private var yearlyDatePicker: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "calendar")
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(NSLocalizedString("scheduled.yearly.date", comment: ""))
                .foregroundStyle(.primary)

            Spacer()

            Picker("", selection: $yearlyMonth) {
                ForEach(1...12, id: \.self) { month in
                    Text(monthName(month)).tag(month)
                }
            }
            .pickerStyle(.menu)

            Picker("", selection: $yearlyDay) {
                ForEach(1...daysInMonth(yearlyMonth), id: \.self) { day in
                    Text("\(day)").tag(day)
                }
            }
            .pickerStyle(.menu)
        }
        .padding()
    }

    private func monthName(_ month: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        return formatter.monthSymbols[month - 1]
    }

    private func daysInMonth(_ month: Int) -> Int {
        switch month {
        case 2: return 29
        case 4, 6, 9, 11: return 30
        default: return 31
        }
    }

    private var startDateRow: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "calendar.badge.plus")
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(NSLocalizedString("scheduled.start.date", comment: ""))
                .foregroundStyle(.primary)

            Spacer()

            DatePicker("", selection: $startDate, displayedComponents: .date)
                .labelsHidden()
        }
        .padding()
    }

    private var endDateSection: some View {
        VStack(spacing: 0) {
            Toggle(isOn: $hasEndDate) {
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: "calendar.badge.minus")
                        .foregroundStyle(.secondary)
                        .frame(width: 24)

                    Text(NSLocalizedString("scheduled.has.end.date", comment: ""))
                }
            }
            .tint(Color.electricIndigo)
            .padding()

            if hasEndDate {
                SubsectionDivider()

                HStack(spacing: DS.Spacing.md) {
                    Spacer()
                        .frame(width: 24 + DS.Spacing.md)

                    Text(NSLocalizedString("scheduled.end.date", comment: ""))
                        .foregroundStyle(.primary)

                    Spacer()

                    DatePicker("", selection: $endDate, in: startDate..., displayedComponents: .date)
                        .labelsHidden()
                }
                .padding()
            }
        }
    }

    // MARK: - Save

    private func saveRecurring() {
        let finalName = name.trimmingCharacters(in: .whitespaces)
        guard !finalName.isEmpty else { return }
        guard parsedAmount > 0 else { return }

        let nextDueDate = startDate

        let scheduled = ScheduledPayment(
            name: finalName,
            note: includeNote && !note.isEmpty ? note : nil,
            amount: parsedAmount,
            currencyCode: currencyCode,
            transactionType: transactionType.rawValue,
            account: selectedAccount,
            subcategory: selectedSubcategory,
            tags: selectedTagObjects,
            natureOverride: natureOverride?.rawValue,
            isRecurring: isRecurring,
            recurrenceType: recurrenceType.rawValue,
            recurrenceInterval: recurrenceInterval,
            nextDueDate: nextDueDate,
            paymentCategory: paymentCategory.rawValue
        )

        if isRecurring {
            switch recurrenceType {
            case .weekly:
                scheduled.selectedWeekdays = selectedWeekdays.sorted().map(String.init).joined(separator: ",")
            case .monthly:
                scheduled.dayOfMonth = dayOfMonth
            case .yearly:
                scheduled.yearlyMonth = yearlyMonth
                scheduled.yearlyDay = yearlyDay
            case .daily:
                break
            }

            if hasEndDate {
                scheduled.endDate = endDate
            }
        }

        scheduled.isActive = true
        scheduled.notifyOnDueDate = true
        scheduled.notifyDaysBefore = 3

        modelContext.insert(scheduled)
        do {
            try modelContext.save()
            onSaved(L10n.Action.savedAsRecurring)
            dismiss()
        } catch {
            print("Error saving recurring payment: \(error)")
        }
    }
}
