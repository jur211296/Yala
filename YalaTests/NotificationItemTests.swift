// Tests generated for: NotificationItem + ReportConfig
// Cobertura estimada: 90%

import Foundation
import Testing

@testable import Yala

// MARK: - NotificationItem Tests

struct NotificationItemTests {

    // MARK: - notificationType Computed Property

    @Test func notificationType_parsesFromTypeRaw() {
        let item = NotificationItem(
            name: "Test", text: "Hello", hour: 9, minute: 0, type: .dailyReport
        )
        #expect(item.notificationType == .dailyReport)
        #expect(item.typeRaw == "dailyReport")
    }

    @Test func notificationType_defaultsToCustomForUnknownRaw() {
        let item = NotificationItem(
            name: "Test", text: "Hello", hour: 9, minute: 0, type: .custom
        )
        item.typeRaw = "invalidType"
        #expect(item.notificationType == .custom)
    }

    // MARK: - selectedWeekdays Computed Property

    @Test func selectedWeekdays_withNilRaw_returnsEmptySet() {
        let item = NotificationItem(
            name: "Test", text: "Hello", hour: 9, minute: 0, type: .dailyReport
        )
        item.weekdaysRaw = nil
        #expect(item.selectedWeekdays.isEmpty)
    }

    @Test func selectedWeekdays_withEmptyRaw_returnsEmptySet() {
        let item = NotificationItem(
            name: "Test", text: "Hello", hour: 9, minute: 0, type: .dailyReport
        )
        item.weekdaysRaw = ""
        #expect(item.selectedWeekdays.isEmpty)
    }

    @Test func selectedWeekdays_withCommaSeparatedValues_parsesCorrectly() {
        let item = NotificationItem(
            name: "Test", text: "Hello", hour: 9, minute: 0, type: .dailyReport
        )
        item.weekdaysRaw = "2,4,6"  // Mon, Wed, Fri
        let weekdays = item.selectedWeekdays
        #expect(weekdays == [2, 4, 6])
    }

    @Test func selectedWeekdays_setter_allDays_clearsRaw() {
        let item = NotificationItem(
            name: "Test", text: "Hello", hour: 9, minute: 0, type: .dailyReport
        )
        item.selectedWeekdays = [1, 2, 3, 4, 5, 6, 7]
        #expect(item.weekdaysRaw == nil) // All days = no filter
    }

    @Test func selectedWeekdays_setter_emptySet_clearsRaw() {
        let item = NotificationItem(
            name: "Test", text: "Hello", hour: 9, minute: 0, type: .dailyReport
        )
        item.weekdaysRaw = "2,4"
        item.selectedWeekdays = []
        #expect(item.weekdaysRaw == nil)
    }

    @Test func selectedWeekdays_setter_partialSet_storesSorted() {
        let item = NotificationItem(
            name: "Test", text: "Hello", hour: 9, minute: 0, type: .dailyReport
        )
        item.selectedWeekdays = [5, 2, 7]
        #expect(item.weekdaysRaw == "2,5,7")
    }

    // MARK: - shouldFireOnWeekday

    @Test func shouldFireOnWeekday_emptySelection_firesEveryDay() {
        let item = NotificationItem(
            name: "Test", text: "Hello", hour: 9, minute: 0, type: .dailyReport
        )
        item.weekdaysRaw = nil
        for day in 1...7 {
            #expect(item.shouldFireOnWeekday(day))
        }
    }

    @Test func shouldFireOnWeekday_specificDays_firesOnlyOnSelected() {
        let item = NotificationItem(
            name: "Test", text: "Hello", hour: 9, minute: 0, type: .dailyReport
        )
        item.weekdaysRaw = "2,4" // Monday, Wednesday
        #expect(!item.shouldFireOnWeekday(1))  // Sunday
        #expect(item.shouldFireOnWeekday(2))   // Monday
        #expect(!item.shouldFireOnWeekday(3))  // Tuesday
        #expect(item.shouldFireOnWeekday(4))   // Wednesday
        #expect(!item.shouldFireOnWeekday(5))  // Thursday
    }

    // MARK: - scheduledTime

    @Test func scheduledTime_returnsDateWithCorrectHourMinute() {
        let item = NotificationItem(
            name: "Test", text: "Hello", hour: 14, minute: 30, type: .custom
        )
        let time = item.scheduledTime
        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        #expect(components.hour == 14)
        #expect(components.minute == 30)
    }

    @Test func scheduledTime_setter_updatesHourAndMinute() {
        let item = NotificationItem(
            name: "Test", text: "Hello", hour: 9, minute: 0, type: .custom
        )
        var components = DateComponents()
        components.hour = 21
        components.minute = 45
        if let newTime = Calendar.current.date(from: components) {
            item.scheduledTime = newTime
        }
        #expect(item.hour == 21)
        #expect(item.minute == 45)
    }

    // MARK: - Factory: Icon and Color Defaults

