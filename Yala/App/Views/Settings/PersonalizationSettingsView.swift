//
//  PersonalizationSettingsView.swift
//  Yala
//
//  Personalization settings sheet with default period selector.
//

import SwiftUI
import WidgetKit

struct PersonalizationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionState.self) private var sessionState
    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences

    @ScaledMetric(relativeTo: .largeTitle) private var heroIconSize: CGFloat = 48 // A11Y-DT: @ScaledMetric

    private var forcesMonochromeIcons: Bool { theme.forcesMonochromeIcons }
    private var decimalPlaces: Int { appPreferences.decimalPlaces }
    @State private var showingPeriodPicker = false
    @State private var showingAutoFocusPicker = false
    @State private var showingDecimalsPicker = false
    @State private var showingCurrencyFormatPicker = false
    @State private var showingAverageLinePicker = false
    @State private var showingWeekdayPicker = false
    @State private var showingLanguagePicker = false
    @State private var showingExpensesOnlyConfirmation = false
    @State private var showingSmartInsightsSettings = false

    private var isProUser: Bool {
        FeatureGateService.shared.canAccess(.chatAssistant)
    }

    private var selectedWeekday: FirstWeekday {
        appPreferences.firstWeekday
    }

    private var decimalPlacesDisplayName: String {
        switch decimalPlaces {
        case 0: return L10n.Settings.decimalsNone
        case 1: return L10n.Settings.decimalsOne
        default: return L10n.Settings.decimalsTwo
        }
    }

    private var averageLineDisplayName: String {
        switch appPreferences.averageLineMode {
        case 1: return L10n.Settings.averageLineTotal
        case 2: return L10n.Settings.averageLineSegmented
        default: return L10n.Settings.averageLineOff
        }
    }

    private var currencyFormatDisplayName: String {
        appPreferences.currencyDisplayFormat == .symbol ? L10n.Settings.currencySymbol : L10n.Settings.currencyCode
    }

    private var currentLanguageDisplayName: String {
        guard let code = LanguageManager.overrideLanguage else { return "" }
        return LanguageManager.supportedLanguages.first { $0.code == code }?.nativeName ?? code
    }


    var body: some View {
        @Bindable var prefs = appPreferences
        return YalaSettingsList {
            // Header
            Section {
                VStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: heroIconSize))
                        .foregroundStyle(.thAccent)
                        .padding(.bottom, DS.Spacing.sm)

                    Text(L10n.Settings.personalization)
                        .font(.title2.bold())
                        .foregroundStyle(.thPrimaryText)

                    Text(L10n.Settings.personalizationDescription)
                        .font(DS.Typography.body)
                        .foregroundStyle(.thSecondaryText)
                        .multilineTextAlignment(.center)
                }
                // Aire lateral: la fila no lleva márgenes, y con el texto a punto de caber en una línea SwiftUI recorta los bordes
                // de los glifos (medido 2026-10-03: Tutoriales en el SE en vertical, Personalización en el Pro Max girado).
                .padding(.horizontal, DS.Spacing.sm)
                .frame(maxWidth: .infinity)
                .padding(.top, DS.Spacing.lg)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
            }

            // MARK: - Modo de uso
            YalaSettingsSection(L10n.Settings.sectionUsageMode) {
                YalaSettingsToggleRow(L10n.Settings.expensesOnlyMode, isOn: Binding(
                    get: { sessionState.isExpensesOnlyMode },
                    set: { _ in showingExpensesOnlyConfirmation = true }
                ))
                .accessibilityIdentifier("personalization_row_expenses_only")
            } footer: {
                Text(L10n.Settings.expensesOnlyModeDescription)
            }

            // MARK: - Interfaz
            // El idioma de la app (solo con override activo) lleva su propia ayuda: va en su bloque, con la
            // cabecera; si no está, la cabecera pasa al bloque siguiente.
            if LanguageManager.overrideLanguage != nil {
                YalaSettingsSection(L10n.Settings.sectionInterface) {
                    YalaSettingsValueRow(L10n.Settings.appLanguage, value: currentLanguageDisplayName) {
                        showingLanguagePicker = true
                    }
                    .accessibilityIdentifier("personalization_row_app_language")
                } footer: {
                    Text(L10n.Settings.appLanguageRestart)
                }
            }

            YalaSettingsSection(LanguageManager.overrideLanguage == nil ? L10n.Settings.sectionInterface : nil) {
                Menu {
                    ForEach(VoiceLanguage.allCases) { language in
                        Button {
                            appPreferences.voiceLanguage = language
                        } label: {
                            HStack {
                                Text(language.displayName)
                                if appPreferences.voiceLanguage == language {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        .accessibilityIdentifier("voice_language_option_\(language.rawValue)")
                        .accessibilityAddTraits(appPreferences.voiceLanguage == language ? [.isSelected] : [])
                    }
                } label: {
                    YalaSettingsRowLabel(
                        title: L10n.Settings.voiceLanguage,
                        value: appPreferences.voiceLanguage.displayName,
                        accessory: "chevron.up.chevron.down"
                    )
                }
                .accessibilityIdentifier("voice_language_menu")

                YalaSettingsValueRow(L10n.Settings.customizeAISummary) {
                    showingSmartInsightsSettings = true
                }
                .accessibilityIdentifier("personalization_row_ai_summary")

                // Último del bloque: su ayuda (solo cuando el tema lo apaga) cae justo debajo.
                YalaSettingsToggleRow(
                    L10n.Settings.colorfulIcons,
                    isOn: $prefs.colorfulIcons,
                    isDisabled: forcesMonochromeIcons
                )
                .accessibilityHint(forcesMonochromeIcons ? L10n.Accessibility.systemMonochromeIcons : "")
                .accessibilityIdentifier("settings_colorful_icons_toggle")
            } footer: {
                if forcesMonochromeIcons {
                    Text(L10n.Settings.colorfulIconsDisabledByTheme)
                }
            }

            // Chat FAB visibility (Free users only — Pro users manage it via per-section Panel preferences)
            if !isProUser {
                YalaSettingsSection {
                    YalaSettingsToggleRow(L10n.Widget.chatFabToggle, isOn: $prefs.chatFABVisible) {
                        ProBadge(size: .small)
                    }
                    .accessibilityIdentifier("personalization_row_chat_fab")
                } footer: {
                    Text(L10n.Widget.chatFabHint)
                }
            }

            // MARK: - Calendario
            YalaSettingsSection(L10n.Settings.sectionCalendar) {
                YalaSettingsValueRow(L10n.Settings.defaultPeriod, value: appPreferences.defaultPeriod.displayName) {
                    showingPeriodPicker = true
                }
                .accessibilityIdentifier("personalization_row_default_period")

                YalaSettingsValueRow(L10n.Settings.firstWeekday, value: selectedWeekday.displayName) {
                    showingWeekdayPicker = true
                }
                .accessibilityIdentifier("personalization_row_first_weekday")
            } footer: {
                // Nombra su fila («Este período…»): no hace falta que sea la última del bloque.
                Text(L10n.Settings.defaultPeriodDescription)
            }

            // MARK: - Indicadores
            YalaSettingsSection(L10n.Settings.sectionIndicators) {
                YalaSettingsToggleRow(L10n.Settings.widgetHints, isOn: $prefs.showWidgetHints)
                    .accessibilityIdentifier("personalization_row_widget_hints")
            } footer: {
                Text(L10n.Settings.widgetHintsDescription)
            }

            YalaSettingsSection {
                YalaSettingsValueRow(L10n.Settings.averageLine, value: averageLineDisplayName) {
                    showingAverageLinePicker = true
                }
                .accessibilityIdentifier("personalization_row_average_line")

                YalaSettingsToggleRow(L10n.Settings.showVariations, isOn: $prefs.showVariations)
                    .accessibilityIdentifier("personalization_row_variations")
            } footer: {
                Text(L10n.Settings.showVariationsDescription)
            }

            // MARK: - Formato
            YalaSettingsSection(L10n.Settings.sectionFormat) {
                YalaSettingsValueRow(L10n.Settings.currencyFormat, value: currencyFormatDisplayName) {
                    showingCurrencyFormatPicker = true
                }
                .accessibilityIdentifier("personalization_row_currency_format")

                YalaSettingsValueRow(L10n.Settings.decimalPlaces, value: decimalPlacesDisplayName) {
                    showingDecimalsPicker = true
                }
                .accessibilityIdentifier("personalization_row_decimals")
            } footer: {
                Text(L10n.Settings.decimalPlacesDescription)
            }

            YalaSettingsSection {
                YalaSettingsValueRow(L10n.Settings.autoFocusField, value: appPreferences.autoFocusField.displayName) {
                    showingAutoFocusPicker = true
                }
                .accessibilityIdentifier("personalization_row_auto_focus")
            } footer: {
                Text(L10n.Settings.autoFocusFieldDescription)
            }
        }
        .navigationTitle(L10n.Settings.personalization)
        .navigationBarTitleDisplayMode(.inline)
        .yalaScreenBackground(.subtle)
        .swipeBack()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                YalaToolbarButton(systemName: "chevron.left", label: L10n.Action.back) {
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showingPeriodPicker) {
            PeriodPickerSheet(
                selectedPeriod: appPreferences.defaultPeriod,
                onSelect: { period in
                    appPreferences.defaultPeriod = period
                    sessionState.selectedPeriod = period
                    showingPeriodPicker = false
                }
            )
            .presentationDetents([.large])
        }
        .sheet(isPresented: $showingWeekdayPicker) {
            WeekdayPickerSheet(
                selectedWeekday: selectedWeekday,
                onSelect: { weekday in
                    appPreferences.firstWeekday = weekday
                    // Force recalculation of dateInterval with new firstWeekday
                    let currentPeriod = sessionState.selectedPeriod
                    sessionState.selectedPeriod = currentPeriod

                    // Sync to App Group for widgets
                    if let defaults = UserDefaults(suiteName: SharedContainerService.appGroupIdentifier) {
                        defaults.set(weekday.rawValue, forKey: "firstWeekday")
                    }
                    WidgetCenter.shared.reloadAllTimelines()

                    showingWeekdayPicker = false
                }
            )
            .yalaSheetDetents([.height(280)])
        }
        .sheet(isPresented: $showingDecimalsPicker) {
            DecimalsPickerSheet(
                selectedDecimals: decimalPlaces,
                onSelect: { decimals in
                    appPreferences.decimalPlaces = decimals
                    showingDecimalsPicker = false
                }
            )
            .yalaSheetDetents([.height(320)])
        }
        .sheet(isPresented: $showingCurrencyFormatPicker) {
            CurrencyFormatPickerSheet(
                selectedFormat: appPreferences.currencyDisplayFormat.rawValue,
                onSelect: { format in
                    if let parsed = CurrencyDisplayFormat(rawValue: format) {
                        appPreferences.currencyDisplayFormat = parsed
                    }
                    showingCurrencyFormatPicker = false
                }
            )
            .yalaSheetDetents([.height(280)])
        }
        .sheet(isPresented: $showingAutoFocusPicker) {
            AutoFocusPickerSheet(
                selectedField: appPreferences.autoFocusField,
                onSelect: { field in
                    appPreferences.autoFocusField = field
                    showingAutoFocusPicker = false
                }
            )
            .yalaSheetDetents([.height(320)])
        }
        .sheet(isPresented: $showingAverageLinePicker) {
            AverageLinePickerSheet(
                selectedMode: appPreferences.averageLineMode,
                onSelect: { mode in
                    appPreferences.averageLineMode = mode
                    showingAverageLinePicker = false
                }
            )
            .yalaSheetDetents([.height(320)])
        }
        .sheet(isPresented: $showingLanguagePicker) {
            LanguagePickerSheet(
                selectedLanguage: LanguageManager.overrideLanguage ?? "en",
                onSelect: { code in
                    LanguageManager.overrideLanguage = code
                    // Las summaries diarias de pagos se agendan con el body YA localizado
                    // (contenido congelado): sin re-plan quedarían en el idioma viejo.
                    ScheduledPaymentNotificationService.shared.requestSummaryReplan()
                    showingLanguagePicker = false
                }
            )
            .yalaSheetDetents([.medium])
        }
        .sheet(isPresented: $showingSmartInsightsSettings) {
            SmartInsightsSettingsView()
        }
        .confirmationDialog(
            sessionState.isExpensesOnlyMode
                ? L10n.Settings.expensesOnlyDeactivateTitle
                : L10n.Settings.expensesOnlyActivateTitle,
            isPresented: $showingExpensesOnlyConfirmation,
            titleVisibility: .visible
        ) {
            Button(
                sessionState.isExpensesOnlyMode
                    ? L10n.Settings.expensesOnlyDeactivateConfirm
                    : L10n.Settings.expensesOnlyActivateConfirm,
                role: sessionState.isExpensesOnlyMode ? nil : .destructive
            ) {
                // Este toggle es el punto de INTENCIÓN del usuario y la key es `synced: true`, así
                // que publica ÉL — mismo orden que `OnboardingView`, que ya lo hacía a mano.
                // El espejo (`SessionState.isExpensesOnlyMode.didSet`) escribe local + App Group +
                // recarga widgets, pero NO encola y no debe: a ese mismo `didSet` llegan también el
                // merge remoto (`PreferenceSyncService.applyMergeOutcome`) y el reset de
                // `-uitest-reset`, y publicar ahí devolvería el eco (en `.cloud`, con HLC fresco
                // sobre un valor recién bajado) y haría que un XCUITest encolara preferencias.
                // Hasta ahora llegaba a iCloud de rebote, porque `AppPreferences.loadFromDefaults`
                // re-persistía lo que releía; ese puente accidental se cerró.
                let newValue = !sessionState.isExpensesOnlyMode
                PreferenceSyncService.shared.set(
                    bool: newValue, forKey: AppPreferences.Keys.expensesOnlyMode)
                sessionState.isExpensesOnlyMode = newValue
            }
            Button(L10n.Settings.cancel, role: .cancel) {}
        } message: {
            Text(
                sessionState.isExpensesOnlyMode
                    ? L10n.Settings.expensesOnlyDeactivateMessage
                    : L10n.Settings.expensesOnlyActivateMessage
            )
        }
    }

}

