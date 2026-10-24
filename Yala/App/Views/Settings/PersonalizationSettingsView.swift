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
    @Environment(\.settingsListIsAlongside) private var settingsListIsAlongside
    @Environment(SessionState.self) private var sessionState
    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(SceneNavigation.self) private var navigation
    @Environment(\.openURL) private var openURL

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
    /// UX 2.2 · L16-6: dos avisos, uno por sentido, con el texto de sus botones LITERAL: el `actions` de un `.alert` no
    /// admite un botón cuyo texto dependa del estado (`swiftui-ds.md`), y un solo aviso para los dos lo necesitaba.
    @State private var showingExpensesOnlyActivate = false
    @State private var showingExpensesOnlyDeactivate = false
    @State private var showingSmartInsightsSettings = false
    @State private var showingAIPersonalization = false

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

    /// UX 2.2 · L16-5 (B): el idioma en que se ve Yala ahora, elegido en Yala o heredado del iPhone.
    private var currentLanguageCode: String {
        AppLanguageRowLogic.currentCode(
            overrideLanguage: LanguageManager.overrideLanguage,
            preferredLanguages: Locale.preferredLanguages,
            region: Locale.current.region?.identifier)
    }

    private var currentLanguageDisplayName: String {
        let code = currentLanguageCode
        return LanguageManager.supportedLanguages.first { $0.code == code }?.nativeName ?? code
    }

    private var languageRoute: AppLanguageRowLogic.Route {
        AppLanguageRowLogic.route(
            overrideLanguage: LanguageManager.overrideLanguage,
            preferredLanguages: Locale.preferredLanguages)
    }

    /// Con varios idiomas en el iPhone, a la página de Yala en los Ajustes de iOS (donde está «Idioma»); con uno solo o
    /// con un idioma elegido en Yala, el selector de Yala.
    private func openAppLanguage() {
        switch languageRoute {
        case .iOSSettings:
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            openURL(url)
        case .yalaPicker:
            showingLanguagePicker = true
        }
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
                    set: { _ in
                        if sessionState.isExpensesOnlyMode {
                            showingExpensesOnlyDeactivate = true
                        } else {
                            showingExpensesOnlyActivate = true
                        }
                    }
                ))
                .accessibilityIdentifier("personalization_row_expenses_only")
            } footer: {
                Text(L10n.Settings.expensesOnlyModeDescription)
            }

            // MARK: - Interfaz
            // UX 2.2 · L16-5 (opción B de Jürgen, 2026-10-23): la fila sale SIEMPRE. Antes solo existía si en la bienvenida
            // se había elegido idioma, y no había otra forma de cambiarlo. Lleva su propia ayuda: va en su bloque, con la
            // cabecera.
            YalaSettingsSection(L10n.Settings.sectionInterface) {
                YalaSettingsValueRow(L10n.Settings.appLanguage, value: currentLanguageDisplayName) {
                    openAppLanguage()
                }
                .accessibilityIdentifier("personalization_row_app_language")
            } footer: {
                Text(languageRoute == .iOSSettings ? L10n.PJ22.appLanguageInIOSFooter : L10n.Settings.appLanguageAppliesNow)
            }

            YalaSettingsSection {
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
            } footer: {
                // UX 2.2 · L16-7: cada pie dice dónde se ve (o se usa) su ajuste.
                Text(L10n.UXL15.voiceLanguageFooter)
            }

            YalaSettingsSection {
                // UX 2.2 · L14-10 (opción C): el tono se busca en Ajustes, y aquí solo estaba el resumen, que es otra
                // cosa. La fila abre la misma hoja que el botón de ajustes del chat.
                YalaSettingsValueRow(L10n.AISettings.title) {
                    showingAIPersonalization = true
                }
                .accessibilityIdentifier("personalization_row_ai_tone")

                // UX 2.2 · L16-8: «Qué sale en el resumen» (antes «Personalizar resumen de IA»): controla Estadísticas ›
                // Resumen, y de lo que enciende solo las Observaciones son de IA.
                YalaSettingsValueRow(L10n.Settings.customizeAISummary) {
                    showingSmartInsightsSettings = true
                }
                .accessibilityIdentifier("personalization_row_ai_summary")
            }

            YalaSettingsSection {
                YalaSettingsToggleRow(
                    L10n.Settings.colorfulIcons,
                    isOn: $prefs.colorfulIcons,
                    isDisabled: forcesMonochromeIcons
                )
                .accessibilityHint(forcesMonochromeIcons ? L10n.Accessibility.systemMonochromeIcons : "")
                .accessibilityIdentifier("settings_colorful_icons_toggle")
            } footer: {
                Text(forcesMonochromeIcons ? L10n.Settings.colorfulIconsDisabledByTheme : L10n.UXL15.colorfulIconsFooter)
            }

            // El botón de Yala IA, para todos (UX 2.2 · L14-12, opción B): un Pro que no quiere IA no tenía cómo
            // quitarlo, y el comentario de aquí lo mandaba a unas «preferencias del Panel» que no existían.
            YalaSettingsSection {
                YalaSettingsToggleRow(L10n.Widget.chatFabToggle, isOn: $prefs.chatFABVisible) {
                    if !isProUser {
                        ProBadge(size: .small)
                    }
                }
                .accessibilityIdentifier("personalization_row_chat_fab")
            } footer: {
                Text(L10n.Widget.chatFabHint)
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
            } footer: {
                Text(L10n.UXL15.averageLineFooter)
            }

            YalaSettingsSection {
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
            } footer: {
                Text(L10n.UXL15.currencyFormatFooter)
            }

            YalaSettingsSection {
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
            // Con la lista de Ajustes al lado, la lista es la vuelta (UX 2.2 · L16-20).
            if !settingsListIsAlongside {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "chevron.left", label: L10n.Action.back) {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingPeriodPicker) {
            PeriodPickerSheet(
                selectedPeriod: appPreferences.defaultPeriod,
                onSelect: { period in
                    appPreferences.defaultPeriod = period
                    // `choosePeriod`: es una elección de la persona, y si había abierto Estadísticas desde un informe, el
                    // período que acaba de elegir no se le cambia por el de antes del aviso al salir (UX 2.2 · L11-2).
                    sessionState.choosePeriod(period)
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
                selectedLanguage: currentLanguageCode,
                onSelect: { code in
                    // L16-5 (B): cambiar el idioma reconstruye la app y cierra Ajustes; el Panel la reabre aquí, en
                    // Personalización (`PanelSettingsReturnOpening`). Se apunta ANTES de cambiarlo: la reconstrucción
                    // ocurre en la misma vuelta. Si es el que ya se ve, no hay nada que reconstruir ni que reabrir.
                    guard code != currentLanguageCode else {
                        showingLanguagePicker = false
                        return
                    }
                    navigation.pendingSettingsReturn = .personalization
                    navigation.selectMainTab(.panel)
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
        .sheet(isPresented: $showingAIPersonalization) {
            AIPersonalizationSheet()
        }
        // UX 2.2 · L16-6: un aviso del sistema y no un diálogo anclado al interruptor, que no pintaba «Cancelar»
        // (`swiftui-ds.md`); y «Activar» sin rojo: activar no borra nada, solo oculta.
        .alert(L10n.Settings.expensesOnlyActivateTitle, isPresented: $showingExpensesOnlyActivate) {
            Button(L10n.Settings.expensesOnlyActivateConfirm) { setExpensesOnlyMode(true) }
                .accessibilityIdentifier("expenses_only_activate_confirm")
            Button(L10n.Settings.cancel, role: .cancel) {}
                .accessibilityIdentifier("expenses_only_cancel")
        } message: {
            Text(L10n.Settings.expensesOnlyActivateMessage)
        }
        .alert(L10n.Settings.expensesOnlyDeactivateTitle, isPresented: $showingExpensesOnlyDeactivate) {
            Button(L10n.Settings.expensesOnlyDeactivateConfirm) { setExpensesOnlyMode(false) }
                .accessibilityIdentifier("expenses_only_deactivate_confirm")
            Button(L10n.Settings.cancel, role: .cancel) {}
        } message: {
            Text(L10n.Settings.expensesOnlyDeactivateMessage)
        }
    }

    private func setExpensesOnlyMode(_ newValue: Bool) {
        // Este toggle es el punto de INTENCIÓN del usuario y la key es `synced: true`, así
        // que publica ÉL — mismo orden que `OnboardingView`, que ya lo hacía a mano.
        // El espejo (`SessionState.isExpensesOnlyMode.didSet`) escribe local + App Group +
        // recarga widgets, pero NO encola y no debe: a ese mismo `didSet` llegan también el
        // merge remoto (`PreferenceSyncService.applyMergeOutcome`) y el reset de
        // `-uitest-reset`, y publicar ahí devolvería el eco (en `.cloud`, con HLC fresco
        // sobre un valor recién bajado) y haría que un XCUITest encolara preferencias.
        // Hasta ahora llegaba a iCloud de rebote, porque `AppPreferences.loadFromDefaults`
        // re-persistía lo que releía; ese puente accidental se cerró.
        guard newValue != sessionState.isExpensesOnlyMode else { return }
        PreferenceSyncService.shared.set(
            bool: newValue, forKey: AppPreferences.Keys.expensesOnlyMode)
        sessionState.isExpensesOnlyMode = newValue
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
                    .font(DS.Typography.body.weight(isSelected ? .semibold : .regular))
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
            // Lo elegido, relleno (UX 2.2 · L16-9): antes solo un ✓ a la derecha.
            .selectedOptionFill(isSelected)
            .padding(.horizontal, DS.Spacing.xs)
            .padding(.vertical, DS.Spacing.xxs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])

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
                    .font(DS.Typography.body.weight(isSelected ? .semibold : .regular))
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
            // Lo elegido, relleno (UX 2.2 · L16-9): antes solo un ✓ a la derecha.
            .selectedOptionFill(isSelected)
            .padding(.horizontal, DS.Spacing.xs)
            .padding(.vertical, DS.Spacing.xxs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])

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
                        .font(DS.Typography.body.weight(isSelected ? .semibold : .regular))
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
            // Lo elegido, relleno (UX 2.2 · L16-9): antes solo un ✓ a la derecha.
            .selectedOptionFill(isSelected)
            .padding(.horizontal, DS.Spacing.xs)
            .padding(.vertical, DS.Spacing.xxs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])

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
                        .font(DS.Typography.body.weight(isSelected ? .semibold : .regular))
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
            // Lo elegido, relleno (UX 2.2 · L16-9): antes solo un ✓ a la derecha.
            .selectedOptionFill(isSelected)
            .padding(.horizontal, DS.Spacing.xs)
            .padding(.vertical, DS.Spacing.xxs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])

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
                        .font(DS.Typography.body.weight(isSelected ? .semibold : .regular))
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
                // Lo elegido, relleno (UX 2.2 · L16-9): antes solo un ✓ a la derecha.
                .selectedOptionFill(isSelected)
                .padding(.horizontal, DS.Spacing.xs)
                .padding(.vertical, DS.Spacing.xxs)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .accessibilityIdentifier("app_language_option_\(lang.code)")

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
                        .font(DS.Typography.body.weight(isSelected ? .semibold : .regular))
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
            // Lo elegido, relleno (UX 2.2 · L16-9): antes solo un ✓ a la derecha.
            .selectedOptionFill(isSelected)
            .padding(.horizontal, DS.Spacing.xs)
            .padding(.vertical, DS.Spacing.xxs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])

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
                    .font(DS.Typography.body.weight(isSelected ? .semibold : .regular))
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
            // Lo elegido, relleno (UX 2.2 · L16-9): antes solo un ✓ a la derecha.
            .selectedOptionFill(isSelected)
            .padding(.horizontal, DS.Spacing.xs)
            .padding(.vertical, DS.Spacing.xxs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])

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
            .environment(SceneNavigation())
            .previewAppPreferences()
    }
}
