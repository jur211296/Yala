//
//  DatePickerSheet.swift
//  Yala
//

import SwiftUI

// MARK: - Date Picker Sheet

struct DatePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.yalaTheme) private var theme
    @Binding var selectedDate: Date
    var minDate: Date = .distantPast
    var maxDate: Date? = nil         // nil = Date.now at runtime (avoids stale capture)
    var title: String = L10n.Common.date
    /// Modo del formulario de registro (UX 2.2 · L2-7, decidido por Jürgen el 14-oct): atajos Hoy / Ayer / Anteayer
    /// arriba, tocar un atajo o un día aplica la fecha y cierra la hoja (sin ✓; la X sigue cancelando), y una nota que
    /// explica los días en gris con un enlace a Pagos planificados en una hoja encima. Los demás usos de la hoja no cambian.
    var quickPick: Bool = false

    @State private var workingDate: Date = .now
    @State private var selectedDetent: PresentationDetent = .medium
    /// El `onAppear` copia la fecha del formulario a `workingDate`: ese cambio no es un toque y no puede cerrar la hoja.
    @State private var hasLoadedDate = false
    @State private var showScheduledPayments = false

    /// Computed range: nil maxDate means "up to today" at render time
    private var dateRange: ClosedRange<Date> {
        let upper = maxDate ?? Date.now
        return minDate...upper
    }

    private var isLargeDetent: Bool { selectedDetent == .large }

    var body: some View {
        NavigationStack {
            ZStack {
                if quickPick {
                    quickPickContent
                } else {
                    VStack {
                        calendar
                        Spacer()
                    }
                }
            }
            .yalaScreenBackground(isLargeDetent ? .subtle : .transparent)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }

                if !quickPick {
                    ToolbarItem(placement: .topBarTrailing) {
                        YalaSaveButton(action: {
                            selectedDate = workingDate
                            dismiss()
                        })
                    }
                }
            }
            .onAppear {
                guard !hasLoadedDate else { return }
                workingDate = selectedDate
                hasLoadedDate = true
            }
            .onChange(of: workingDate) { _, newDate in
                applyTappedDay(newDate)
            }
            .sheet(isPresented: $showScheduledPayments) {
                NavigationStack {
                    ScheduledPaymentsView()
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                                    showScheduledPayments = false
                                }
                                .accessibilityIdentifier("date_picker_scheduled_close")
                            }
                        }
                }
            }
        }
        .yalaSheetDetents([.medium, .large], selection: $selectedDetent)
        .presentationDragIndicator(.visible)
    }

    private var calendar: some View {
        DatePicker(
            title,
            selection: $workingDate,
            in: dateRange,
            displayedComponents: [.date]
        )
        .datePickerStyle(.graphical)
        .padding(DS.Spacing.md)
        .accessibilityIdentifier("date_picker_calendar")
    }

    // MARK: - Atajos (L2-7)

    private var quickPickContent: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.none) {
                quickPickRow
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.top, DS.Spacing.sm)
                calendar
                futureDaysNote
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.bottom, DS.Spacing.lg)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private var quickPickRow: some View {
        HStack(spacing: DS.Spacing.sm) {
            ForEach(DatePickerQuickPickLogic.Shortcut.allCases, id: \.self) { shortcut in
                let date = DatePickerQuickPickLogic.date(for: shortcut)
                let isChosen = Calendar.current.isDate(selectedDate, inSameDayAs: date)
                Button {
                    choose(date)
                } label: {
                    // El atajo elegido, relleno y con ✓ (UX 2.2 · L2-19).
                    HStack(spacing: DS.Spacing.xs) {
                        if isChosen {
                            Image(systemName: "checkmark.circle.fill")
                                .font(DS.Typography.labelSmall)
                                .accessibilityHidden(true)
                        }
                        Text(shortcut.title)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                        .font(DS.Typography.label)
                        .foregroundStyle(isChosen ? Color.white : Color.primary)
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.vertical, DS.Spacing.sm)
                        .frame(maxWidth: .infinity)
                        .background(
                            Capsule().fill(isChosen ? Color.selectedIndigoFill : Color.primary.opacity(0.08))
                        )
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isChosen ? .isSelected : [])
                .accessibilityIdentifier("date_quick_\(shortcut.rawValue)")
            }
        }
    }

    /// «Los días que vienen salen en gris. Para un pago que aún no llega, usa Pagos planificados», con el enlace.
    private var futureDaysNote: some View {
        Text(DatePickerQuickPickLogic.noteText(L10n.UXL2.futureDaysNote))
            .font(DS.Typography.caption)
            .foregroundStyle(.secondary)
            .tint(theme.accent)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .environment(\.openURL, OpenURLAction { url in
                guard url == DatePickerQuickPickLogic.scheduledPaymentsURL else { return .systemAction }
                showScheduledPayments = true
                return .handled
            })
            .accessibilityIdentifier("date_picker_future_note")
    }

    private func choose(_ date: Date) {
        selectedDate = date
        dismiss()
    }

    /// Un día tocado en el calendario aplica la fecha y cierra, solo en el modo del formulario. Cambiar de mes no toca
    /// la selección, así que no cierra.
    private func applyTappedDay(_ newDate: Date) {
        guard quickPick, hasLoadedDate,
              !Calendar.current.isDate(newDate, inSameDayAs: selectedDate) else { return }
        choose(newDate)
    }
}

/// Los atajos de la hoja de fecha y su nota. Lógica pura para fijarla con tests.
enum DatePickerQuickPickLogic {
    enum Shortcut: String, CaseIterable {
        case today, yesterday, dayBeforeYesterday

        var title: String {
            switch self {
            case .today: return L10n.Date.today
            case .yesterday: return L10n.Date.yesterday
            case .dayBeforeYesterday: return L10n.UXL2.dayBeforeYesterday
            }
        }

        var daysBack: Int {
            switch self {
            case .today: return 0
            case .yesterday: return 1
            case .dayBeforeYesterday: return 2
            }
        }
    }

    /// El enlace de la nota a Pagos planificados. No sale de la app: lo atiende la propia hoja.
    static let scheduledPaymentsURL = URL(string: "yala-form://scheduled")

    /// El día del atajo a la hora de ahora, como guarda el formulario un registro de hoy.
    static func date(for shortcut: Shortcut, now: Date = .now, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: -shortcut.daysBack, to: now) ?? now
    }

    /// La nota en markdown (`[Pagos planificados](yala-form://scheduled)`), o el texto tal cual si no se deja leer.
    static func noteText(_ markdown: String) -> AttributedString {
        do {
            return try AttributedString(markdown: markdown)
        } catch {
            #if DEBUG
            print("DatePickerQuickPickLogic: Error: markdown de la nota: \(error)")
            #endif
            return AttributedString(markdown)
        }
    }
}
