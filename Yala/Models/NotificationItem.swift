//
//  NotificationItem.swift
//  Yala
//
//  Modelo para notificaciones personalizables.
//

import Foundation
import SwiftData

// MARK: - NotificationType

/// Tipos de notificación predefinidos
enum NotificationType: String, Codable, CaseIterable, Sendable {
    case endOfDay = "endOfDay"
    case lunchTime = "lunchTime"
    case dailyReport = "dailyReport"
    case weeklyReport = "weeklyReport"
    case monthlyReport = "monthlyReport"
    case scheduledPayments = "scheduledPayments"
    case groups = "groups"
    case custom = "custom"

    /// Localization key suffix for report period: "daily", "weekly", "monthly"
    var periodKeySuffix: String {
        switch self {
        case .dailyReport: "daily"
        case .weeklyReport: "weekly"
        case .monthlyReport: "monthly"
        default: "daily"
        }
    }

    var defaultIcon: String {
        switch self {
        case .endOfDay: return "moon.stars.fill"
        case .lunchTime: return "fork.knife"
        case .dailyReport: return "chart.bar.fill"
        case .weeklyReport: return "calendar.badge.clock"
        case .monthlyReport: return "calendar"
        case .scheduledPayments: return "creditcard.fill"
        case .groups: return "person.2.fill"
        case .custom: return "bell.fill"
        }
    }

    var defaultColor: String {
        switch self {
        case .endOfDay: return "#5E5CE6"      // Purple
        case .lunchTime: return "#FF9F0A"     // Orange
        case .dailyReport: return "#30D158"   // Green
        case .weeklyReport: return "#32ADE6"  // Teal
        case .monthlyReport: return "#0A84FF" // Blue
        case .scheduledPayments: return "#FF375F" // Pink
        case .groups: return "#8B5CF6"        // Purple
        case .custom: return "#64D2FF"        // Cyan
        }
    }

    /// Hora por defecto (hour, minute)
    var defaultTime: (hour: Int, minute: Int) {
        switch self {
        case .endOfDay: return (20, 0)        // 8:00 PM
        case .lunchTime: return (13, 30)      // 1:30 PM
        case .dailyReport: return (21, 0)     // 9:00 PM
        case .weeklyReport: return (9, 0)     // 9:00 AM
        case .monthlyReport: return (9, 0)    // 9:00 AM
        case .scheduledPayments: return (9, 0) // 9:00 AM
        case .groups: return (10, 0)          // 10:00 AM (not used — event-driven)
        case .custom: return (12, 0)          // 12:00 PM
        }
    }

    /// Whether the notification text is customizable by user
    var isTextCustomizable: Bool {
        switch self {
        case .endOfDay, .lunchTime, .custom:
            return true
        case .dailyReport, .weeklyReport, .monthlyReport, .scheduledPayments, .groups:
            return false
        }
    }

    /// Whether the notification name is customizable by user
    var isNameCustomizable: Bool {
        switch self {
        case .custom:
            return true
        default:
            return false
        }
    }

    /// Whether this notification can be deleted
    var isDeletable: Bool {
        return self == .custom
    }

    /// Whether this is a report type notification
    var isReportType: Bool {
        switch self {
        case .dailyReport, .weeklyReport, .monthlyReport:
            return true
        default:
            return false
        }
    }

    /// Whether this notification supports weekday selection
    var supportsWeekdaySelection: Bool {
        switch self {
        case .dailyReport, .custom:
            return true
        default:
            return false
        }
    }

    /// Whether icon/color can be customized
    var supportsIconColorCustomization: Bool {
        return self == .custom
    }

    /// Whether this notification requires dynamic content calculated at runtime
    /// These types should NOT use UNCalendarNotificationTrigger(repeats:) because
    /// the content would be frozen at schedule time. Instead, they use background
    /// tasks and foreground checks to send notifications with real data.
    var requiresDynamicContent: Bool {
        switch self {
        case .dailyReport, .weeklyReport, .monthlyReport,
             .scheduledPayments, .groups:
            return true
        default:
            return false
        }
    }

    /// Whether this notification is event-driven (no configurable schedule)
    var isEventDriven: Bool {
        self == .groups
    }

