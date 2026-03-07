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

    @ScaledMetric(relativeTo: .largeTitle) private var heroIconSize: CGFloat = 48 // A11Y-DT: @ScaledMetric

    @AppStorage("defaultPeriod") private var defaultPeriodRaw: String = DetailPeriod.allTime
        .rawValue
    @AppStorage("colorfulIcons") private var colorfulIcons: Bool = true
    @AppStorage("firstWeekday") private var firstWeekdayRaw: Int = 2  // Default to Monday
    @AppStorage("showWidgetHints") private var showWidgetHints: Bool = true
    @AppStorage("showVariations") private var showVariations: Bool = true
    @AppStorage("averageLineMode") private var averageLineMode: Int = 1
    @AppStorage("decimalPlaces") private var decimalPlaces: Int = 0
    @AppStorage("currencyDisplayFormat") private var currencyDisplayFormat: String = "code"  // "code" or "symbol"
    @AppStorage("autoFocusField") private var autoFocusField: String = "none"
    @AppStorage(InsightTone.storageKey) private var insightsToneRaw: String = InsightTone.normal.rawValue
    @AppStorage(InsightFocus.storageKey) private var insightsFocusRaw: String = InsightFocus.balanced.rawValue

    @State private var showingPeriodPicker = false
    @State private var showingTonePicker = false
    @State private var showingFocusPicker = false
    @State private var showingAutoFocusPicker = false
    @State private var showingDecimalsPicker = false
    @State private var showingCurrencyFormatPicker = false
    @State private var showingTabBarConfig = false
    @State private var showingAverageLinePicker = false
    @State private var showingWeekdayPicker = false
    @State private var showingLanguagePicker = false
    @State private var showingExpensesOnlyConfirmation = false
    @State private var showingSmartInsightsSettings = false

    private var selectedPeriod: DetailPeriod {
        DetailPeriod(rawValue: defaultPeriodRaw) ?? .thisMonth
    }

    private var selectedWeekday: FirstWeekday {
        FirstWeekday(rawValue: firstWeekdayRaw) ?? .monday
    }

    private var decimalPlacesDisplayName: String {
        switch decimalPlaces {
        case 0: return L10n.Settings.decimalsNone
        case 1: return L10n.Settings.decimalsOne
        default: return L10n.Settings.decimalsTwo
        }
    }

    private var averageLineDisplayName: String {
        switch averageLineMode {
        case 1: return L10n.Settings.averageLineTotal
        case 2: return L10n.Settings.averageLineSegmented
        default: return L10n.Settings.averageLineOff
        }
    }

    private var currencyFormatDisplayName: String {
        currencyDisplayFormat == "symbol" ? L10n.Settings.currencySymbol : L10n.Settings.currencyCode
    }

    private var autoFocusDisplayName: String {
        switch autoFocusField {
        case "amount": return L10n.Settings.autoFocusAmount
        case "description": return L10n.Settings.autoFocusNote
        default: return L10n.Settings.autoFocusNone
        }
    }

    private var currentLanguageDisplayName: String {
        guard let code = LanguageManager.overrideLanguage else { return "" }
        return LanguageManager.supportedLanguages.first { $0.code == code }?.nativeName ?? code
    }

    private var selectedTone: InsightTone {
        InsightTone(rawValue: insightsToneRaw) ?? .normal
    }

    private var selectedFocus: InsightFocus {
        InsightFocus(rawValue: insightsFocusRaw) ?? .balanced
    }

    var body: some View {
        ZStack {
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

                        // Colorful Icons Toggle
                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            HStack {
                                Text(L10n.Settings.colorfulIcons)
                                    .font(DS.Typography.body)
                                    .foregroundStyle(.thPrimaryText)

                                Spacer()

                                Toggle(L10n.Settings.colorfulIcons, isOn: $colorfulIcons)
                                    .labelsHidden()
                                    .onChange(of: colorfulIcons) { _, newValue in
                                        PreferenceSyncService.shared.set(bool: newValue, forKey: "colorfulIcons")
                                    }

                            }
                            .padding(.horizontal, DS.FormRow.paddingH)
                            .padding(.vertical, DS.Spacing.sm)
                            .background(.thCard)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Radius.lg)
                                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                            )

                            Text(L10n.Settings.colorfulIconsDescription)
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

                                    Text(selectedPeriod.displayName)
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

                                Toggle(L10n.Settings.widgetHints, isOn: $showWidgetHints)
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

                                Toggle(L10n.Settings.showVariations, isOn: $showVariations)
                                    .labelsHidden()
                                    .onChange(of: showVariations) { _, newValue in
                                        PreferenceSyncService.shared.set(bool: newValue, forKey: "showVariations")
                                    }

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

                    // MARK: - Smart Insights Section
                    VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                        YalaSectionHeader(L10n.Insights.title)

                        VStack(spacing: 0) {
                            // Tone selector
                            Button {
                                showingTonePicker = true
                            } label: {
                                HStack {
                                    Text(L10n.Insights.toneLabel)
                                        .font(DS.Typography.body)
                                        .foregroundStyle(.thPrimaryText)

                                    Spacer()

                                    Text(selectedTone.displayName)
                                        .font(DS.Typography.body)
                                        .foregroundStyle(.secondary)

                                    Image(systemName: "chevron.right")
                                        .font(DS.Typography.labelSmall.weight(.medium))
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.horizontal, DS.FormRow.paddingH)
                                .padding(.vertical, DS.FormRow.paddingV)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            Divider().padding(.leading, DS.FormRow.paddingH)

                            // Focus selector
                            Button {
                                showingFocusPicker = true
                            } label: {
                                HStack {
                                    Text(L10n.Insights.focusLabel)
                                        .font(DS.Typography.body)
                                        .foregroundStyle(.thPrimaryText)

                                    Spacer()

                                    Text(selectedFocus.displayName)
                                        .font(DS.Typography.body)
                                        .foregroundStyle(.secondary)

                                    Image(systemName: "chevron.right")
                                        .font(DS.Typography.labelSmall.weight(.medium))
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.horizontal, DS.FormRow.paddingH)
                                .padding(.vertical, DS.FormRow.paddingV)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            Divider().padding(.leading, DS.FormRow.paddingH)

                            // Smart Insights settings
                            Button {
                                showingSmartInsightsSettings = true
                            } label: {
                                HStack {
                                    Image(systemName: "sparkles")
                                        .font(DS.Typography.body)
                                        .foregroundStyle(.thAccent)
                                        .frame(width: 28)

                                    Text(L10n.Insights.title)
                                        .font(DS.Typography.body)
                                        .foregroundStyle(.thPrimaryText)

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(DS.Typography.labelSmall.weight(.medium))
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.horizontal, DS.FormRow.paddingH)
                                .padding(.vertical, DS.FormRow.paddingV)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        .background(.thCard)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.lg)
                                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                        )
                    }
                    .sheet(isPresented: $showingTonePicker) {
                        insightsToneSheet
                    }
                    .sheet(isPresented: $showingFocusPicker) {
                        insightsFocusSheet
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

                                    Text(autoFocusDisplayName)
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
                selectedPeriod: selectedPeriod,
                onSelect: { period in
                    defaultPeriodRaw = period.rawValue
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
                    firstWeekdayRaw = weekday.rawValue
                    PreferenceSyncService.shared.set(int: weekday.rawValue, forKey: "firstWeekday")
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
            .presentationDetents([.height(280)])
        }
        .sheet(isPresented: $showingDecimalsPicker) {
            DecimalsPickerSheet(
                selectedDecimals: decimalPlaces,
                onSelect: { decimals in
                    decimalPlaces = decimals
                    PreferenceSyncService.shared.set(int: decimals, forKey: "decimalPlaces")
                    // Trigger UI refresh for all views showing formatted amounts
                    sessionState.formattingVersion += 1
                    showingDecimalsPicker = false
                }
            )
            .presentationDetents([.height(320)])
        }
        .sheet(isPresented: $showingCurrencyFormatPicker) {
            CurrencyFormatPickerSheet(
                selectedFormat: currencyDisplayFormat,
                onSelect: { format in
                    currencyDisplayFormat = format
                    PreferenceSyncService.shared.set(string: format, forKey: "currencyDisplayFormat")
                    // Trigger UI refresh for all views showing formatted amounts
                    sessionState.formattingVersion += 1
                    showingCurrencyFormatPicker = false
                }
            )
            .presentationDetents([.height(280)])
        }
        .sheet(isPresented: $showingAutoFocusPicker) {
            AutoFocusPickerSheet(
                selectedField: autoFocusField,
                onSelect: { field in
                    autoFocusField = field
                    PreferenceSyncService.shared.set(string: field, forKey: "autoFocusField")
                    showingAutoFocusPicker = false
                }
            )
            .presentationDetents([.height(320)])
        }
        .sheet(isPresented: $showingAverageLinePicker) {
            AverageLinePickerSheet(
                selectedMode: averageLineMode,
                onSelect: { mode in
                    averageLineMode = mode
                    PreferenceSyncService.shared.set(int: mode, forKey: "averageLineMode")
                    showingAverageLinePicker = false
                }
            )
            .presentationDetents([.height(320)])
        }
        .sheet(isPresented: $showingLanguagePicker) {
            LanguagePickerSheet(
                selectedLanguage: LanguageManager.overrideLanguage ?? "en",
                onSelect: { code in
                    LanguageManager.overrideLanguage = code
                    showingLanguagePicker = false
                }
            )
            .presentationDetents([.medium])
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

    // MARK: - Insight Preference Picker Sheets

    private var insightsToneSheet: some View {
        insightPickerSheet(
            title: L10n.Insights.toneLabel,
            items: InsightTone.allCases,
            selected: selectedTone,
            label: \.displayName,
            detail: \.previewText,
            onSelect: { tone in
                insightsToneRaw = tone.rawValue
                PreferenceSyncService.shared.set(string: tone.rawValue, forKey: InsightTone.storageKey)
            },
            onDismiss: { showingTonePicker = false }
        )
    }

    private var insightsFocusSheet: some View {
        insightPickerSheet(
            title: L10n.Insights.focusLabel,
            items: InsightFocus.allCases,
            selected: selectedFocus,
            label: \.displayName,
            detail: \.descriptionText,
            onSelect: { focus in
                insightsFocusRaw = focus.rawValue
                PreferenceSyncService.shared.set(string: focus.rawValue, forKey: InsightFocus.storageKey)
            },
            onDismiss: { showingFocusPicker = false }
        )
    }

    private func insightPickerSheet<T: CaseIterable & Identifiable & Equatable>(
        title: String,
        items: [T],
        selected: T,
        label: KeyPath<T, String>,
        detail: KeyPath<T, String>,
        onSelect: @escaping (T) -> Void,
        onDismiss: @escaping () -> Void
    ) -> some View {
        NavigationStack {
            List {
                ForEach(items) { item in
                    Button {
                        onSelect(item)
                        InsightsLLMService.shared.invalidateCache()
                        onDismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                                Text(item[keyPath: label])
                                    .font(DS.Typography.body)
                                    .foregroundStyle(.primary)
                                Text(item[keyPath: detail])
                                    .font(DS.Typography.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if item == selected {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.thAccent)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Settings.cancel) { onDismiss() }
                }
            }
        }
        .presentationDetents([.medium])
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
                        ForEach(LanguageManager.supportedLanguages, id: \.code) { lang in
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

    private func languageRow(lang: (code: String, nativeName: String, flag: String)) -> some View {
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
    let selectedField: String
    let onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    private let options: [(value: String, label: String)] = [
        ("none", L10n.Settings.autoFocusNone),
        ("amount", L10n.Settings.autoFocusAmount),
        ("description", L10n.Settings.autoFocusNote),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

                ScrollView {
                    VStack(spacing: DS.Spacing.none) {
                        ForEach(options, id: \.value) { option in
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
    private func autoFocusRow(for option: (value: String, label: String)) -> some View {
        let isSelected = selectedField == option.value

        Button {
            onSelect(option.value)
        } label: {
            HStack {
                Text(option.label)
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

        if option.value != "description" {
            Divider()
                .padding(.leading, DS.Spacing.lg)
        }
    }
}

#Preview {
    NavigationStack {
        PersonalizationSettingsView()
            .environment(SessionState())
    }
}