// MARK: - Period Picker Sheet

private struct PeriodPickerSheet: View {
    let selectedPeriod: DetailPeriod
    let onSelect: (DetailPeriod) -> Void

    @Environment(\.dismiss) private var dismiss

    /// Exclude .custom - default period should be relative, not absolute dates
    private var availablePeriods: [DetailPeriod] {
        DetailPeriod.allCases.filter { $0 != .custom }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.none) {
                    ForEach(availablePeriods) { period in
                        periodRow(for: period)
                    }
                }
                .background(.thCard)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                        .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                )
                .padding(DS.Spacing.lg)
            }
            .navigationTitle(L10n.Settings.defaultPeriod)
            .navigationBarTitleDisplayMode(.inline)
            .yalaScreenBackground(.subtle)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func periodRow(for period: DetailPeriod) -> some View {
        let isSelected = selectedPeriod == period

        Button {
            onSelect(period)
        } label: {
            HStack {
                Text(period.displayName)
                    .font(DS.Typography.body)
                    .foregroundStyle(.thPrimaryText)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.thAccent)
                        .font(DS.Typography.headline)
                }
            }
            .padding(.horizontal, DS.FormRow.paddingH)
            .padding(.vertical, DS.FormRow.paddingV)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        if period != availablePeriods.last {
            Divider()
                .padding(.leading, DS.Spacing.lg)
        }
    }
}