    /// Whether this notification can be edited by tapping
    var isEditable: Bool {
        self != .groups
    }
}

// MARK: - ReportDataType

/// Tipo de dato a incluir en reportes
enum ReportDataType: String, Codable, CaseIterable, Sendable {
    case balance = "balance"
    case expenses = "expenses"
    case income = "income"
    case topCategory = "topCategory"

    var displayName: String {
        switch self {
        case .balance: return L10n.Notifications.dataBalance
        case .expenses: return L10n.Notifications.dataExpenses
        case .income: return L10n.Notifications.dataIncome
        case .topCategory: return L10n.Notifications.dataTopCategory
        }
    }

    var icon: String {
        switch self {
        case .balance: return "banknote"
        case .expenses: return "arrow.down.circle"
        case .income: return "arrow.up.circle"
        case .topCategory: return "chart.pie"
        }
    }
}

// MARK: - ReportDayPreference

/// Preferencia de día para reportes semanales/mensuales
enum ReportDayPreference: String, Codable, CaseIterable, Sendable {
    // Weekly
    case sunday = "sunday"      // Include Sunday (report on Sunday)
    case monday = "monday"      // Exclude Sunday (report on Monday)

    // Monthly
    case lastDay = "lastDay"    // Last day of month
    case firstDay = "firstDay"  // First day of next month

    var weeklyDisplayName: String {
        switch self {
        case .sunday: return L10n.Notifications.daySunday
        case .monday: return L10n.Notifications.dayMonday
        default: return ""
        }
    }

    var monthlyDisplayName: String {
        switch self {
        case .lastDay: return L10n.Notifications.dayLastOfMonth
        case .firstDay: return L10n.Notifications.dayFirstOfMonth
        default: return ""
        }
    }
}

// MARK: - ReportConfig

/// Configuración para reportes (diario, semanal, mensual)
struct ReportConfig: Equatable, Sendable {
    var dataType: ReportDataType = .expenses
    var dayPreference: ReportDayPreference = .monday // For weekly/monthly

    static let `default` = ReportConfig()

    /// Encode to Data for storage
    func toData() -> Data? {
        // Manual encoding to avoid Codable concurrency issues
        let dict: [String: String] = [
            "dataType": dataType.rawValue,
            "dayPreference": dayPreference.rawValue
        ]
        do {
            return try JSONSerialization.data(withJSONObject: dict)
        } catch {
            #if DEBUG
            print("ReportConfig: Error encoding to data: \(error)")
            #endif
            return nil
        }
    }

    /// Decode from Data
    static func fromData(_ data: Data) -> ReportConfig? {
        let jsonObject: Any
        do {
            jsonObject = try JSONSerialization.jsonObject(with: data)
        } catch {
            #if DEBUG
            print("ReportConfig: Error decoding from data: \(error)")
            #endif
            return nil
        }
        guard let dict = jsonObject as? [String: String],
              let dataTypeRaw = dict["dataType"],
              let dayPrefRaw = dict["dayPreference"],
              let dataType = ReportDataType(rawValue: dataTypeRaw),
              let dayPref = ReportDayPreference(rawValue: dayPrefRaw) else {
            return nil
        }
        return ReportConfig(dataType: dataType, dayPreference: dayPref)
    }
}

// MARK: - NotificationItem

@Model
final class NotificationItem {
    // CloudKit: defaults required
    var id: UUID = UUID()
    var name: String = ""
    var text: String = ""
    var hour: Int = 12
    var minute: Int = 0
    var typeRaw: String = "custom"
    var isActive: Bool = true
    var iconName: String = "bell.fill"
    var colorHex: String = "#6366F1"
    var createdAt: Date = Date.now
    var sortOrder: Int = 0

    /// JSON-encoded configuration for report notifications
    var configurationData: Data?

    /// Selected weekdays as comma-separated string (1=Sun, 2=Mon, ..., 7=Sat)
    /// Empty or nil means all days (daily)
    var weekdaysRaw: String?

    /// Last time this notification was sent (prevents duplicate sends within same period)
    /// Used by ReportNotificationService to avoid spam when app is opened multiple times
    var lastNotifiedDate: Date?

    /// Computed property for notification type
    var notificationType: NotificationType {
        get { NotificationType(rawValue: typeRaw) ?? .custom }
        set { typeRaw = newValue.rawValue }
    }

