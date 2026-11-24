//
//  RecurringQuickSheet.swift
//  Yala
//
//  «Hacer recurrente» del formulario de registro (UX 2.2 · L2-15, decidido por Jürgen el 14-oct y cerrado el 21-oct):
//  una hoja corta con tres frecuencias que salen de la fecha del registro, y «Más opciones…» para el editor completo.
//
//  Rediseño del 23-nov (pedido de Jürgen en las pruebas de 2.3): fondo sólido del tema (a media altura el cristal dejaba
//  ver los botones del formulario de atrás), arriba el registro que se va a programar —para ver que sus datos viajan— y
//  las frecuencias en una tarjeta, cada una con una mini hoja de calendario que enseña su ancla.
//

import SwiftData
import SwiftUI

/// Las tres filas de la hoja, con el texto que sale de la fecha del registro. Lógica pura para fijarla con tests.
enum RecurringQuickChoiceLogic {

    struct Choice: Equatable {
        let recurrence: RecurrenceType
        let title: String
    }

    /// «Cada semana, el martes», «Cada mes, el día 13», «Cada año, el 13 de octubre».
    static func choices(for date: Date, locale: Locale, calendar: Calendar = .current) -> [Choice] {
        let weekday = formatter("EEEE", locale: locale, calendar: calendar)
        let dayMonth = formatter("dMMMM", locale: locale, calendar: calendar)
        let day = calendar.component(.day, from: date)
        return [
            Choice(recurrence: .weekly, title: L10n.UXL2.recurringWeekly(weekday.string(from: date))),
            Choice(recurrence: .monthly, title: L10n.UXL2.recurringMonthly(day)),
            Choice(recurrence: .yearly, title: L10n.UXL2.recurringYearly(dayMonth.string(from: date))),
        ]
    }

    /// Lo que enseña la mini hoja de calendario de cada fila: arriba, en la franja de color, el mes (solo al año); en
    /// grande, el día de la semana abreviado (cada semana) o el día (cada mes y cada año). Sale de los formatos del
    /// idioma, sin textos propios: «LUN» · «23» · «NOV» + «23».
    struct Badge: Equatable {
        let band: String?
        let main: String
        /// `main` es un nombre (el día de la semana), no un número: va en una letra más pequeña.
        let mainIsWord: Bool
    }

    static func badge(
        for recurrence: RecurrenceType, date: Date, locale: Locale, calendar: Calendar = .current
    ) -> Badge {
        let day = String(calendar.component(.day, from: date))
        switch recurrence {
        case .weekly:
            let weekday = formatter("EEE", locale: locale, calendar: calendar).string(from: date)
            return Badge(band: nil, main: shortWord(weekday, locale: locale), mainIsWord: true)
        case .yearly:
            // `LLL`: el mes suelto, en su forma de calendario («nov», no el genitivo de algunos idiomas).
            let month = formatter("LLL", locale: locale, calendar: calendar).string(from: date)
            return Badge(band: shortWord(month, locale: locale), main: day, mainIsWord: false)
        case .monthly, .daily:
            return Badge(band: nil, main: day, mainIsWord: false)
        }
    }

    /// Sin el punto de abreviatura («lun.», «nov.») y en mayúsculas del idioma.
    private static func shortWord(_ text: String, locale: Locale) -> String {
        text.replacingOccurrences(of: ".", with: "").uppercased(with: locale)
    }

    private static func formatter(_ template: String, locale: Locale, calendar: Calendar) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter
    }

    /// El ancla del pago planificado para cada frecuencia: el día de la semana, el día del mes o el día y el mes de la
    /// fecha del registro. Antes, con precarga, el día de la semana se quedaba en lunes.
    struct Anchor: Equatable {
        let weekday: Int
        let dayOfMonth: Int
        let month: Int
    }

    static func anchor(for date: Date, calendar: Calendar = .current) -> Anchor {
        Anchor(
            weekday: calendar.component(.weekday, from: date),
            dayOfMonth: calendar.component(.day, from: date),
            month: calendar.component(.month, from: date)
        )
    }

    /// La segunda línea del resumen: la cuenta y la categoría › subcategoría que lleva el registro, lo que haya.
    static func summaryDetail(accountName: String?, categoryName: String?, subcategoryName: String?) -> String {
        let category: String?
        switch (categoryName?.nonEmptyTrimmed, subcategoryName?.nonEmptyTrimmed) {
        case let (parent?, child?) where parent != child: category = "\(parent) › \(child)"
        case let (_, child?): category = child
        case let (parent?, nil): category = parent
        case (nil, nil): category = nil
        }
        return [accountName?.nonEmptyTrimmed, category].compactMap { $0 }.joined(separator: " · ")
    }
}

private extension String {
    var nonEmptyTrimmed: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct RecurringQuickSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences

    /// El registro que se programa, tal como está en el formulario: la hoja lo resume y sus dos salidas lo copian.
    let record: RecurringFromRecordService.FormRecord
    let onPick: (RecurrenceType) -> Void
    let onMoreOptions: () -> Void

    /// Etiquetas que caben en el resumen antes del «+n».
    private static let visibleTags = 2

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    summaryCard