// MARK: - Weekday Picker Sheet

private struct WeekdayPickerSheet: View {
    let selectedWeekday: FirstWeekday
    let onSelect: (FirstWeekday) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.none) {
                    ForEach(FirstWeekday.allCases) { weekday in
                        weekdayRow(for: weekday)
                    }
                }
                .background(.thCard)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                        .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                )
                .padding(DS.Spacing.lg)
            }
            .navigationTitle(L10n.Settings.firstWeekday)
            .navigationBarTitleDisplayMode(.inline)
            .yalaScreenBackground(.partialSheet)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func weekdayRow(for weekday: FirstWeekday) -> some View {
        let isSelected = selectedWeekday == weekday

        Button {
            onSelect(weekday)
        } label: {
            HStack {
                Text(weekday.displayName)
                    .font(DS.Typography.body)
                    .foregroundStyle(.thPrimaryText)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.thAccent)
                        .font(DS.Typography.headline)
                }
            }
            .padding(.horizontal, DS.FormRow.paddingH)
            .padding(.vertical, DS.FormRow.paddingV)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        if weekday != FirstWeekday.allCases.last {
            Divider()
                .padding(.leading, DS.Spacing.lg)
        }
    }
}

// MARK: - Decimals Picker Sheet

private struct DecimalsPickerSheet: View {
    let selectedDecimals: Int
    let onSelect: (Int) -> Void

