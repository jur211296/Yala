//
//  CurrencySettingsView.swift
//  Yala
//
//  Settings view for preferred currency and exchange rates.
//

import SwiftData
import SwiftUI

struct CurrencySettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(CurrencyConverter.self) private var currencyConverter
    @Environment(ExchangeRateService.self) private var exchangeRateService
    @Environment(AppPreferences.self) private var appPreferences

    @ScaledMetric(relativeTo: .largeTitle) private var heroIconSize: CGFloat = 48 // A11Y-DT: @ScaledMetric

    // MARK: - Computed Properties

    private var preferredCurrency: CurrencyCode {
        appPreferences.defaultCurrencyCode
    }

    /// Parsed secondary currencies from AppPreferences
    private var secondaryCurrencies: Set<CurrencyCode> {
        Set(appPreferences.secondaryCurrencies.compactMap { CurrencyCode(rawValue: $0) })
    }

    // MARK: - State

    @State private var isUpdating: Bool = false
    @State private var updateProgress: Double = 0.0

    // Sheet states
    @State private var showPreferredCurrencySheet = false
    @State private var showSecondaryCurrenciesSheet = false
    @State private var showExchangeRatesSheet = false

    // Temporary binding values for sheets
    @State private var tempPreferredCurrency: CurrencyCode = .pen
    @State private var tempSecondaryCurrencies: Set<CurrencyCode> = []

    var body: some View {
        ZStack {
            // Main Content
            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {

                    // Header
                    VStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: heroIconSize))
                            .foregroundStyle(.thAccent)
                            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                            .padding(.bottom, DS.Spacing.sm)

                        Text(L10n.Settings.currencyAndExchange)
                            .font(DS.Typography.title2)
                            .foregroundStyle(.thPrimaryText)

                        Text(L10n.Settings.currencyDescription)
                            .font(Typography.body)
                            .foregroundStyle(.thSecondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, DS.Spacing.xxxl)

                    VStack(spacing: DS.Spacing.xxl) {
                        preferredCurrencySection
                        secondaryCurrenciesSection
                        exchangeRatesSection
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xxl)
            }
            .blur(radius: isUpdating ? 3 : 0)
            .disabled(isUpdating)
            .accessibilityHint(isUpdating ? L10n.Accessibility.updatingExchangeRates : "")

            // Progress Overlay
            if isUpdating {
                Color.black.opacity(DS.Opacity.overlay)
                    .ignoresSafeArea()

                VStack(spacing: DS.Spacing.lg) {
                    ProgressView(value: updateProgress, total: 1.0)
                        .progressViewStyle(.linear)
                        .frame(width: 200)

                    Text(L10n.Common.updatingRecords)
                        .font(DS.Typography.headline)
                        .foregroundStyle(.primary)

                    Text(L10n.Common.recalculatingConversions)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(DS.Spacing.xxl)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
            }
        }
        .yalaScreenBackground(.subtle)
        .navigationTitle(L10n.Settings.currencyAndExchange)
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(isUpdating)
        .sheet(isPresented: $showPreferredCurrencySheet) {
            CurrencyPickerSheet(selectedCurrency: $tempPreferredCurrency)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showSecondaryCurrenciesSheet) {
            SecondaryCurrencyPickerSheet(
                selectedCurrencies: $tempSecondaryCurrencies,
                preferredCurrency: preferredCurrency
            )
            .presentationDetents([.large])
        }
        .sheet(isPresented: $showExchangeRatesSheet) {
            ExchangeRatesSheet(preferredCurrency: preferredCurrency)
                .presentationDetents([.large])
        }
        .onChange(of: tempPreferredCurrency) { _, newValue in
            if newValue != preferredCurrency {
                updatePreferredCurrency(to: newValue)
            }
        }
        .onChange(of: tempSecondaryCurrencies) { oldValue, newValue in
            handleSecondaryChange(from: oldValue, to: newValue)
        }
    }

    // MARK: - Preferred Currency Section

    private var preferredCurrencySection: some View {
        SectionBox(title: L10n.Settings.preferredCurrency) {
            Button {
                tempPreferredCurrency = preferredCurrency
                showPreferredCurrencySheet = true
            } label: {
                let info = currencyInfo(for: preferredCurrency)
                HStack(spacing: DS.Spacing.md) {
                    Text(info.flag)
                        .font(DS.Typography.title)

                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        Text(info.name.capitalized)
                            .font(DS.Typography.body)
                            .foregroundStyle(.primary)
                        Text(info.code)
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, DS.FormRow.paddingH)
                .padding(.vertical, DS.FormRow.paddingV)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Secondary Currencies Section

    private var secondaryCurrenciesSection: some View {
        VStack(spacing: DS.Spacing.sm) {
            SectionBox(title: L10n.Settings.secondaryCurrencies) {
                Button {
                    tempSecondaryCurrencies = secondaryCurrencies
                    showSecondaryCurrenciesSheet = true
                } label: {
                    HStack(spacing: DS.Spacing.md) {
                        // Show selected currencies or "None"
                        if secondaryCurrencies.isEmpty {
                            Text(L10n.Common.none)
                                .font(DS.Typography.body)
                                .foregroundStyle(.secondary)
                        } else {
                            let sorted = secondaryCurrencies.sorted {
                                $0.localizedName < $1.localizedName
                            }
                            HStack(spacing: DS.Spacing.sm) {
                                ForEach(sorted, id: \.self) { currency in
                                    let info = currencyInfo(for: currency)
                                    HStack(spacing: DS.Spacing.xxs) {
                                        Text(info.flag)
                                            .font(DS.Typography.title)
                                        Text(info.code)
                                            .font(DS.Typography.body)
                                            .foregroundStyle(.primary)
                                    }
                                }
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, DS.FormRow.paddingH)
                    .padding(.vertical, DS.FormRow.paddingV)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("currency_secondary_button")
            }

            // Hint text
            Text(L10n.Settings.secondaryCurrenciesHint)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    // MARK: - Exchange Rates Section

    private var exchangeRatesSection: some View {
        VStack(spacing: DS.Spacing.sm) {
            SectionBox(title: L10n.Settings.exchangeRate) {
                VStack(spacing: DS.Spacing.none) {
                    // Show secondary currencies inline (or first 2 if none selected)
                    let displayCurrencies: [CurrencyCode] = {
                        if secondaryCurrencies.isEmpty {
                            return Array(
                                CurrencyCode.allCases.filter { $0 != preferredCurrency }.prefix(2))
                        }
                        return secondaryCurrencies.sorted { $0.localizedName < $1.localizedName }
                    }()

                    ForEach(Array(displayCurrencies.enumerated()), id: \.element) {
                        index, currency in
                        if index > 0 {
                            SubsectionDivider()
                        }
                        exchangeRateRow(currency: currency)
                    }

                    SubsectionDivider()

                    // "See all" button
                    Button {
                        showExchangeRatesSheet = true
                    } label: {
                        HStack {
                            Text(L10n.Common.seeAll)
                                .font(DS.Typography.body)
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(DS.Typography.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, DS.FormRow.paddingH)
                        .padding(.vertical, DS.FormRow.paddingV)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            // Last updated disclaimer
            if let latestRate = exchangeRateService.getLatestRate(context: modelContext) {
                let rateDate: Date? =
                    latestRate.timestamp
                    ?? Self.dateKeyFormatter.date(from: latestRate.dateKey)

                if let date = rateDate {
                    Text("\(L10n.Common.lastUpdate) \(formatLastUpdated(date))")
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
    }

    @ViewBuilder
    private func exchangeRateRow(currency: CurrencyCode) -> some View {
        let info = currencyInfo(for: currency)
        let rate = getDisplayRate(from: currency, to: preferredCurrency)
        let preferredInfo = currencyInfo(for: preferredCurrency)

        HStack(spacing: DS.Spacing.md) {
            Text(info.flag)
                .font(DS.Typography.title)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text("1 \(info.code)")
                    .font(DS.Typography.bodyBold)
                    .foregroundStyle(.primary)
                Text(info.name.capitalized)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let rate = rate {
                Text(String(format: "%.4f %@", rate, preferredInfo.code))
                    .font(DS.Typography.body.monospacedDigit())
                    .foregroundStyle(.primary)
            } else {
                Text("--")
                    .font(DS.Typography.body)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.FormRow.paddingV)
        .contentShape(Rectangle())
    }

    // MARK: - Static Formatters

    private static let dateKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    private static let lastUpdatedFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateStyle = .long
        f.timeStyle = .short
        return f
    }()

    // MARK: - Helpers

    private func formatLastUpdated(_ date: Date) -> String {
        Self.lastUpdatedFormatter.string(from: date)
    }

    private func getDisplayRate(from: CurrencyCode, to: CurrencyCode) -> Double? {
        currencyConverter.getDisplayRate(
            from: from.rawValue, to: to.rawValue, context: modelContext)
    }

    // MARK: - Update Actions

    private func handleSecondaryChange(from oldValue: Set<CurrencyCode>, to newValue: Set<CurrencyCode>) {
        // Find newly added currencies
        let added = newValue.subtracting(oldValue)
        let removed = oldValue.subtracting(newValue)

        // Save to storage
        appPreferences.secondaryCurrencies = newValue.map { $0.rawValue }

        // Signal widget refresh if anything changed
        if !added.isEmpty || !removed.isEmpty {
            SessionState.shared.needsExchangeRateWidgetRefresh = true
        }

        // Load historical data for newly added currencies
        for currency in added {
            loadHistoricalRatesForCurrency(currency)
        }
    }

    private func loadHistoricalRatesForCurrency(_ currency: CurrencyCode) {
        isUpdating = true
        updateProgress = 0.0

        Task {
            // 1. First, force update TODAY's rate with ALL currencies
            await exchangeRateService.forceUpdateToday(context: modelContext)

            // 2. Calculate 1 year date range for historical data
            let calendar = Calendar.current
            let today = Date.now
            guard let oneYearAgo = calendar.date(byAdding: .year, value: -1, to: today) else {
                isUpdating = false
                return
            }

            let dateInterval = DateInterval(start: oneYearAgo, end: today)

            // 3. FORCE refresh historical rates
            await exchangeRateService.forceRefreshRates(for: dateInterval, context: modelContext)

            // Signal widget to refresh
            SessionState.shared.needsExchangeRateWidgetRefresh = true

            isUpdating = false
        }
    }

    private func updatePreferredCurrency(to newCurrency: CurrencyCode) {
        guard newCurrency != preferredCurrency else { return }

        // Auto-remove from secondary currencies if it was selected there
        if secondaryCurrencies.contains(newCurrency) {
            var updated = secondaryCurrencies
            updated.remove(newCurrency)
            appPreferences.secondaryCurrencies = updated.map { $0.rawValue }
        }

        isUpdating = true
        updateProgress = 0.0

        Task {
            do {
                // Run the batch update for transactions
                try await CurrencyChangeService.shared.updateAllTransactions(
                    to: newCurrency.rawValue,
                    context: modelContext,
                    onProgress: { progress in
                        updateProgress = progress * 0.5  // First half of progress
                    }
                )

                // Only update AppPreferences AFTER successful migration
                appPreferences.defaultCurrencyCode = newCurrency

                // Force refresh exchange rates
                await exchangeRateService.forceUpdateToday(context: modelContext)

                // Force refresh historical rates (1 year)
                let calendar = Calendar.current
                let today = Date.now
                if let oneYearAgo = calendar.date(byAdding: .year, value: -1, to: today) {
                    let dateInterval = DateInterval(start: oneYearAgo, end: today)
                    await exchangeRateService.forceRefreshRates(for: dateInterval, context: modelContext)
                }

                // Signal widget to refresh with new preferred currency
                SessionState.shared.needsExchangeRateWidgetRefresh = true

                // Update widget cache with new currency values (must be on MainActor)
                await MainActor.run {
                    WidgetDataCache.updateCache(context: modelContext)
                }

            } catch {
                #if DEBUG
                print("CurrencySettingsView: Error updating transactions: \(error)")
                #endif
            }

            isUpdating = false
        }
    }
}

#Preview {
    NavigationStack {
        CurrencySettingsView()
    }
    .modelContainer(for: [Account.self, ExchangeRate.self])
    .previewAppPreferences()
}