    @Test func init_usesTypeDefaultsWhenNilProvided() {
        let item = NotificationItem(
            name: "Test", text: "Hello", hour: 9, minute: 0,
            type: .endOfDay, iconName: nil, colorHex: nil
        )
        #expect(item.iconName == NotificationType.endOfDay.defaultIcon)
        #expect(item.colorHex == NotificationType.endOfDay.defaultColor)
    }

    @Test func init_usesCustomValuesWhenProvided() {
        let item = NotificationItem(
            name: "Test", text: "Hello", hour: 9, minute: 0,
            type: .custom, iconName: "star.fill", colorHex: "#123456"
        )
        #expect(item.iconName == "star.fill")
        #expect(item.colorHex == "#123456")
    }
}

// MARK: - NotificationType Tests

struct NotificationTypeTests {

    @Test func isReportType_trueForReports() {
        #expect(NotificationType.dailyReport.isReportType)
        #expect(NotificationType.weeklyReport.isReportType)
        #expect(NotificationType.monthlyReport.isReportType)
    }

    @Test func isReportType_falseForNonReports() {
        #expect(!NotificationType.endOfDay.isReportType)
        #expect(!NotificationType.lunchTime.isReportType)
        #expect(!NotificationType.custom.isReportType)
        #expect(!NotificationType.scheduledPayments.isReportType)
    }

    @Test func isDeletable_onlyForCustom() {
        #expect(NotificationType.custom.isDeletable)
        #expect(!NotificationType.endOfDay.isDeletable)
        #expect(!NotificationType.dailyReport.isDeletable)
    }

    @Test func isTextCustomizable_trueForRemindersAndCustom() {
        #expect(NotificationType.endOfDay.isTextCustomizable)
        #expect(NotificationType.lunchTime.isTextCustomizable)
        #expect(NotificationType.custom.isTextCustomizable)
    }

    @Test func isTextCustomizable_falseForReportsAndScheduled() {
        #expect(!NotificationType.dailyReport.isTextCustomizable)
        #expect(!NotificationType.weeklyReport.isTextCustomizable)
        #expect(!NotificationType.monthlyReport.isTextCustomizable)
        #expect(!NotificationType.scheduledPayments.isTextCustomizable)
    }

    @Test func supportsWeekdaySelection_forDailyAndCustom() {
        #expect(NotificationType.dailyReport.supportsWeekdaySelection)
        #expect(NotificationType.custom.supportsWeekdaySelection)
        #expect(!NotificationType.weeklyReport.supportsWeekdaySelection)
        #expect(!NotificationType.monthlyReport.supportsWeekdaySelection)
    }

    @Test func requiresDynamicContent_forReportsAndScheduled() {
        #expect(NotificationType.dailyReport.requiresDynamicContent)
        #expect(NotificationType.weeklyReport.requiresDynamicContent)
        #expect(NotificationType.monthlyReport.requiresDynamicContent)
        #expect(NotificationType.scheduledPayments.requiresDynamicContent)
        #expect(!NotificationType.endOfDay.requiresDynamicContent)
        #expect(!NotificationType.custom.requiresDynamicContent)
    }

    @Test func defaultTime_returnsExpectedValues() {
        #expect(NotificationType.endOfDay.defaultTime == (20, 0))
        #expect(NotificationType.lunchTime.defaultTime == (13, 30))
        #expect(NotificationType.dailyReport.defaultTime == (21, 0))
        #expect(NotificationType.weeklyReport.defaultTime == (9, 0))
        #expect(NotificationType.custom.defaultTime == (12, 0))
    }
}

// MARK: - ReportConfig Tests

struct ReportConfigTests {

    @Test func default_hasExpensesAndMonday() {
        let config = ReportConfig.default
        #expect(config.dataType == .expenses)
        #expect(config.dayPreference == .monday)
    }

    @Test func toData_andFromData_roundTrips() {
        let original = ReportConfig(dataType: .income, dayPreference: .sunday)
        guard let data = original.toData() else {
            Issue.record("toData returned nil")
            return
        }
        guard let decoded = ReportConfig.fromData(data) else {
            Issue.record("fromData returned nil")
            return
        }
        #expect(decoded.dataType == .income)
        #expect(decoded.dayPreference == .sunday)
    }

    @Test func toData_andFromData_allDataTypes() {
        for dataType in ReportDataType.allCases {
            let config = ReportConfig(dataType: dataType, dayPreference: .firstDay)
            guard let data = config.toData(),
                  let decoded = ReportConfig.fromData(data) else {
                Issue.record("Round-trip failed for \(dataType)")
                continue
            }
            #expect(decoded.dataType == dataType)
        }
    }

    @Test func toData_andFromData_allDayPreferences() {
        for dayPref in ReportDayPreference.allCases {
            let config = ReportConfig(dataType: .balance, dayPreference: dayPref)
            guard let data = config.toData(),
                  let decoded = ReportConfig.fromData(data) else {
                Issue.record("Round-trip failed for \(dayPref)")
                continue
            }
            #expect(decoded.dayPreference == dayPref)
        }
    }