    /// Computed property for time as Date (for DatePicker)
    var scheduledTime: Date {
        get {
            var components = DateComponents()
            components.hour = hour
            components.minute = minute
            return Calendar.current.date(from: components) ?? Date.now
        }
        set {
            let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            hour = components.hour ?? 12
            minute = components.minute ?? 0
        }
    }

    /// Formatted time string
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: scheduledTime)
    }

    /// Report configuration (for report types)
    var reportConfig: ReportConfig {
        get {
            guard notificationType.isReportType,
                  let data = configurationData else {
                return .default
            }
            return ReportConfig.fromData(data) ?? .default
        }
        set {
            configurationData = newValue.toData()
        }
    }

    /// Selected weekdays as Set (1=Sunday, 2=Monday, ..., 7=Saturday)
    /// Empty set means all days
    var selectedWeekdays: Set<Int> {
        get {
            guard let raw = weekdaysRaw, !raw.isEmpty else {
                return [] // All days
            }
            let days = raw.split(separator: ",").compactMap { Int($0) }
            return Set(days)
        }
        set {
            if newValue.isEmpty || newValue.count == 7 {
                weekdaysRaw = nil // All days
            } else {
                weekdaysRaw = newValue.sorted().map { String($0) }.joined(separator: ",")
            }
        }
    }

    /// Check if notification should fire on a given weekday (1=Sunday...7=Saturday)
    func shouldFireOnWeekday(_ weekday: Int) -> Bool {
        let selected = selectedWeekdays
        return selected.isEmpty || selected.contains(weekday)
    }

    /// Formatted weekdays string for display
    var formattedWeekdays: String {
        let selected = selectedWeekdays
        if selected.isEmpty || selected.count == 7 {
            return L10n.Notifications.allDays
        }

        let symbols = Calendar.current.shortWeekdaySymbols
        let sorted = selected.sorted()
        let names = sorted.compactMap { day -> String? in
            guard day >= 1 && day <= 7 else { return nil }
            return symbols[day - 1]
        }
        return names.joined(separator: ", ")
    }

    init(
        id: UUID = UUID(),
        name: String,
        text: String,
        hour: Int,
        minute: Int,
        type: NotificationType,
        isActive: Bool = true,
        iconName: String? = nil,
        colorHex: String? = nil,
        sortOrder: Int = 0,
        reportConfig: ReportConfig? = nil
    ) {
        self.id = id
        self.name = name
        self.text = text
        self.hour = hour
        self.minute = minute
        self.typeRaw = type.rawValue
        self.isActive = isActive
        self.iconName = iconName ?? type.defaultIcon
        self.colorHex = colorHex ?? type.defaultColor
        self.createdAt = Date.now
        self.sortOrder = sortOrder

        // Set default config for report types
        if type.isReportType {
            self.configurationData = (reportConfig ?? .default).toData()
        }
    }

    // MARK: - Factory Methods

    /// Create default notifications for first-time setup
    static func createDefaults() -> [NotificationItem] {
        return [
            // Recordatorios
            NotificationItem(
                name: L10n.Notifications.endOfDayName,
                text: L10n.Notifications.endOfDayText,
                hour: NotificationType.endOfDay.defaultTime.hour,
                minute: NotificationType.endOfDay.defaultTime.minute,
                type: .endOfDay,
                isActive: false,
                sortOrder: 0
            ),
            NotificationItem(
                name: L10n.Notifications.lunchTimeName,
                text: L10n.Notifications.lunchTimeText,
                hour: NotificationType.lunchTime.defaultTime.hour,
                minute: NotificationType.lunchTime.defaultTime.minute,
                type: .lunchTime,
                isActive: false,
                sortOrder: 1
            ),
            // Reportes
            NotificationItem(
                name: L10n.Notifications.dailyReportName,
                text: "", // Generated dynamically
                hour: NotificationType.dailyReport.defaultTime.hour,
                minute: NotificationType.dailyReport.defaultTime.minute,
                type: .dailyReport,
                isActive: false,
                sortOrder: 2,
                reportConfig: ReportConfig(dataType: .expenses, dayPreference: .monday)
            ),
            NotificationItem(
                name: L10n.Notifications.weeklyReportName,
                text: "", // Generated dynamically
                hour: NotificationType.weeklyReport.defaultTime.hour,
                minute: NotificationType.weeklyReport.defaultTime.minute,
                type: .weeklyReport,
                isActive: false,
                sortOrder: 3,
                reportConfig: ReportConfig(dataType: .expenses, dayPreference: .monday)
            ),
            NotificationItem(
                name: L10n.Notifications.monthlyReportName,
                text: "", // Generated dynamically
                hour: NotificationType.monthlyReport.defaultTime.hour,
                minute: NotificationType.monthlyReport.defaultTime.minute,
                type: .monthlyReport,
                isActive: false,
                sortOrder: 4,
                reportConfig: ReportConfig(dataType: .expenses, dayPreference: .firstDay)
            ),
            // Sistema
            NotificationItem(
                name: L10n.Notifications.scheduledPaymentsName,
                text: "", // Generated dynamically based on payment
                hour: NotificationType.scheduledPayments.defaultTime.hour,
                minute: NotificationType.scheduledPayments.defaultTime.minute,
                type: .scheduledPayments,
                isActive: false,
                sortOrder: 5
            ),
            // Grupos
            NotificationItem(
                name: L10n.Notifications.groupsName,
                text: "", // Event-driven — no static text
                hour: NotificationType.groups.defaultTime.hour,
                minute: NotificationType.groups.defaultTime.minute,
                type: .groups,
                isActive: false,
                sortOrder: 6
            ),
        ]
    }
}