    @Environment(\.dismiss) private var dismiss

    private let options: [(value: Int, label: String, example: String)] = [
        (0, L10n.Settings.decimalsNone, "1,234"),
        (1, L10n.Settings.decimalsOne, "1,234.5"),
        (2, L10n.Settings.decimalsTwo, "1,234.56"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.none) {
                    ForEach(options, id: \.value) { option in
                        decimalsRow(for: option)
                    }
                }
                .background(.thCard)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                        .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                )
                .padding(DS.Spacing.lg)
            }
            .navigationTitle(L10n.Settings.decimalPlaces)
            .navigationBarTitleDisplayMode(.inline)
            .yalaScreenBackground(.partialSheet)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func decimalsRow(for option: (value: Int, label: String, example: String)) -> some View {
        let isSelected = selectedDecimals == option.value

        Button {
            onSelect(option.value)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(option.label)
                        .font(DS.Typography.body)
                        .foregroundStyle(.thPrimaryText)

                    Text(option.example)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.thAccent)
                        .font(DS.Typography.headline)
                }
            }
            .padding(.horizontal, DS.FormRow.paddingH)
            .padding(.vertical, DS.FormRow.paddingV)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        if option.value != 2 {
            Divider()
                .padding(.leading, DS.Spacing.lg)
        }
    }
}

