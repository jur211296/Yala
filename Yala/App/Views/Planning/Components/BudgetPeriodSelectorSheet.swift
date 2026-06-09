//
//  BudgetPeriodSelectorSheet.swift
//  Yala
//
//  Period selector sheet for choosing specific week/month/year
//

import SwiftUI

struct BudgetPeriodSelectorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.yalaTheme) private var theme
    @ScaledMetric(relativeTo: .largeTitle) private var scaledIconSize: CGFloat = 36 // A11Y-DT: @ScaledMetric
    @Bindable var viewModel: BudgetsViewModel
    var transactions: [TransactionItem]
    var onPeriodChange: () -> Void

    @State private var periods: [PeriodOption] = []
    @State private var selectedIndex: Int = 0
    @State private var isScrolling: Bool = false
    @State private var lastScrollTime: Date = Date.now
    @State private var scrollProxy: ScrollViewProxy?
    @State private var currentPeriodIndex: Int?

    var body: some View {
        VStack(spacing: DS.Spacing.none) {
            // Header with icon and title
            VStack(spacing: DS.Spacing.lg) {
                // Icon
                ZStack {
                    Circle()
                        .fill(theme.accent.opacity(0.15))
                        .frame(width: 80, height: 80)

                    Image(systemName: periodIcon)
                        .font(.system(size: scaledIconSize, weight: .medium))
                        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                        .foregroundStyle(.thAccent)
                        .accessibilityHidden(true)
                }
                .padding(.top, DS.Spacing.xxl)

                // Title
                Text(periodSelectorTitle)
                    .font(DS.Typography.title)
                    .foregroundStyle(.primary)
            }
            .padding(.bottom, DS.Spacing.xl)

            // Wheel Picker Style
            ZStack {
                // Selection highlight
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .strokeBorder(theme.accent.opacity(0.3), lineWidth: 1.5)
                    .frame(height: 50)
                    .padding(.horizontal, DS.Spacing.xl)
                    .allowsHitTesting(false)

                // Scrollable picker
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: DS.Spacing.none) {
                            // Top spacer
                            Color.clear.frame(height: 95)

                            ForEach(Array(periods.enumerated()), id: \.element.id) { index, period in
                                GeometryReader { geo in
                                    let minY = geo.frame(in: .named("scroll")).minY
                                    let offset = abs(minY - 95)  // Distance from center
                                    let scale = max(0.85, 1 - (offset / 300))

                                    Button {
                                        isScrolling = true
                                        dsWithAnimation(reduceMotion) {
                                            selectedIndex = index
                                            proxy.scrollTo(period.id, anchor: .center)
                                        }
                                        Task {
                                            try? await Task.sleep(for: .milliseconds(500))
                                            isScrolling = false
                                        }
                                    } label: {
                                        Text(!period.subtitle.isEmpty ? period.subtitle : period.title)
                                            .font(.body.weight(selectedIndex == index ? .semibold : .regular))
                                            .foregroundStyle(selectedIndex == index ? Color.primary : Color.secondary)
                                            .scaleEffect(scale)
                                            .frame(maxWidth: .infinity)
                                            .multilineTextAlignment(.center)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .frame(height: 50)
                                    .onChange(of: minY) { _, newValue in
                                        // Update selected index based on scroll position
                                        if !isScrolling && abs(newValue - 95) < 25 {
                                            selectedIndex = index
                                        }

                                        // Track scroll activity
                                        lastScrollTime = Date.now

                                        // Schedule snap check
                                        Task {
                                            try? await Task.sleep(for: .milliseconds(150))
                                            checkAndSnap(proxy: proxy)
                                        }
                                    }
                                }
                                .frame(height: 50)
                                .id(period.id)
                            }

                            // Bottom spacer
                            Color.clear.frame(height: 95)
                        }
                    }
                    .coordinateSpace(name: "scroll")
                    .frame(height: 240)
                    .onAppear {
                        scrollProxy = proxy
                    }
                    .onChange(of: periods.count) { _, _ in
                        // Scroll to currently selected period when periods are loaded
                        if !periods.isEmpty, let currentIndex = periods.firstIndex(where: { $0.isSelected }) {
                            selectedIndex = currentIndex
                            Task {
                                try? await Task.sleep(for: .milliseconds(200))
                                proxy.scrollTo(periods[currentIndex].id, anchor: .center)
                            }
                        }
                    }
                }

                // Top fade overlay
                VStack {
                    LinearGradient(
                        colors: [
                            theme.background,
                            theme.background.opacity(0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 60)
                    .allowsHitTesting(false)

                    Spacer()

                    // Bottom fade overlay
                    LinearGradient(
                        colors: [
                            theme.background.opacity(0),
                            theme.background
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 60)
                    .allowsHitTesting(false)
                }
            }
            .frame(height: 240)

            Spacer()

            // Go to today button
            if let currentIndex = currentPeriodIndex,
               selectedIndex != currentIndex {
                Button {
                    goToToday()
                } label: {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(DS.Typography.caption)
                        Text(NSLocalizedString("budgets.period.goToToday", comment: ""))
                            .font(DS.Typography.subheadline)
                    }
                    .foregroundStyle(.thAccent)
                }
                .buttonStyle(.plain)
                .padding(.bottom, DS.Spacing.md)
            }

            // Confirm button
            YalaPrimaryButton(NSLocalizedString("budgets.period.confirm", comment: "")) {
                confirmSelection()
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.bottom, DS.Spacing.xxl)
        }
        .yalaScreenBackground(DS.Adaptive.usesLargeSheets ? .subtle : .transparent)
        .onAppear {
            generatePeriods()
        }
    }

    private var periodSelectorTitle: String {
        switch viewModel.selectedPeriodType {
        case .weekly:
            return NSLocalizedString("budgets.period.selector.title.weekly", comment: "")
        case .monthly:
            return NSLocalizedString("budgets.period.selector.title.monthly", comment: "")
        case .yearly:
            return NSLocalizedString("budgets.period.selector.title.yearly", comment: "")
        default:
            return ""
        }
    }

    private var periodIcon: String {
        switch viewModel.selectedPeriodType {
        case .weekly:
            return "calendar.badge.clock"
        case .monthly:
            return "calendar"
        case .yearly:
            return "calendar.circle"
        default:
            return "calendar"
        }
    }

    private func checkAndSnap(proxy: ScrollViewProxy) {
        // Check if scrolling has stopped
        let timeSinceLastScroll = Date.now.timeIntervalSince(lastScrollTime)
        if timeSinceLastScroll >= 0.15 && !isScrolling {
            // Haptic feedback on snap
            DS.Haptic.light()
            // Snap to the selected index
            dsWithAnimation(reduceMotion) {
                proxy.scrollTo(periods[selectedIndex].id, anchor: .center)
            }
        }
    }

    private func goToToday() {
        guard let currentIndex = currentPeriodIndex,
              let proxy = scrollProxy else { return }
        isScrolling = true
        dsWithAnimation(reduceMotion) {
            selectedIndex = currentIndex
            proxy.scrollTo(periods[currentIndex].id, anchor: .center)
        }
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            isScrolling = false
        }
    }

    private func confirmSelection() {
        guard selectedIndex < periods.count else { return }
        let period = periods[selectedIndex]

        switch viewModel.selectedPeriodType {
        case .weekly:
            viewModel.selectedWeek = period.date
        case .monthly:
            viewModel.selectedMonth = period.date
        case .yearly:
            if let yearStr = period.title.components(separatedBy: " ").first,
               let year = Int(yearStr) {
                viewModel.selectedYear = year
            }
        case .unique:
            break
        }

        onPeriodChange()
        dismiss()
    }

    // MARK: - Period Generation

    private static let weekDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        return f
    }()

    private static let monthDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    private func generatePeriods() {
        let calendar = userConfiguredCalendar()
        var generatedPeriods: [PeriodOption] = []

        // Calculate date range based on transactions
        let today = Date.now
        let oldestTransactionDate = transactions.map { $0.date }.min() ?? today
        let oneYearFromNow = calendar.date(byAdding: .year, value: 1, to: today) ?? today

        switch viewModel.selectedPeriodType {
        case .weekly:
            // Generate weeks from oldest transaction to 1 year from now
            let startWeek = calendar.startOfWeek(for: oldestTransactionDate)
            let endWeek = calendar.startOfWeek(for: oneYearFromNow)
            let currentWeek = calendar.startOfWeek(for: today)

            var weekDate = startWeek
            while weekDate <= endWeek {
                let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekDate) ?? weekDate

                let startStr = Self.weekDateFormatter.string(from: weekDate)
                let endStr = Self.weekDateFormatter.string(from: weekEnd)

                let isCurrent = calendar.isDate(weekDate, equalTo: currentWeek, toGranularity: .weekOfYear) &&
                                calendar.isDate(weekDate, equalTo: currentWeek, toGranularity: .year)
                let isSelected = calendar.isDate(weekDate, equalTo: viewModel.selectedWeek, toGranularity: .weekOfYear) &&
                                 calendar.isDate(weekDate, equalTo: viewModel.selectedWeek, toGranularity: .year)

                // Special text for current, previous, and next week
                let specialText: String
                if calendar.isDate(weekDate, equalTo: currentWeek, toGranularity: .weekOfYear) {
                    specialText = L10n.Period.thisWeek
                } else if let previousWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: currentWeek),
                          calendar.isDate(weekDate, equalTo: previousWeek, toGranularity: .weekOfYear) {
                    specialText = L10n.Period.lastWeek
                } else if let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: currentWeek),
                          calendar.isDate(weekDate, equalTo: nextWeek, toGranularity: .weekOfYear) {
                    specialText = L10n.Period.nextWeek
                } else {
                    specialText = ""
                }

                generatedPeriods.append(PeriodOption(
                    date: weekDate,
                    title: "\(startStr) - \(endStr)",
                    subtitle: specialText,
                    isCurrent: isCurrent,
                    isSelected: isSelected
                ))

                // Move to next week
                guard let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: weekDate) else { break }
                weekDate = nextWeek
            }

        case .monthly:
            // Generate months from oldest transaction to 1 year from now
            let startMonth = calendar.startOfMonth(for: oldestTransactionDate)
            let endMonth = calendar.startOfMonth(for: oneYearFromNow)
            let currentMonth = calendar.startOfMonth(for: today)

            var monthDate = startMonth
            while monthDate <= endMonth {
                let monthStr = Self.monthDateFormatter.string(from: monthDate)

                let isCurrent = calendar.isDate(monthDate, equalTo: currentMonth, toGranularity: .month)
                let isSelected = calendar.isDate(monthDate, equalTo: viewModel.selectedMonth, toGranularity: .month)

                // Special text for current, previous, and next month
                let specialText: String
                if calendar.isDate(monthDate, equalTo: currentMonth, toGranularity: .month) {
                    specialText = L10n.Period.thisMonth
                } else if let previousMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth),
                          calendar.isDate(monthDate, equalTo: previousMonth, toGranularity: .month) {
                    specialText = L10n.Period.lastMonth
                } else if let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth),
                          calendar.isDate(monthDate, equalTo: nextMonth, toGranularity: .month) {
                    specialText = L10n.Period.nextMonth
                } else {
                    specialText = ""
                }

                generatedPeriods.append(PeriodOption(
                    date: monthDate,
                    title: monthStr.capitalized,
                    subtitle: specialText,
                    isCurrent: isCurrent,
                    isSelected: isSelected
                ))

                // Move to next month
                guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthDate) else { break }
                monthDate = nextMonth
            }

        case .yearly:
            // Generate years from oldest transaction to 1 year from now
            let oldestYear = calendar.component(.year, from: oldestTransactionDate)
            let endYear = calendar.component(.year, from: oneYearFromNow)
            let currentYear = calendar.component(.year, from: today)

            for year in oldestYear...endYear {
                let isCurrent = year == currentYear
                let isSelected = year == viewModel.selectedYear

                // Special text for current, previous, and next year
                let specialText: String
                if year == currentYear {
                    specialText = L10n.Period.thisYear
                } else if year == currentYear - 1 {
                    specialText = L10n.Period.lastYear
                } else if year == currentYear + 1 {
                    specialText = L10n.Period.nextYear
                } else {
                    specialText = ""
                }

                generatedPeriods.append(PeriodOption(
                    date: calendar.date(from: DateComponents(year: year)) ?? Date.now,
                    title: "\(year)",
                    subtitle: specialText,
                    isCurrent: isCurrent,
                    isSelected: isSelected
                ))
            }

        case .unique:
            break
        }

        periods = generatedPeriods
        currentPeriodIndex = generatedPeriods.firstIndex(where: { $0.isCurrent })
    }
}

// MARK: - Calendar Extension

