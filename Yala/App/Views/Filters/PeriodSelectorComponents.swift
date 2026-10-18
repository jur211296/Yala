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
                                .accessibilityHidden(true)
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
                                .accessibilityHidden(true)
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
                                .accessibilityHidden(true)
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

    /// «agosto de 2026» si el rango es un mes entero, «2024» si es un año, y si no «1–27 dic» (con el año solo si no es
    /// el actual). Antes salía «1 dic. 25 - 27 dic. 25» siempre, también para los meses a los que llevan las flechas de
    /// Estadísticas (UX 2.2 · L11-3).
    private func formattedRange(_ range: DateInterval) -> String {
        PeriodStepLogic.customTitle(range)
    }
}

// MARK: - Custom Period Picker Sheet

struct CustomPeriodPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionState.self) private var sessionState
    @Environment(\.yalaTheme) private var theme

    /// Límites del calendario: cualquier fecha hasta hoy (UX 2.2 · L3-4). Antes iban del primer al último movimiento,
    /// y una cuenta nueva solo podía elegir un día, con el resto en gris y sin explicación. Si hay movimientos con
    /// fecha futura (pagos planificados ya registrados), el tope llega hasta el último.
    let minDate: Date
    let maxDate: Date

    /// Suelo del calendario: el primer movimiento o veinte años atrás, lo que sea antes. «Cualquier fecha» sin un
    /// suelo dejaría la rueda del año en el año 1.
    static func pickerBounds(firstRecord: Date, lastRecord: Date, now: Date = .now, calendar: Calendar = .current) -> (min: Date, max: Date) {
        let floor = calendar.date(byAdding: .year, value: -20, to: calendar.startOfDay(for: now)) ?? firstRecord
        let lower = min(firstRecord, lastRecord, floor)
        let upper = max(firstRecord, lastRecord, now)
        return (lower, upper)
    }

    /// Local state for editingPer
    @State private var startDate: Date
    @State private var endDate: Date

    init(minDate: Date, maxDate: Date, currentRange: DateInterval?) {
        // Ensure minDate <= maxDate to prevent range crashes
        let bounds = Self.pickerBounds(firstRecord: minDate, lastRecord: maxDate)
        let safeMinDate = bounds.min
        let safeMaxDate = bounds.max

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
                        in: min(minDate, endDate)...max(minDate, endDate),
                        displayedComponents: .date
                    )
                    .listRowBackground(theme.card)

                    DatePicker(
                        L10n.Period.endDate,
                        selection: $endDate,
                        in: min(startDate, maxDate)...max(startDate, maxDate),
                        displayedComponents: .date
                    )
                    .listRowBackground(theme.card)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(.thCard)
            .yalaScreenBackground(.partialSheet)
            .navigationTitle(L10n.Period.custom)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    YalaToolbarButton(systemName: "chevron.left", label: L10n.Action.back) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    YalaSaveButton {
                        applyRange()
                    }
                }
            }
        }
        // El color de marca, no el que herede: Estadísticas pone `.tint(.primary)` a sus barras y desde sus pestañas el ✓
        // salía blanco sobre blanco en modo oscuro (auditoría UX 2.2 · lote 11 · B6).
        .tint(theme.accent)
        .yalaSheetDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func applyRange() {
        // Ensure end is at end of day
        let calendar = Calendar.current
        let endOfDay =
            calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endDate) ?? endDate
        let range = DateInterval(start: calendar.startOfDay(for: startDate), end: endOfDay)

        // Un rango propio es una elección de la persona: si un aviso había puesto su período para esa visita, deja de
        // valer (UX 2.2 · L11-2).
        sessionState.choosePeriod(.custom, customRange: range)
        dismiss()
    }
}
