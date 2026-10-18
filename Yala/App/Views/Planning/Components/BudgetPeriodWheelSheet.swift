//
//  BudgetPeriodWheelSheet.swift
//  Yala
//
//  Selector de período de los presupuestos con la rueda NATIVA de iOS (UX 2.2 · L9-8). La rueda propia de antes vivía
//  en un `ScrollView` dentro de una hoja a media altura: arrastrarla hacia abajo cerraba la hoja (medido: seis de seis
//  intentos), y sus franjas de degradado se veían como bandas oscuras sobre la hoja transparente. La rueda del sistema
//  se queda con su gesto y no compite con el de cerrar.
//
//  Mensual = el selector de mes y año de iOS (`UIDatePicker`, `.yearAndMonth`). Semanal y anual = `Picker` en rueda.
//  Lo comparten la lista de Presupuestos, las gráficas de un presupuesto y Pagos planificados (mensual).
//

import SwiftUI
import UIKit

struct BudgetPeriodWheelSheet: View {
    @Environment(\.dismiss) private var dismiss

    let periodType: BudgetPeriodType
    let initialWeek: Date
    let initialMonth: Date
    let initialYear: Int
    /// El movimiento más antiguo guardado: la rueda empieza en su período.
    var oldestRecordDate: Date?
    /// Título propio: Pagos planificados reusa esta hoja con su «Seleccionar mes».
    var title: String?
    let onConfirm: (_ week: Date, _ month: Date, _ year: Int) -> Void

    @State private var week: Date = .now
    @State private var month: Date = .now
    @State private var year: Int = 0
    @State private var weeks: [WeekOption] = []
    @State private var years: [Int] = []
    @State private var didLoad = false

    private var calendar: Calendar { userConfiguredCalendar() }

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            header

            wheel
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("budget_period_wheel")

            Spacer(minLength: 0)

