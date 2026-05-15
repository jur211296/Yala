//
//  ScheduledPaymentPeriodSelectorSheet.swift
//  Yala
//
//  Period selector sheet for choosing a month in scheduled payments
//

import SwiftUI

struct ScheduledPaymentPeriodSelectorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.yalaTheme) private var theme
    @ScaledMetric(relativeTo: .largeTitle) private var scaledIconSize: CGFloat = 36 // A11Y-DT: @ScaledMetric
    @Bindable var viewModel: ScheduledPaymentsViewModel
    var payments: [ScheduledPayment]
    var onPeriodChange: () -> Void

    @State private var periods: [PeriodOption] = []
    @State private var selectedIndex: Int = 0
    @State private var isScrolling: Bool = false
    @State private var lastScrollTime: Date = Date.now

    var body: some View {
        VStack(spacing: DS.Spacing.none) {
            // Header with icon and title
            VStack(spacing: DS.Spacing.lg) {
                ZStack {
                    Circle()
                        .fill(theme.accent.opacity(0.15))
                        .frame(width: 80, height: 80)

                    Image(systemName: "calendar")
                        .font(.system(size: scaledIconSize, weight: .medium))
                        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                        .foregroundStyle(.thAccent)
                        .accessibilityHidden(true)
                }
                .padding(.top, DS.Spacing.xxl)

                Text(NSLocalizedString("scheduled.period.selector.title", comment: ""))
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
                            Color.clear.frame(height: 95)

                            ForEach(Array(periods.enumerated()), id: \.element.id) { index, period in
                                GeometryReader { geo in
                                    let minY = geo.frame(in: .named("scroll")).minY
                                    let offset = abs(minY - 95)
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
                                        if !isScrolling && abs(newValue - 95) < 25 {
                                            selectedIndex = index
                                        }
                                        lastScrollTime = Date.now
                                        Task {
                                            try? await Task.sleep(for: .milliseconds(150))
                                            checkAndSnap(proxy: proxy)
                                        }
                                    }
                                }
                                .frame(height: 50)
                                .id(period.id)
                            }

                            Color.clear.frame(height: 95)
                        }
                    }
                    .coordinateSpace(name: "scroll")
                    .frame(height: 240)
                    .onChange(of: periods.count) { _, _ in
                        if !periods.isEmpty, let currentIndex = periods.firstIndex(where: { $0.isCurrent }) {
                            selectedIndex = currentIndex
                            Task {
                                try? await Task.sleep(for: .milliseconds(200))
                                proxy.scrollTo(periods[currentIndex].id, anchor: .center)
                            }
                        }
                    }
                }

                // Fade overlays
                VStack {
                    LinearGradient(
                        colors: [theme.background, theme.background.opacity(0)],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: 60)
                    .allowsHitTesting(false)

                    Spacer()

                    LinearGradient(
                        colors: [theme.background.opacity(0), theme.background],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: 60)
                    .allowsHitTesting(false)
                }
            }
            .frame(height: 240)

            Spacer()

            // Confirm button
            Button {
                confirmSelection()
            } label: {
                Text(NSLocalizedString("budgets.period.confirm", comment: ""))
                    .font(DS.Typography.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.bottom, DS.Spacing.xxl)
        }
        .yalaScreenBackground(.compact)
        .onAppear {
            generatePeriods()
        }
    }

    private func checkAndSnap(proxy: ScrollViewProxy) {
        let timeSinceLastScroll = Date.now.timeIntervalSince(lastScrollTime)
        if timeSinceLastScroll >= 0.15 && !isScrolling {
            dsWithAnimation(reduceMotion) {
                proxy.scrollTo(periods[selectedIndex].id, anchor: .center)
            }
        }
    }

    private func confirmSelection() {
        guard selectedIndex < periods.count else { return }
        let period = periods[selectedIndex]
        viewModel.selectedMonth = period.date
        onPeriodChange()
        dismiss()
    }

    // MARK: - Period Generation

    private static let monthYearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    private func generatePeriods() {
        let calendar = Calendar.current
        let today = Date.now

        // Range: from oldest payment createdAt to 1 year ahead
        let oldestDate = payments.map(\.createdAt).min() ?? today
        let startMonth = calendar.startOfMonth(for: oldestDate)
        let endMonth = calendar.startOfMonth(for: calendar.date(byAdding: .year, value: 1, to: today) ?? today)
        let currentMonth = calendar.startOfMonth(for: today)

        var generatedPeriods: [PeriodOption] = []
        var monthDate = startMonth

        while monthDate <= endMonth {
            let monthStr = Self.monthYearFormatter.string(from: monthDate)

            let isCurrent = calendar.isDate(monthDate, equalTo: viewModel.selectedMonth, toGranularity: .month)

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
                isCurrent: isCurrent
            ))

            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthDate) else { break }
            monthDate = nextMonth
        }

        periods = generatedPeriods
    }
}