// MARK: - Currency Format Picker Sheet

private struct CurrencyFormatPickerSheet: View {
    let selectedFormat: String  // "code" or "symbol"
    let onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    private let options: [(value: String, label: String, example: String)] = [
        ("code", L10n.Settings.currencyCode, "PEN 1,234"),
        ("symbol", L10n.Settings.currencySymbol, "S/ 1,234"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.none) {
                    ForEach(options, id: \.value) { option in
                        formatRow(for: option)
                    }
                }
                .background(.thCard)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                        .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                )
                .padding(DS.Spacing.lg)
            }
            .navigationTitle(L10n.Settings.currencyFormat)
            .navigationBarTitleDisplayMode(.inline)
            .yalaScreenBackground(.partialSheet)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func formatRow(for option: (value: String, label: String, example: String)) -> some View {
        let isSelected = selectedFormat == option.value

        Button {
            onSelect(option.value)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(option.label)
                        .font(DS.Typography.body)
                        .foregroundStyle(.thPrimaryText)

                    Text(option.example)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.thAccent)
                        .font(DS.Typography.headline)
                }
            }
            .padding(.horizontal, DS.FormRow.paddingH)
            .padding(.vertical, DS.FormRow.paddingV)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        if option.value != "symbol" {
            Divider()
                .padding(.leading, DS.Spacing.lg)
        }
    }
}

// MARK: - Language Picker Sheet