// MARK: - Text Length Limits

extension NotificationItem {
    static let maxNameLength = 30
    static let maxTextLength = 100
}

// MARK: - Localized Display

extension NotificationItem {
    /// Returns the localized name for predefined types, or the stored name for custom notifications
    var localizedName: String {
        switch notificationType {
        case .endOfDay: return L10n.Notifications.endOfDayName
        case .lunchTime: return L10n.Notifications.lunchTimeName
        case .dailyReport: return L10n.Notifications.dailyReportName
        case .weeklyReport: return L10n.Notifications.weeklyReportName
        case .monthlyReport: return L10n.Notifications.monthlyReportName
        case .scheduledPayments: return L10n.Notifications.scheduledPaymentsName
        case .groups: return L10n.Notifications.groupsName
        case .custom: return name
        }
    }

    /// Returns the localized text if it matches a known default, or the stored text if user-customized
    var localizedText: String {
        switch notificationType {
        case .endOfDay:
            return Self.defaultEndOfDayTexts.contains(text) ? L10n.Notifications.endOfDayText : text
        case .lunchTime:
            return Self.defaultLunchTimeTexts.contains(text) ? L10n.Notifications.lunchTimeText : text
        case .custom:
            return text
        default:
            return text
        }
    }

    // MARK: Default text sets (all supported languages)

    private static let defaultEndOfDayTexts: Set<String> = collectDefaults(for: "notifications.endOfDay.text")
    private static let defaultLunchTimeTexts: Set<String> = collectDefaults(for: "notifications.lunchTime.text")

    private static func collectDefaults(for key: String) -> Set<String> {
        var texts = Set<String>()
        for lang in LanguageManager.supportedLanguages {
            if let path = Bundle.main.path(forResource: lang.code, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                texts.insert(NSLocalizedString(key, bundle: bundle, comment: ""))
            }
        }
        return texts
    }
}

// MARK: - Display Text Generation

extension NotificationItem {
    /// Get the display text for this notification (for preview in list)
    var displayText: String {
        switch notificationType {
        case .dailyReport:
            return L10n.Notifications.dailyReportHint(formattedTime, reportConfig.dataType.displayName)
        case .weeklyReport:
            let day = reportConfig.dayPreference.weeklyDisplayName
            return L10n.Notifications.weeklyReportHint(reportConfig.dataType.displayName, day)
        case .monthlyReport:
            let day = reportConfig.dayPreference.monthlyDisplayName
            return L10n.Notifications.monthlyReportHint(reportConfig.dataType.displayName, day)
        case .scheduledPayments:
            return L10n.Notifications.scheduledPaymentsHint
        case .groups:
            return L10n.Notifications.groupsHint
        default:
            return localizedText
        }
    }
}
