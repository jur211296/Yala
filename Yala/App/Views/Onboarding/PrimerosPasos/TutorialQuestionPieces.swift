//
//  TutorialQuestionPieces.swift
//  Yala
//
//  Las piezas de las preguntas de Yala de los pasos 3, 4 y 5 de Primeros pasos 2.3 (prototipo oficial v35: la cabecera
//  «Yala · Tu primer …» con sus puntos, la tarjeta que se llena arriba, la pregunta y lo de abajo). Mismo aspecto que las
//  del paso 1 (`FirstAccountFlowView`), que las lleva dentro de su vista; aquí se comparten entre los tres pasos.
//

import SwiftUI

/// La pantalla de una pregunta: cabecera, tarjeta (opcional), pregunta y lo de abajo, que se funde al cambiar de pregunta.
struct TutorialQuestionScreen<Card: View, Dock: View>: View {
    let subtitle: String
    let stepCount: Int
    let stepIndex: Int
    let isDone: Bool
    let question: String
    let detail: String?
    /// Cambia con cada pregunta: la nueva se funde.
    let identity: String
    let backID: String
    let onBack: () -> Void
    @ViewBuilder let card: () -> Card
    @ViewBuilder let dock: () -> Dock

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.yalaTheme) private var theme

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    card()
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text(question)
                            .font(DS.Typography.title2.weight(.bold))
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("tutorial_question")
                        if let detail, !detail.isEmpty {
                            Text(detail)
                                .font(DS.Typography.body)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .id(identity)
                    .transition(.opacity)
                    dock()
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.xl)
                .animation(reduceMotion ? nil : DS.Animation.appear, value: identity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private var header: some View {
        HStack(spacing: DS.Spacing.sm) {
            YalaToolbarButton(systemName: "chevron.left", label: L10n.Action.back, action: onBack)
                .accessibilityIdentifier(backID)
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: "Yala").font(DS.Typography.headline)
                Text(subtitle)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: DS.Spacing.xxs) {
                ForEach(0..<stepCount, id: \.self) { offset in
                    Circle()
                        .fill(offset < stepIndex || isDone ? theme.accent : Color.primary.opacity(0.2))
                        .frame(width: 6, height: 6)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L10n.PrimerosPasos23.partOf(min(stepIndex + 1, stepCount), stepCount))
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.top, DS.Spacing.sm)
    }
}

/// Una respuesta: título, frase debajo, icono opcional y la flecha. La destacada lleva borde del acento.
struct TutorialOptionButton: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    var tint: Color? = nil
    var highlighted = false
    /// `false` cuando la respuesta guarda y vibra ella al guardar bien (un háptico por gesto).
    var vibrates = true
    let id: String
    let action: () -> Void

    @Environment(\.yalaTheme) private var theme

    var body: some View {
        Button {
            if vibrates { DS.Haptic.selection() }
            action()
        } label: {
            HStack(spacing: DS.Spacing.md) {
                if let icon {
                    Image(systemName: icon)
                        .font(DS.Typography.body.weight(.semibold))
                        .foregroundStyle(tint ?? theme.accentText)
                        .frame(width: 28)
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(title).font(DS.Typography.body.weight(.semibold)).foregroundStyle(.primary)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle).font(DS.Typography.caption).foregroundStyle(.secondary)
                    }
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: DS.Spacing.sm)
                Image(systemName: "chevron.right")
                    .font(DS.Typography.caption)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(DS.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .fill(theme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                        .strokeBorder(highlighted ? theme.accent.opacity(0.6) : .clear, lineWidth: 1.5)
                )
        )
        .accessibilityIdentifier(id)
    }
}

/// Una tarjeta que se marca (categorías del presupuesto, tipos del pago): icono en su color, nombre y, debajo, una línea.
/// Marcada: borde del color y ✓ en la esquina.
struct TutorialSelectableTile: View {
    let icon: String
    let color: Color
    let title: String
    var caption: String? = nil
    let isOn: Bool
    let id: String
    let action: () -> Void

