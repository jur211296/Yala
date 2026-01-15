import SwiftUI

// MARK: - Equatable Period Selectors
// Extracted to prevent view re-evaluation during async data updates

struct TrendsPeriodMenu: View, Equatable {
    let selectedPeriod: DetailPeriod
    let customDateRange: DateInterval?
    let onSelect: (DetailPeriod) -> Void
    let onCustomTapped: () -> Void

    static func == (lhs: TrendsPeriodMenu, rhs: TrendsPeriodMenu) -> Bool {
        lhs.selectedPeriod == rhs.selectedPeriod
            && lhs.customDateRange?.start == rhs.customDateRange?.start
            && lhs.customDateRange?.end == rhs.customDateRange?.end
    }

    /// Standard periods (all except .custom)
    private var standardPeriods: [DetailPeriod] {
        DetailPeriod.allCases.filter { $0 != .custom }
    }

    /// Display title for the selector button
    private var displayTitle: String {
        if selectedPeriod == .custom, let range = customDateRange {
            return formattedRange(range)
        }
        return selectedPeriod.displayName
    }

    var body: some View {
        Menu {
            // Standard periods
            ForEach(standardPeriods) { period in
                Button {
                    onSelect(period)
                } label: {
                    HStack {
                        Text(period.displayName)
                        if selectedPeriod == period {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }

            Divider()

            // Custom period section
            if let range = customDateRange {
                // Show current range with checkmark if selected
                Button {
                    onSelect(.custom)
                } label: {
                    HStack {
                        Text(formattedRange(range))
                        if selectedPeriod == .custom {
                            Image(systemName: "checkmark")
                        }
                    }
                }

                // Edit option
                Button {
                    onCustomTapped()
                } label: {
                    Text(L10n.Action.edit)
                }
            } else {
                // No range yet - show "Personalizado" to create one
                Button {
                    onCustomTapped()
                } label: {
                    HStack {
                        Text(L10n.Period.custom)
                        if selectedPeriod == .custom {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            PeriodSelectorLabel(title: displayTitle)
        }
        .transaction { $0.animation = nil }
        .id("\(selectedPeriod.rawValue)-\(customDateRange?.start.timeIntervalSince1970 ?? 0)")
    }

    /// Format date range as "1 dic 25 - 27 dic 25"
    private func formattedRange(_ range: DateInterval) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yy"
        formatter.locale = AppLocale.current
        return "\(formatter.string(from: range.start)) - \(formatter.string(from: range.end))"
    }
}

// MARK: - Custom Period Picker Sheet

struct CustomPeriodPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionState.self) private var sessionState

    /// Date range limits (from first to last transaction)
    let minDate: Date
    let maxDate: Date

    /// Local state for editingPer
    @State private var startDate: Date
    @State private var endDate: Date

    init(minDate: Date, maxDate: Date, currentRange: DateInterval?) {
        // Ensure minDate <= maxDate to prevent range crashes
        let safeMinDate = min(minDate, maxDate)
        let safeMaxDate = max(minDate, maxDate)

        self.minDate = safeMinDate
        self.maxDate = safeMaxDate

        // Initialize with current range or default to last 30 days
        if let range = currentRange {
            // Clamp dates to valid range (currentRange may be outside transaction bounds)
            let clampedStart = max(safeMinDate, min(range.start, safeMaxDate))
            let clampedEnd = min(safeMaxDate, max(range.end, safeMinDate))

            // Ensure start <= end after clamping
            if clampedStart <= clampedEnd {
                _startDate = State(initialValue: clampedStart)
                _endDate = State(initialValue: clampedEnd)
            } else {
                // Fallback: use full available range
                _startDate = State(initialValue: safeMinDate)
                _endDate = State(initialValue: safeMaxDate)
            }
        } else {
            let defaultStart =
                Calendar.current.date(byAdding: .day, value: -30, to: safeMaxDate) ?? safeMinDate
            _startDate = State(initialValue: max(defaultStart, safeMinDate))
            _endDate = State(initialValue: safeMaxDate)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    DatePicker(
                        L10n.Period.startDate,
                        selection: $startDate,
                        in: minDate...endDate,
                        displayedComponents: .date
                    )

                    DatePicker(
                        L10n.Period.endDate,
                        selection: $endDate,
                        in: startDate...maxDate,
                        displayedComponents: .date
                    )
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.netoBackground)
            .navigationTitle(L10n.Period.custom)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    NetoToolbarButton(systemName: "chevron.left") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    NetoSaveButton {
                        applyRange()
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func applyRange() {
        // Ensure end is at end of day
        let calendar = Calendar.current
        let endOfDay =
            calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endDate) ?? endDate
        let range = DateInterval(start: calendar.startOfDay(for: startDate), end: endOfDay)

        sessionState.customDateRange = range
        sessionState.selectedPeriod = .custom
        dismiss()
    }
}
