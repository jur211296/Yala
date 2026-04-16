//
//  PanelFilterAndWidgetsSection.swift
//  Yala
//
//  Extracted from PanelView to isolate ~40 observation tracking points.
//  Contains: period selector, filter chips, widget grid.
//  No closures — navigation via viewModel.navigateToStatistics().
//

import SwiftData
import SwiftUI

struct PanelFilterAndWidgetsSection: View {
    let viewModel: PanelViewModel
    let sessionState: SessionState
    let defaultCurrencyCodeRaw: String
    let showVariations: Bool
    @Binding var showWidgetPreferences: Bool
    @Binding var showCustomPeriodPicker: Bool
    @Binding var showBudgetFavoritesSettings: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Namespace para morphing de los filter chips (iOS 26 GlassEffectContainer + glassEffectID).
    @Namespace private var chipNamespace

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {

            // Unified Period Selector & Filters Row
            HStack(alignment: .center, spacing: DS.Spacing.md) {
                TrendsPeriodMenu(
                    selectedPeriod: sessionState.selectedPeriod,
                    customDateRange: sessionState.customDateRange,
                    onSelect: { period in
                        sessionState.selectedPeriod = period
                    },
                    onCustomTapped: {
                        showCustomPeriodPicker = true
                    }
                )

                // Filter chips (Scrollable to the right)
                let hasAccountFilter = viewModel.selectedAccountID != nil
                let hasDateFilter = viewModel.focusedDate != nil
                let hasCategoryFilter = viewModel.selectedCategoryID != nil
                let hasNeedFilter = viewModel.selectedNeed != nil
                let hasSubcategoryFilter = !viewModel.selectedSubcategoryIDs.isEmpty
                let hasTagFilter = !viewModel.selectedTags.isEmpty
                let hasCurrencyFilter = !viewModel.selectedCurrencies.isEmpty
                let hasAmountFilter = viewModel.amountCondition.isActive
                let hasNoteFilter = !viewModel.searchText.isEmpty
                let hasTransactionNatureFilter = sessionState.selectedTransactionNatures.count == 1

                let activeFilterCount = [
                    hasAccountFilter, hasDateFilter, hasCategoryFilter,
                    hasNeedFilter, hasSubcategoryFilter, hasTagFilter,
                    hasCurrencyFilter, hasAmountFilter, hasNoteFilter,
                    hasTransactionNatureFilter,
                ].count(where: { $0 })

                if activeFilterCount > 0 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        GlassEffectContainer(spacing: DS.Spacing.sm) {
                        HStack(spacing: DS.Spacing.sm) {
                            // Exclude mode badge
                            if viewModel.isExcludeMode {
                                HStack(spacing: DS.Spacing.xs) {
                                    Image(systemName: "minus.circle.fill")
                                        .font(DS.Typography.chipIconOnly)
                                        .foregroundStyle(DS.Semantic.errorForeground)
                                        .accessibilityHidden(true)
                                    Text(L10n.Filters.excludeMode)
                                        .font(DS.Typography.caption)
                                        .foregroundStyle(DS.Semantic.errorForeground)
                                }
                                .padding(.horizontal, DS.Spacing.sm)
                                .padding(.vertical, DS.Spacing.xs)
                                .background(DS.Semantic.errorBackgroundSubtle, in: Capsule())
                                .glassEffectID("chip.excludeMode", in: chipNamespace)
                            }

                            // Account Chip
                            if let selectedID = viewModel.selectedAccountID,
                                let account = viewModel.accounts.first(where: {
                                    $0.persistentModelID == selectedID
                                })
                            {
                                FilterChipView(
                                    accountName: account.name,
                                    onClear: { viewModel.selectedAccountID = nil }
                                )
                                .excludeMode(viewModel.isExcludeMode)
                                .glassEffectID("chip.account", in: chipNamespace)
                            }

                            // Date Chip
                            if let focusedDate = viewModel.focusedDate {
                                FilterChipView(
                                    text: L10n.Filters.datePrefix(formattedDate(focusedDate)),
                                    onClear: {
                                        dsWithAnimation(reduceMotion) {
                                            viewModel.focusedDate = nil
                                        }
                                    }
                                )
                                .glassEffectID("chip.date", in: chipNamespace)
                            }

                            // Category Chip
                            let selectedSubsByID = viewModel.allSubcategories.filter {
                                viewModel.selectedSubcategoryIDs.contains($0.persistentModelID)
                            }
                            let isAllSubsSelected =
                                !selectedSubsByID.isEmpty
                                && selectedSubsByID.count == viewModel.allSubcategories.count

                            if let categoryID = viewModel.selectedCategoryID,
                               let category = viewModel.topSpendingCategories.first(where: { $0.category.persistentModelID == categoryID })?.category {
                                FilterChipView(
                                    categoryName: category.name,
                                    iconName: category.iconName,
                                    colorHex: category.colorHex,
                                    count: 1,
                                    onClear: {
                                        viewModel.selectedCategoryID = nil
                                        viewModel.selectedSubcategoryIDs.removeAll()
                                        sessionState.selectedCategoryIDs.removeAll()
                                        sessionState.selectedSubcategoryIDs.removeAll()
                                    }
                                )
                                .excludeMode(viewModel.isExcludeMode)
                                .glassEffectID("chip.category", in: chipNamespace)
                            } else if !isAllSubsSelected && !selectedSubsByID.isEmpty {
                                let parentCategories = Set(
                                    selectedSubsByID.compactMap { $0.category })
                                if let firstCategory = parentCategories.first {
                                    FilterChipView(
                                        categoryName: firstCategory.name,
                                        iconName: firstCategory.iconName,
                                        colorHex: firstCategory.colorHex,
                                        count: parentCategories.count,
                                        onClear: {
                                            viewModel.selectedCategoryID = nil
                                            viewModel.selectedSubcategoryIDs.removeAll()
                                            sessionState.selectedCategoryIDs.removeAll()
                                            sessionState.selectedSubcategoryIDs.removeAll()
                                        }
                                    )
                                    .excludeMode(viewModel.isExcludeMode)
                                    .glassEffectID("chip.category", in: chipNamespace)
                                }
                            }

                            // Subcategory Chip
                            if !isAllSubsSelected && !selectedSubsByID.isEmpty {
                                if let firstSub = selectedSubsByID.first {
                                    let color =
                                        (firstSub.colorHex?.isEmpty == false
                                            ? firstSub.colorHex : nil)
                                        ?? firstSub.safeCategory.colorHex
                                    FilterChipView(
                                        subcategoryName: firstSub.name,
                                        iconName: firstSub.iconName,
                                        colorHex: color,
                                        count: selectedSubsByID.count,
                                        onClear: {
                                            viewModel.selectedSubcategoryIDs.removeAll()
                                            sessionState.selectedSubcategoryIDs.removeAll()
                                        }
                                    )
                                    .excludeMode(viewModel.isExcludeMode)
                                    .glassEffectID("chip.subcategory", in: chipNamespace)
                                }
                            }

                            // Nature Chip
                            if let need = viewModel.selectedNeed {
                                FilterChipView(
                                    need: need,
                                    onClear: {
                                        dsWithAnimation(reduceMotion) { viewModel.selectedNeed = nil }
                                    }
                                )
                                .excludeMode(viewModel.isExcludeMode)
                                .glassEffectID("chip.need", in: chipNamespace)
                            }

                            // Transaction Nature Chip
                            if sessionState.selectedTransactionNatures.count == 1,
                               let transactionNature = sessionState.selectedTransactionNatures.first {
                                FilterChipView(
                                    transactionNature: transactionNature,
                                    onClear: {
                                        dsWithAnimation(reduceMotion) {
                                            sessionState.selectedTransactionNatures.removeAll()
                                        }
                                    }
                                )
                                .glassEffectID("chip.nature", in: chipNamespace)
                            }

                            // Tag Chips
                            ForEach(Array(viewModel.selectedTags), id: \.self) { tagID in
                                if let tag = viewModel.tags.first(where: { $0.persistentModelID == tagID }) {
                                    FilterChipView(
                                        tagName: tag.name,
                                        iconName: tag.iconName,
                                        colorHex: tag.colorHex,
                                        onClear: {
                                            dsWithAnimation(reduceMotion) {
                                                viewModel.selectedTags.remove(tagID)
                                                viewModel.syncToSessionState(sessionState)
                                            }
                                        }
                                    )
                                    .excludeMode(viewModel.isExcludeMode)
                                    .glassEffectID("chip.tag.\(tagID.hashValue)", in: chipNamespace)
                                }
                            }

                            // Currency Chips
                            ForEach(Array(viewModel.selectedCurrencies), id: \.self) { currency in
                                FilterChipView(
                                    currencyCode: currency.rawValue,
                                    onClear: {
                                        dsWithAnimation(reduceMotion) {
                                            viewModel.selectedCurrencies.remove(currency)
                                            viewModel.syncToSessionState(sessionState)
                                        }
                                    }
                                )
                                .excludeMode(viewModel.isExcludeMode)
                                .glassEffectID("chip.currency.\(currency.rawValue)", in: chipNamespace)
                            }

                            // Amount Chip
                            if viewModel.amountCondition.isActive {
                                FilterChipView(
                                    amountText: viewModel.amountCondition.displayText,
                                    onClear: {
                                        dsWithAnimation(reduceMotion) {
                                            viewModel.amountCondition = .any
                                            viewModel.syncToSessionState(sessionState)
                                        }
                                    }
                                )
                                .glassEffectID("chip.amount", in: chipNamespace)
                            }

                            // Note/Search Chip
                            if !viewModel.searchText.isEmpty {
                                FilterChipView(
                                    noteText: viewModel.searchText,
                                    onClear: {
                                        dsWithAnimation(reduceMotion) {
                                            viewModel.searchText = ""
                                            viewModel.syncToSessionState(sessionState)
                                        }
                                    }
                                )
                                .glassEffectID("chip.note", in: chipNamespace)
                            }

                            // Clear All Button
                            if activeFilterCount > 1 {
                                Button {
                                    dsWithAnimation(reduceMotion) {
                                        clearAllPanelFilters()
                                    }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .accessibilityLabel(L10n.Accessibility.clearFilters)
                                .buttonStyle(.plain)
                                .glassEffectID("chip.clearAll", in: chipNamespace)
                            }
                        }
                        } // GlassEffectContainer
                    }
                    .contentMargins(.horizontal, DS.Spacing.md, for: .scrollContent)
                    .scrollClipDisabled()
                } else {
                    Spacer()
                }
            }
            .padding(.bottom, DS.Spacing.sm)