                    VStack(spacing: 0) {
                        let choices = RecurringQuickChoiceLogic.choices(for: record.date, locale: AppLocale.current)
                        ForEach(Array(choices.enumerated()), id: \.element.recurrence) { index, choice in
                            if index > 0 {
                                Divider().padding(.leading, DS.Spacing.lg + Self.badgeWidth + DS.Spacing.md)
                            }
                            frequencyRow(choice)
                        }
                    }
                    .background(.thCard, in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))

                    moreOptionsRow

                    Text(L10n.UXL2.recurringHeader)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, DS.Spacing.xs)
                        .accessibilityIdentifier("recurring_quick_header")
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.xs)
                .padding(.bottom, DS.Spacing.md)
            }
            .scrollBounceBehavior(.basedOnSize)
            .navigationTitle(L10n.UXL2.recurringTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }
            }
            // Fondo sólido del tema también a media altura (Jürgen, 23-nov): con el cristal del sistema se veían los
            // botones de color del formulario de atrás. Excepción a «a media altura, el cristal» de `swiftui-ds.md`.
            .yalaScreenBackground(.subtle)
        }
        .yalaSheetDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Resumen

    private var displayName: String {
        let name = record.paymentName
        return name.isEmpty ? record.transactionType.displayName : name
    }

    private var amountText: String {
        appPreferences.currency(record.amount, currencyCode: record.currencyCode)
    }

    private var summaryCard: some View {
        let detail = RecurringQuickChoiceLogic.summaryDetail(
            accountName: record.account?.name,
            categoryName: record.subcategory?.category?.name,
            subcategoryName: record.subcategory?.name)
        let tags = record.tags
        return VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(alignment: .center, spacing: DS.Spacing.md) {
                categoryIcon
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(displayName)
                        .font(DS.Typography.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    if !detail.isEmpty {
                        Text(detail)
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: DS.Spacing.sm)
                Text(amountText)
                    .font(DS.Typography.amount)
                    .monospacedDigit()
                    .foregroundStyle(record.transactionType == .income ? Color.incomeAmount : Color.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            if !tags.isEmpty {
                tagsRow(tags)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thCard, in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("recurring_quick_summary")
    }

    /// El icono de la subcategoría sobre el color de su categoría, como en la fila de Registros.
    private var categoryIcon: some View {
        let colorHex = record.subcategory?.category?.colorHex ?? AppConstants.defaultColorHex
        let iconName = record.subcategory?.iconName ?? record.subcategory?.category?.iconName ?? "tag.fill"
        return ZStack {
            Circle()
                .fill(Color(hex: colorHex))
                .frame(width: DS.ListRow.iconSize, height: DS.ListRow.iconSize)
            Image(systemName: iconName)
                .font(DS.Typography.label)
                // A11Y-DM: blanco fijo sobre el color de la categoría, como en `RecordRowView`.
                .foregroundStyle(.white)
        }
        .accessibilityHidden(true)
    }

    /// Las píldoras de etiqueta de Registros: punto del color y texto en tinta sobre su tinte.
    private func tagsRow(_ tags: [Tag]) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            ForEach(Array(tags.prefix(Self.visibleTags)), id: \.persistentModelID) { tag in
                HStack(spacing: DS.Spacing.xs) {
                    Circle()
                        .fill(Color(hex: tag.colorHex))
                        .frame(width: DS.Chip.dotSize - 2, height: DS.Chip.dotSize - 2)
                    Text(tag.name)
                        .font(DS.Typography.labelTiny)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                .padding(.horizontal, DS.Chip.paddingV)
                .padding(.vertical, DS.Spacing.xxs)
                .background(Capsule().fill(Color(hex: tag.colorHex).opacity(0.15)))
            }
            if tags.count > Self.visibleTags {
                Text(verbatim: "+\(tags.count - Self.visibleTags)")
                    .font(DS.Typography.labelTiny)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.leading, DS.ListRow.iconSize + DS.Spacing.md)
    }

    // MARK: - Frecuencias

    private static let badgeWidth: CGFloat = 40

    private func frequencyRow(_ choice: RecurringQuickChoiceLogic.Choice) -> some View {
        Button {
            onPick(choice.recurrence)
        } label: {
            HStack(spacing: DS.Spacing.md) {
                calendarBadge(
                    RecurringQuickChoiceLogic.badge(for: choice.recurrence, date: record.date, locale: AppLocale.current))
                Text(choice.title)
                    .font(DS.Typography.label)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: DS.Spacing.sm)
                Image(systemName: "chevron.right")
                    .font(DS.Typography.caption)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("recurring_quick_\(choice.recurrence.rawValue)")
    }

    /// Una mini hoja de calendario: franja del acento arriba (con el mes, al año) y el ancla en grande debajo.
    private func calendarBadge(_ badge: RecurringQuickChoiceLogic.Badge) -> some View {
        let shape = RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
        return VStack(spacing: 0) {
            Text(verbatim: badge.band ?? " ")
                .font(DS.Typography.badgeLabel)
                .foregroundStyle(theme.onAccent)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.xxs)
                .background(theme.accent)
            Text(verbatim: badge.main)
                .font(badge.mainIsWord ? DS.Typography.indicator : DS.Typography.headline)
                .monospacedDigit()
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: Self.badgeWidth, height: Self.badgeWidth + DS.Spacing.xs)
        .background(theme.background, in: shape)
        .clipShape(shape)
        .overlay(shape.strokeBorder(theme.accent.opacity(0.35), lineWidth: 1))
        .accessibilityHidden(true)
    }

    // MARK: - Más opciones

    private var moreOptionsRow: some View {
        Button(action: onMoreOptions) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "slider.horizontal.3")
                    .font(DS.Typography.label)
                    .foregroundStyle(theme.accentText)
                    .frame(width: Self.badgeWidth, height: Self.badgeWidth)
                    .background(theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(L10n.UXL2.recurringMoreOptions)
                        .font(DS.Typography.label)
                        .foregroundStyle(.primary)
                    Text(L10n.RecurringFromRecord.quickMoreOptionsDetail)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: DS.Spacing.sm)
                Image(systemName: "chevron.right")
                    .font(DS.Typography.caption)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(.thCard, in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        .accessibilityIdentifier("recurring_quick_more")
    }
}