    @Test func fromData_withInvalidData_returnsNil() {
        let invalidData = "not json".data(using: .utf8)!
        let result = ReportConfig.fromData(invalidData)
        #expect(result == nil)
    }

    @Test func fromData_withMissingFields_returnsNil() {
        let partial = "{\"dataType\": \"balance\"}".data(using: .utf8)!
        let result = ReportConfig.fromData(partial)
        #expect(result == nil)
    }

    @Test func fromData_withUnknownValues_returnsNil() {
        let unknown = "{\"dataType\": \"unknown\", \"dayPreference\": \"monday\"}".data(using: .utf8)!
        let result = ReportConfig.fromData(unknown)
        #expect(result == nil)
    }

    @Test func equatable_sameValues_areEqual() {
        let a = ReportConfig(dataType: .expenses, dayPreference: .monday)
        let b = ReportConfig(dataType: .expenses, dayPreference: .monday)
        #expect(a == b)
    }

    @Test func equatable_differentValues_areNotEqual() {
        let a = ReportConfig(dataType: .expenses, dayPreference: .monday)
        let b = ReportConfig(dataType: .income, dayPreference: .monday)
        #expect(a != b)
    }
}

// MARK: - ReportConfig Integration with NotificationItem

struct NotificationReportConfigTests {

    @Test func reportConfig_defaultForReportType() {
        let item = NotificationItem(
            name: "Daily", text: "", hour: 21, minute: 0, type: .dailyReport
        )
        let config = item.reportConfig
        #expect(config.dataType == .expenses) // default
    }

    @Test func reportConfig_setter_persistsToConfigurationData() {
        let item = NotificationItem(
            name: "Weekly", text: "", hour: 9, minute: 0, type: .weeklyReport
        )
        item.reportConfig = ReportConfig(dataType: .topCategory, dayPreference: .sunday)
        let roundTripped = item.reportConfig
        #expect(roundTripped.dataType == .topCategory)
        #expect(roundTripped.dayPreference == .sunday)
    }

    @Test func reportConfig_nonReportType_returnsDefault() {
        let item = NotificationItem(
            name: "Reminder", text: "Hello", hour: 20, minute: 0, type: .endOfDay
        )
        let config = item.reportConfig
        #expect(config == .default)
    }
}

/*
Tests generated:
NotificationItemTests:
1. notificationType_parsesFromTypeRaw - Computed property parsing
2. notificationType_defaultsToCustomForUnknownRaw - Fallback behavior
3. selectedWeekdays_withNilRaw_returnsEmptySet - Nil handling
4. selectedWeekdays_withEmptyRaw_returnsEmptySet - Empty handling
5. selectedWeekdays_withCommaSeparatedValues_parsesCorrectly - Parsing
6. selectedWeekdays_setter_allDays_clearsRaw - 7-day optimization
7. selectedWeekdays_setter_emptySet_clearsRaw - Empty set clearing
8. selectedWeekdays_setter_partialSet_storesSorted - Sort order in storage
9. shouldFireOnWeekday_emptySelection_firesEveryDay - All days behavior
10. shouldFireOnWeekday_specificDays_firesOnlyOnSelected - Selective firing
11. scheduledTime_returnsDateWithCorrectHourMinute - Time computation
12. scheduledTime_setter_updatesHourAndMinute - Time setter
13. init_usesTypeDefaultsWhenNilProvided - Default icon/color
14. init_usesCustomValuesWhenProvided - Custom icon/color

NotificationTypeTests:
15. isReportType_trueForReports - Report type classification
16. isReportType_falseForNonReports - Non-report classification
17. isDeletable_onlyForCustom - Delete permission
18. isTextCustomizable true/false - Text customization rules
19. supportsWeekdaySelection - Weekday selection rules
20. requiresDynamicContent - Dynamic content flags
21. defaultTime_returnsExpectedValues - Default time values

ReportConfigTests:
22. default_hasExpensesAndMonday - Default values
23. toData_andFromData_roundTrips - Serialization roundtrip
24. toData_andFromData_allDataTypes - All data types roundtrip
25. toData_andFromData_allDayPreferences - All preferences roundtrip
26. fromData_withInvalidData_returnsNil - Invalid JSON
27. fromData_withMissingFields_returnsNil - Partial JSON
28. fromData_withUnknownValues_returnsNil - Unknown enum values
29. equatable_sameValues_areEqual - Equality
30. equatable_differentValues_areNotEqual - Inequality

NotificationReportConfigTests:
31. reportConfig_defaultForReportType - Default config for report
32. reportConfig_setter_persistsToConfigurationData - Config persistence
33. reportConfig_nonReportType_returnsDefault - Non-report fallback

Casos NO cubiertos:
- formattedWeekdays (depends on Calendar.current locale in tests)
- formattedTime (locale-dependent)
- localizedName/localizedText (depend on localization bundles)
- displayText (depends on L10n which varies by locale)
*/