            // Thematic sections. `onPreferences` is wired only on Tendencias for
            // now; it opens the global widget preferences sheet (shared across all
            // sections) until per-section sheets arrive.
            ForEach(PanelSectionKind.allCases, id: \.self) { kind in
                PanelThematicSection(
                    kind: kind,
                    viewModel: viewModel,
                    sessionState: sessionState,
                    defaultCurrencyCodeRaw: defaultCurrencyCodeRaw,
                    showVariations: showVariations,
                    showBudgetFavoritesSettings: $showBudgetFavoritesSettings,
                    onPreferences: kind == .tendencias
                        ? { showWidgetPreferences = true }
                        : nil
                )
            }
        }
    }

    // MARK: - Helpers

    private static let chipDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = AppLocale.current
        f.dateFormat = "d MMM"
        return f
    }()

    private func formattedDate(_ date: Date) -> String {
        Self.chipDateFormatter.string(from: date)
    }

    private func clearAllPanelFilters() {
        viewModel.selectedAccountID = nil
        viewModel.focusedDate = nil
        viewModel.selectedCategoryID = nil
        viewModel.selectedSubcategoryIDs.removeAll()
        viewModel.subcategoriesWidgetFilter = nil
        viewModel.selectedNeed = nil
        viewModel.selectedTags.removeAll()
        viewModel.selectedCurrencies.removeAll()
        viewModel.amountCondition = .any
        viewModel.searchText = ""
        sessionState.selectedTransactionNatures.removeAll()
        viewModel.syncToSessionState(sessionState)
    }
}