            if !isOnToday {
                Button(action: goToToday) {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(DS.Typography.caption)
                        Text(NSLocalizedString("budgets.period.goToToday", comment: ""))
                            .font(DS.Typography.subheadline)
                    }
                    .foregroundStyle(.thAccent)
                }
                .buttonStyle(.plain)
            }

            YalaPrimaryButton(NSLocalizedString("budgets.period.confirm", comment: "")) {
                onConfirm(week, month, year)
                dismiss()
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.bottom, DS.Spacing.xxl)
        }
        .yalaScreenBackground(.partialSheet)
        .onAppear(perform: load)
    }

    // MARK: - Header

    /// Solo el título: la hoja es de media altura y el icono de antes quedaba cortado bajo el asa.
    private var header: some View {
        Text(title ?? periodSelectorTitle)
            .font(DS.Typography.title)
            .foregroundStyle(.primary)
            .padding(.top, DS.Spacing.xxl)
    }

    // MARK: - Wheel

    @ViewBuilder
    private var wheel: some View {
        switch periodType {
        case .monthly:
            MonthYearWheel(
                date: $month,
                // El mes elegido siempre cabe: con ‹ › la lista puede ir más allá del rango de los movimientos.
                minimumDate: min(calendar.startOfMonth(for: earliest), month),
                maximumDate: max(latest, month),
                calendar: calendar,
                locale: AppLocale.current
            )
            .frame(height: 216)
        case .weekly:
            Picker(NSLocalizedString("budgets.period.selector.title.weekly", comment: ""), selection: $week) {
                ForEach(weeks) { option in
                    Text(option.label).tag(option.start)
                }
            }
            .pickerStyle(.wheel)
        case .yearly:
            Picker(NSLocalizedString("budgets.period.selector.title.yearly", comment: ""), selection: $year) {
                ForEach(years, id: \.self) { value in
                    Text(yearLabel(value)).tag(value)
                }
            }
            .pickerStyle(.wheel)
        case .unique:
            EmptyView()
        }
    }

    // MARK: - Data

    private var earliest: Date { min(oldestRecordDate ?? .now, .now) }
    private var latest: Date { calendar.date(byAdding: .year, value: 1, to: .now) ?? .now }

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        week = calendar.startOfWeek(for: initialWeek)
        month = calendar.startOfMonth(for: initialMonth)
        year = initialYear

        switch periodType {
        case .weekly:
            // La semana elegida siempre está en la rueda, aunque quede fuera del rango de los movimientos.
            weeks = Self.weekOptions(
                from: min(earliest, week), to: max(latest, week), now: .now, calendar: calendar, locale: AppLocale.current)
        case .yearly:
            let first = calendar.component(.year, from: earliest)
            let last = calendar.component(.year, from: latest)
            years = Array(min(first, year)...max(last, year))
        default:
            break
        }
    }

    private var isOnToday: Bool {
        switch periodType {
        case .weekly: return calendar.isDate(week, equalTo: .now, toGranularity: .weekOfYear)
        case .monthly: return calendar.isDate(month, equalTo: .now, toGranularity: .month)
        case .yearly: return year == calendar.component(.year, from: .now)
        case .unique: return true
        }
    }

    private func goToToday() {
        week = calendar.startOfWeek(for: .now)
        month = calendar.startOfMonth(for: .now)
        year = calendar.component(.year, from: .now)
    }

    private func yearLabel(_ value: Int) -> String {
        let current = calendar.component(.year, from: .now)
        switch value {
        case current: return "\(L10n.Period.thisYear) · \(value)"
        case current - 1: return "\(L10n.Period.lastYear) · \(value)"
        default: return "\(value)"
        }
    }

    private var periodSelectorTitle: String {
        switch periodType {
        case .weekly: return NSLocalizedString("budgets.period.selector.title.weekly", comment: "")
        case .monthly: return NSLocalizedString("budgets.period.selector.title.monthly", comment: "")
        case .yearly: return NSLocalizedString("budgets.period.selector.title.yearly", comment: "")
        case .unique: return ""
        }
    }

    // MARK: - Semanas

    struct WeekOption: Identifiable, Equatable {
        let start: Date
        let label: String
        var id: Date { start }
    }

    /// Una opción por semana, de la del movimiento más antiguo a un año vista. «Esta semana · 13 – 19 oct».
    static func weekOptions(from earliest: Date, to latest: Date, now: Date, calendar: Calendar, locale: Locale) -> [WeekOption] {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("dMMM")
        let current = calendar.startOfWeek(for: now)
        var options: [WeekOption] = []
        var start = calendar.startOfWeek(for: earliest)
        let end = calendar.startOfWeek(for: latest)
        while start <= end {
            let last = calendar.date(byAdding: .day, value: 6, to: start) ?? start
            let range = "\(formatter.string(from: start)) – \(formatter.string(from: last))"
            let label: String
            if calendar.isDate(start, equalTo: current, toGranularity: .weekOfYear) {
                label = "\(L10n.Period.thisWeek) · \(range)"
            } else if let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: current),
                      calendar.isDate(start, equalTo: previous, toGranularity: .weekOfYear) {
                label = "\(L10n.Period.lastWeek) · \(range)"
            } else {
                label = range
            }
            options.append(WeekOption(start: start, label: label))
            guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: start) else { break }
            start = next
        }
        return options
    }
}

// MARK: - Rueda de mes y año del sistema

/// `UIDatePicker` en modo mes y año, en rueda: el mismo control que usa iOS. SwiftUI no lo expone.
private struct MonthYearWheel: UIViewRepresentable {
    @Binding var date: Date
    let minimumDate: Date
    let maximumDate: Date
    let calendar: Calendar
    let locale: Locale

    func makeUIView(context: Context) -> UIDatePicker {
        let picker = UIDatePicker()
        picker.datePickerMode = .yearAndMonth
        picker.preferredDatePickerStyle = .wheels
        picker.calendar = calendar
        picker.locale = locale
        picker.minimumDate = minimumDate
        picker.maximumDate = maximumDate
        picker.date = date
        picker.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .valueChanged)
        picker.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return picker
    }

    func updateUIView(_ picker: UIDatePicker, context: Context) {
        context.coordinator.parent = self
        if !calendar.isDate(picker.date, equalTo: date, toGranularity: .month) {
            picker.setDate(date, animated: true)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject {
        var parent: MonthYearWheel
        init(parent: MonthYearWheel) { self.parent = parent }

        @objc func changed(_ picker: UIDatePicker) {
            parent.date = parent.calendar.startOfMonth(for: picker.date)
        }
    }
}