    @Environment(\.yalaTheme) private var theme

    var body: some View {
        Button {
            DS.Haptic.selection()
            action()
        } label: {
            VStack(spacing: DS.Spacing.xs) {
                Image(systemName: icon)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(color))
                    .accessibilityHidden(true)
                Text(title)
                    .font(DS.Typography.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                if let caption {
                    Text(caption)
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(DS.Spacing.sm)
            .frame(maxWidth: .infinity, minHeight: 104, alignment: .top)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .fill(theme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                        .strokeBorder(isOn ? color : .clear, lineWidth: 2)
                )
        )
        .overlay(alignment: .topTrailing) {
            if isOn {
                Image(systemName: "checkmark.circle.fill")
                    .font(DS.Typography.body)
                    .foregroundStyle(.white, color)
                    .padding(DS.Spacing.xs)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier(id)
    }
}

/// Un interruptor con su frase («Es una suscripción», «Cambia cada vez»).
struct TutorialToggleRow: View {
    let title: String
    let hint: String
    @Binding var isOn: Bool
    let id: String

    @Environment(\.yalaTheme) private var theme

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(title).font(DS.Typography.body.weight(.semibold))
                Text(hint).font(DS.Typography.caption).foregroundStyle(.secondary)
            }
        }
        .padding(DS.Spacing.md)
        .background(RoundedRectangle(cornerRadius: DS.Radius.lg).fill(theme.card))
        .accessibilityIdentifier(id)
    }
}

/// Una pastilla de las que se tocan (ejemplos de nombre, días del mes).
struct TutorialChip: View {
    let title: String
    var isOn = false
    let id: String
    let action: () -> Void

    @Environment(\.yalaTheme) private var theme

    var body: some View {
        Button {
            DS.Haptic.selection()
            action()
        } label: {
            Text(title)
                .font(DS.Typography.subheadline.weight(.semibold))
                .foregroundStyle(isOn ? theme.onAccent : .primary)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .frame(minHeight: 44)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .background(Capsule().fill(isOn ? theme.accent : theme.card))
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier(id)
    }
}

/// Columnas de una rejilla de tarjetas: las de la ficha a tamaño normal; menos con texto de accesibilidad, para que los
/// nombres no se corten.
enum TutorialGridColumns {
    static func count(_ regular: Int, dynamicTypeSize: DynamicTypeSize) -> Int {
        guard dynamicTypeSize.isAccessibilitySize else { return regular }
        return dynamicTypeSize >= .accessibility3 ? 1 : max(1, regular - 1)
    }
}

/// El campo de un monto con su símbolo delante.
struct TutorialAmountField: View {
    @Binding var text: String
    let currencySymbol: String
    var prompt = "0"
    let accessibilityLabel: String
    let id: String
    var focus: FocusState<Bool>.Binding

    @Environment(\.yalaTheme) private var theme

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            Text(currencySymbol).font(DS.Typography.headline).foregroundStyle(.secondary)
            TextField("", text: $text, prompt: Text(verbatim: prompt).foregroundStyle(.tertiary))
                .font(DS.Typography.title3.weight(.semibold))
                .amountKeyboard()
                .focused(focus)
                .accessibilityLabel(accessibilityLabel)
                .accessibilityIdentifier(id)
        }
        .padding(.horizontal, DS.Spacing.md)
        .frame(minHeight: 48)
        .background(RoundedRectangle(cornerRadius: DS.Radius.lg).fill(theme.card))
    }
}

extension TutorialQuestionScreen where Card == EmptyView {
    init(
        subtitle: String, stepCount: Int, stepIndex: Int, isDone: Bool, question: String, detail: String?,
        identity: String, backID: String, onBack: @escaping () -> Void, @ViewBuilder dock: @escaping () -> Dock
    ) {
        self.init(
            subtitle: subtitle, stepCount: stepCount, stepIndex: stepIndex, isDone: isDone, question: question,
            detail: detail, identity: identity, backID: backID, onBack: onBack, card: { EmptyView() }, dock: dock)
    }
}

