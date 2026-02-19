//
//  NotificationEditorSheet.swift
//  Yala
//
//  Sheet para crear/editar una notificación.
//

import SwiftUI

struct NotificationEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.yalaTheme) private var theme
    @FocusState private var focusedField: Field?

    let notification: NotificationItem?
    let onSave: (NotificationItem) -> Void

    // Form state
    @State private var name: String = ""
    @State private var text: String = ""
    @State private var scheduledTime: Date = Date()

    // Report config (for report types)
    @State private var selectedDataType: ReportDataType = .expenses
    @State private var selectedDayPreference: ReportDayPreference = .monday

    // Icon/color (for custom notifications)
    @State private var selectedIconName: String = NotificationType.custom.defaultIcon
    @State private var selectedColorHex: String = NotificationType.custom.defaultColor
    @State private var showingIconPicker: Bool = false

    // Weekday selection (for custom and daily report)
    @State private var selectedWeekdays: Set<Int> = [] // Empty = all days

    private var isEditing: Bool { notification != nil }
    private var notificationType: NotificationType { notification?.notificationType ?? .custom }

    // Type checks
    private var isCustom: Bool { notificationType == .custom }
    private var isReportType: Bool { notificationType.isReportType }
    private var isTextCustomizable: Bool { notificationType.isTextCustomizable }
    private var isNameCustomizable: Bool { notificationType.isNameCustomizable }

    // For weekly/monthly reports
    private var showDayPreference: Bool {
        notificationType == .weeklyReport || notificationType == .monthlyReport
    }

    // For weekday selection (custom and daily report)
    private var showWeekdaySelection: Bool {
        notificationType.supportsWeekdaySelection
    }

    // For icon/color customization (custom only)
    private var showIconColorPicker: Bool {
        notificationType.supportsIconColorCustomization
    }

    private var canSave: Bool {
        if isCustom {
            return !name.trimmingCharacters(in: .whitespaces).isEmpty &&
                   !text.trimmingCharacters(in: .whitespaces).isEmpty
        }
        return true // Non-custom notifications always valid
    }

    private enum Field: Hashable {
        case name
        case text
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()
                    .dismissKeyboardOnTap()

                ScrollView {
                    VStack(spacing: DS.Spacing.xxl) {
                        // Icon preview (tappable for custom notifications)
                        iconPreview

                        // Time section (always shown)
                        timeSection

                        // Weekday selection (for custom and daily report)
                        if showWeekdaySelection {
                            weekdaySection
                        }

                        // Report config (for report types)
                        if isReportType {
                            reportConfigSection
                        }

                        // Day preference (for weekly/monthly reports)
                        dayPreferenceSection

                        // Text section (only for customizable types)
                        if isTextCustomizable {
                            textSection
                        }

                        // Test button
                        testNotificationButton
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.xxl)
                }
                .scrollDismissesKeyboard(.interactively)
                .sheet(isPresented: $showingIconPicker) {
                    IconColorPickerSheet(
                        selectedIconName: $selectedIconName,
                        selectedColorHex: $selectedColorHex
                    )
                }
            }
            .navigationTitle(notification?.name ?? L10n.Notifications.addNew)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: "Cerrar") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    YalaSaveButton(action: saveNotification, isDisabled: !canSave)
                }
            }
            .onAppear {
                loadNotificationData()
            }
        }
    }

    // MARK: - Icon Preview

    private var iconPreview: some View {
        VStack(spacing: DS.Spacing.md) {
            // Icon circle (tappable only for custom notifications)
            iconCircle

            // Show dynamic hint for non-customizable types
            if !isTextCustomizable && !isCustom {
                Text(currentPreviewText)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Spacing.xl)
            }
        }
        .padding(.top, DS.Spacing.lg)
    }

    @ViewBuilder
    private var iconCircle: some View {
        if showIconColorPicker {
            // Tappable for custom notifications
            Button {
                showingIconPicker = true
            } label: {
                iconCircleContent
            }
            .buttonStyle(.plain)
        } else {
            // Non-tappable for default notifications (no dimming)
            iconCircleContent
        }
    }

    private var iconCircleContent: some View {
        ZStack {
            Circle()
                .fill(Color(hex: currentIconColor))
                .frame(width: 80, height: 80)

            Image(systemName: currentIconName)
                .font(DS.Typography.amountLarge)
                .foregroundStyle(.white)

            // Edit badge for custom notifications
            if showIconColorPicker {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: "pencil.circle.fill")
                            .font(DS.Typography.largeTitle)
                            .foregroundStyle(Color(hex: selectedColorHex))
                            .background(Circle().fill(.thBackground).padding(2))
                    }
                }
                .frame(width: 80, height: 80)
            }
        }
    }

    /// Current icon name (from selection or notification)
    private var currentIconName: String {
        if showIconColorPicker {
            return selectedIconName
        }
        return notification?.iconName ?? notificationType.defaultIcon
    }

    /// Current icon color (from selection or notification)
    private var currentIconColor: String {
        if showIconColorPicker {
            return selectedColorHex
        }
        return notification?.colorHex ?? notificationType.defaultColor
    }

    /// Dynamic preview text based on current selections
    private var currentPreviewText: String {
        switch notificationType {
        case .dailyReport:
            let timeString = formattedScheduledTime
            return L10n.Notifications.dailyReportHint(timeString, selectedDataType.displayName)
        case .weeklyReport:
            let day = selectedDayPreference.weeklyDisplayName
            return L10n.Notifications.weeklyReportHint(selectedDataType.displayName, day)
        case .monthlyReport:
            let day = selectedDayPreference.monthlyDisplayName
            return L10n.Notifications.monthlyReportHint(selectedDataType.displayName, day)
        case .scheduledPayments:
            return L10n.Notifications.scheduledPaymentsHint
        case .announcements:
            return L10n.Notifications.announcementsHint
        default:
            return notification?.displayText ?? ""
        }
    }

    /// Formatted time string for preview
    private var formattedScheduledTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: scheduledTime)
    }

    // MARK: - Time Section

    private var timeSection: some View {
        SectionBox(title: L10n.Notifications.time) {
            HStack {
                Image(systemName: "clock")
                    .font(DS.Typography.body)
                    .foregroundStyle(.secondary)
                    .frame(width: 28)

                Text(L10n.Notifications.time)
                    .font(DS.Typography.body)
                    .foregroundStyle(.primary)

                Spacer()

                DatePicker(
                    "",
                    selection: $scheduledTime,
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()

            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.FormRow.paddingV)
        }
    }

    // MARK: - Weekday Selection Section

    private var weekdaySection: some View {
        SectionBox(title: L10n.Notifications.selectWeekdays) {
            HStack(spacing: DS.Spacing.sm) {
                ForEach(weekdayOptions, id: \.value) { weekday in
                    weekdayChip(weekday)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
    }

    private var weekdayOptions: [(value: Int, short: String)] {
        [
            (1, L10n.Weekday.shortSunday),
            (2, L10n.Weekday.shortMonday),
            (3, L10n.Weekday.shortTuesday),
            (4, L10n.Weekday.shortWednesday),
            (5, L10n.Weekday.shortThursday),
            (6, L10n.Weekday.shortFriday),
            (7, L10n.Weekday.shortSaturday)
        ]
    }

    private func weekdayChip(_ weekday: (value: Int, short: String)) -> some View {
        let isSelected = selectedWeekdays.isEmpty || selectedWeekdays.contains(weekday.value)

        return Button {
            toggleWeekday(weekday.value)
        } label: {
            Text(weekday.short)
                .font(DS.Typography.labelSmall)
                .foregroundStyle(isSelected ? .white : .primary)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(isSelected ? theme.accent : Color(.tertiarySystemFill))
                )
        }
        .buttonStyle(.plain)
    }

    private func toggleWeekday(_ weekday: Int) {
        // If all days selected (empty set), start with just this day
        if selectedWeekdays.isEmpty {
            selectedWeekdays = Set(1...7)
            selectedWeekdays.remove(weekday)
        } else if selectedWeekdays.contains(weekday) {
            // Don't allow deselecting the last day
            if selectedWeekdays.count > 1 {
                selectedWeekdays.remove(weekday)
            }
        } else {
            selectedWeekdays.insert(weekday)
            // If all days selected, clear to represent "all days"
            if selectedWeekdays.count == 7 {
                selectedWeekdays = []
            }
        }
    }

    // MARK: - Report Config Section

    private var availableDataTypes: [ReportDataType] {
        if SessionState.shared.isExpensesOnlyMode {
            return ReportDataType.allCases.filter { $0 != .income && $0 != .balance }
        }
        return ReportDataType.allCases
    }

    private var reportConfigSection: some View {
        SectionBox(title: L10n.Notifications.selectData) {
            VStack(spacing: DS.Spacing.none) {
                // Data type selection
                ForEach(Array(availableDataTypes.enumerated()), id: \.element) { index, dataType in
                    Button {
                        selectedDataType = dataType
                    } label: {
                        HStack {
                            Image(systemName: dataType.icon)
                                .font(DS.Typography.body)
                                .foregroundStyle(.secondary)
                                .frame(width: 28)

                            Text(dataType.displayName.capitalized)
                                .font(DS.Typography.body)
                                .foregroundStyle(.primary)

                            Spacer()

                            if selectedDataType == dataType {
                                Image(systemName: "checkmark")
                                    .font(DS.Typography.headline)
                                    .foregroundStyle(.thAccent)
                            }
                        }
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.vertical, DS.FormRow.paddingV)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if index < availableDataTypes.count - 1 {
                        SubsectionDivider()
                    }
                }
            }
        }
    }

    // MARK: - Day Preference Section (for weekly/monthly)

    @ViewBuilder
    private var dayPreferenceSection: some View {
        if showDayPreference {
            SectionBox(title: L10n.Notifications.selectDay) {
                VStack(spacing: DS.Spacing.none) {
                    if notificationType == .weeklyReport {
                        dayPreferenceRow(.monday, display: L10n.Notifications.dayMonday)
                        SubsectionDivider()
                        dayPreferenceRow(.sunday, display: L10n.Notifications.daySunday)
                    } else if notificationType == .monthlyReport {
                        dayPreferenceRow(.firstDay, display: L10n.Notifications.dayFirstOfMonth)
                        SubsectionDivider()
                        dayPreferenceRow(.lastDay, display: L10n.Notifications.dayLastOfMonth)
                    }
                }
            }
        }
    }

    private func dayPreferenceRow(_ preference: ReportDayPreference, display: String) -> some View {
        Button {
            selectedDayPreference = preference
            // Update time based on day preference
            updateTimeForDayPreference(preference)
        } label: {
            HStack {
                Text(display.capitalized)
                    .font(DS.Typography.body)
                    .foregroundStyle(.primary)

                Spacer()

                if selectedDayPreference == preference {
                    Image(systemName: "checkmark")
                        .font(DS.Typography.headline)
                        .foregroundStyle(.thAccent)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.FormRow.paddingV)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Update scheduled time based on day preference
    private func updateTimeForDayPreference(_ preference: ReportDayPreference) {
        var components = DateComponents()

        switch preference {
        case .monday:
            // Monday morning 7:00 AM
            components.hour = 7
            components.minute = 0
        case .sunday:
            // Sunday evening 9:00 PM
            components.hour = 21
            components.minute = 0
        case .firstDay:
            // First day of month, morning 9:00 AM
            components.hour = 9
            components.minute = 0
        case .lastDay:
            // Last day of month, evening 8:00 PM
            components.hour = 20
            components.minute = 0
        }

        if let date = Calendar.current.date(from: components) {
            scheduledTime = date
        }
    }

    // MARK: - Text Section

    private var textSection: some View {
        SectionBox(title: L10n.Notifications.text) {
            VStack(spacing: DS.Spacing.none) {
                // Name field (only for custom)
                if isNameCustomizable {
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        HStack {
                            Image(systemName: "textformat")
                                .font(DS.Typography.body)
                                .foregroundStyle(.secondary)
                                .frame(width: 28)

                            TextField(L10n.Notifications.namePlaceholder, text: $name)
                                .focused($focusedField, equals: .name)
                                .onChange(of: name) { _, newValue in
                                    if newValue.count > NotificationItem.maxNameLength {
                                        name = String(newValue.prefix(NotificationItem.maxNameLength))
                                    }
                                }

                            Text("\(name.count)/\(NotificationItem.maxNameLength)")
                                .font(DS.Typography.caption)
                                .foregroundStyle(name.count > 20 ? DS.Semantic.warningForeground : Color.secondary)
                        }
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.vertical, DS.FormRow.paddingV)
                    }

                    SubsectionDivider()
                }

                // Text field
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    HStack(alignment: .top) {
                        Image(systemName: "text.bubble")
                            .font(DS.Typography.body)
                            .foregroundStyle(.secondary)
                            .frame(width: 28)
                            .padding(.top, 2)

                        VStack(alignment: .trailing, spacing: DS.Spacing.xs) {
                            TextField(L10n.Notifications.textPlaceholder, text: $text, axis: .vertical)
                                .focused($focusedField, equals: .text)
                                .lineLimit(3...5)
                                .onChange(of: text) { _, newValue in
                                    if newValue.count > NotificationItem.maxTextLength {
                                        text = String(newValue.prefix(NotificationItem.maxTextLength))
                                    }
                                }

                            Text("\(text.count)/\(NotificationItem.maxTextLength)")
                                .font(DS.Typography.caption)
                                .foregroundStyle(text.count > 80 ? DS.Semantic.warningForeground : Color.secondary)
                        }
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.FormRow.paddingV)
                }
            }
        }
    }

    // MARK: - Test Notification Button

    private var testNotificationButton: some View {
        Button {
            Task {
                let testText = getTestNotificationText()
                await NotificationService.shared.sendTestNotification(title: "Yala", body: testText)
            }
        } label: {
            HStack {
                Image(systemName: "bell.badge")
                Text(L10n.Notifications.testNotification)
            }
            .font(DS.Typography.label)
            .foregroundStyle(.thAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.md)
            .background(
                Capsule()
                    .fill(theme.accent.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
    }

    /// Get appropriate test text based on notification type
    private func getTestNotificationText() -> String {
        switch notificationType {
        case .dailyReport:
            return getTestTextForDataType(period: .daily)
        case .weeklyReport:
            return getTestTextForDataType(period: .weekly)
        case .monthlyReport:
            return getTestTextForDataType(period: .monthly)
        case .scheduledPayments:
            return L10n.Notifications.testScheduledPayment
        case .endOfDay, .lunchTime, .custom:
            return text.isEmpty ? L10n.Notifications.endOfDayText : text
        case .announcements:
            return L10n.Notifications.announcementsHint
        }
    }

    private enum TestPeriod {
        case daily, weekly, monthly
    }

    private func getTestTextForDataType(period: TestPeriod) -> String {
        switch (selectedDataType, period) {
        case (.balance, .daily): return L10n.Notifications.testBalanceDaily
        case (.balance, .weekly): return L10n.Notifications.testBalanceWeekly
        case (.balance, .monthly): return L10n.Notifications.testBalanceMonthly
        case (.expenses, .daily): return L10n.Notifications.testExpensesDaily
        case (.expenses, .weekly): return L10n.Notifications.testExpensesWeekly
        case (.expenses, .monthly): return L10n.Notifications.testExpensesMonthly
        case (.income, .daily): return L10n.Notifications.testIncomeDaily
        case (.income, .weekly): return L10n.Notifications.testIncomeWeekly
        case (.income, .monthly): return L10n.Notifications.testIncomeMonthly
        case (.topCategory, .daily): return L10n.Notifications.testTopCategoryDaily
        case (.topCategory, .weekly): return L10n.Notifications.testTopCategoryWeekly
        case (.topCategory, .monthly): return L10n.Notifications.testTopCategoryMonthly
        }
    }

    // MARK: - Data Loading

    private func loadNotificationData() {
        guard let notification = notification else {
            // Set default time for new notification
            var components = DateComponents()
            components.hour = 12
            components.minute = 0
            scheduledTime = Calendar.current.date(from: components) ?? Date()
            return
        }

        name = notification.name
        text = notification.text
        scheduledTime = notification.scheduledTime

        // Load icon/color for custom notifications
        if notification.notificationType.supportsIconColorCustomization {
            selectedIconName = notification.iconName
            selectedColorHex = notification.colorHex
        }

        // Load weekdays if supported
        if notification.notificationType.supportsWeekdaySelection {
            selectedWeekdays = notification.selectedWeekdays
        }

        // Load report config
        if notification.notificationType.isReportType {
            let config = notification.reportConfig
            selectedDataType = config.dataType
            selectedDayPreference = config.dayPreference

            // In expenses-only mode, force incompatible data types to expenses
            if SessionState.shared.isExpensesOnlyMode &&
                (selectedDataType == .income || selectedDataType == .balance) {
                selectedDataType = .expenses
            }
        }
    }

    // MARK: - Save

    private func saveNotification() {
        let timeComponents = Calendar.current.dateComponents([.hour, .minute], from: scheduledTime)

        if let notification = notification {
            // Update existing
            notification.hour = timeComponents.hour ?? 12
            notification.minute = timeComponents.minute ?? 0

            // Update text only if customizable
            if notification.notificationType.isTextCustomizable {
                notification.text = text.trimmingCharacters(in: .whitespaces)
            }

            // Update name only if customizable
            if notification.notificationType.isNameCustomizable {
                notification.name = name.trimmingCharacters(in: .whitespaces)
            }

            // Update icon/color for custom notifications
            if notification.notificationType.supportsIconColorCustomization {
                notification.iconName = selectedIconName
                notification.colorHex = selectedColorHex
            }

            // Update weekdays if supported
            if notification.notificationType.supportsWeekdaySelection {
                notification.selectedWeekdays = selectedWeekdays
            }

            // Update report config if applicable
            if notification.notificationType.isReportType {
                var config = ReportConfig()
                config.dataType = selectedDataType
                config.dayPreference = selectedDayPreference
                notification.reportConfig = config
            }

            onSave(notification)
        } else {
            // Create new custom notification
            let newNotification = NotificationItem(
                name: name.trimmingCharacters(in: .whitespaces),
                text: text.trimmingCharacters(in: .whitespaces),
                hour: timeComponents.hour ?? 12,
                minute: timeComponents.minute ?? 0,
                type: .custom,
                isActive: true,
                iconName: selectedIconName,
                colorHex: selectedColorHex,
                sortOrder: 100
            )
            newNotification.selectedWeekdays = selectedWeekdays

            onSave(newNotification)
        }

        dismiss()
    }
}

#Preview {
    NotificationEditorSheet(notification: nil) { _ in }
}
