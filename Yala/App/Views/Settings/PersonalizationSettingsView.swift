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
    @State private var showingTabBarConfig = false
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
        return ZStack {
            PanelBackgroundView()

            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    // Header
                    VStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: heroIconSize))
                            .foregroundStyle(.thAccent)
                            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                            .padding(.bottom, DS.Spacing.sm)

                        Text(L10n.Settings.personalization)
                            .font(.title2.bold())
                            .foregroundStyle(.thPrimaryText)

                        Text(L10n.Settings.personalizationDescription)
                            .font(DS.Typography.body)
                            .foregroundStyle(.thSecondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, DS.Spacing.xxxl)

                    // MARK: - Modo de uso Section
                    VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                        YalaSectionHeader(L10n.Settings.sectionUsageMode)

                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            HStack {
                                Text(L10n.Settings.expensesOnlyMode)
                                    .font(DS.Typography.body)
                                    .foregroundStyle(.thPrimaryText)

                                Spacer()

                                Toggle(L10n.Settings.expensesOnlyMode, isOn: Binding(
                                    get: { sessionState.isExpensesOnlyMode },
                                    set: { _ in showingExpensesOnlyConfirmation = true }
                                ))
                                .labelsHidden()

                            }
                            .padding(.horizontal, DS.FormRow.paddingH)
                            .padding(.vertical, DS.Spacing.sm)
                            .background(.thCard)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Radius.lg)
                                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                            )

                            Text(L10n.Settings.expensesOnlyModeDescription)
                                .font(DS.Typography.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, DS.Spacing.xxs)
                        }
                    }

                    // MARK: - Grupos Section (A0-Bridge)
                    VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                        YalaSectionHeader(L10n.Settings.sectionGroups)

                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            @Bindable var prefs = appPreferences
                            Toggle(isOn: $prefs.includeGroupsInPanelTotal) {
                                Text(L10n.Settings.includeGroupsInPanelTotal)
                                    .font(DS.Typography.body)
                                    .foregroundStyle(.thPrimaryText)
                            }
                            .padding(.horizontal, DS.FormRow.paddingH)
                            .padding(.vertical, DS.Spacing.sm)
                            .background(.thCard)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Radius.lg)
                                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                            )

                            Toggle(isOn: $prefs.includeGroupTransactionsInStats) {
                                Text(L10n.Settings.includeGroupTransactionsInStats)
                                    .font(DS.Typography.body)
                                    .foregroundStyle(.thPrimaryText)
                            }
                            .padding(.horizontal, DS.FormRow.paddingH)
                            .padding(.vertical, DS.Spacing.sm)
                            .background(.thCard)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Radius.lg)
                                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                            )

                            Text(L10n.Settings.sectionGroupsHint)
                                .font(DS.Typography.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, DS.Spacing.xxs)
                        }
                    }

                    // MARK: - Interfaz Section
                    VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                        YalaSectionHeader(L10n.Settings.sectionInterface)

                        // App Language (only visible if override is active)
                        if LanguageManager.overrideLanguage != nil {
                            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                                Button {
                                    showingLanguagePicker = true
                                } label: {
                                    HStack {
                                        Text(L10n.Settings.appLanguage)
                                            .font(DS.Typography.body)
                                            .foregroundStyle(.thPrimaryText)

                                        Spacer()

                                        Text(currentLanguageDisplayName)
                                            .font(DS.Typography.body)
                                            .foregroundStyle(.secondary)

                                        Image(systemName: "chevron.right")
                                            .font(DS.Typography.labelSmall.weight(.medium))
                                            .foregroundStyle(.tertiary)
                                    }
                                    .padding(.horizontal, DS.FormRow.paddingH)
                                    .padding(.vertical, DS.FormRow.paddingV)
                                    .background(.thCard)
                                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DS.Radius.lg)
                                            .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)

                                Text(L10n.Settings.appLanguageRestart)
                                    .font(DS.Typography.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, DS.Spacing.xxs)
                            }
                        }

                        // Tab Bar Configuration
                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            Button {
                                showingTabBarConfig = true
                            } label: {
                                HStack {
                                    Text(L10n.Settings.tabBarConfig)
                                        .font(DS.Typography.body)
                                        .foregroundStyle(.thPrimaryText)

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(DS.Typography.labelSmall.weight(.medium))
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.horizontal, DS.FormRow.paddingH)
                                .padding(.vertical, DS.FormRow.paddingV)
                                .background(.thCard)
                                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                                .overlay(
                                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                                        .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)

                            Text(L10n.Settings.tabBarConfigInfo)
                                .font(DS.Typography.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, DS.Spacing.xxs)
                        }

                        // Voice Language
                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
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
                                }
                            } label: {
                                HStack {
                                    Text(L10n.Settings.voiceLanguage)
                                        .font(DS.Typography.body)
                                        .foregroundStyle(.thPrimaryText)

                                    Spacer()

                                    Text(appPreferences.voiceLanguage.displayName)
                                        .font(DS.Typography.body)
                                        .foregroundStyle(.secondary)

                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(DS.Typography.labelSmall.weight(.medium))
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.horizontal, DS.FormRow.paddingH)
                                .padding(.vertical, DS.FormRow.paddingV)
                                .background(.thCard)
                                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                                .overlay(
                                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                                        .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        // Customize AI Summary
                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            Button {
                                showingSmartInsightsSettings = true
                            } label: {
                                HStack {
                                    Text(L10n.Settings.customizeAISummary)
                                        .font(DS.Typography.body)
                                        .foregroundStyle(.thPrimaryText)

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(DS.Typography.labelSmall.weight(.medium))
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.horizontal, DS.FormRow.paddingH)
                                .padding(.vertical, DS.FormRow.paddingV)
                                .background(.thCard)
                                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                                .overlay(
                                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                                        .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)

                            Text(L10n.Settings.customizeAISummaryHint)
                                .font(DS.Typography.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, DS.Spacing.xxs)
                        }

                        // Chat FAB visibility (Free users only — Pro users manage it via per-section Panel preferences)
                        if !isProUser {
                            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                                HStack {
                                    Text(L10n.Widget.chatFabToggle)
                                        .font(DS.Typography.body)
                                        .foregroundStyle(.thPrimaryText)

                                    ProBadge(size: .small)

                                    Spacer()

                                    Toggle(L10n.Widget.chatFabToggle, isOn: $prefs.chatFABVisible)
                                        .labelsHidden()
                                }
                                .padding(.horizontal, DS.FormRow.paddingH)
                                .padding(.vertical, DS.FormRow.paddingV)
                                .background(.thCard)
                                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                                .overlay(
                                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                                        .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                                )

                                Text(L10n.Widget.chatFabHint)
                                    .font(DS.Typography.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, DS.Spacing.xxs)
                            }
                        }

                        // Colorful Icons Toggle
                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            HStack {
                                Text(L10n.Settings.colorfulIcons)
                                    .font(DS.Typography.body)
                                    .foregroundStyle(forcesMonochromeIcons ? .thSecondaryText : .thPrimaryText)

                                Spacer()

                                Toggle(L10n.Settings.colorfulIcons, isOn: $prefs.colorfulIcons)
                                    .labelsHidden()
                                    .disabled(forcesMonochromeIcons)
                                    .accessibilityHint(forcesMonochromeIcons ? L10n.Accessibility.systemMonochromeIcons : "")

                            }
                            .padding(.horizontal, DS.FormRow.paddingH)
                            .padding(.vertical, DS.Spacing.sm)
                            .background(.thCard)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Radius.lg)
                                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                            )

                            Text(forcesMonochromeIcons
                                ? L10n.Settings.colorfulIconsDisabledByTheme
                                : L10n.Settings.colorfulIconsDescription)
                                .font(DS.Typography.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, DS.Spacing.xxs)
                        }
                    }

                    // MARK: - Calendario Section
                    VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                        YalaSectionHeader(L10n.Settings.sectionCalendar)

                        // Default Period
                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            Button {
                                showingPeriodPicker = true
                            } label: {
                                HStack {
                                    Text(L10n.Settings.defaultPeriod)
                                        .font(DS.Typography.body)
                                        .foregroundStyle(.thPrimaryText)

                                    Spacer()

                                    Text(appPreferences.defaultPeriod.displayName)
                                        .font(DS.Typography.body)
                                        .foregroundStyle(.secondary)

                                    Image(systemName: "chevron.right")
                                        .font(DS.Typography.labelSmall.weight(.medium))
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.horizontal, DS.FormRow.paddingH)
                                .padding(.vertical, DS.FormRow.paddingV)
                                .background(.thCard)
                                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                                .overlay(
                                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                                        .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)

                            Text(L10n.Settings.defaultPeriodDescription)
                                .font(DS.Typography.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, DS.Spacing.xxs)
                        }

                        // First Weekday
                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            Button {
                                showingWeekdayPicker = true
                            } label: {
                                HStack {
                                    Text(L10n.Settings.firstWeekday)
                                        .font(DS.Typography.body)
                                        .foregroundStyle(.thPrimaryText)

                                    Spacer()

                                    Text(selectedWeekday.displayName)
                                        .font(DS.Typography.body)
                                        .foregroundStyle(.secondary)

                                    Image(systemName: "chevron.right")
                                        .font(DS.Typography.labelSmall.weight(.medium))
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.horizontal, DS.FormRow.paddingH)
                                .padding(.vertical, DS.FormRow.paddingV)
                                .background(.thCard)
                                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                                .overlay(
                                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                                        .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)

                            Text(L10n.Settings.firstWeekdayDescription)
                                .font(DS.Typography.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, DS.Spacing.xxs)
                        }
                    }

                    // MARK: - Indicadores Section
                    VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                        YalaSectionHeader(L10n.Settings.sectionIndicators)

                        // Widget Hints Toggle
                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            HStack {
                                Text(L10n.Settings.widgetHints)
                                    .font(DS.Typography.body)
                                    .foregroundStyle(.thPrimaryText)

                                Spacer()

                                Toggle(L10n.Settings.widgetHints, isOn: $prefs.showWidgetHints)
                                    .labelsHidden()

                            }
                            .padding(.horizontal, DS.FormRow.paddingH)
                            .padding(.vertical, DS.Spacing.sm)
                            .background(.thCard)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Radius.lg)
                                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                            )

                            Text(L10n.Settings.widgetHintsDescription)
                                .font(DS.Typography.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, DS.Spacing.xxs)
                        }

                        // Show Variations Toggle
                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            HStack {
                                Text(L10n.Settings.showVariations)
                                    .font(DS.Typography.body)
                                    .foregroundStyle(.thPrimaryText)

                                Spacer()

                                Toggle(L10n.Settings.showVariations, isOn: $prefs.showVariations)
                                    .labelsHidden()

                            }
                            .padding(.horizontal, DS.FormRow.paddingH)
                            .padding(.vertical, DS.Spacing.sm)
                            .background(.thCard)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Radius.lg)
                                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                            )

                            Text(L10n.Settings.showVariationsDescription)
                                .font(DS.Typography.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, DS.Spacing.xxs)
                        }

                        // Average Line Picker
                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            Button {
                                showingAverageLinePicker = true
                            } label: {
                                HStack {
                                    Text(L10n.Settings.averageLine)
                                        .font(DS.Typography.body)
                                        .foregroundStyle(.thPrimaryText)

                                    Spacer()

                                    Text(averageLineDisplayName)
                                        .font(DS.Typography.body)
                                        .foregroundStyle(.secondary)

                                    Image(systemName: "chevron.right")
                                        .font(DS.Typography.labelSmall.weight(.medium))
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.horizontal, DS.FormRow.paddingH)
                                .padding(.vertical, DS.FormRow.paddingV)
                                .background(.thCard)
                                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                                .overlay(
                                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                                        .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)

                            Text(L10n.Settings.averageLineDescription)
                                .font(DS.Typography.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, DS.Spacing.xxs)
                        }
                    }

                    // MARK: - Formato Section
                    VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                        YalaSectionHeader(L10n.Settings.sectionFormat)

                        // Decimal Places
                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            Button {
                                showingDecimalsPicker = true
                            } label: {
                                HStack {
                                    Text(L10n.Settings.decimalPlaces)
                                        .font(DS.Typography.body)
                                        .foregroundStyle(.thPrimaryText)

                                    Spacer()

                                    Text(decimalPlacesDisplayName)
                                        .font(DS.Typography.body)
                                        .foregroundStyle(.secondary)

                                    Image(systemName: "chevron.right")
                                        .font(DS.Typography.labelSmall.weight(.medium))
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.horizontal, DS.FormRow.paddingH)
                                .padding(.vertical, DS.FormRow.paddingV)
                                .background(.thCard)
                                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                                .overlay(
                                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                                        .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)

                            Text(L10n.Settings.decimalPlacesDescription)
                                .font(DS.Typography.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, DS.Spacing.xxs)
                        }

                        // Currency Display Format
                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            Button {
                                showingCurrencyFormatPicker = true
                            } label: {
                                HStack {
                                    Text(L10n.Settings.currencyFormat)
                                        .font(DS.Typography.body)
                                        .foregroundStyle(.thPrimaryText)

                                    Spacer()

                                    Text(currencyFormatDisplayName)
                                        .font(DS.Typography.body)
                                        .foregroundStyle(.secondary)

                                    Image(systemName: "chevron.right")
                                        .font(DS.Typography.labelSmall.weight(.medium))
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.horizontal, DS.FormRow.paddingH)
                                .padding(.vertical, DS.FormRow.paddingV)
                                .background(.thCard)
                                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                                .overlay(
                                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                                        .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)

                            Text(L10n.Settings.currencyFormatDescription)
                                .font(DS.Typography.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, DS.Spacing.xxs)
                        }

                        // Auto-Focus Field
                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            Button {
                                showingAutoFocusPicker = true
                            } label: {
                                HStack {
                                    Text(L10n.Settings.autoFocusField)
                                        .font(DS.Typography.body)
                                        .foregroundStyle(.thPrimaryText)

                                    Spacer()

                                    Text(appPreferences.autoFocusField.displayName)
                                        .font(DS.Typography.body)
                                        .foregroundStyle(.secondary)

                                    Image(systemName: "chevron.right")
                                        .font(DS.Typography.labelSmall.weight(.medium))
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.horizontal, DS.FormRow.paddingH)
                                .padding(.vertical, DS.FormRow.paddingV)
                                .background(.thCard)
                                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                                .overlay(
                                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                                        .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)

                            Text(L10n.Settings.autoFocusFieldDescription)
                                .font(DS.Typography.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, DS.Spacing.xxs)
                        }
                    }

                    Spacer()
                }
                .padding(DS.Spacing.lg)
            }
        }
        .navigationTitle(L10n.Settings.personalization)
        .navigationBarTitleDisplayMode(.inline)
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
        .sheet(isPresented: $showingTabBarConfig) {
            TabBarConfigView()
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
            .presentationDetents(DS.Adaptive.sheetDetents([.height(280)]))
        }
        .sheet(isPresented: $showingDecimalsPicker) {
            DecimalsPickerSheet(
                selectedDecimals: decimalPlaces,
                onSelect: { decimals in
                    appPreferences.decimalPlaces = decimals
                    showingDecimalsPicker = false
                }
            )
            .presentationDetents(DS.Adaptive.sheetDetents([.height(320)]))
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
            .presentationDetents(DS.Adaptive.sheetDetents([.height(280)]))
        }
        .sheet(isPresented: $showingAutoFocusPicker) {
            AutoFocusPickerSheet(
                selectedField: appPreferences.autoFocusField,
                onSelect: { field in
                    appPreferences.autoFocusField = field
                    showingAutoFocusPicker = false
                }
            )
            .presentationDetents(DS.Adaptive.sheetDetents([.height(320)]))
        }
        .sheet(isPresented: $showingAverageLinePicker) {
            AverageLinePickerSheet(
                selectedMode: appPreferences.averageLineMode,
                onSelect: { mode in
                    appPreferences.averageLineMode = mode
                    showingAverageLinePicker = false
                }
            )
            .presentationDetents(DS.Adaptive.sheetDetents([.height(320)]))
        }
        .sheet(isPresented: $showingLanguagePicker) {
            LanguagePickerSheet(
                selectedLanguage: LanguageManager.overrideLanguage ?? "en",
                onSelect: { code in
                    LanguageManager.overrideLanguage = code
                    showingLanguagePicker = false
                }
            )
            .presentationDetents(DS.Adaptive.sheetDetents([.medium]))
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
                sessionState.isExpensesOnlyMode.toggle()
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
            ZStack {
                PanelBackgroundView()

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
            }
            .navigationTitle(L10n.Settings.defaultPeriod)
            .navigationBarTitleDisplayMode(.inline)
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
            ZStack {
                PanelBackgroundView()

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
            }
            .navigationTitle(L10n.Settings.firstWeekday)
            .navigationBarTitleDisplayMode(.inline)
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
            ZStack {
                PanelBackgroundView()

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
            }
            .navigationTitle(L10n.Settings.decimalPlaces)
            .navigationBarTitleDisplayMode(.inline)
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
            ZStack {
                PanelBackgroundView()

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
            }
            .navigationTitle(L10n.Settings.currencyFormat)
            .navigationBarTitleDisplayMode(.inline)
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
            ZStack {
                PanelBackgroundView()

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
            }
            .navigationTitle(L10n.Settings.appLanguage)
            .navigationBarTitleDisplayMode(.inline)
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
            ZStack {
                PanelBackgroundView()

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
            }
            .navigationTitle(L10n.Settings.averageLine)
            .navigationBarTitleDisplayMode(.inline)
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
            ZStack {
                PanelBackgroundView()

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
            }
            .navigationTitle(L10n.Settings.autoFocusField)
            .navigationBarTitleDisplayMode(.inline)
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