// MARK: - Las cuentas que comparten Primeros pasos y los guiados de Yala IA

/// Lo gastado con un presupuesto de prueba y la frase del pago planificado: los pasos 3 y 4 de Primeros pasos y los
/// guiados de Yala IA (`Views/Chat/Guiados/`) enseñan las mismas cifras con las mismas reglas.
enum TutorialPlanningMath {

    /// Lo gastado en el período en curso con estas subcategorías (vacío = todos los gastos): la misma regla que
    /// Planificación (`BudgetsViewModel.calculateSpending`), sobre un presupuesto de prueba que no se guarda.
    static func budgetSpent(
        subcategoryIDs: [UUID],
        period: BudgetPeriodType,
        currencyCode: String,
        transactions: [TransactionItem],
        startDate: Date? = nil,
        endDate: Date? = nil,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Double {
        // Sin nombre a propósito: un presupuesto sin filtros CON nombre dispara el canario `budgetFiltersAppearEmpty`.
        let probe = Budget(
            currencyCode: currencyCode,
            limitAmount: 1,
            periodType: period.rawValue,
            startDate: period == .unique ? startDate : nil,
            endDate: period == .unique ? endDate : nil,
            subcategoryIDs: CSVMirrorCodec.encode(subcategoryIDs)
        )
        let interval = BudgetPeriodInterval.current(for: probe, now: now, calendar: calendar)
        return BudgetsViewModel.calculateSpending(budget: probe, transactions: transactions, interval: interval)
    }

    /// La fecha del primer pago (la misma cuenta que el editor).
    static func paymentFirstDue(
        frequency: FirstScheduledPaymentFlowLogic.Frequency,
        dayOfMonth: Int,
        weekday: Int,
        date: Date,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Date? {
        guard frequency.isRecurring else { return calendar.startOfDay(for: date) }
        return ScheduledPaymentEditorViewModel.firstDueDate(
            start: calendar.startOfDay(for: now),
            recurrenceType: frequency.recurrenceType,
            recurrenceInterval: 1,
            dayOfMonth: frequency == .monthly ? dayOfMonth : nil,
            weekdays: frequency == .weekly ? String(weekday) : "",
            yearlyMonth: frequency == .yearly ? calendar.component(.month, from: date) : nil,
            yearlyDay: frequency == .yearly ? calendar.component(.day, from: date) : nil,
            endDate: nil
        )
    }

    /// «≈ S/ 80.00 cada mes, el día 1. Primer pago: 1 de diciembre.» (el resumen del editor). `amountText` ya formateado.
    static func paymentSummary(
        amountText: String,
        frequency: FirstScheduledPaymentFlowLogic.Frequency,
        dayOfMonth: Int,
        date: Date,
        due: Date
    ) -> String {
        let dueDay = Calendar.current.isDateInToday(due) ? L10n.UXL10.today : ScheduledPaymentDateText.dayMonthLong(due)
        switch frequency {
        case .once: return L10n.UXL10.summaryOnce(amountText, dueDay)
        case .monthly:
            return L10n.UXL10.summaryRecurring(amountText, L10n.UXL10.cadenceMonthly(interval: 1, day: dayOfMonth), dueDay)
        case .weekly:
            return L10n.UXL10.summaryRecurring(amountText, L10n.UXL10.cadenceWeekly(interval: 1), dueDay)
        case .yearly:
            let cadence = L10n.UXL10.cadenceYearly(interval: 1, date: ScheduledPaymentDateText.dayMonthLong(date))
            return L10n.UXL10.summaryRecurring(amountText, cadence, dueDay)
        }
    }

    /// «Hoy», «Mañana» o «En N días» hasta el pago.
    static func dueInText(_ due: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: due)).day ?? 0
        switch days {
        case ..<1: return L10n.UXL10.stateToday
        case 1: return L10n.UXL10.stateTomorrow
        default: return L10n.UXL10.stateInDays(days)
        }
    }
}