private struct LanguagePickerSheet: View {
    let selectedLanguage: String
    let onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.none) {
                    ForEach(LanguageManager.supportedLanguages) { lang in
                        languageRow(lang: lang)
                    }
                }
                .background(.thCard)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                        .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                )
                .padding(DS.Spacing.lg)
            }
            .navigationTitle(L10n.Settings.appLanguage)
            .navigationBarTitleDisplayMode(.inline)
            .yalaScreenBackground(.partialSheet)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Action.cancel) { dismiss() }
                }
            }
        }
    }

    private func languageRow(lang: SupportedLocale) -> some View {
        let isSelected = selectedLanguage == lang.code

        return VStack(spacing: DS.Spacing.none) {
            Button {
                onSelect(lang.code)
            } label: {
                HStack(spacing: DS.Spacing.md) {
                    Text(lang.flag)
                        .font(DS.Typography.title)

                    Text(lang.nativeName)
                        .font(DS.Typography.body)
                        .foregroundStyle(.thPrimaryText)

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.thAccent)
                            .font(DS.Typography.headline)
                    }
                }
                .padding(.horizontal, DS.FormRow.paddingH)
                .padding(.vertical, DS.FormRow.paddingV)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if lang.code != LanguageManager.supportedLanguages.last?.code {
                Divider()
                    .padding(.leading, DS.Spacing.lg)
            }
        }
    }
}

// MARK: - Average Line Picker Sheet

private struct AverageLinePickerSheet: View {
    let selectedMode: Int
    let onSelect: (Int) -> Void

    @Environment(\.dismiss) private var dismiss

    private let options: [(value: Int, label: String, description: String)] = [
        (0, L10n.Settings.averageLineOff, L10n.Settings.averageLineOffDescription),
        (1, L10n.Settings.averageLineTotal, L10n.Settings.averageLineTotalDescription),
        (2, L10n.Settings.averageLineSegmented, L10n.Settings.averageLineSegmentedDescription),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.none) {
                    ForEach(options, id: \.value) { option in
                        averageLineRow(for: option)
                    }
                }
                .background(.thCard)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                        .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                )
                .padding(DS.Spacing.lg)
            }
            .navigationTitle(L10n.Settings.averageLine)
            .navigationBarTitleDisplayMode(.inline)
            .yalaScreenBackground(.partialSheet)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func averageLineRow(for option: (value: Int, label: String, description: String)) -> some View {
        let isSelected = selectedMode == option.value

        Button {
            onSelect(option.value)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(option.label)
                        .font(DS.Typography.body)
                        .foregroundStyle(.thPrimaryText)

                    Text(option.description)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.thAccent)
                        .font(DS.Typography.headline)
                }
            }
            .padding(.horizontal, DS.FormRow.paddingH)
            .padding(.vertical, DS.FormRow.paddingV)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        if option.value != 2 {
            Divider()
                .padding(.leading, DS.Spacing.lg)
        }
    }
}

// MARK: - Auto-Focus Picker Sheet

private struct AutoFocusPickerSheet: View {
    let selectedField: AutoFocusField
    let onSelect: (AutoFocusField) -> Void

    @Environment(\.dismiss) private var dismiss

    private let options: [AutoFocusField] = AutoFocusField.allCases

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.none) {
                    ForEach(options) { option in
                        autoFocusRow(for: option)
                    }
                }
                .background(.thCard)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                        .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                )
                .padding(DS.Spacing.lg)
            }
            .navigationTitle(L10n.Settings.autoFocusField)
            .navigationBarTitleDisplayMode(.inline)
            .yalaScreenBackground(.partialSheet)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func autoFocusRow(for option: AutoFocusField) -> some View {
        let isSelected = selectedField == option

        Button {
            onSelect(option)
        } label: {
            HStack {
                Text(option.displayName)
                    .font(DS.Typography.body)
                    .foregroundStyle(.thPrimaryText)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.thAccent)
                        .font(DS.Typography.headline)
                }
            }
            .padding(.horizontal, DS.FormRow.paddingH)
            .padding(.vertical, DS.FormRow.paddingV)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        if option != .description {
            Divider()
                .padding(.leading, DS.Spacing.lg)
        }
    }
}

#Preview {
    NavigationStack {
        PersonalizationSettingsView()
            .environment(SessionState())
            .previewAppPreferences()
    }
}
